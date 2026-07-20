extends CharacterBody2D
## Mascota de la tienda: gato con comportamientos variados — dormir, pasear,
## sentarse, acicalarse, jugar (abalanzarse) y seguir a la protagonista.
## Clic izquierdo → menú contextual (seguir con la cámara). Emotes sueltos.

enum State { SLEEP, WANDER, SIT, GROOM, PLAY, FOLLOW, CHASE, PORTAL }

const PORTAL_RANGE: float = 220.0   ## distancia para elegir un portal cercano

const WANDER_SPEED: float = 42.0
const FOLLOW_SPEED: float = 78.0
const POUNCE_SPEED: float = 150.0
const SLEEP_MIN: float = 20.0
const SLEEP_MAX: float = 40.0
const AWAKE_MIN: float = 8.0
const AWAKE_MAX: float = 16.0
const EMOTES: Array = ["♥", "🐾", "🐟", "✨", "🧶", "😽"]
const HAPPY_EMOTES: Array = ["🎉", "♪", "✨", "💛", "😺"]

var state: State = State.SLEEP
var home_position: Vector2 = Vector2.ZERO
var _timer: float = 10.0
var _wander_target: Vector2 = Vector2.ZERO
var _facing: StringName = &"down"
var _facing_x: float = 1.0
var _zzz: Label = null
var _emote: Label = null
var _zzz_accum: float = 0.0
var _emote_accum: float = 0.0
var _pounces: int = 0
var _bob_t: float = 0.0
var _chase_target: Node2D = null
var _beg_cd: float = 0.0  ## pedir mimos cuando la protagonista pasa cerca
var _portal: Node2D = null  ## portal al que va para viajar de zona
var _follow_after_portal: bool = false  ## true: tras cruzar, retomar el seguimiento
var _affection: float = 0.6  ## cariño 0..1: sube al acariciar, baja despacio
var _react_cd: float = 0.0  ## cooldown para reaccionar a eventos del local

@onready var _spr: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("pets")
	CharShadow.attach(self, 14.0)
	home_position = global_position
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	_zzz = _make_bubble("💤", Vector2(6.0, -40.0))
	_emote = _make_bubble("♥", Vector2(4.0, -44.0))
	_setup_click_area()
	_emote_accum = randf_range(4.0, 9.0)
	# Reacciona a la vida del local: se alegra con cada venta y se pone curioso
	# cuando una estación termina de craftear (solo si está a la vista).
	OrderManager.order_completed.connect(_on_sale)
	call_deferred("_hook_workstations")


func _hook_workstations() -> void:
	for ws in get_tree().get_nodes_in_group("workstations"):
		if ws.has_signal(&"craft_completed") and not ws.craft_completed.is_connected(_on_craft_done):
			ws.craft_completed.connect(_on_craft_done)


## Venta completada: el gato celebra con un emote y un saltito feliz.
func _on_sale(_order: Object = null) -> void:
	_react(HAPPY_EMOTES[randi() % HAPPY_EMOTES.size()], 0.06, true)


## Estación termina un crafteo: a veces asoma curioso.
func _on_craft_done(_recipe: Object = null) -> void:
	if randf() < 0.5:
		_react("❔", 0.0, false)


## Reacción común: solo si está visible y fuera de cooldown. `hop` da un squash
## (si no duerme) y `aff` sube un poco el cariño.
func _react(txt: String, aff: float, hop: bool) -> void:
	if not visible or _react_cd > 0.0:
		return
	_react_cd = randf_range(2.5, 4.0)
	_puff(_emote, txt)
	if aff > 0.0:
		_affection = minf(1.0, _affection + aff)
	if hop and state != State.SLEEP:
		_squash()


func _make_bubble(txt: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.modulate.a = 0.0
	l.z_index = 20
	add_child(l)
	return l


func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	cs.shape = circ
	cs.position = Vector2(0, -12)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(func(_vp, ev, _idx):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if BuildManager.is_active() or BuildManager.is_move_active() \
					or BuildManager.is_demolish_active() or BuildManager.is_copy_active():
				return
			var menu: Node = get_tree().get_first_node_in_group("entity_menu")
			if menu != null and menu.has_method("open_for"):
				menu.open_for(self, "🐱 Gato", [{
					"text": "♥ Acariciar",
					"cb": Callable(self, "pet"),
				}], Callable(self, "_stats_data"), _portrait_texture())
				get_viewport().set_input_as_handled())


## Stats para el menú: cariño (sube al acariciar) + actividad actual.
func _stats_data() -> Array:
	var a: float = clampf(_affection, 0.0, 1.0)
	return [
		{"label": "♥ Cariño", "ratio": a, "color": Color(0.95, 0.5, 0.62), "value_text": "%d%%" % int(round(a * 100.0))},
		{"label": "Ahora", "text": _cat_state_label()},
	]


func _cat_state_label() -> String:
	match state:
		State.SLEEP: return "😴 Durmiendo"
		State.WANDER: return "🚶 Paseando"
		State.SIT: return "🪑 Sentado"
		State.GROOM: return "😽 Acicalándose"
		State.PLAY: return "🐾 Jugando"
		State.FOLLOW: return "🫏 Siguiendo"
		State.CHASE: return "🦋 Cazando"
		State.PORTAL: return "🌀 Al portal"
		_: return "…"


func _portrait_texture() -> Texture2D:
	if _spr != null and _spr.sprite_frames != null and _spr.sprite_frames.has_animation(_spr.animation):
		return _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame)
	return null


