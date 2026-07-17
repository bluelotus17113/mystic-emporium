extends Node

signal build_mode_entered(buildable: BuildableData)
signal build_mode_exited
signal buildable_unlocked(buildable: BuildableData)
signal placement_completed(buildable: BuildableData, position: Vector2)
signal demolish_mode_changed(active: bool)
signal tool_mode_changed(mode: StringName)  ## "", place, move, rotate, demolish
signal building_demolished(grid_pos: Vector2i, refund: int)

const DEMOLISH_REFUND_RATIO: float = 0.5

var _unlocked_buildables: Array[BuildableData] = []
var _catalog: Array[BuildableData] = []  ## set por game_bootstrap para lookup por id
var _current_buildable: BuildableData = null
var _ghost: Node2D = null
var _ghost_rotation_deg: float = 0.0
var _is_active: bool = false
var _demolish_active: bool = false
## Herramientas del modo obra: mover y rotar lo ya construido.
var _move_active: bool = false
var _moving_node: Node2D = null
var _moving_from: Vector2i = Vector2i.ZERO
var _moving_id: StringName = &""
var _moving_cost: int = 0
var _moving_rot: float = 0.0
var _rotate_tool_active: bool = false
var _copy_tool_active: bool = false
var _demolish_highlight_node: Node2D = null
var _demolish_orig_modulate: Color = Color.WHITE
var _grid_cost_lookup: Dictionary = {}  # Vector2i -> int (original cost for refund)
var _grid_buildable_lookup: Dictionary = {}  # Vector2i -> StringName (buildable id placed)
var _grid_rotation_lookup: Dictionary = {}  # Vector2i -> float (rotation_degrees al colocar)

const DEMOLISH_HIGHLIGHT: Color = Color(1.0, 0.35, 0.35, 1.0)


func set_catalog(catalog: Array[BuildableData]) -> void:
	_catalog = catalog


## Registra en el grid un objeto ya instanciado (p.ej. faroles por defecto del
## bootstrap) para que las herramientas de mover/demoler/copiar lo traten como
## cualquier objeto colocado. Devuelve false si la celda ya está ocupada.
func register_prebuilt(instance: Node2D, world_pos: Vector2, buildable_id: StringName, cost: int = 0, rot: float = 0.0) -> bool:
	if instance == null:
		return false
	var gp: Vector2i = GridManager.world_to_grid(world_pos)
	if GridManager.is_cell_occupied(gp):
		return false
	instance.global_position = GridManager.grid_to_world(gp)
	instance.rotation_degrees = rot
	GridManager.place_object(gp, instance)
	_grid_cost_lookup[gp] = cost
	_grid_buildable_lookup[gp] = buildable_id
	_grid_rotation_lookup[gp] = rot
	return true


## Registra un buildable creado en runtime (Abracadabra) y lo desbloquea.
func register_custom_buildable(bd: BuildableData) -> void:
	if bd == null or bd in _catalog:
		return
	_catalog.append(bd)
	unlock_buildable(bd, false)


## Si el buildable es custom, pasa su id a la instancia (antes de add_child,
## para que su _ready cargue la textura correcta).
func _apply_custom_id(instance: Node2D, b: BuildableData) -> void:
	if b != null and b.custom_id != &"" and instance != null and "custom_id" in instance:
		instance.custom_id = b.custom_id


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
	exit_copy_mode()
	_current_buildable = buildable
	_ghost = buildable.scene.instantiate() as Node2D
	_apply_custom_id(_ghost, buildable)
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
	tool_mode_changed.emit(&"place")


func exit_build_mode() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_current_buildable = null
	if _is_active:
		_is_active = false
		build_mode_exited.emit()
		tool_mode_changed.emit(&"")


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
	elif _move_active:
		if _moving_node != null and is_instance_valid(_moving_node):
			var mw: Vector2 = get_tree().current_scene.get_global_mouse_position()
			var gp: Vector2i = GridManager.world_to_grid(mw)
			_moving_node.global_position = GridManager.grid_to_world(gp)
			var ok: bool = _cell_ok_for(_find_buildable_by_id(_moving_id), gp)
			_moving_node.modulate = Color(0.5, 1.0, 0.5, 0.7) if ok else Color(1.0, 0.4, 0.4, 0.7)
		else:
			_update_move_highlight()
	elif _rotate_tool_active:
		_update_demolish_highlight(Color(0.55, 0.8, 1.0, 1.0))
	elif _copy_tool_active:
		_update_move_highlight()


