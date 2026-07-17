extends Node
## Logical grid + zone lookup. Supports two backends:
##  - TileMapLayers (per-cell precision, registered via register_zone_layer)
##  - Rect2 zones (rectangular AABBs, registered via register_zone_rect)
## Either one can be used; rects are faster to set up for placeholder art.

const CELL_SIZE: int = 32

var _occupied: Dictionary = {}  # Vector2i -> Node2D
var _zone_layers: Dictionary = {}  # ZoneType -> TileMapLayer
var _zone_rects: Dictionary = {}  # ZoneType -> Array[Rect2]


func register_zone_layer(zone: GameEnums.ZoneType, layer: TileMapLayer) -> void:
	if layer == null:
		return
	_zone_layers[zone] = layer


func register_zone_rect(zone: GameEnums.ZoneType, rect: Rect2) -> void:
	# ZoneRegion re-llama esto cada vez que el patio se expande. Reemplazamos en vez
	# de acumular para que el lookup no arrastre rects obsoletos. Si en el futuro
	# alguna zona necesita varios rects, exponer register_zone_rect_additive aparte.
	_zone_rects[zone] = [rect]


func clear_zone_layers() -> void:
	_zone_layers.clear()
	_zone_rects.clear()


func get_playable_rect() -> Rect2:
	var out := Rect2()
	var has_any := false
	for arr in _zone_rects.values():
		for r in arr:
			if not has_any:
				out = r
				has_any = true
			else:
				out = out.merge(r)
	return out


func is_in_playable_area(pos: Vector2) -> bool:
	for arr in _zone_rects.values():
		for r in arr:
			if (r as Rect2).has_point(pos):
				return true
	return false


func get_zone_rect(zone: GameEnums.ZoneType) -> Rect2:
	var arr: Array = _zone_rects.get(zone, [])
	return arr[0] if not arr.is_empty() else Rect2()


func get_zone_rect_at(pos: Vector2) -> Rect2:
	for arr in _zone_rects.values():
		for r in arr:
			if (r as Rect2).has_point(pos):
				return r
	return Rect2()


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / CELL_SIZE), floor(world_pos.y / CELL_SIZE))


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5, grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5)


func is_cell_occupied(grid_pos: Vector2i) -> bool:
	if not _occupied.has(grid_pos):
		return false
	if not is_instance_valid(_occupied[grid_pos]):
		_occupied.erase(grid_pos)
		return false
	return true


func place_object(grid_pos: Vector2i, object: Node2D) -> bool:
	if is_cell_occupied(grid_pos):
		return false
	_occupied[grid_pos] = object
	return true


func remove_object(grid_pos: Vector2i) -> void:
	_occupied.erase(grid_pos)


func get_zone_type(grid_pos: Vector2i) -> GameEnums.ZoneType:
	# Check tile layers first (precise)
	for zone in [GameEnums.ZoneType.NATURE, GameEnums.ZoneType.WORKSHOP, GameEnums.ZoneType.RECEPTION]:
		var layer: TileMapLayer = _zone_layers.get(zone)
		if layer == null:
			continue
		if layer.get_cell_source_id(grid_pos) != -1:
			return zone
	# Fallback: check rectangle zones (coarse)
	var world_point: Vector2 = grid_to_world(grid_pos)
	for zone in [GameEnums.ZoneType.NATURE, GameEnums.ZoneType.WORKSHOP, GameEnums.ZoneType.RECEPTION]:
		var rects: Array = _zone_rects.get(zone, [])
		for rect in rects:
			if rect.has_point(world_point):
				return zone
	return GameEnums.ZoneType.NONE


func clear_all() -> void:
	_occupied.clear()
