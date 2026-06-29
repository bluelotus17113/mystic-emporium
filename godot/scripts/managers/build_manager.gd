extends Node

signal build_mode_entered(buildable: BuildableData)
signal build_mode_exited
signal buildable_unlocked(buildable: BuildableData)
signal placement_completed(buildable: BuildableData, position: Vector2)
signal demolish_mode_changed(active: bool)
signal building_demolished(grid_pos: Vector2i, refund: int)

const DEMOLISH_REFUND_RATIO: float = 0.5

var _unlocked_buildables: Array[BuildableData] = []
var _catalog: Array[BuildableData] = []  ## set por game_bootstrap para lookup por id
var _current_buildable: BuildableData = null
var _ghost: Node2D = null
var _ghost_rotation_deg: float = 0.0
var _is_active: bool = false
var _demolish_active: bool = false
var _demolish_highlight_node: Node2D = null
var _demolish_orig_modulate: Color = Color.WHITE
var _grid_cost_lookup: Dictionary = {}  # Vector2i -> int (original cost for refund)
var _grid_buildable_lookup: Dictionary = {}  # Vector2i -> StringName (buildable id placed)
var _grid_rotation_lookup: Dictionary = {}  # Vector2i -> float (rotation_degrees al colocar)

const DEMOLISH_HIGHLIGHT: Color = Color(1.0, 0.35, 0.35, 1.0)


func set_catalog(catalog: Array[BuildableData]) -> void:
	_catalog = catalog


func unlock_buildable(buildable: BuildableData, silent: bool = false) -> void:
	if buildable == null or buildable in _unlocked_buildables:
		return
	_unlocked_buildables.append(buildable)
	if not silent:
		buildable_unlocked.emit(buildable)


func unlock_default_buildables(catalog: Array[BuildableData]) -> void:
	for b in catalog:
		if b != null and b.unlocked_by_default:
			unlock_buildable(b, true)
	# También desbloqueamos los gated por nivel del Patio Natural que ya estén
	# disponibles (por ejemplo si cargamos un save con natural_level alto).
	apply_natural_level_unlocks(ZoneExpansionManager.natural_level)


## Desbloquea buildables con min_natural_level <= level. Idempotente.
func apply_natural_level_unlocks(level: int) -> void:
	for b in _catalog:
		if b == null or b in _unlocked_buildables:
			continue
		if b.min_natural_level > 0 and b.min_natural_level <= level:
			unlock_buildable(b, false)


func get_unlocked_buildables() -> Array[BuildableData]:
	return _unlocked_buildables.duplicate()


func enter_build_mode(buildable: BuildableData) -> void:
	if buildable == null or buildable.scene == null:
		return
	exit_build_mode()
	_current_buildable = buildable
	_ghost = buildable.scene.instantiate() as Node2D
	if _ghost == null:
		_current_buildable = null
		return
	_ghost.modulate = Color(1, 1, 1, 0.5)
	_ghost_rotation_deg = 0.0
	_ghost.rotation_degrees = 0.0
	# disable physics/processing on ghost
	for child in _ghost.get_children():
		if child is CollisionObject2D:
			(child as CollisionObject2D).input_pickable = false
	get_tree().current_scene.add_child(_ghost)
	_is_active = true
	build_mode_entered.emit(buildable)


func exit_build_mode() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_current_buildable = null
	if _is_active:
		_is_active = false
		build_mode_exited.emit()


func is_active() -> bool:
	return _is_active


func _process(_delta: float) -> void:
	if _is_active and _ghost != null:
		var mouse_world: Vector2 = _ghost.get_global_mouse_position()
		var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
		_ghost.global_position = GridManager.grid_to_world(grid_pos)
		var valid: bool = _is_valid_placement(grid_pos)
		_ghost.modulate = Color(0.5, 1.0, 0.5, 0.6) if valid else Color(1.0, 0.4, 0.4, 0.6)
	elif _demolish_active:
		_update_demolish_highlight()


func _update_demolish_highlight() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var mouse_world: Vector2 = scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	var node: Node2D = null
	if GridManager.is_cell_occupied(grid_pos):
		node = GridManager._occupied.get(grid_pos)
	if node == _demolish_highlight_node:
		return
	_clear_demolish_highlight()
	if node != null and is_instance_valid(node):
		_demolish_highlight_node = node
		_demolish_orig_modulate = node.modulate
		node.modulate = DEMOLISH_HIGHLIGHT


func _clear_demolish_highlight() -> void:
	if _demolish_highlight_node != null and is_instance_valid(_demolish_highlight_node):
		_demolish_highlight_node.modulate = _demolish_orig_modulate
	_demolish_highlight_node = null