func _update_demolish_highlight(hl: Color = DEMOLISH_HIGHLIGHT) -> void:
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


## Highlight de Mover: objetos del grid o estaciones/generadores de escena.
func _update_move_highlight() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var mouse_world: Vector2 = scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	var node: Node2D = null
	if GridManager.is_cell_occupied(grid_pos):
		node = GridManager._occupied.get(grid_pos)
	if node == null or not is_instance_valid(node):
		node = _find_movable_under_mouse(mouse_world)
	if node == _demolish_highlight_node:
		return
	_clear_demolish_highlight()
	if node != null and is_instance_valid(node):
		_demolish_highlight_node = node
		_demolish_orig_modulate = node.modulate
		node.modulate = Color(1.0, 0.9, 0.45, 1.0)


func _clear_demolish_highlight() -> void:
	if _demolish_highlight_node != null and is_instance_valid(_demolish_highlight_node):
		_demolish_highlight_node.modulate = _demolish_orig_modulate
	_demolish_highlight_node = null


func _input(event: InputEvent) -> void:
	if _move_active:
		if event.is_action_pressed("build_cancel"):
			exit_move_mode()
			return
		if event.is_action_pressed("build_confirm"):
			if _moving_node == null or not is_instance_valid(_moving_node):
				_try_pick_for_move()
			else:
				_try_drop_moving()
		return
	if _rotate_tool_active:
		if event.is_action_pressed("build_cancel"):
			exit_rotate_mode()
			return
		if event.is_action_pressed("build_confirm"):
			_try_rotate_existing()
		return
	if _copy_tool_active:
		if event.is_action_pressed("build_cancel"):
			exit_copy_mode()
			return
		if event.is_action_pressed("build_confirm"):
			_try_copy()
		return
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
	exit_move_mode()
	exit_rotate_mode()
	exit_copy_mode()
	_demolish_active = true
	demolish_mode_changed.emit(true)
	tool_mode_changed.emit(&"demolish")


func exit_demolish_mode() -> void:
	if not _demolish_active:
		return
	_clear_demolish_highlight()
	_demolish_active = false
	demolish_mode_changed.emit(false)
	tool_mode_changed.emit(&"")


func is_demolish_active() -> bool:
	return _demolish_active


func enter_move_mode() -> void:
	exit_build_mode()
	exit_demolish_mode()
	exit_rotate_mode()
	exit_copy_mode()
	_move_active = true
	tool_mode_changed.emit(&"move")


func exit_move_mode() -> void:
	if not _move_active:
		return
	if _moving_node != null and is_instance_valid(_moving_node):
		_return_moving_to_origin()
	_clear_demolish_highlight()
	_move_active = false
	tool_mode_changed.emit(&"")


func is_move_active() -> bool:
	return _move_active


func enter_rotate_mode() -> void:
	exit_build_mode()
	exit_demolish_mode()
	exit_move_mode()
	exit_copy_mode()
	_rotate_tool_active = true
	tool_mode_changed.emit(&"rotate")


func exit_rotate_mode() -> void:
	if not _rotate_tool_active:
		return
	_clear_demolish_highlight()
	_rotate_tool_active = false
	tool_mode_changed.emit(&"")


func is_rotate_active() -> bool:
	return _rotate_tool_active


func enter_copy_mode() -> void:
	exit_build_mode()
	exit_demolish_mode()
	exit_move_mode()
	exit_rotate_mode()
	_copy_tool_active = true
	tool_mode_changed.emit(&"copy")


func exit_copy_mode() -> void:
	if not _copy_tool_active:
		return
	_clear_demolish_highlight()
	_copy_tool_active = false
	tool_mode_changed.emit(&"")


func is_copy_active() -> bool:
	return _copy_tool_active


