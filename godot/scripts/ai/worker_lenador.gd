extends WorkerBase
## Leñador: especializado en madera arcana (raw del Patio Natural).
## La mena de hierro es tarea del Gólem (minerales).
##
## Es el único que puede talar los árboles del patio, y solo cuando el jugador
## se lo ordena desde su menú. Los árboles nacen cerrados a los workers
## (ver TreeNatural): sin esta orden nadie los toca, así el bosque no se
## deshace solo en cuanto contratas un leñador.


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.LENADOR
	preferred_resource_types = [
		GameEnums.ResourceType.ARCANE_WOOD,
		GameEnums.ResourceType.UMBRAL_ROOT,
		GameEnums.ResourceType.ANCIENT_SAP,
	]
	move_speed = 80.0


func _acciones_de_oficio() -> Array:
	var sin_marcar: int = _arboles_sin_marcar().size()
	var marcados: int = _arboles_marcados()
	var acciones: Array = []
	if sin_marcar > 0:
		acciones.append({
			"text": "🪓 Talar el árbol más cercano",
			"cb": Callable(self, "ordenar_talar_cercano"),
		})
	if marcados > 0:
		acciones.append({
			"text": "✋ Cancelar tala (%d marcados)" % marcados,
			"cb": Callable(self, "cancelar_tala"),
		})
	elif sin_marcar == 0:
		acciones.append({"text": "🪵 No quedan árboles", "cb": Callable()})
	return acciones


func _arboles_sin_marcar() -> Array:
	var out: Array = []
	for t in get_tree().get_nodes_in_group("arboles_talables"):
		var a := t as TreeNatural
		if a != null and is_instance_valid(a) and not a.esta_marcado():
			out.append(a)
	return out


func _arboles_marcados() -> int:
	var n: int = 0
	for t in get_tree().get_nodes_in_group("arboles_talables"):
		var a := t as TreeNatural
		if a != null and is_instance_valid(a) and a.esta_marcado():
			n += 1
	return n


## Marca UN árbol, el más cercano a este leñador. De uno en uno a propósito:
## un interruptor de "talar todo" arrasaría el patio con un clic y no habría
## vuelta atrás. A partir de aquí lo coge por su ciclo normal de recolección.
func ordenar_talar_cercano() -> void:
	var mejor: TreeNatural = null
	var mejor_d: float = INF
	for a in _arboles_sin_marcar():
		var d: float = (a as Node2D).global_position.distance_squared_to(global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = a
	if mejor == null:
		NotificationManager.post("No queda ningún árbol que talar.",
				NotificationManager.Kind.INFO)
		return
	mejor.marcar_para_talar()
	NotificationManager.post("%s va a talar un árbol." % _get_name(),
			NotificationManager.Kind.INFO)


## Devuelve los árboles marcados a decorado, si el jugador se arrepiente antes
## de que lleguen a caer.
func cancelar_tala() -> void:
	var n: int = 0
	for t in get_tree().get_nodes_in_group("arboles_talables"):
		var a := t as TreeNatural
		if a != null and is_instance_valid(a) and a.esta_marcado():
			a.desmarcar()
			n += 1
	if n > 0:
		NotificationManager.post("Tala cancelada (%d árboles)." % n,
				NotificationManager.Kind.INFO)