## Mimo: corazones, ronroneo y se sienta feliz un rato.
func pet() -> void:
	state = State.SIT
	_timer = randf_range(3.0, 5.0)
	velocity = Vector2.ZERO
	_affection = minf(1.0, _affection + 0.25)
	_squash()
	for i in 3:
		var t := get_tree().create_timer(0.18 * float(i))
		t.timeout.connect(func(): _puff(_emote, "♥"))
	AudioManager.play_beep(880.0, 0.12, -14.0)


func _physics_process(delta: float) -> void:
	_timer -= delta
	_react_cd -= delta
	_affection = lerpf(_affection, 0.5, delta * 0.01)  # cariño vuelve a la línea base
	_maybe_emote(delta)
	_maybe_beg(delta)
	match state:
		State.SLEEP:
			velocity = Vector2.ZERO
			_zzz_accum += delta
			if _zzz_accum >= 3.0:
				_zzz_accum = 0.0
				_puff(_zzz)
			if _timer <= 0.0:
				_wake()
		State.WANDER:
			var dir: Vector2 = _wander_target - global_position
			if dir.length() < 6.0:
				velocity = Vector2.ZERO
				_pick_wander()
			else:
				velocity = dir.normalized() * WANDER_SPEED
				move_and_slide()
			if _timer <= 0.0:
				_next_activity()
		State.SIT:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_next_activity()
		State.GROOM:
			velocity = Vector2.ZERO
			_bob_t += delta * 6.0
			if _timer <= 0.0:
				_next_activity()
		State.PLAY:
			var d: Vector2 = _wander_target - global_position
			if d.length() < 8.0:
				_pounces -= 1
				if _pounces <= 0:
					_next_activity()
				else:
					_pick_wander()
					_squash()
			else:
				velocity = d.normalized() * POUNCE_SPEED
				move_and_slide()
		State.FOLLOW:
			var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
			if proto == null:
				_go_sleep()
			elif _follow_cross_zone(proto):
				pass  # la maga cambió de zona: gestionar el cruce por el portal
			else:
				var pd: Vector2 = proto.global_position + Vector2(24, 12) - global_position
				velocity = pd.normalized() * FOLLOW_SPEED if pd.length() > 26.0 else Vector2.ZERO
				if pd.length() > 26.0:
					move_and_slide()
				if _timer <= 0.0:
					_go_sleep()
		State.CHASE:
			if _chase_target == null or not is_instance_valid(_chase_target):
				_next_activity()
			else:
				var cd: Vector2 = _chase_target.global_position - global_position
				if cd.length() > 22.0:
					velocity = cd.normalized() * POUNCE_SPEED * 0.8
					move_and_slide()
				else:
					velocity = Vector2.ZERO
				if _timer <= 0.0:
					_next_activity()
		State.PORTAL:
			if _portal == null or not is_instance_valid(_portal) or _timer <= 0.0:
				_portal = null
				_next_activity()
			else:
				var pd: Vector2 = _portal.global_position - global_position
				if pd.length() > 8.0:
					velocity = pd.normalized() * FOLLOW_SPEED
					move_and_slide()
				else:
					velocity = Vector2.ZERO
					_use_portal()
	_update_anim()


func _wake() -> void:
	_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
	_next_activity(true)


func _next_activity(just_woke: bool = false) -> void:
	_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
	var roll: float = randf()
	var has_proto: bool = get_tree().get_first_node_in_group("protagonist") != null
	if not just_woke and roll < 0.22:
		_go_sleep()
	elif roll < 0.42 and has_proto:
		state = State.FOLLOW
	elif roll < 0.54 and _pick_chase_prey():
		state = State.CHASE
		_puff(_emote, "🐾")
	elif roll < 0.58 and _pick_portal():
		state = State.PORTAL
		_puff(_emote, "🌀")
	elif roll < 0.62:
		state = State.SIT
	elif roll < 0.74:
		state = State.GROOM
		_bob_t = 0.0
		_puff(_emote, "😽")
	elif roll < 0.9:
		state = State.PLAY
		_pounces = randi_range(2, 4)
		_pick_wander()
		_squash()
	else:
		state = State.WANDER
		_pick_wander()


