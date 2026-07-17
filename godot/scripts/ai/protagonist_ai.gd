class_name ProtagonistAI
extends CharacterBody2D
## Atiende pedidos (teleport con flash mágico), deambula sólo dentro de su zona
## actual, rota su sitio favorito, suelta burbujas con emojis. Click izquierdo:
## drag estilo Tomodachi. No cruza zonas caminando — sólo si la arrastrás.

@export var move_speed: float = 110.0
@export var arrival_distance: float = 8.0
@export var home_position_offset: Vector2 = Vector2.ZERO

enum State { IDLE_HOME, DELIVERING, RETURNING, DRAGGING, WANDERING }

const DRAG_FOLLOW_SMOOTH: float = 0.35
const PICK_RADIUS: float = 50.0
const PICK_OFFSET_Y: float = -48.0
const WANDER_IDLE_DELAY_MIN: float = 6.0
const WANDER_IDLE_DELAY_MAX: float = 12.0
const WANDER_LINGER_MIN: float = 2.5
const WANDER_LINGER_MAX: float = 5.0
const FAVORITE_ROTATE_SECONDS: float = 180.0
const BUBBLE_BASE_Y: float = -64.0
const PLAYABLE_MARGIN: float = 20.0
const DELIVER_DURATION: float = 0.7
const IDLE_EMOJIS := ["♪", "♫", "✨", "★", "☕", "♥", "🌙", "🍀", "💭", "🌸"]

var state: State = State.IDLE_HOME
var home_position: Vector2 = Vector2.ZERO
var _current_customer = null
var _anim_sprite: AnimatedSprite2D = null
var _sprite_base_scale: Vector2 = Vector2.ONE
var _facing_x: float = 1.0
var _facing: StringName = &"down"  ## down/up/side — dirección actual del sprite
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_zone_rect: Rect2 = Rect2()  ## zona (suelo) donde empezó el drag; confina el arrastre para no soltar sobre la pared
var _wobble_tween: Tween = null
var _idle_timer: float = 0.0
var _wander_idle_delay: float = 8.0
var _wander_target: Vector2 = Vector2.ZERO
var _linger_timer: float = 0.0
var _favorite_rotate_timer: float = 0.0
var _delivering_timer: float = 0.0
var _bubble_label: Label = null
var _bubble_tween: Tween = null


func _ready() -> void:
	add_to_group("protagonist")
	CharShadow.attach(self, 24.0)
	home_position = global_position + home_position_offset
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _anim_sprite != null:
		_sprite_base_scale = _anim_sprite.scale
	_create_bubble()
	_wander_idle_delay = randf_range(WANDER_IDLE_DELAY_MIN, WANDER_IDLE_DELAY_MAX)
	call_deferred("_wire_zone_switch")


func _wire_zone_switch() -> void:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_signal("zone_changed"):
		cam.zone_changed.connect(_on_zone_switched)


const _ZONE_BY_NAME: Dictionary = {
	&"natural": GameEnums.ZoneType.NATURE,
	&"taller": GameEnums.ZoneType.WORKSHOP,
	&"recepcion": GameEnums.ZoneType.RECEPTION,
}


## Si cambias de zona (Q/E) mientras la arrastras, la protagonista y el ratón
## saltan al centro de la nueva zona y el drag continúa allí — así no queda
## trabada en la pared ni cae en la oscuridad entre zonas.
func _on_zone_switched(zone_name: StringName) -> void:
	if state != State.DRAGGING:
		return
	var rect: Rect2 = GridManager.get_zone_rect(_ZONE_BY_NAME.get(zone_name, -1))
	if rect.size == Vector2.ZERO:
		return
	_drag_zone_rect = rect
	global_position = rect.get_center()
	_drag_offset = Vector2.ZERO
	# Warp del ratón a donde quedó ella en pantalla (esperar a que la cámara asiente).
	await get_tree().process_frame
	if state == State.DRAGGING:
		get_viewport().warp_mouse(get_global_transform_with_canvas().origin)


func _create_bubble() -> void:
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 22)
	_bubble_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_bubble_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15, 0.7))
	_bubble_label.add_theme_constant_override("outline_size", 4)
	_bubble_label.position = Vector2(-14.0, BUBBLE_BASE_Y)
	_bubble_label.z_index = 20
	_bubble_label.modulate.a = 0.0
	_bubble_label.pivot_offset = Vector2(11, 14)
	add_child(_bubble_label)


