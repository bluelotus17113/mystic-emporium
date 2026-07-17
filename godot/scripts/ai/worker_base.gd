class_name WorkerBase
extends CharacterBody2D
## Base FSM for all helpers (Duende, Golem, Apprentice).

@export var move_speed: float = 80.0
@export var arrival_distance: float = 6.0
@export var worker_type: GameEnums.WorkerType = GameEnums.WorkerType.DUENDE
@export var preferred_resource_type: GameEnums.ResourceType = GameEnums.ResourceType.HERB
## Si se llena, el worker busca el nodo más cercano de CUALQUIERA de estos tipos.
## Cuando está vacío, se usa preferred_resource_type singular (compat Duende/Gólem).
@export var preferred_resource_types: Array[int] = []

## Identidad y progresión: cada ayudante tiene nombre propio y sube de nivel
## recolectando (cada nivel lo hace un poco más rápido).
const NAMES: Dictionary = {
	GameEnums.WorkerType.DUENDE: ["Fizwick", "Pip", "Bramble", "Tato", "Nix", "Coco", "Gwen", "Moss"],
	GameEnums.WorkerType.GOLEM: ["Roco", "Canto", "Basalto", "Terrón", "Guijarro", "Sílex"],
	GameEnums.WorkerType.APPRENTICE: ["Lumi", "Sage", "Vera", "Orin", "Mira", "Nube"],
	GameEnums.WorkerType.LENADOR: ["Roble", "Serrín", "Hacha", "Nudo"],
	GameEnums.WorkerType.ESPIRITU: ["Bruma", "Eco", "Vela", "Alba"],
}
const NAMES_FALLBACK: Array = ["Alma", "Trébol", "Fauno", "Espina"]
const XP_PER_LEVEL: int = 5
const MAX_LEVEL: int = 6
const SPEED_PER_LEVEL: float = 0.06  ## +6% velocidad por nivel
const MOOD_MIN: float = 7.0
const MOOD_MAX: float = 15.0

var worker_name: String = ""
var level: int = 1
var xp: int = 0
var _base_move_speed: float = 0.0
var _mood: Label = null
var _mood_accum: float = 0.0
var _dust_accum: float = 0.0

var state: GameEnums.WorkerState = GameEnums.WorkerState.IDLE
var target: Node2D = null
var _action_timer: float = 0.0
var _anim_phase: float = 0.0
var _facing_x: float = 1.0
var _facing: StringName = &"down"
var _anim_sprite: AnimatedSprite2D = null  ## opcional, solo workers que tienen AnimatedSprite2D
## Wander: cuando no hay recursos disponibles (o están reservados por otros),
## el worker pasea hacia un punto random cerca de su home para no congelarse.
var _home_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
const WANDER_RADIUS: float = 120.0
const WANDER_REPICK_MIN: float = 1.5
const WANDER_REPICK_MAX: float = 3.5
const WANDER_SPEED_FACTOR: float = 0.55  ## wander es más lento que ir a recolectar
const TARGET_SEARCH_INTERVAL: float = 0.3  ## no escanear recursos cada frame; cada 0.3s basta
var _target_search_cd: float = 0.0
var _step_accum: float = 0.0
var _stuck_time: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

signal state_changed(new_state: GameEnums.WorkerState)


func _ready() -> void:
	add_to_group("workers")
	CharShadow.attach(self)
	_setup_click_area()
	_base_move_speed = move_speed
	if worker_name == "":
		worker_name = _random_name()
	_mood = _make_mood_bubble()
	_mood_accum = randf_range(MOOD_MIN, MOOD_MAX)
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	# call_deferred porque al spawnear, global_position aún no está finalizado.
	call_deferred("_capture_home")


func _random_name() -> String:
	var pool: Array = NAMES.get(worker_type, NAMES_FALLBACK)
	if pool.is_empty():
		pool = NAMES_FALLBACK
	return pool[randi() % pool.size()]


func set_worker_name(new_name: String) -> void:
	var t: String = new_name.strip_edges()
	if t != "":
		worker_name = t.left(16)


func _make_mood_bubble() -> Label:
	var l := Label.new()
	l.z_index = 20
	l.position = Vector2(6, -46)
	l.modulate.a = 0.0
	l.add_theme_font_size_override(&"font_size", 15)
	add_child(l)
	return l


## Sube XP al recolectar; cada nivel reduce el cooldown (más velocidad).
func gain_xp(amount: int = 1) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		move_speed = _base_move_speed * (1.0 + SPEED_PER_LEVEL * float(level - 1))
		_puff_mood("⭐")
		VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	if level >= MAX_LEVEL:
		xp = 0


