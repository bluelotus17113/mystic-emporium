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

var state: GameEnums.WorkerState = GameEnums.WorkerState.IDLE
var target: Node2D = null
var _action_timer: float = 0.0
var _anim_phase: float = 0.0
var _facing_x: float = 1.0
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

signal state_changed(new_state: GameEnums.WorkerState)


func _ready() -> void:
	add_to_group("workers")
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	# call_deferred porque al spawnear, global_position aún no está finalizado.
	call_deferred("_capture_home")


func _capture_home() -> void:
	_home_position = global_position
	_wander_target = global_position


func _physics_process(delta: float) -> void:
	match state:
		GameEnums.WorkerState.IDLE:
			_on_idle(delta)
		GameEnums.WorkerState.FETCHING:
			_move_to(target, delta)
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


func _update_anim(delta: float) -> void:
	var is_moving: bool = velocity.length_squared() > 4.0
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


func _on_idle(delta: float) -> void:
	# Si el inventario está lleno, no recolectar más (evita spam y trabajo en vacío).
	if InventoryManager.get_total_count() >= InventoryManager.max_capacity:
		_wander(delta)
		return
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
