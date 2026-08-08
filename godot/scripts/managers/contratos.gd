extends Node
## Autoload. Bolsa diaria de 3 candidatos a ayudante.
##
## Cada día real se generan 3 fichas con tipo, nombre, rasgo, recurso favorito
## y precio variable (±30 % sobre el precio base). El jugador elige uno —o
## ninguno— y espera al día siguiente para ver candidatos nuevos.
##
## Guarda un timestamp Unix en vez del día del calendario del juego: así la
## bolsa rota con el reloj del sistema, no con los días simulados de la partida.

const MAX_POR_TIPO: int = 10
const PRECIO_MIN: float = 0.70
const PRECIO_MAX: float = 1.30

## Tipos que pueden salir como candidatos (sin protagonista ni cliente).
const HIRABLE_TYPES: Array[int] = [
	GameEnums.WorkerType.DUENDE,
	GameEnums.WorkerType.GOLEM,
	GameEnums.WorkerType.APPRENTICE,
	GameEnums.WorkerType.LENADOR,
	GameEnums.WorkerType.ESPIRITU,
]

var _candidatos: Array = []      ## 3 Dictionary; los contratados se vacían → {}
var _last_refresh: int = 0       ## timestamp Unix del momento de la última renovación


## --- API pública -----------------------------------------------------------

## Devuelve los candidatos activos (máx. 3). Si toca renovar, los genera antes.
func candidatos() -> Array:
	if _toca_renovar():
		_renovar()
	var out: Array = []
	for c in _candidatos:
		if not c.is_empty():
			out.append(_marcar_tope(c))
	return out


## La bolsa tal cual, con los huecos vacíos incluidos. `candidatos()` filtra los
## contratados y renumera, así que sus índices NO sirven para `contratar(idx)`.
## Quien vaya a contratar necesita esta.
func candidatos_crudos() -> Array:
	if _toca_renovar():
		_renovar()
	return _candidatos


## Saca al candidato idx de la bolsa y devuelve sus datos. Si ya fue contratado
## o el índice es inválido, devuelve {}.
func contratar(idx: int) -> Dictionary:
	if idx < 0 or idx >= _candidatos.size():
		return {}
	var c: Dictionary = _candidatos[idx]
	if c.is_empty():
		return {}
	_candidatos[idx] = {}
	return c


## ¿Quedan plazas de este tipo? (máx. 10 por tipo).
func puede_contratar(tipo: int) -> bool:
	return _contar_activos(tipo) < MAX_POR_TIPO


## Cuántas plazas quedan libres para este tipo.
func plazas_libres(tipo: int) -> int:
	return maxi(0, MAX_POR_TIPO - _contar_activos(tipo))


## --- Persistencia ----------------------------------------------------------

func get_save_state() -> Dictionary:
	var ser: Array = []
	for c in _candidatos:
		ser.append(c.duplicate() if not c.is_empty() else {})
	return {"last_refresh": _last_refresh, "candidatos": ser}


func load_save_state(data: Dictionary) -> void:
	_last_refresh = int(data.get("last_refresh", 0))
	var guardados: Array = data.get("candidatos", [])
	_candidatos.clear()
	for i in 3:
		if i < guardados.size() and not guardados[i].is_empty():
			_candidatos.append(guardados[i].duplicate())
		else:
			_candidatos.append({})
	# Al cargar partida, si ya pasó el día o el reloj fue hacia atrás, renueva.
	if _toca_renovar():
		_renovar()


## --- Lógica de día real ----------------------------------------------------

## ¿Ha cambiado el día UTC o el reloj retrocedió?
func _toca_renovar() -> bool:
	var now: int = Time.get_unix_time_from_system()
	if now < _last_refresh:
		return true                    # el reloj fue hacia atrás
	return _dia_of(now) > _dia_of(_last_refresh)


func _dia_of(ts: int) -> int:
	return ts / 86400


func _renovar() -> void:
	_candidatos.clear()
	for _i in 3:
		_candidatos.append(_generar_candidato())
	_last_refresh = Time.get_unix_time_from_system()


## --- Generación de candidatos ----------------------------------------------

func _generar_candidato() -> Dictionary:
	var tipo: int = HIRABLE_TYPES[randi() % HIRABLE_TYPES.size()]
	# El precio parte del ACTUAL de ese tipo, no del de base. ShopManager sube un
	# 40 % tras cada contratación (shop_manager.gd:76) y esa escalada es el freno
	# que sostiene el ritmo medido de 18,9 h de partida. Usando DEFAULT_PRICES el
	# décimo ayudante costaría lo mismo que el primero y el freno desaparecería.
	var pre: int = ShopManager.get_price(tipo)
	var precio: int = int(round(float(pre) * randf_range(PRECIO_MIN, PRECIO_MAX)))

	# Nombre desde el mismo diccionario que usa worker_base._random_name().
	var pool: Array = WorkerBase.NAMES.get(tipo, WorkerBase.NAMES_FALLBACK)
	if pool.is_empty():
		pool = WorkerBase.NAMES_FALLBACK
	var nombre: String = pool[randi() % pool.size()]

	var rasgo: int = randi() % WorkerBase.TRAIT_NAMES.size()
	var fav: int = _recurso_favorito_para(tipo)

	return {
		"type": tipo,
		"name": nombre,
		"trait": rasgo,
		"trait_label": WorkerBase.TRAIT_NAMES.get(rasgo, ""),
		"favorite": fav,
		"price": precio,
		# El carácter va en la ficha: desde que existe el MBTI es media personalidad,
		# y fichar a ciegas justo esa parte vaciaba la idea del contrato.
		"ejes": VidaSocial.sortear_ejes(),
	}


## Recurso favorito aleatorio entre los que recolecta este tipo de ayudante.
## Para aprendices (sin recursos) devuelve NONE.
func _recurso_favorito_para(tipo: int) -> int:
	var opciones: Array[int] = []
	for rt in GameEnums.RESOURCE_TO_WORKER.keys():
		if GameEnums.RESOURCE_TO_WORKER[rt] == tipo:
			opciones.append(rt)
	if opciones.is_empty():
		return GameEnums.ResourceType.NONE
	return opciones[randi() % opciones.size()]


## --- Tope de plantilla -----------------------------------------------------

func _marcar_tope(c: Dictionary) -> Dictionary:
	var out: Dictionary = c.duplicate()
	if _contar_activos(out["type"]) >= MAX_POR_TIPO:
		out["contratable"] = false
		out["motivo"] = "Tope de %d %s alcanzado" % [MAX_POR_TIPO, GameEnums.WORKER_LABEL.get(out["type"], "ayudantes")]
	else:
		out["contratable"] = true
		out["motivo"] = ""
	return out


func _contar_activos(tipo: int) -> int:
	var n: int = 0
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w) and w.get("worker_type") == tipo:
			n += 1
	return n
