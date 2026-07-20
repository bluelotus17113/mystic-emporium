class_name ProtagonistAI
extends CharacterBody2D
## Atiende pedidos (teleport con flash mágico), deambula sólo dentro de su zona
## actual, rota su sitio favorito, suelta burbujas con emojis. Click izquierdo:
## drag estilo Tomodachi. No cruza zonas caminando — sólo si la arrastrás.

@export var move_speed: float = 110.0
@export var arrival_distance: float = 8.0
@export var home_position_offset: Vector2 = Vector2.ZERO

enum State { IDLE_HOME, DELIVERING, RETURNING, DRAGGING, WANDERING, CHASING_CAT, THROUGH_DOOR }

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
const THOUGHTS_DAY := ["qué paz ☕", "buen día ☀", "¿un té? 🍵", "todo en calma"]
const THOUGHTS_NIGHT := ["a descansar 🌙", "qué tranquilo", "buenas noches ✨"]
const THOUGHTS_SEASON := {
	3: ["qué frío ❄", "brr… 🧣"],   # WINTER
	2: ["hojas 🍂", "huele a otoño"], # AUTUMN
	0: ["flores 🌸", "qué primavera"],# SPRING
	1: ["calorcito ☀", "verano 🍉"],  # SUMMER
}

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
var _wander_poi: StringName = &""   ## tipo de sitio al que va (para micro-emote)
var _curiosity_point: Vector2 = Vector2.ZERO
var _has_curiosity: bool = false    ## acaban de construir algo → va a fisgonear
var _look_scan: float = 0.0
var _cat_react_cd: float = 0.0
# --- combate de asedio ---
const PROTA_MAX_HP: float = 120.0
const P_COMBAT_AGGRO: float = 250.0
const P_MELEE_RANGE: float = 42.0
const P_MELEE_DAMAGE: float = 22.0
const P_MELEE_INTERVAL: float = 0.6
const DOWN_COOLDOWN: float = 300.0  ## 5 min derribada (no muere)
var _combat_hb: HealthBar = null
var _downed: bool = false
var _down_cd: float = 0.0
var _pmelee_cd: float = 0.0
## Estado de ánimo 0..1: sube con cosas buenas (ventas, mimos), baja poco a poco.
var mood: float = 0.6
const MOOD_BASELINE: float = 0.55
var _mood_emote_cd: float = 12.0
var _chase_cat: Node2D = null
var _chase_timer: float = 0.0
var _linger_timer: float = 0.0
var _wander_watchdog: float = 0.0
var _favorite_rotate_timer: float = 0.0
var _delivering_timer: float = 0.0
var _bubble_label: Label = null
var _bubble_tween: Tween = null
var _step_accum: float = 0.0
var _door_node: ZoneDoor = null       ## puerta que va a cruzar
var _door_approach: Vector2 = Vector2.ZERO
var _door_watchdog: float = 0.0


func _ready() -> void:
	add_to_group("protagonist")
	CharShadow.attach(self, 24.0)
	home_position = global_position + home_position_offset
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _anim_sprite != null:
		_sprite_base_scale = _anim_sprite.scale
	# Combate de asedio: vida y derribo (no muere, cooldown de 5 min).
	_combat_hb = HealthBar.new()
	add_child(_combat_hb)
	_combat_hb.setup(PROTA_MAX_HP, -62.0, false)
	_combat_hb.died.connect(_enter_downed)
	_create_bubble()
	_wander_idle_delay = randf_range(WANDER_IDLE_DELAY_MIN, WANDER_IDLE_DELAY_MAX)
	call_deferred("_wire_zone_switch")
	WardrobeManager.outfit_changed.connect(_on_outfit_changed)
	if WardrobeManager.current_outfit != &"default":
		_on_outfit_changed(WardrobeManager.current_outfit)
	InventoryManager.coins_changed.connect(_on_coins_changed_fx)
	if OrderManager.has_signal("order_completed"):
		OrderManager.order_completed.connect(_on_order_celebrate)
	if OrderManager.has_signal("order_expired"):
		OrderManager.order_expired.connect(func(_o): _add_mood(-0.18))
	if BuildManager.has_signal("placement_completed"):
		BuildManager.placement_completed.connect(_on_new_build)