## Presa a perseguir: de día caza mariposas (¡las adora!); si no hay, algún
## worker cercano al que corretear.
func _pick_chase_prey() -> bool:
	if CalendarManager.get_darkness() < 0.4:
		var flies: Array = []
		for f in get_tree().get_nodes_in_group("butterfly"):
			if f is Node2D and is_instance_valid(f) and (f as Node2D).visible \
					and global_position.distance_to((f as Node2D).global_position) < 220.0:
				flies.append(f)
		if not flies.is_empty():
			_chase_target = flies[randi() % flies.size()]
			return true
	return _pick_chase_worker()


## Elige un worker cercano de la misma zona para perseguir un rato.
func _pick_chase_worker() -> bool:
	var workers: Array = get_tree().get_nodes_in_group("workers")
	var candidates: Array = []
	for w in workers:
		if w is Node2D and is_instance_valid(w) and w.visible \
				and global_position.distance_to(w.global_position) < 260.0:
			candidates.append(w)
	if candidates.is_empty():
		return false
	_chase_target = candidates[randi() % candidates.size()]
	return true


## Zona concreta (natural/taller/recepcion) en una posición del mundo.
func _zone_name_at(pos: Vector2) -> StringName:
	match GridManager.get_zone_type(GridManager.world_to_grid(pos)):
		GameEnums.ZoneType.NATURE: return &"natural"
		GameEnums.ZoneType.WORKSHOP: return &"taller"
		GameEnums.ZoneType.RECEPTION: return &"recepcion"
	return &""


## Región visible: el taller y la recepción son un mismo edificio contiguo
## ("indoor"); el Patio Natural es exterior y está separado por el vacío. Solo se
## cruza por portal entre regiones distintas, no entre taller↔recepción.
func _visual_region_at(pos: Vector2) -> StringName:
	return &"natural" if _zone_name_at(pos) == &"natural" else &"indoor"


## Si la protagonista quedó en otra región (tras cruzar su portal), el gato la
## sigue por el portal en vez de atravesar el fondo negro. Devuelve true si tomó
## el control del seguimiento este frame.
func _follow_cross_zone(proto: Node2D) -> bool:
	var my_region: StringName = _visual_region_at(global_position)
	var proto_region: StringName = _visual_region_at(proto.global_position)
	if my_region == proto_region:
		return false
	_follow_after_portal = true
	if _pick_portal_to_region(proto_region):
		state = State.PORTAL
		_timer = randf_range(6.0, 10.0)  # margen para alcanzar y cruzar el portal
		_puff(_emote, "🌀")
	else:
		# Sin portal que enlace ambas regiones: teleporte de cortesía junto a ella.
		_snap_to_zone(proto)
	return true


## Portal en la región actual del gato que lleva a `target_region`, el más cercano.
func _pick_portal_to_region(target_region: StringName) -> bool:
	var my_region: StringName = _visual_region_at(global_position)
	var best: Node2D = null
	var best_d: float = INF
	for d in get_tree().get_nodes_in_group("zone_doors"):
		var zd := d as ZoneDoor
		if zd == null or not is_instance_valid(zd):
			continue
		var src_region: StringName = _visual_region_at(zd.global_position)
		var dest: StringName = zd.dest_zone_name()
		var dest_region: StringName = &"natural" if dest == &"natural" else &"indoor"
		if src_region != my_region or dest_region != target_region:
			continue
		var dist: float = global_position.distance_to(zd.global_position)
		if dist < best_d:
			best_d = dist
			best = zd
	if best == null:
		return false
	_portal = best
	return true


## Reubica al gato junto a la protagonista y ajusta su zona/visibilidad (fallback
## cuando no hay un portal que enlace ambas regiones).
func _snap_to_zone(proto: Node2D) -> void:
	global_position = proto.global_position + Vector2(-22.0, 10.0)
	home_position = global_position
	_set_zone_visual(_zone_name_at(proto.global_position))
	_puff(_emote, "🌀")


## Elige un portal cercano de la misma zona para viajar (como la maga).
func _pick_portal() -> bool:
	var rect: Rect2 = GridManager.get_zone_rect_at(global_position)
	var best: Node2D = null
	var best_d: float = PORTAL_RANGE
	for d in get_tree().get_nodes_in_group("zone_doors"):
		var n2: Node2D = d as Node2D
		if n2 == null or not is_instance_valid(n2):
			continue
		if rect.size != Vector2.ZERO and not rect.has_point(n2.global_position):
			continue
		var dist: float = global_position.distance_to(n2.global_position)
		if dist < best_d:
			best_d = dist
			best = n2
	if best == null:
		return false
	_portal = best
	return true


