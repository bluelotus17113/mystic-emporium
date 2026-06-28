extends Node

signal workstation_registered(station)
signal workstation_unregistered(station)
signal workstation_clicked(station)

var _stations: Array = []


func register(station) -> void:
	if station == null or _stations.has(station):
		return
	_stations.append(station)
	workstation_registered.emit(station)


func unregister(station) -> void:
	if station == null:
		return
	var idx: int = _stations.find(station)
	if idx == -1:
		return
	_stations.remove_at(idx)
	workstation_unregistered.emit(station)


func get_closest_idle(from_pos: Vector2, station_type: GameEnums.StationType):
	var best = null
	var best_dist_sq: float = INF
	for s in _stations:
		if not is_instance_valid(s):
			continue
		if station_type != GameEnums.StationType.NONE and s.station_type != station_type:
			continue
		if not s.has_method("is_ready_to_work") or not s.is_ready_to_work():
			continue
		var d: float = s.global_position.distance_squared_to(from_pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best = s
	return best


func get_by_type(station_type: GameEnums.StationType) -> Array:
	var result: Array = []
	for s in _stations:
		if is_instance_valid(s) and s.station_type == station_type:
			result.append(s)
	return result


func get_save_state() -> Dictionary:
	# Indexa por grid_pos. BuildManager.load_save_state ya reinstanció las stations
	# en su sitio antes de que SaveManager nos llame.
	var by_grid: Dictionary = {}
	for s in _stations:
		if not is_instance_valid(s) or not s.has_method("get_state_dict"):
			continue
		var gp: Vector2i = GridManager.world_to_grid(s.global_position)
		by_grid["%d,%d" % [gp.x, gp.y]] = s.get_state_dict()
	return {"by_grid": by_grid}


func load_save_state(data: Dictionary) -> void:
	var by_grid: Dictionary = data.get("by_grid", {})
	for s in _stations:
		if not is_instance_valid(s) or not s.has_method("apply_state_dict"):
			continue
		var gp: Vector2i = GridManager.world_to_grid(s.global_position)
		var key: String = "%d,%d" % [gp.x, gp.y]
		if by_grid.has(key):
			s.apply_state_dict(by_grid[key])
