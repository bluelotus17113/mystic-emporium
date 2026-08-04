extends Node
## Construye un generador de los nuevos y abre el selector de especialidad, para
## poder verlos en una grabación. Se arranca con `--caprecolectable`, junto a
## `--write-movie`.
##
## Las dos cosas que añadimos al endgame solo existen si alguien las provoca: un
## generador hay que construirlo, y el selector solo sale al hacer clic en un
## ayudante. En una captura automática nadie pulsa nada, así que lo hace esto.
##
## No toca la partida: la bandera está en SaveManager.BANDERAS_DIAGNOSTICO, que
## fuerza modo solo lectura.

const GENERADOR: String = "res://scenes/environment/resource_generator_sal_abisal.tscn"

const ESPERA_INICIAL: int = 40
const TRAS_VIAJE: int = 140      ## el telón de nubes tarda lo suyo
const VER_GENERADOR: int = 120
const VER_MENU: int = 60


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--caprecolectable"):
		queue_free()
		return
	for _i in ESPERA_INICIAL:
		await get_tree().process_frame

	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam == null:
		print("[CapRec] no encuentro la cámara")
		return
	# Igual que en captura_viaje: en una grabación el ratón se queda en un borde
	# y el patio panea solo hasta salirse del mapa.
	cam.pan_por_borde = false

	# --- 1. al patio, que es donde vive un generador -----------------------
	print("[CapRec] nivel de patio = %d (los nuevos piden 5)" % ZoneExpansionManager.natural_level)
	cam.goto_zone(&"natural")
	for _i in TRAS_VIAJE:
		await get_tree().process_frame

	# --- 2. construir la Salina Abisal -------------------------------------
	var escena: PackedScene = load(GENERADOR)
	if escena == null:
		print("[CapRec] no carga %s" % GENERADOR)
		return
	var gen: Node2D = escena.instantiate() as Node2D
	get_tree().current_scene.add_child(gen)
	# Cerca del centro de la vista, para que salga en cuadro.
	var destino: Vector2 = cam.get_screen_center_position() + Vector2(0, 40)
	var ok: bool = BuildManager.register_prebuilt(gen, destino, &"build_generador_sal_abisal", 850)
	print("[CapRec] construida en %s -> %s" % [destino, "OK" if ok else "CELDA OCUPADA"])
	if not ok:
		# Segunda oportunidad un poco a la izquierda: el patio tiene props.
		ok = BuildManager.register_prebuilt(gen, destino + Vector2(96, 0), &"build_generador_sal_abisal", 850)
		print("[CapRec] segundo intento -> %s" % ("OK" if ok else "TAMPOCO"))

	for _i in VER_GENERADOR:
		await get_tree().process_frame
	print("[CapRec] FRAME-GENERADOR %d" % Engine.get_frames_drawn())
	print("[CapRec] item asignado = %s" % (gen.item_data.id if gen.item_data != null else "NINGUNO"))
	print("[CapRec] tipo=%d cooldown=%.1f nivel_min=%d" % [
		gen.resource_type, gen.generation_cooldown, gen.min_natural_level])
	var nodos: int = 0
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(n) and n.resource_type == gen.resource_type:
			nodos += 1
	print("[CapRec] nodos de sal abisal en el mundo: %d" % nodos)

	# --- 3. de vuelta al taller y clic en un ayudante -----------------------
	cam.goto_zone(&"taller")
	for _i in TRAS_VIAJE:
		await get_tree().process_frame

	var elegido: Node = null
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w) and "preferred_resource_types" in w \
				and w.preferred_resource_types.size() > 1:
			elegido = w
			break
	if elegido == null:
		print("[CapRec] ningún ayudante con más de un tipo de recurso")
		return
	print("[CapRec] ayudante: %s, %d tipos, especialidad = %s" % [
		elegido.worker_name, elegido.preferred_resource_types.size(),
		elegido.especialidad_texto()])

	# Clic sintético por el camino real, no llamando al menú a mano: así se
	# comprueba que la acción se construye de verdad al pulsar.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	elegido._on_body_clicked(null, ev, 0)
	for _i in VER_MENU:
		await get_tree().process_frame

	print("[CapRec] FRAME-MENU %d" % Engine.get_frames_drawn())
	var menu: Node = get_tree().get_first_node_in_group("entity_menu")
	print("[CapRec] tras abrir: manual=%s tipo=%d texto=%s | botones 'Especialidad' en el menú: %d" % [
		elegido._favorite_manual, elegido._favorite_type,
		elegido.especialidad_texto(), _contar_botones(menu, "Especialidad")])
	var boton: Button = _buscar_boton(menu, "Especialidad")
	if boton == null:
		print("[CapRec] NO aparece el botón de Especialidad en el menú")
		return
	print("[CapRec] botón encontrado: '%s'" % boton.text)

	# --- 4. darle vueltas al selector --------------------------------------
	for vuelta in 3:
		boton.pressed.emit()
		for _i in VER_MENU:
			await get_tree().process_frame
		print("[CapRec] vuelta %d -> '%s'  (manual=%s)" % [
			vuelta + 1, boton.text, elegido._favorite_manual])
	print("[CapRec] fin en frame %d" % Engine.get_frames_drawn())


## Cuántos Button descendientes empiezan por `prefijo`. Si sale más de uno, es
## que quedaron botones de una apertura anterior sin liberar.
func _contar_botones(raiz: Node, prefijo: String) -> int:
	if raiz == null:
		return 0
	var n: int = 0
	for h in raiz.get_children():
		if h is Button and (h as Button).text.begins_with(prefijo):
			n += 1
		n += _contar_botones(h, prefijo)
	return n


## Primer Button descendiente cuyo texto empieza por `prefijo`.
func _buscar_boton(raiz: Node, prefijo: String) -> Button:
	if raiz == null:
		return null
	for h in raiz.get_children():
		if h is Button and (h as Button).text.begins_with(prefijo):
			return h as Button
		var hallado: Button = _buscar_boton(h, prefijo)
		if hallado != null:
			return hallado
	return null
