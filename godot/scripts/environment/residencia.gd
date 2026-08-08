extends Node
## Autoload. Registro de qué ayudante vive en cada casa.
##
## Identificador estable: grid_pos (Vector2i). BuildManager reconstruye los
## edificios en las mismas celdas antes de que ShopManager reinstancie los
## workers, así que la grid_pos sobrevive al save/load sin IDs inventados.
##
## Cuatro operaciones: asignar, casa_de, residentes_de, liberar.

var _asignadas: Dictionary = {}  ## Node (worker) → Vector2i (grid_pos de su casa)


## Vincula un worker a una casa, identificada por su celda en la cuadrícula.
## Si el worker ya tenía casa, la sobreescribe (la plaza anterior no se libera
## aquí: enter/leave lo gestiona worker_house al descansar, no al asignar).
func asignar(worker: Node, grid_pos: Vector2i) -> void:
	_asignadas[worker] = grid_pos


## Devuelve la casa del worker, o null si no tiene asignada o fue demolida.
## No reasigna automáticamente: que el orquestador busque otra por proximidad.
func casa_de(worker: Node) -> Node2D:
	var gp: Vector2i = _asignadas.get(worker, Vector2i(-1, -1))
	if gp.x < 0:
		return null
	return _buscar_en(gp)


## grid_pos guardada, incluso si la casa fue demolida. Para el save dict:
## el worker almacena esta celda y al cargar se reencuentra con la casa si
## BuildManager la reconstruyó antes. Vector2i(-1,-1) = sin casa.
func grid_de(worker: Node) -> Vector2i:
	return _asignadas.get(worker, Vector2i(-1, -1))


## Lista de workers cuyo registro apunta a esta casa. Limpia referencias
## muertas al iterar (workers que hicieron queue_free sin llamar a liberar).
func residentes_de(house: Node2D) -> Array:
	var gp: Vector2i = GridManager.world_to_grid(house.global_position)
	var out: Array = []
	var muertos: Array = []
	for w in _asignadas.keys():
		if not is_instance_valid(w):
			muertos.append(w)
			continue
		if _asignadas[w] == gp:
			out.append(w)
	for w in muertos:
		_asignadas.erase(w)
	return out


## Olvida al worker. No toca el aforo de la casa: enter/leave es cosa de
## worker_house.gd durante el descanso.
func liberar(worker: Node) -> void:
	_asignadas.erase(worker)


## Busca un nodo worker_house visible en la celda dada. Si el jugador demolió
## la casa, la celda está vacía o tiene otro edificio, y devuelve null.
func _buscar_en(grid_pos: Vector2i) -> Node2D:
	for h in get_tree().get_nodes_in_group("worker_house"):
		var n: Node2D = h as Node2D
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		if GridManager.world_to_grid(n.global_position) == grid_pos:
			return n
	return null