func _input(event: InputEvent) -> void:
	if _demolish_active:
		if event.is_action_pressed("build_cancel"):
			exit_demolish_mode()
			return
		if event.is_action_pressed("build_confirm"):
			_try_demolish()
		return
	if not _is_active:
		return
	if event.is_action_pressed("build_cancel"):
		exit_build_mode()
		return
	if event.is_action_pressed("build_confirm"):
		_try_place()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_rotate_ghost()


func _rotate_ghost() -> void:
	# Solo rotamos decoraciones 1x1 — tamaños mayores romperían la lógica de grid lock.
	if _current_buildable == null or _ghost == null:
		return
	if _current_buildable.size != Vector2i(1, 1):
		return
	_ghost_rotation_deg = fposmod(_ghost_rotation_deg + 90.0, 360.0)
	_ghost.rotation_degrees = _ghost_rotation_deg
	AudioManager.play_named(&"menu_select")


func enter_demolish_mode() -> void:
	exit_build_mode()
	_demolish_active = true
	demolish_mode_changed.emit(true)


func exit_demolish_mode() -> void:
	if not _demolish_active:
		return
	_clear_demolish_highlight()
	_demolish_active = false
	demolish_mode_changed.emit(false)


func is_demolish_active() -> bool:
	return _demolish_active


func _try_demolish() -> void:
	var mouse_world: Vector2 = get_tree().current_scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	if not GridManager.is_cell_occupied(grid_pos):
		return
	var node: Node2D = GridManager._occupied.get(grid_pos)
	if node == null or not is_instance_valid(node):
		GridManager._occupied.erase(grid_pos)
		return
	# Si el node a borrar es el highlighted, soltar referencia para no restaurar modulate post-free.
	if node == _demolish_highlight_node:
		_demolish_highlight_node = null
	var refund: int = int(_grid_cost_lookup.get(grid_pos, 30) * DEMOLISH_REFUND_RATIO)
	InventoryManager.add_coins(refund)
	GridManager.remove_object(grid_pos)
	_grid_cost_lookup.erase(grid_pos)
	_grid_buildable_lookup.erase(grid_pos)
	_grid_rotation_lookup.erase(grid_pos)
	VFXManager.play(VFXManager.FX.BUILD, node.global_position)
	AudioManager.play_beep(220.0, 0.15, -12.0)
	building_demolished.emit(grid_pos, refund)
	NotificationManager.post("Edificio demolido. +%d ⚜ devueltos." % refund, NotificationManager.Kind.INFO)
	node.queue_free()


func _is_valid_placement(grid_pos: Vector2i) -> bool:
	if _current_buildable == null:
		return false
	if GridManager.is_cell_occupied(grid_pos):
		return false
	if InventoryManager.arcane_coins < _current_buildable.cost:
		return false
	var zone: GameEnums.ZoneType = GridManager.get_zone_type(grid_pos)
	# Regla universal: nada se coloca fuera de las zonas (NATURE/WORKSHOP/RECEPTION).
	if zone == GameEnums.ZoneType.NONE:
		return false
	# Buildables con allowed_zone definido solo van en esa zona específica.
	if _current_buildable.allowed_zone != GameEnums.ZoneType.NONE:
		if zone != _current_buildable.allowed_zone:
			return false
	return true


func _placement_error(grid_pos: Vector2i) -> String:
	# Devuelve "" si OK, o motivo concreto del fallo. El orden del check es el
	# mismo que _is_valid_placement; ambos deben mantenerse en sincronía.
	if _current_buildable == null:
		return "Sin edificio seleccionado."
	if GridManager.is_cell_occupied(grid_pos):
		return "Casilla ocupada."
	if InventoryManager.arcane_coins < _current_buildable.cost:
		return "Faltan %d ⚜ (tenés %d)." % [_current_buildable.cost, InventoryManager.arcane_coins]
	var zone: GameEnums.ZoneType = GridManager.get_zone_type(grid_pos)
	if zone == GameEnums.ZoneType.NONE:
		return "Fuera de zona. Construí dentro de Natural, Taller o Recepción."
	if _current_buildable.allowed_zone != GameEnums.ZoneType.NONE:
		if zone != _current_buildable.allowed_zone:
			return "Este edificio solo va en la zona %s." % _zone_name(_current_buildable.allowed_zone)
	return ""


func _zone_name(z: GameEnums.ZoneType) -> String:
	match z:
		GameEnums.ZoneType.NATURE: return "Natural"
		GameEnums.ZoneType.WORKSHOP: return "Taller"
		GameEnums.ZoneType.RECEPTION: return "Recepción"
		_: return "Otra"


