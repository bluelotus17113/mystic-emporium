extends Node
## Registers ResourceNodes spawned in the world so AI can query the closest
## available node by type without doing scene-wide scans.

signal node_registered(node)
signal node_unregistered(node)

var _registered_nodes: Array = []  # Array of ResourceNode (Node2D)


func register_node(node) -> void:
	if node == null or _registered_nodes.has(node):
		return
	_registered_nodes.append(node)
	node_registered.emit(node)


func unregister_node(node) -> void:
	if node == null:
		return
	var idx: int = _registered_nodes.find(node)
	if idx == -1:
		return
	_registered_nodes.remove_at(idx)
	node_unregistered.emit(node)


func get_closest_available_node(from_pos: Vector2, type: GameEnums.ResourceType):
	var best = null
	var best_dist_sq: float = INF
	for n in _registered_nodes:
		if not is_instance_valid(n):
			continue
		if not n.is_available():
			continue
		if type != GameEnums.ResourceType.NONE and n.resource_type != type:
			continue
		var d: float = n.global_position.distance_squared_to(from_pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best = n
	return best


func get_all_nodes_of_type(type: GameEnums.ResourceType) -> Array:
	var result: Array = []
	for n in _registered_nodes:
		if is_instance_valid(n) and n.resource_type == type:
			result.append(n)
	return result


func count_available(type: GameEnums.ResourceType) -> int:
	var c: int = 0
	for n in _registered_nodes:
		if is_instance_valid(n) and n.is_available() and n.resource_type == type:
			c += 1
	return c