## Copiar: clic sobre un objeto colocado → entra en modo colocación de ESE
## buildable con su misma rotación, para estampar copias (paga su coste).
func _try_copy() -> void:
	var mouse_world: Vector2 = get_tree().current_scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	var id: StringName = _grid_buildable_lookup.get(grid_pos, &"")
	var rot: float = _grid_rotation_lookup.get(grid_pos, 0.0)
	if id == &"":
		# Fallback: estación/generador de escena bajo el ratón (no clonables aquí).
		AudioManager.play_named(&"build_error")
		return
	var b: BuildableData = _find_buildable_by_id(id)
	if b == null:
		return
	exit_copy_mode()
	enter_build_mode(b)
	if b.size == Vector2i(1, 1):
		_ghost_rotation_deg = rot
		if _ghost != null:
			_ghost.rotation_degrees = rot
	AudioManager.play_named(&"menu_select")


func _return_moving_to_origin() -> void:
	SolidBase.set_enabled(_moving_node, true)
	_moving_node.global_position = GridManager.grid_to_world(_moving_from)
	_moving_node.modulate = Color.WHITE
	GridManager.place_object(_moving_from, _moving_node)
	_grid_cost_lookup[_moving_from] = _moving_cost
	_grid_buildable_lookup[_moving_from] = _moving_id
	_grid_rotation_lookup[_moving_from] = _moving_rot
	_moving_node = null