func _try_place() -> void:
	if _ghost == null:
		return
	var grid_pos: Vector2i = GridManager.world_to_grid(_ghost.get_global_mouse_position())
	var err: String = _placement_error(grid_pos)
	if err != "":
		NotificationManager.post("🚫 %s" % err, NotificationManager.Kind.ALERT)
		AudioManager.play_named(&"build_error")
		return
	if not InventoryManager.spend_coins(_current_buildable.cost):
		return
	var instance: Node2D = _current_buildable.scene.instantiate() as Node2D
	get_tree().current_scene.add_child(instance)
	instance.global_position = GridManager.grid_to_world(grid_pos)
	instance.rotation_degrees = _ghost_rotation_deg
	GridManager.place_object(grid_pos, instance)
	_grid_cost_lookup[grid_pos] = _current_buildable.cost
	_grid_buildable_lookup[grid_pos] = _current_buildable.id
	_grid_rotation_lookup[grid_pos] = _ghost_rotation_deg
	_assign_zone_visual_group(instance, _current_buildable.allowed_zone)
	VFXManager.play(VFXManager.FX.BUILD, instance.global_position)
	AudioManager.play_beep(540.0, 0.1, -12.0)
	placement_completed.emit(_current_buildable, instance.global_position)
	exit_build_mode()


func _assign_zone_visual_group(node: Node, zone: int) -> void:
	# ponytail: 3 grupos mutuamente exclusivos por zona.
	var grp: StringName = &""
	var zone_name: StringName = &""
	match zone:
		GameEnums.ZoneType.NATURE:
			grp = &"natural_visual"
			zone_name = &"natural"
		GameEnums.ZoneType.WORKSHOP:
			grp = &"taller_visual"
			zone_name = &"taller"
		GameEnums.ZoneType.RECEPTION:
			grp = &"recepcion_visual"
			zone_name = &"recepcion"
	if grp == &"":
		return
	node.add_to_group(grp)
	var cam = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		node.visible = cam.get_current_zone().name == zone_name


func _find_buildable_by_id(id: StringName) -> BuildableData:
	for b in _catalog:
		if b != null and b.id == id:
			return b
	return null


func reset_for_prestige() -> void:
	# Despawn cada building colocado y limpia el grid.
	for grid_pos in _grid_buildable_lookup.keys():
		var node = GridManager._occupied.get(grid_pos)
		if node != null and is_instance_valid(node):
			node.queue_free()
	_grid_buildable_lookup.clear()
	_grid_cost_lookup.clear()
	_grid_rotation_lookup.clear()
	GridManager._occupied.clear()
	# Volver a sólo los buildables default desbloqueados.
	_unlocked_buildables.clear()
	unlock_default_buildables(_catalog)
	exit_build_mode()
	exit_demolish_mode()


func get_save_state() -> Dictionary:
	var placed: Array = []
	for grid_pos in _grid_buildable_lookup.keys():
		placed.append({
			"id": String(_grid_buildable_lookup[grid_pos]),
			"x": grid_pos.x,
			"y": grid_pos.y,
			"cost": _grid_cost_lookup.get(grid_pos, 0),
			"rot": _grid_rotation_lookup.get(grid_pos, 0.0),
		})
	var unlocked_ids: Array = []
	for b in _unlocked_buildables:
		if b != null:
			unlocked_ids.append(String(b.id))
	return {"placed": placed, "unlocked": unlocked_ids}


func load_save_state(data: Dictionary) -> void:
	# Reaplicar unlocks.
	for sid in data.get("unlocked", []):
		var b := _find_buildable_by_id(StringName(sid))
		if b != null:
			unlock_buildable(b)
	# Reinstanciar buildings sin re-cobrar coins (ya pagados en la sesión original).
	for entry in data.get("placed", []):
		var b := _find_buildable_by_id(StringName(entry.get("id", "")))
		if b == null or b.scene == null:
			continue
		var grid_pos := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if GridManager.is_cell_occupied(grid_pos):
			continue
		var instance: Node2D = b.scene.instantiate() as Node2D
		if instance == null:
			continue
		get_tree().current_scene.add_child(instance)
		instance.global_position = GridManager.grid_to_world(grid_pos)
		var rot: float = float(entry.get("rot", 0.0))
		instance.rotation_degrees = rot
		GridManager.place_object(grid_pos, instance)
		_grid_cost_lookup[grid_pos] = int(entry.get("cost", b.cost))
		_grid_buildable_lookup[grid_pos] = b.id
		_grid_rotation_lookup[grid_pos] = rot
		_assign_zone_visual_group(instance, b.allowed_zone)