func say(emoji: String, lift: float = 28.0) -> void:
	if _bubble_label == null:
		return
	_bubble_label.text = emoji
	_bubble_label.position = Vector2(-14.0, BUBBLE_BASE_Y)
	_bubble_label.scale = Vector2(0.4, 0.4)
	_bubble_label.modulate.a = 0.0
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble_label, "modulate:a", 1.0, 0.22)
	_bubble_tween.parallel().tween_property(_bubble_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.parallel().tween_property(_bubble_label, "position:y", BUBBLE_BASE_Y - lift, 1.4).set_trans(Tween.TRANS_QUAD)
	_bubble_tween.tween_property(_bubble_label, "modulate:a", 0.0, 0.5)


func _physics_process(_delta: float) -> void:
	_favorite_rotate_timer += _delta
	if _favorite_rotate_timer >= FAVORITE_ROTATE_SECONDS:
		_favorite_rotate_timer = 0.0
		_rotate_favorite_home()
	# Cliente toma prioridad. No interrumpe drag ni delivering (a medio teleport).
	if state != State.DRAGGING and state != State.DELIVERING:
		_try_pickup_task()
	match state:
		State.IDLE_HOME:
			velocity = Vector2.ZERO
			_idle_timer += _delta
			if _idle_timer >= _wander_idle_delay:
				_idle_timer = 0.0
				_wander_idle_delay = randf_range(WANDER_IDLE_DELAY_MIN, WANDER_IDLE_DELAY_MAX)
				_start_wander()
		State.DELIVERING:
			velocity = Vector2.ZERO
			_delivering_timer -= _delta
			if _delivering_timer <= 0.0:
				_complete_delivery_and_return()
		State.RETURNING:
			_move_toward(home_position)
			if global_position.distance_to(home_position) <= arrival_distance:
				global_position = home_position
				state = State.IDLE_HOME
				velocity = Vector2.ZERO
		State.DRAGGING:
			velocity = Vector2.ZERO
			var target: Vector2 = _clamp_to_rect(get_global_mouse_position() + _drag_offset, _drag_zone_rect)
			global_position = global_position.lerp(target, DRAG_FOLLOW_SMOOTH)
		State.WANDERING:
			if _linger_timer > 0.0:
				velocity = Vector2.ZERO
				_linger_timer -= _delta
				if _linger_timer <= 0.0:
					say(IDLE_EMOJIS[randi() % IDLE_EMOJIS.size()])
					state = State.RETURNING
			else:
				_move_toward(_wander_target)
				if global_position.distance_to(_wander_target) <= arrival_distance + 6.0:
					_linger_timer = randf_range(WANDER_LINGER_MIN, WANDER_LINGER_MAX)
	_update_anim()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if state == State.DRAGGING:
		if not event.pressed:
			_end_drag()
			get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if BuildManager.is_active():
		return
	var pick_point: Vector2 = global_position + Vector2(0.0, PICK_OFFSET_Y)
	if get_global_mouse_position().distance_to(pick_point) > PICK_RADIUS:
		return
	_begin_drag()
	get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	_current_customer = null
	_drag_offset = global_position - get_global_mouse_position()
	# Confina el arrastre al suelo de la zona actual (excluye la pared).
	_drag_zone_rect = GridManager.get_zone_rect_at(global_position)
	if _drag_zone_rect.size == Vector2.ZERO:
		_drag_zone_rect = GridManager.get_playable_rect()
	state = State.DRAGGING
	velocity = Vector2.ZERO
	_idle_timer = 0.0
	say("!", 18.0)
	_start_lift_visual()


func _end_drag() -> void:
	global_position = _clamp_to_rect(global_position, _drag_zone_rect)
	home_position = global_position
	state = State.IDLE_HOME
	_idle_timer = 0.0
	say("✨")
	_start_land_visual()


func _start_wander() -> void:
	_wander_target = _pick_wander_point()
	state = State.WANDERING


func _pick_wander_point() -> Vector2:
	# Wander queda confinado a la zona donde está parada. No cruza por voluntad propia.
	var zone_rect: Rect2 = GridManager.get_zone_rect_at(global_position)
	if zone_rect.size == Vector2.ZERO:
		zone_rect = GridManager.get_playable_rect()
	var stations: Array = get_tree().get_nodes_in_group("workstations")
	if not stations.is_empty() and randf() < 0.55:
		var in_zone: Array = []
		for st in stations:
			if zone_rect.has_point((st as Node2D).global_position):
				in_zone.append(st)
		if not in_zone.is_empty():
			var st: Node2D = in_zone[randi() % in_zone.size()] as Node2D
			var candidate: Vector2 = st.global_position + Vector2(randf_range(-26.0, 26.0), randf_range(8.0, 28.0))
			return _clamp_to_rect(candidate, zone_rect)
	var min_p: Vector2 = zone_rect.position + Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	var max_p: Vector2 = zone_rect.position + zone_rect.size - Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	return Vector2(randf_range(min_p.x, max_p.x), randf_range(min_p.y, max_p.y))


func _rotate_favorite_home() -> void:
	# La nueva casa también respeta la zona actual.
	var zone_rect: Rect2 = GridManager.get_zone_rect_at(global_position)
	var stations: Array = get_tree().get_nodes_in_group("workstations")
	if stations.is_empty():
		return
	var in_zone: Array = []
	for st in stations:
		if zone_rect.size == Vector2.ZERO or zone_rect.has_point((st as Node2D).global_position):
			in_zone.append(st)
	if in_zone.is_empty():
		return
	var st: Node2D = in_zone[randi() % in_zone.size()] as Node2D
	if st == null:
		return
	home_position = _clamp_to_playable(st.global_position + Vector2(randf_range(-20.0, 20.0), 32.0))
	say("✨", 32.0)


func _start_lift_visual() -> void:
	if _anim_sprite == null:
		return
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	_anim_sprite.modulate = Color(1.15, 1.05, 1.25)
	var lift := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(_anim_sprite, "scale", _sprite_base_scale * 1.15, 0.18)
	lift.tween_property(_anim_sprite, "position:y", -8.0, 0.18)
	_wobble_tween = create_tween().set_loops()
	_wobble_tween.tween_property(_anim_sprite, "rotation", deg_to_rad(10.0), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(_anim_sprite, "rotation", deg_to_rad(-10.0), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_land_visual() -> void:
	if _anim_sprite == null:
		return
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	var land := create_tween().set_parallel(true)
	land.tween_property(_anim_sprite, "rotation", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	land.tween_property(_anim_sprite, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	land.tween_property(_anim_sprite, "modulate", Color.WHITE, 0.25)
	var squash := create_tween()
	squash.tween_property(_anim_sprite, "scale", _sprite_base_scale * Vector2(1.2, 0.85), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	squash.tween_property(_anim_sprite, "scale", _sprite_base_scale * Vector2(0.92, 1.1), 0.09).set_trans(Tween.TRANS_QUAD)
	squash.tween_property(_anim_sprite, "scale", _sprite_base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_teleport() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.modulate = Color(2.4, 2.0, 2.8, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_anim_sprite, "modulate", Color.WHITE, 0.45)
	tw.tween_property(_anim_sprite, "scale", _sprite_base_scale * 1.15, 0.08).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_property(_anim_sprite, "scale", _sprite_base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_anim() -> void:
	if _anim_sprite == null:
		return
	if state == State.DRAGGING or state == State.DELIVERING:
		if _anim_sprite.animation != &"idle_down":
			_anim_sprite.play(&"idle_down")
		return
	var moving: bool = velocity.length_squared() > 4.0
	# Elegir dirección por el eje dominante del movimiento (4 direcciones).
	if moving:
		if absf(velocity.x) > absf(velocity.y):
			_facing = &"side"
			_facing_x = signf(velocity.x)
		else:
			_facing = &"down" if velocity.y > 0.0 else &"up"
	_anim_sprite.flip_h = _facing == &"side" and _facing_x < 0.0
	var prefix: StringName = &"walk_" if moving else &"idle_"
	var want: StringName = prefix + _facing
	if _anim_sprite.animation != want:
		_anim_sprite.play(want)


func _try_pickup_task() -> void:
	# Si el jugador apagó auto_orders, el protagonista no agarra tareas y se
	# convierte en pet/decoración. La entrega manual sigue posible via la UI.
	if not IdleAutomationManager.auto_orders:
		return
	var order: OrderData = OrderManager.get_current_order()
	if order == null or order.requested_item == null:
		return
	if InventoryManager.get_item_count(order.requested_item) < order.requested_quantity:
		return
	var customer = OrderManager.get_current_customer()
	if not is_instance_valid(customer) or customer.state != GameEnums.WorkerState.WAITING:
		return
	_current_customer = customer
	_idle_timer = 0.0
	_start_delivery_teleport()


func _start_delivery_teleport() -> void:
	state = State.DELIVERING
	say("✨", 32.0)
	var dest: Vector2 = (_current_customer as Node2D).global_position
	global_position = dest + Vector2(arrival_distance + 8.0, 0.0)
	velocity = Vector2.ZERO
	_flash_teleport()
	_delivering_timer = DELIVER_DURATION


func _complete_delivery_and_return() -> void:
	if is_instance_valid(_current_customer):
		if OrderManager.try_complete_current():
			print("[Protagonist] Pedido entregado.")
	say("♥", 32.0)
	_current_customer = null
	# Teleport de regreso a casa para no cruzar zonas caminando.
	global_position = home_position
	velocity = Vector2.ZERO
	_flash_teleport()
	say("✨", 28.0)
	state = State.IDLE_HOME
	_idle_timer = 0.0


func _move_toward(target_pos: Vector2) -> void:
	velocity = (target_pos - global_position).normalized() * move_speed
	move_and_slide()


func _clamp_to_playable(pos: Vector2) -> Vector2:
	var r: Rect2 = GridManager.get_playable_rect()
	if r.size == Vector2.ZERO:
		return pos
	return _clamp_to_rect(pos, r)


func _clamp_to_rect(pos: Vector2, r: Rect2) -> Vector2:
	if r.size == Vector2.ZERO:
		return pos
	var min_p: Vector2 = r.position + Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	var max_p: Vector2 = r.position + r.size - Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	return Vector2(clamp(pos.x, min_p.x, max_p.x), clamp(pos.y, min_p.y, max_p.y))