## Cruza el portal: aparece en el enlazado, ajusta zona/visibilidad.
func _use_portal() -> void:
	var portal: Node2D = _portal
	_portal = null
	if portal == null or not is_instance_valid(portal) or not portal.has_method("linked_portal"):
		_after_portal_activity()
		return
	var lp: Node2D = portal.call("linked_portal")
	if lp == null or not is_instance_valid(lp):
		_after_portal_activity()
		return
	portal.call("open_flash")
	var zn: StringName = portal.call("dest_zone_name")
	global_position = lp.global_position + Vector2(0.0, 6.0)
	home_position = global_position
	_puff(_emote, "🌀")
	_set_zone_visual(zn)
	_after_portal_activity()


## Tras cruzar: si estaba siguiendo a la maga, retoma el seguimiento (ya en su
## misma zona); si no, elige una actividad nueva como siempre.
func _after_portal_activity() -> void:
	if _follow_after_portal and get_tree().get_first_node_in_group("protagonist") != null:
		_follow_after_portal = false
		state = State.FOLLOW
		_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
		return
	_follow_after_portal = false
	_next_activity()


## Cambia el grupo visual del gato a la zona destino (y su visibilidad actual).
func _set_zone_visual(zone_name: StringName) -> void:
	if zone_name == &"":
		return
	for g in ["natural_visual", "taller_visual", "recepcion_visual"]:
		if is_in_group(g):
			remove_from_group(g)
	var grp: StringName = &""
	match zone_name:
		&"natural": grp = &"natural_visual"
		&"taller": grp = &"taller_visual"
		&"recepcion": grp = &"recepcion_visual"
	if grp != &"":
		add_to_group(grp)
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		visible = cam.get_current_zone().name == zone_name


func _go_sleep() -> void:
	state = State.SLEEP
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	_zzz_accum = 0.0
	scale = Vector2.ONE


func _pick_wander() -> void:
	var rect: Rect2 = GridManager.get_zone_rect_at(home_position)
	if rect.size == Vector2.ZERO:
		rect = Rect2(home_position - Vector2(90, 60), Vector2(180, 120))
	_wander_target = Vector2(
		randf_range(rect.position.x + 30.0, rect.end.x - 30.0),
		randf_range(rect.position.y + 60.0, rect.end.y - 24.0))


func _squash() -> void:
	var tw := create_tween()
	scale = Vector2(1.25, 0.75)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _maybe_emote(delta: float) -> void:
	if state == State.SLEEP or state == State.PLAY:
		return
	_emote_accum -= delta
	if _emote_accum <= 0.0:
		_emote_accum = randf_range(6.0, 14.0)
		_puff(_emote, EMOTES[randi() % EMOTES.size()])


## Si la protagonista pasa cerca y el gato no duerme, pide mimos: ♥ y se orienta
## hacia ella (a veces se sienta a esperar caricias).
func _maybe_beg(delta: float) -> void:
	_beg_cd -= delta
	if _beg_cd > 0.0 or state == State.SLEEP or state == State.PLAY or state == State.CHASE:
		return
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if proto == null or not is_instance_valid(proto):
		return
	var d: Vector2 = proto.global_position - global_position
	if d.length() > 46.0:
		return
	_beg_cd = randf_range(5.0, 9.0)
	_puff(_emote, "♥")
	_facing = &"side" if absf(d.x) > absf(d.y) else (&"down" if d.y > 0.0 else &"up")
	_facing_x = signf(d.x)
	if randf() < 0.5:
		state = State.SIT
		_timer = randf_range(2.0, 4.0)
		velocity = Vector2.ZERO


func _puff(lbl: Label, txt: String = "") -> void:
	if lbl == null:
		return
	if txt != "":
		lbl.text = txt
	var base_y: float = lbl.position.y
	lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 0.95, 0.3)
	tw.parallel().tween_property(lbl, "position:y", base_y - 14.0, 1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): lbl.position.y = base_y)


func _update_anim() -> void:
	if _spr == null or _spr.sprite_frames == null:
		return
	if state == State.SLEEP:
		if _spr.animation != &"sleep":
			_spr.play(&"sleep")
		return
	if state == State.GROOM:
		_spr.flip_h = false
		if _spr.animation != &"groom":
			_spr.play(&"groom")
		return
	if state == State.SIT:
		if _spr.animation != &"sit":
			_spr.play(&"sit")
		return
	var moving: bool = velocity.length_squared() > 4.0
	if state == State.PLAY and not moving:
		if _spr.animation != &"crouch":
			_spr.play(&"crouch")
		return
	if moving:
		if absf(velocity.x) > absf(velocity.y):
			_facing = &"side"
			_facing_x = signf(velocity.x)
		else:
			_facing = &"down" if velocity.y > 0.0 else &"up"
	_spr.flip_h = _facing == &"side" and _facing_x < 0.0
	var want: StringName = (&"walk_" if moving else &"idle_") + _facing
	if _spr.animation != want:
		_spr.play(want)