## Objeto "movible" bajo el ratón aunque no esté en el grid (estaciones y
## generadores colocados a mano en la escena).
func _find_movable_under_mouse(mouse_world: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = 44.0
	for grp in ["workstations", "generators"]:
		for n in get_tree().get_nodes_in_group(grp):
			var n2: Node2D = n as Node2D
			if n2 == null or not is_instance_valid(n2) or not n2.visible:
				continue
			var d: float = n2.global_position.distance_to(mouse_world)
			if d < best_d:
				best_d = d
				best = n2
	return best


func _try_pick_for_move() -> void:
	var mouse_world: Vector2 = get_tree().current_scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	var node: Node2D = null
	if GridManager.is_cell_occupied(grid_pos):
		node = GridManager._occupied.get(grid_pos)
	if node == null or not is_instance_valid(node):
		# Fallback: estaciones/generadores de la escena (no registrados en grid).
		node = _find_movable_under_mouse(mouse_world)
		if node == null:
			return
		grid_pos = GridManager.world_to_grid(node.global_position)
	_moving_node = node
	_moving_from = grid_pos
	_moving_id = _grid_buildable_lookup.get(grid_pos, &"")
	_moving_cost = _grid_cost_lookup.get(grid_pos, 0)
	_moving_rot = _grid_rotation_lookup.get(grid_pos, 0.0)
	GridManager.remove_object(grid_pos)
	_grid_cost_lookup.erase(grid_pos)
	_grid_buildable_lookup.erase(grid_pos)
	_grid_rotation_lookup.erase(grid_pos)
	SolidBase.set_enabled(_moving_node, false)
	_clear_demolish_highlight()
	AudioManager.play_named(&"menu_select")


func _try_drop_moving() -> void:
	var mouse_world: Vector2 = get_tree().current_scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	var b: BuildableData = _find_buildable_by_id(_moving_id)
	if not _cell_ok_for(b, grid_pos):
		AudioManager.play_named(&"build_error")
		return
	_moving_node.global_position = GridManager.grid_to_world(grid_pos)
	_moving_node.modulate = Color.WHITE
	GridManager.place_object(grid_pos, _moving_node)
	_grid_cost_lookup[grid_pos] = _moving_cost
	_grid_buildable_lookup[grid_pos] = _moving_id
	_grid_rotation_lookup[grid_pos] = _moving_rot
	SolidBase.set_enabled(_moving_node, true)
	VFXManager.play(VFXManager.FX.BUILD, _moving_node.global_position)
	AudioManager.play_named(&"build_place")
	_moving_node = null


## ¿La celda vale para este buildable? (libre + dentro de zona permitida)
func _cell_ok_for(b: BuildableData, grid_pos: Vector2i) -> bool:
	if GridManager.is_cell_occupied(grid_pos):
		return false
	var zone: GameEnums.ZoneType = GridManager.get_zone_type(grid_pos)
	if zone == GameEnums.ZoneType.NONE:
		return false
	if b != null and b.allowed_zone != GameEnums.ZoneType.NONE and zone != b.allowed_zone:
		return false
	return true


func _try_rotate_existing() -> void:
	var mouse_world: Vector2 = get_tree().current_scene.get_global_mouse_position()
	var grid_pos: Vector2i = GridManager.world_to_grid(mouse_world)
	if not GridManager.is_cell_occupied(grid_pos):
		return
	var node: Node2D = GridManager._occupied.get(grid_pos)
	var b: BuildableData = _find_buildable_by_id(_grid_buildable_lookup.get(grid_pos, &""))
	if b == null or b.size != Vector2i(1, 1):
		AudioManager.play_named(&"build_error")
		return
	var rot: float = fposmod(_grid_rotation_lookup.get(grid_pos, 0.0) + 90.0, 360.0)
	node.rotation_degrees = rot
	_grid_rotation_lookup[grid_pos] = rot
	AudioManager.play_named(&"menu_select")


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


## Contenedor donde viven todos los objetos colocados: el mismo World que
## tiene y_sort_enabled, para que ordenen por Y junto a personajes y workers.
func _object_parent() -> Node:
	var w: Node = get_tree().get_first_node_in_group("world_container")
	return w if w != null else get_tree().current_scene


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
	_apply_custom_id(instance, _current_buildable)
	_object_parent().add_child(instance)
	instance.global_position = GridManager.grid_to_world(grid_pos)
	instance.rotation_degrees = _ghost_rotation_deg
	GridManager.place_object(grid_pos, instance)
	_grid_cost_lookup[grid_pos] = _current_buildable.cost
	_grid_buildable_lookup[grid_pos] = _current_buildable.id
	_grid_rotation_lookup[grid_pos] = _ghost_rotation_deg
	_assign_zone_visual_group(instance, _current_buildable.allowed_zone)
	_attach_deco_solid(instance, _current_buildable)
	VFXManager.play(VFXManager.FX.BUILD, instance.global_position)
	_spawn_pop(instance)
	AudioManager.play_beep(540.0, 0.1, -12.0)
	placement_completed.emit(_current_buildable, instance.global_position)
	exit_build_mode()


## Colisión de pies para decoraciones físicas (mesas, muebles, naturaleza).
## Alfombras/suelos y cosas de pared no bloquean el paso.
func _attach_deco_solid(instance: Node2D, b: BuildableData) -> void:
	if instance == null or b == null or not b.is_decorative:
		return
	if b.decoration_category != &"table" and b.decoration_category != &"nature":
		return
	var w: float = max(24.0, b.size.x * 32.0 * 0.6)
	SolidBase.attach(instance, Vector2(w, 14.0), Vector2(0, 4))


func _spawn_pop(instance: Node2D) -> void:
	# El objeto aparece con un "pop": tras un pequeño destello mágico crece con
	# rebote y hace flash. Deja ver primero la explosión de VFXManager.play(BUILD).
	if instance == null or not is_instance_valid(instance):
		return
	var base_scale: Vector2 = instance.scale
	instance.scale = Vector2.ZERO
	instance.modulate = Color(1.9, 1.9, 2.2, 0.0)  # brillante y transparente
	var tw: Tween = instance.create_tween()
	tw.tween_interval(0.08)
	tw.set_parallel(true)
	tw.tween_property(instance, "scale", base_scale, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(instance, "modulate", Color(1, 1, 1, 1), 0.34)


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
		_apply_custom_id(instance, b)
		_object_parent().add_child(instance)
		instance.global_position = GridManager.grid_to_world(grid_pos)
		var rot: float = float(entry.get("rot", 0.0))
		instance.rotation_degrees = rot
		GridManager.place_object(grid_pos, instance)
		_grid_cost_lookup[grid_pos] = int(entry.get("cost", b.cost))
		_grid_buildable_lookup[grid_pos] = b.id
		_grid_rotation_lookup[grid_pos] = rot
		_assign_zone_visual_group(instance, b.allowed_zone)
		_attach_deco_solid(instance, b)
