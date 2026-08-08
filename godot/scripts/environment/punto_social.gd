class_name PuntoSocial
extends Node2D
## Punto de reunión social. Se cuelga de un decorativo (ej. Banco de Jardín)
## para que los ayudantes paren a charlar durante el wander.
##
## Hasta CAP ayudantes se plantan aquí. Llegan, ocupan una posición distinta
## cada uno, y al rato siguen su camino. Si está lleno, el que llega pasa de
## largo sin bloquearse ni hacer cola.
##
## La función estática mas_cercano() sigue el patrón de _find_warm_spot() de
## worker_base.gd para que el enganche sea mínimo.

const CAP: int = 2

## Dos posiciones separadas para que los sprites no se solapen.
## Offsets relativos al centro del nodo (global_position).
## Dos posiciones a 20 px entre sí (dentro de GREET_RADIUS=28). Así el worker
## que llega caminando ve al que ya está sentado y _maybe_greet dispara la charla.
const STAND_OFFSETS: Array[Vector2] = [
	Vector2(-10, 48),
	Vector2(10, 48),
]

## Quién ocupa cada plaza, no cuántos. Con un contador, al irse el de la plaza 0
## el siguiente en llegar recibía otra vez el índice 1 y se plantaba encima del que
## ya estaba: dos sprites en el mismo píxel, que es justo lo que las dos posiciones
## separadas venían a evitar.
var _plazas: Array = [null, null]


func _ready() -> void:
	if modulate.a < 0.9:  # fantasma de previsualización en BuildManager
		return
	add_to_group("social_spot")


## --- API para el worker ----------------------------------------------------

func has_room() -> bool:
	return _libre() >= 0


## Ocupa la primera plaza libre y devuelve dónde plantarse. El worker usa ese
## Vector2 como _wander_target en vez de un punto al azar.
## Devuelve Vector2.ZERO si no cabía: quien llame debe comprobar has_room() antes.
func enter(w: Node) -> Vector2:
	var idx: int = _libre()
	if idx < 0:
		return Vector2.ZERO
	_plazas[idx] = w
	return _stand_at(idx)


func leave(w: Node) -> void:
	for i in _plazas.size():
		if _plazas[i] == w:
			_plazas[i] = null
			return


## Primera plaza libre, o -1. De paso suelta las de ayudantes que ya no existen:
## sin esto, un worker eliminado durante un asedio dejaría su plaza ocupada para
## siempre y el banco acabaría "lleno" sin nadie sentado.
func _libre() -> int:
	for i in _plazas.size():
		if _plazas[i] != null and not is_instance_valid(_plazas[i]):
			_plazas[i] = null
		if _plazas[i] == null:
			return i
	return -1


func _stand_at(idx: int) -> Vector2:
	return global_position + STAND_OFFSETS[clampi(idx, 0, STAND_OFFSETS.size() - 1)]


## --- Búsqueda (estática, misma firma conceptual que _find_warm_spot) --------

## Devuelve el PuntoSocial más cercano con hueco, o null. max_dist evita que
## un worker cruce medio mapa para sentarse en un banco.
static func mas_cercano(origen: Vector2, max_dist: float = 420.0) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Node2D = null
	var best_d: float = max_dist
	for s in tree.get_nodes_in_group("social_spot"):
		var n: Node2D = s as Node2D
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		if not n.has_method("has_room") or not n.has_room():
			continue
		var d: float = origen.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