func _maybe_mood(delta: float) -> void:
	_mood_accum -= delta
	if _mood_accum > 0.0:
		return
	_mood_accum = randf_range(MOOD_MIN, MOOD_MAX)
	var pool: Array
	match state:
		GameEnums.WorkerState.FETCHING:
			pool = ["🎵", "✨", "👀"]
		GameEnums.WorkerState.WORKING:
			pool = ["💪", "⚙", "🔨"]
		_:
			pool = ["🍃", "😌", "💭", "♪"]
	_puff_mood(pool[randi() % pool.size()])


func _puff_mood(txt: String) -> void:
	if _mood == null:
		return
	_mood.text = txt
	var base_y: float = -46.0
	_mood.position.y = base_y
	_mood.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_mood, "modulate:a", 0.95, 0.25)
	tw.parallel().tween_property(_mood, "position:y", base_y - 12.0, 1.4)
	tw.tween_property(_mood, "modulate:a", 0.0, 0.45)


## Clic izquierdo sobre el worker → menú contextual (Seguir con la cámara).
func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	cs.shape = circ
	cs.position = Vector2(0, -18)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_body_clicked)


func _on_body_clicked(_vp: Node, event: InputEvent, _idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# En modo obra el clic lo gestiona BuildManager; no abrir menú.
	if BuildManager.is_active() or BuildManager.is_move_active() \
			or BuildManager.is_rotate_active() or BuildManager.is_demolish_active():
		return
	var menu: Node = get_tree().get_first_node_in_group("entity_menu")
	if menu != null and menu.has_method("open_for"):
		menu.open_for(self, _worker_title(), [{
			"rename": true,
			"text": "✏ Renombrar",
			"get": Callable(self, "_get_name"),
			"set": Callable(self, "set_worker_name"),
		}])
		get_viewport().set_input_as_handled()


func _get_name() -> String:
	return worker_name


func _worker_title() -> String:
	var role: String
	match worker_type:
		GameEnums.WorkerType.DUENDE: role = "🧝 Duende"
		GameEnums.WorkerType.GOLEM: role = "🗿 Gólem"
		GameEnums.WorkerType.APPRENTICE: role = "🧙 Aprendiz"
		GameEnums.WorkerType.LENADOR: role = "🪓 Leñador"
		GameEnums.WorkerType.ESPIRITU: role = "👻 Espíritu"
		_: role = "Ayudante"
	return "%s %s · Nv %d" % [role, worker_name, level]


func _capture_home() -> void:
	_home_position = global_position
	_wander_target = global_position


func _physics_process(delta: float) -> void:
	match state:
		GameEnums.WorkerState.IDLE:
			_on_idle(delta)
		GameEnums.WorkerState.FETCHING:
			_move_to(target, delta)
			# Anti-atasco: encajado contra una colisión cerca del objetivo → llegó.
			if global_position.distance_to(_last_pos) < 1.2 * delta * 60.0 * 0.02 + 0.8:
				_stuck_time += delta
			else:
				_stuck_time = 0.0
			_last_pos = global_position
			if _stuck_time > 1.0 and target != null and is_instance_valid(target):
				_stuck_time = 0.0
				if global_position.distance_to(target.global_position) < 60.0:
					_on_arrived_at_target()
				else:
					_release_target()
					_change_state(GameEnums.WorkerState.IDLE)
			if target == null or not is_instance_valid(target):
				_release_target()
				_change_state(GameEnums.WorkerState.IDLE)
			elif target is ResourceNode and not target.is_available():
				# Otro worker o el sistema colectó este recurso mientras viajábamos:
				# soltar y volver a IDLE. Solo aplica a ResourceNode; workstations
				# manejan su propio ciclo de busy/idle internamente.
				_release_target()
				_change_state(GameEnums.WorkerState.IDLE)
			elif _has_arrived(target):
				_on_arrived_at_target()
		GameEnums.WorkerState.WORKING:
			_action_timer -= delta
			if _action_timer <= 0.0:
				_change_state(GameEnums.WorkerState.IDLE)
		_:
			pass
	_update_anim(delta)
	_maybe_mood(delta)
	# pasos suaves + polvo (solo si el worker está en la zona visible)
	if visible and velocity.length_squared() > 4.0:
		_step_accum -= delta
		if _step_accum <= 0.0:
			_step_accum = 0.42
			AudioManager.play_named(&"footstep", 0.3)
			FootDust.spawn(self)
	else:
		_step_accum = 0.2


func _update_anim(delta: float) -> void:
	var is_moving: bool = velocity.length_squared() > 4.0
	# Workers con hoja direccional (idle/walk × down/up/side): eligen animación
	# por el eje dominante del movimiento, flip_h para izquierda.
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(&"walk_down"):
		_update_anim_directional(is_moving)
		return
	if is_moving:
		_anim_phase += delta * 14.0
		if abs(velocity.x) > 1.0:
			_facing_x = sign(velocity.x)
		var sx: float = _facing_x * (1.0 + sin(_anim_phase * 2.0) * 0.06)
		var sy: float = 1.0 - sin(_anim_phase * 2.0) * 0.06
		scale = Vector2(sx, sy)
		rotation = sin(_anim_phase) * 0.06
	else:
		_anim_phase += delta * 2.0
		scale = Vector2(_facing_x, 1.0)
		rotation = lerp(rotation, 0.0, 0.2)
	# ponytail: si el worker tiene AnimatedSprite2D con anim "idle"/"walk_south", switch entre ellas.
	# Workers viejos (Golem/Apprentice con Sprite2D estático) ignoran este bloque.
	if _anim_sprite != null and _anim_sprite.sprite_frames != null:
		var want: StringName = &"walk_south" if is_moving else &"idle"
		if _anim_sprite.sprite_frames.has_animation(want) and _anim_sprite.animation != want:
			_anim_sprite.play(want)


func _update_anim_directional(is_moving: bool) -> void:
	# El flip se hace en el sprite (flip_h), no en la escala del cuerpo.
	scale = Vector2.ONE
	rotation = 0.0
	if is_moving:
		if absf(velocity.x) > absf(velocity.y):
			_facing = &"side"
			_facing_x = signf(velocity.x)
		else:
			_facing = &"down" if velocity.y > 0.0 else &"up"
	_anim_sprite.flip_h = _facing == &"side" and _facing_x < 0.0
	var prefix: StringName = &"walk_" if is_moving else &"idle_"
	var want: StringName = prefix + _facing
	if _anim_sprite.animation != want:
		_anim_sprite.play(want)


func _on_idle(delta: float) -> void:
	# Si el inventario está lleno, no recolectar más (evita spam y trabajo en vacío).
	if InventoryManager.get_total_count() >= InventoryManager.max_capacity:
		_wander(delta)
		return
	# Escanear todos los nodos de recurso cada frame por worker es caro; basta
	# con hacerlo cada TARGET_SEARCH_INTERVAL. Entre búsquedas, wander.
	_target_search_cd -= delta
	if _target_search_cd <= 0.0:
		_target_search_cd = TARGET_SEARCH_INTERVAL
		var candidate = _find_best_target()
		if candidate != null and candidate.has_method("reserve") and candidate.reserve(self):
			target = candidate
			_change_state(GameEnums.WorkerState.FETCHING)
			return
	# No hay recursos libres (o todos reservados por otros workers): wander como ocioso.
	_wander(delta)


func _find_best_target():
	# Si hay lista de tipos, picamos el más cercano de TODOS los tipos. Sin lista
	# (compat workers viejos), usamos el tipo singular.
	if preferred_resource_types.is_empty():
		return ResourceManager.get_closest_available_node(global_position, preferred_resource_type, self)
	var best = null
	var best_dist_sq: float = INF
	for t in preferred_resource_types:
		var cand = ResourceManager.get_closest_available_node(global_position, t, self)
		if cand == null:
			continue
		var d: float = cand.global_position.distance_squared_to(global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			best = cand
	return best


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) <= arrival_distance:
		_pick_wander_target()
	var dir: Vector2 = (_wander_target - global_position)
	if dir.length() < 1.0:
		velocity = Vector2.ZERO
		return
	velocity = dir.normalized() * move_speed * WANDER_SPEED_FACTOR
	move_and_slide()


func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var radius: float = randf_range(WANDER_RADIUS * 0.3, WANDER_RADIUS)
	_wander_target = _home_position + Vector2(cos(angle), sin(angle)) * radius
	_wander_timer = randf_range(WANDER_REPICK_MIN, WANDER_REPICK_MAX)


func _release_target() -> void:
	if target != null and is_instance_valid(target) and target.has_method("release"):
		target.release(self)
	target = null


func _on_arrived_at_target() -> void:
	if target is ResourceNode:
		(target as ResourceNode).collect()
		target = null
		gain_xp(1)
		_change_state(GameEnums.WorkerState.IDLE)


func _move_to(t: Node2D, delta: float) -> void:
	if t == null or not is_instance_valid(t):
		velocity = Vector2.ZERO
		return
	var dir: Vector2 = (t.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()


func _has_arrived(t: Node2D) -> bool:
	if t == null:
		return false
	return global_position.distance_to(t.global_position) <= arrival_distance


func _change_state(new_state: GameEnums.WorkerState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)
