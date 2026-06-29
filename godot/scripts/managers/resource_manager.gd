extends Node
## Registers ResourceNodes spawned in the world so AI can query the closest
## available node by type without doing scene-wide scans.
## También mantiene el mapeo ResourceType → ItemData para que generadores
## construidos en runtime puedan auto-asignar su item_data sin depender de
## que game_bootstrap los descubra (eso solo pasa al inicio del juego).

signal node_registered(node)
signal node_unregistered(node)

var _registered_nodes: Array = []  # Array of ResourceNode (Node2D)
var _type_to_item: Dictionary = {}  # ResourceType (int) → ItemData


func register_type_item(resource_type: int, item: ItemData) -> void:
	if item == null:
		return
	_type_to_item[resource_type] = item


func get_item_for_type(resource_type: int) -> ItemData:
	return _type_to_item.get(resource_type)


## Asigna el item_data del generador si está vacío. Llamado por cada
## ResourceGenerator en su _ready. Resuelve el problema de gens construidos
## en runtime que no pasan por el wire inicial del bootstrap.
func assign_item_to_generator(gen) -> void:
	if gen == null:
		return
	if "item_data" in gen and gen.item_data == null and "resource_type" in gen:
		var item: ItemData = get_item_for_type(int(gen.resource_type))
		if item != null:
			gen.item_data = item


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


func get_closest_available_node(from_pos: Vector2, type: GameEnums.ResourceType, requester: Node = null):
	var best = null
	var best_dist_sq: float = INF
	for n in _registered_nodes:
		if not is_instance_valid(n):
			continue
		if not n.is_available():
			continue
		# Si otro worker ya reservó este nodo, no lo consideramos: el solicitante
		# debe quedarse en wander en lugar de competir por el mismo target.
		if requester != null and n.has_method("is_reserved_for_other") and n.is_reserved_for_other(requester):
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