var _last_coins_seen: int = -1

## Monedas flotantes cuando entran ⚜ (ventas, logros): feedback en la protagonista.
func _on_coins_changed_fx(total: int) -> void:
	if _last_coins_seen < 0:
		_last_coins_seen = total
		return
	var diff: int = total - _last_coins_seen
	_last_coins_seen = total
	if diff > 0:
		FloatingText.spawn(self, "+%d ⚜" % diff, Color(1.0, 0.86, 0.36))


## Cambia la hoja de sprites al outfit elegido (mismo layout 512x384:
## idle 4 / walk 8 × down/up/side). Con destello mágico.
func _on_outfit_changed(outfit_id: StringName) -> void:
	if _anim_sprite == null:
		return
	var tex: Texture2D = load(WardrobeManager.sheet_path(outfit_id))
	if tex == null:
		return
	var rows: Array = [
		[&"idle_down", 0, 4, 6.0], [&"walk_down", 1, 8, 8.0],
		[&"idle_up", 2, 4, 6.0], [&"walk_up", 3, 8, 8.0],
		[&"idle_side", 4, 4, 6.0], [&"walk_side", 5, 8, 8.0]]
	var sf := SpriteFrames.new()
	for r in rows:
		var anim: StringName = r[0]
		sf.add_animation(anim)
		sf.set_animation_loop(anim, true)
		sf.set_animation_speed(anim, r[3])
		for c in range(r[2]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(c * 64, r[1] * 64, 64, 64)
			sf.add_frame(anim, at)
	sf.remove_animation(&"default")
	var playing: StringName = _anim_sprite.animation
	_anim_sprite.sprite_frames = sf
	if sf.has_animation(playing):
		_anim_sprite.play(playing)
	else:
		_anim_sprite.play(&"idle_down")
	VFXManager.play(VFXManager.FX.BUILD, global_position)


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


## Mezcla emojis sueltos con frases cozy contextuales (hora/estación).
func _cozy_thought() -> String:
	if randf() < 0.5:
		return IDLE_EMOJIS[randi() % IDLE_EMOJIS.size()]
	var pool: Array = []
	pool += THOUGHTS_NIGHT if CalendarManager.is_night() else THOUGHTS_DAY
	if THOUGHTS_SEASON.has(CalendarManager.current_season):
		pool += THOUGHTS_SEASON[CalendarManager.current_season]
	return pool[randi() % pool.size()] if not pool.is_empty() else "♪"


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


var _breath_cd: float = 0.0

func _physics_process(_delta: float) -> void:
	_favorite_rotate_timer += _delta
	if _favorite_rotate_timer >= FAVORITE_ROTATE_SECONDS:
		_favorite_rotate_timer = 0.0
		_rotate_favorite_home()
	# Vaho en invierno.
	if CalendarManager.current_season == CalendarManager.Season.WINTER:
		_breath_cd -= _delta
		if _breath_cd <= 0.0:
			_breath_cd = randf_range(3.5, 6.5)
			BreathPuff.spawn(self, Vector2(_facing_x * 5.0, -44.0))
	_tick_mood(_delta)
	# Derribada: inactiva mientras se recupera (cooldown 5 min).
	if _downed:
		_down_cd -= _delta
		velocity = Vector2.ZERO
		if _down_cd <= 0.0:
			_recover()
		return
	# Durante un asedio, defender manda (salvo si la estás arrastrando/entregando).
	if SiegeManager.is_active() and state != State.DRAGGING and state != State.DELIVERING and _siege_combat(_delta):
		_update_anim()
		return
	# Cliente toma prioridad. No interrumpe drag ni delivering (a medio teleport).
	if state != State.DRAGGING and state != State.DELIVERING:
		_try_pickup_task()
	match state:
		State.IDLE_HOME:
			velocity = Vector2.ZERO
			_look_at_nearest(_delta)
			_idle_timer += _delta
			if _idle_timer >= _wander_idle_delay:
				_idle_timer = 0.0
				var dark: float = CalendarManager.get_darkness()
				_wander_idle_delay = randf_range(WANDER_IDLE_DELAY_MIN, WANDER_IDLE_DELAY_MAX) * (1.0 + 1.8 * dark)
				if dark > 0.7 and randf() < 0.5:
					say(["😴", "🌙", "💤"].pick_random())  # de noche a veces solo bosteza
				else:
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
			# Seguir al ratón CON física: así también al arrastrarla choca con
			# los objetos sólidos en vez de atravesarlos.
			var target: Vector2 = _clamp_to_rect(get_global_mouse_position() + _drag_offset, _drag_zone_rect)
			velocity = (target - global_position) * 14.0
			move_and_slide()
		State.WANDERING:
			if _linger_timer > 0.0:
				velocity = Vector2.ZERO
				_linger_timer -= _delta
				if _linger_timer <= 0.0:
					state = State.RETURNING
			else:
				_move_toward(_wander_target)
				_wander_watchdog += _delta
				if global_position.distance_to(_wander_target) <= arrival_distance + 6.0 \
						or _wander_watchdog > 7.0:
					_wander_watchdog = 0.0
					_linger_timer = randf_range(WANDER_LINGER_MIN, WANDER_LINGER_MAX)
					_poi_emote()  # micro-interacción al llegar
		State.CHASING_CAT:
			_chase_timer -= _delta
			if _chase_cat == null or not is_instance_valid(_chase_cat) or _chase_timer <= 0.0:
				_chase_cat = null
				state = State.RETURNING
			else:
				var cd: Vector2 = _chase_cat.global_position - global_position
				if cd.length() > 34.0:
					_move_toward(_chase_cat.global_position)
				else:
					velocity = Vector2.ZERO
		State.THROUGH_DOOR:
			if _door_node == null or not is_instance_valid(_door_node):
				velocity = Vector2.ZERO
				state = State.IDLE_HOME
			else:
				_move_toward(_door_approach)
				_door_watchdog += _delta
				if global_position.distance_to(_door_approach) <= arrival_distance + 6.0 \
						or _door_watchdog > 6.0:
					_pass_through_door()
	_update_anim()
	_tick_footsteps(_delta)


## Pasos suaves mientras camina (rate por ciclo de paso, pitch variado).
func _tick_footsteps(delta: float) -> void:
	if velocity.length_squared() <= 4.0:
		_step_accum = 0.12  # primer paso suena pronto al arrancar
		return
	_step_accum -= delta
	if _step_accum <= 0.0:
		_step_accum = 0.34
		AudioManager.play_positional(&"footstep", global_position, 0.22)
		FootDust.spawn(self)
		FootPrint.maybe(self)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	# Clic derecho sobre ella → menú de acciones (sin pisar el drag de clic izq).
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and state != State.DRAGGING:
		var pp: Vector2 = global_position + Vector2(0.0, PICK_OFFSET_Y)
		if not _in_build_mode() and get_global_mouse_position().distance_to(pp) <= PICK_RADIUS:
			_open_menu()
			get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
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


func _add_mood(x: float) -> void:
	mood = clampf(mood + x, 0.0, 1.0)


func _tick_mood(delta: float) -> void:
	mood = lerpf(mood, MOOD_BASELINE, delta * 0.015)
	_mood_emote_cd -= delta
	if _mood_emote_cd <= 0.0:
		_mood_emote_cd = randf_range(18.0, 34.0)
		if state == State.IDLE_HOME or state == State.WANDERING:
			if mood >= 0.75:
				say(["♪", "😄", "✨"].pick_random())
			elif mood < 0.3:
				say(["😔", "💤", "…"].pick_random())


func _mood_label() -> String:
	if mood >= 0.8:
		return "😄 Feliz"
	if mood >= 0.55:
		return "🙂 Contenta"
	if mood >= 0.3:
		return "😐 Normal"
	return "😔 Desanimada"


func _menu_chase_cat() -> void:
	var cat: Node2D = get_tree().get_first_node_in_group("pets")
	if cat == null or not is_instance_valid(cat):
		say("?")
		return
	if global_position.distance_to(cat.global_position) > 1500.0:
		say("🐾…")  # el gato está en otra zona, muy lejos
		return
	_chase_cat = cat
	_chase_timer = 12.0
	state = State.CHASING_CAT
	say(["🐾", "♥", "😸"].pick_random())
	_add_mood(0.1)


func _menu_goto_zone(zone_name: StringName) -> void:
	var zt: int = _ZONE_BY_NAME.get(zone_name, -1)
	var rect: Rect2 = GridManager.get_zone_rect(zt)
	if rect.size == Vector2.ZERO:
		return
	global_position = _clamp_to_rect(rect.get_center() + Vector2(0, 40), rect)
	home_position = global_position
	velocity = Vector2.ZERO
	state = State.IDLE_HOME
	_idle_timer = 0.0
	_flash_teleport()
	say("✨")
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("goto_zone"):
		cam.goto_zone(zone_name)


## Una puerta pide que la maga la cruce: camina hasta ella y al llegar viaja a
## la zona destino (destello + reubicación en la puerta hermana + cámara).
func walk_through_door(door: ZoneDoor) -> void:
	if state == State.DRAGGING or state == State.DELIVERING:
		return
	if door == null or not is_instance_valid(door):
		return
	_door_node = door
	var dzr: Rect2 = GridManager.get_zone_rect_at(door.global_position)
	var ap: Vector2 = door.global_position + Vector2(0.0, 8.0)
	_door_approach = _clamp_to_rect(ap, dzr) if dzr.size != Vector2.ZERO else ap
	# Si estuviera en otra zona (raro), aparece de una frente a la puerta.
	if dzr.size != Vector2.ZERO and not dzr.has_point(global_position):
		global_position = _door_approach
		_flash_teleport()
	_door_watchdog = 0.0
	_idle_timer = 0.0
	state = State.THROUGH_DOOR
	say(["🚪", "✨", "🚶"].pick_random())


func _pass_through_door() -> void:
	var door: ZoneDoor = _door_node
	_door_node = null
	if door == null or not is_instance_valid(door):
		state = State.IDLE_HOME
		return
	var dest_door: ZoneDoor = door.linked_portal()
	if dest_door == null:
		# Portal huérfano (su pareja fue demolida): no viaja.
		say("❓")
		state = State.IDLE_HOME
		return
	door.open_flash()
	var target: StringName = door.dest_zone_name()
	var rect: Rect2 = GridManager.get_zone_rect(_ZONE_BY_NAME.get(target, -1))
	var dest: Vector2 = dest_door.global_position + Vector2(0.0, 8.0)
	if rect.size != Vector2.ZERO:
		dest = _clamp_to_rect(dest, rect)
	global_position = dest
	home_position = dest
	velocity = Vector2.ZERO
	_idle_timer = 0.0
	state = State.IDLE_HOME
	_flash_teleport()
	say("✨")
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if target != &"" and cam != null and cam.has_method("goto_zone"):
		cam.goto_zone(target)


func _in_build_mode() -> bool:
	return BuildManager.is_active() or BuildManager.is_move_active() \
			or BuildManager.is_rotate_active() or BuildManager.is_demolish_active() \
			or BuildManager.is_copy_active()


## Menú contextual de la protagonista (clic derecho). Reusa el entity_menu.
func _open_menu() -> void:
	var menu: Node = get_tree().get_first_node_in_group("entity_menu")
	if menu == null or not menu.has_method("open_for"):
		return
	var auto: bool = IdleAutomationManager.auto_orders
	menu.open_for(self, "🧙 Protagonista · %s" % _mood_label(), [
		{"text": "🐾 Perseguir al gato", "cb": Callable(self, "_menu_chase_cat")},
		{"text": "🔨 Ir al Taller", "cb": Callable(self, "_menu_goto_zone").bind(&"taller")},
		{"text": "🛎 Ir a Recepción", "cb": Callable(self, "_menu_goto_zone").bind(&"recepcion")},
		{"text": "🌳 Ir al Patio", "cb": Callable(self, "_menu_goto_zone").bind(&"natural")},
		{"text": "🎀 Vestuario", "cb": Callable(self, "_menu_wardrobe")},
		{"text": "🛎 Auto-pedidos: %s" % ("ON" if auto else "OFF"), "cb": Callable(self, "_menu_toggle_orders")},
		{"text": "😴 Descansa un poco", "cb": Callable(self, "_menu_rest")},
		{"text": "✨ Anímala", "cb": Callable(self, "_menu_cheer")},
	], Callable(self, "_stats_data"), _portrait_texture())


## Stats para el menú: ánimo (mood) + actividad actual.
func _stats_data() -> Array:
	var m: float = clampf(mood, 0.0, 1.0)
	var mcol: Color = Color(0.45, 0.85, 0.4)
	if m <= 0.3:
		mcol = Color(0.9, 0.4, 0.4)
	elif m <= 0.55:
		mcol = Color(0.9, 0.8, 0.35)
	return [
		{"label": "Ánimo", "ratio": m, "color": mcol, "value_text": _mood_label()},
		{"label": "Ahora", "text": _proto_state_label()},
	]


func _proto_state_label() -> String:
	match state:
		State.IDLE_HOME: return "😌 En su sitio"
		State.DELIVERING: return "📦 Entregando"
		State.RETURNING: return "↩ Volviendo"
		State.DRAGGING: return "✋ En tu mano"
		State.WANDERING: return "🚶 Paseando"
		State.CHASING_CAT: return "🐾 Tras el gato"
		State.THROUGH_DOOR: return "🌀 Al portal"
		_: return "…"


func _portrait_texture() -> Texture2D:
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(_anim_sprite.animation):
		return _anim_sprite.sprite_frames.get_frame_texture(_anim_sprite.animation, _anim_sprite.frame)
	return null


func _menu_wardrobe() -> void:
	UIManager.open(&"wardrobe")


func _menu_toggle_orders() -> void:
	IdleAutomationManager.auto_orders = not IdleAutomationManager.auto_orders
	var on: bool = IdleAutomationManager.auto_orders
	say("🛎" if on else "🚫")
	NotificationManager.post("Auto-pedidos %s." % ("activados" if on else "pausados"), NotificationManager.Kind.INFO)


func _menu_rest() -> void:
	if state == State.DRAGGING or state == State.DELIVERING:
		return
	say("😴", 24.0)
	state = State.RETURNING  # vuelve a su sitio a descansar
	_add_mood(0.1)


func _menu_cheer() -> void:
	say(["♥", "😊", "✨", "♪"].pick_random(), 30.0)
	_start_land_visual()  # rebotecito alegre
	_add_mood(0.2)


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


## Al construir algo en su zona, le pica la curiosidad y va a inspeccionarlo.
func _on_new_build(_buildable, pos: Vector2) -> void:
	var zr: Rect2 = GridManager.get_zone_rect_at(global_position)
	if zr.size != Vector2.ZERO and not zr.has_point(pos):
		return  # solo fisgonea cosas de su propia zona (no cruza paredes)
	_curiosity_point = pos
	_has_curiosity = true
	_add_mood(0.05)
	if state == State.IDLE_HOME:  # que vaya prontito
		_idle_timer = maxf(_idle_timer, _wander_idle_delay - 1.0)


func _start_wander() -> void:
	# Prioridad: si hay algo nuevo construido, ir a inspeccionarlo.
	if _has_curiosity:
		_has_curiosity = false
		var zr: Rect2 = GridManager.get_zone_rect_at(global_position)
		var p: Vector2 = _curiosity_point + Vector2(0.0, 30.0)
		_wander_target = _clamp_to_rect(p, zr) if zr.size != Vector2.ZERO else p
		_wander_poi = &"new"
		state = State.WANDERING
		return
	_wander_target = _pick_wander_point()
	state = State.WANDERING


## Estando quieta, se orienta hacia lo mas cercano interesante (gato/cliente/worker).
func _look_at_nearest(delta: float) -> void:
	_look_scan -= delta
	if _look_scan > 0.0:
		return
	_look_scan = 0.5
	var best: Node2D = null
	var best_d: float = 130.0
	for g in ["pets", "customers", "workers"]:
		for n in get_tree().get_nodes_in_group(g):
			var n2: Node2D = n as Node2D
			if n2 != null and is_instance_valid(n2) and n2.visible:
				var d: float = global_position.distance_to(n2.global_position)
				if d < best_d:
					best_d = d
					best = n2
	if best == null:
		return
	var dir: Vector2 = best.global_position - global_position
	if absf(dir.x) > absf(dir.y):
		_facing = &"side"
		_facing_x = signf(dir.x)
	else:
		_facing = &"down" if dir.y > 0.0 else &"up"


## Celebra cualquier pedido completado (si no esta a media entrega).
func _on_order_celebrate(_o) -> void:
	_add_mood(0.15)
	if state == State.IDLE_HOME or state == State.WANDERING:
		say(["👏", "★", "♪", "😊"].pick_random())


func _pick_wander_point() -> Vector2:
	# Ronda con propósito, confinada a la zona actual (no cruza por voluntad propia).
	_wander_poi = &""
	var zone_rect: Rect2 = GridManager.get_zone_rect_at(global_position)
	if zone_rect.size == Vector2.ZERO:
		zone_rect = GridManager.get_playable_rect()
	# 1) Si hay clientes esperando y estoy en Recepción → asomarme al mostrador.
	var cp: Vector2 = _counter_pos()
	if _customers_waiting() and cp != Vector2.ZERO and zone_rect.has_point(cp) and randf() < 0.7:
		_wander_poi = &"counter"
		return _clamp_to_rect(cp + Vector2(randf_range(-24.0, 24.0), 30.0), zone_rect)
	# 2) A veces ir a saludar/acariciar al gato.
	var cat: Node2D = _node_in_zone("pets", zone_rect)
	if cat != null and randf() < 0.22:
		_wander_poi = &"cat"
		return _clamp_to_rect(cat.global_position + Vector2(randf_range(-14.0, 14.0), 18.0), zone_rect)
	# 3) Un punto de interés: caldero/forja/biblioteca, parcela o sitio cálido.
	var poi: Array = _pick_poi_node(zone_rect)
	if not poi.is_empty() and randf() < 0.68:
		_wander_poi = poi[1]
		return _clamp_to_rect((poi[0] as Node2D).global_position + Vector2(randf_range(-24.0, 24.0), randf_range(10.0, 26.0)), zone_rect)
	# 4) Punto libre.
	var min_p: Vector2 = zone_rect.position + Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	var max_p: Vector2 = zone_rect.position + zone_rect.size - Vector2(PLAYABLE_MARGIN, PLAYABLE_MARGIN)
	return Vector2(randf_range(min_p.x, max_p.x), randf_range(min_p.y, max_p.y))


func _pick_poi_node(zone_rect: Rect2) -> Array:
	var kinds: Dictionary = {"workstations": &"station", "generators": &"plant", "warm_spot": &"fire"}
	var pool: Array = []
	for g in kinds:
		for n in get_tree().get_nodes_in_group(g):
			var n2: Node2D = n as Node2D
			if n2 != null and is_instance_valid(n2) and n2.visible and zone_rect.has_point(n2.global_position):
				pool.append([n2, kinds[g]])
	if pool.is_empty():
		return []
	return pool[randi() % pool.size()]


func _counter_pos() -> Vector2:
	var m: Node = get_tree().get_first_node_in_group("customer_counter")
	return (m as Node2D).global_position if m is Node2D else Vector2.ZERO


func _customers_waiting() -> bool:
	for c in get_tree().get_nodes_in_group("customers"):
		if is_instance_valid(c) and c.get("state") == GameEnums.WorkerState.WAITING:
			return true
	return false


func _node_in_zone(group: StringName, zone_rect: Rect2) -> Node2D:
	for n in get_tree().get_nodes_in_group(group):
		var n2: Node2D = n as Node2D
		if n2 != null and is_instance_valid(n2) and n2.visible and zone_rect.has_point(n2.global_position):
			return n2
	return null


## Micro-interacción al llegar a un punto de interés.
func _poi_emote() -> void:
	match _wander_poi:
		&"station": say(["⚗", "🔨", "✨", "☺"].pick_random())
		&"plant": say(["🌿", "🌱", "♪"].pick_random())
		&"fire": say(["🔥", "☺", "♨"].pick_random())
		&"cat": say(["♥", "😊", "🐾"].pick_random())
		&"counter": say(["👀", "🛎", "☺"].pick_random())
		&"new": say(["✨", "😮", "👀", "🤩"].pick_random())
		_: say(_cozy_thought())


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


## Recibe daño de un ogro. Al caer se teletransporta a la base y queda en
## cooldown (no muere) para no colgar el juego si no hay workers.
func hit(amount: float) -> void:
	if _downed or _combat_hb == null:
		return
	_combat_hb.take_damage(amount)
	modulate = Color(1.7, 1.2, 1.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)


func is_downed() -> bool:
	return _downed


func _enter_downed() -> void:
	if _downed:
		return
	_downed = true
	_down_cd = DOWN_COOLDOWN
	velocity = Vector2.ZERO
	state = State.IDLE_HOME
	if SiegeManager.is_active():
		global_position = SiegeManager.base_position + Vector2(30, 0)
	else:
		global_position = home_position
	modulate = Color(0.72, 0.72, 0.88, 0.85)
	VFXManager.play(VFXManager.FX.BUILD, global_position)
	NotificationManager.post("¡La maga fue derribada! Se recupera en 5 min.", NotificationManager.Kind.ALERT)


func _recover() -> void:
	_downed = false
	modulate = Color.WHITE
	if _combat_hb != null:
		_combat_hb.hp = _combat_hb.max_hp
	VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	NotificationManager.post("La maga se recuperó. ✨", NotificationManager.Kind.INFO)


## Ataca al ogro más cercano en rango. Devuelve true si tomó el control.
func _siege_combat(delta: float) -> bool:
	var ogre: Node2D = _nearest_ogre(P_COMBAT_AGGRO)
	if ogre == null:
		return false
	var d: Vector2 = ogre.global_position - global_position
	if d.length() <= P_MELEE_RANGE:
		velocity = Vector2.ZERO
		_pmelee_cd -= delta
		if _pmelee_cd <= 0.0:
			_pmelee_cd = P_MELEE_INTERVAL
			if ogre.has_method("hit"):
				ogre.hit(P_MELEE_DAMAGE)
	else:
		velocity = d.normalized() * move_speed
		move_and_slide()
	return true


func _nearest_ogre(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = radius
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		var n: Node2D = e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var dist: float = global_position.distance_to(n.global_position)
		if dist < best_d:
			best_d = dist
			best = n
	return best


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
