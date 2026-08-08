extends Node
## Comprueba que la enemistad se NOTA en pantalla, no solo en los números.
##
## Coge dos ayudantes, los enemista a la fuerza, los pone pegados y mira qué
## hacen. Las tres cosas que tienen que pasar —darse la espalda, alejarse y no
## compartir banco— son conducta, y la única forma honesta de comprobarlas es
## dejar correr el juego de verdad y medir.
##
## Bandera: `--diagrina`. Está en SaveManager.BANDERAS_DIAGNOSTICO, así que el
## arranque es de SOLO LECTURA y no puede escribir sobre la partida del jugador.
##
##     godot --headless -- --diagrina

const ESPERA_MUNDO: float = 2.0    ## que acabe de cargar y los workers existan
## A 6 s la medida NO servía: el control (sin enemistad) daba 148/267/138 px y la
## riña 122/215/292 px — se solapan. A esa altura el paseo normal ya domina y tapa
## el empujón de la huida. Se mide en el primer segundo, que es cuando el gesto ocurre.
const OBSERVAR: float = 1.0        ## tiempo de observación tras el encuentro

var _fase: int = 0
var _t: float = 0.0
var _a: Node2D = null
var _b: Node2D = null
var _dist_inicial: float = 0.0
var _mirada_ok: bool = false
var _fallos: Array[String] = []
## Con `--diagrina=control` NO se les enemista. Sirve para comparar: dos que se
## saludan también se separan al reanudar el paseo, así que sin este control la
## distancia final no demuestra nada.
var _control: bool = false


## Modo mirador: `--diagrina=mirar`. No mide nada ni se cierra — monta DOS parejas
## en pantalla, una reñida y otra amiga, y las hace cruzarse cada pocos segundos.
## El contraste es lo que hace entendible el gesto: en solitario no sabes si lo que
## ves es la riña o el paseo de siempre.
var _mirar: bool = false
var _pareja_rina: Array = []
var _pareja_amiga: Array = []
var _recolocar: float = 0.0
const CADA: float = 7.0   ## GREET_COOLDOWN son 12 s, pero se resetea al recolocar


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--diagrina=control":
			_control = true
		elif a == "--diagrina=mirar":
			_mirar = true


func _process(delta: float) -> void:
	_t += delta
	if _mirar:
		_tick_mirador(delta)
		return
	match _fase:
		0:
			if _t >= ESPERA_MUNDO:
				_montar()
		1:
			if _t >= ESPERA_MUNDO + OBSERVAR:
				_juzgar()


## Elige dos ayudantes, los enemista y los pone cara a cara.
func _montar() -> void:
	var ws: Array = []
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w) and w.get_node_or_null("VidaSocial") != null:
			ws.append(w)
	if ws.size() < 2:
		print("[DiagRiña] KO: hacen falta 2 ayudantes con VidaSocial, hay %d" % ws.size())
		get_tree().quit()
		return
	_a = ws[0]
	_b = ws[1]
	var va: Node = _a.get_node("VidaSocial")
	var vb: Node = _b.get_node("VidaSocial")
	# Enemistad forzada por los dos lados: el umbral se comprueba con los roces
	# propios, así que ponerlo solo en uno daría una riña de una sola dirección.
	if not _control:
		va._roces[vb._uid] = va.UMBRAL_CONFLICTO
		vb._roces[va._uid] = va.UMBRAL_CONFLICTO
		if not va.enemistado_con(vb) or not vb.enemistado_con(va):
			_fallos.append("con %d roces siguen sin estar reñidos" % va.UMBRAL_CONFLICTO)

	# Pegados y caminando: `tick_saludos` ignora a los que están parados.
	_b.global_position = _a.global_position + Vector2(va.GREET_RADIUS * 0.5, 0.0)
	_a.velocity = Vector2(20.0, 0.0)
	_b.velocity = Vector2(-20.0, 0.0)
	va._greet_cd = 0.0
	va._greet_scan = 0.0
	_dist_inicial = _a.global_position.distance_to(_b.global_position)
	print("[DiagRiña]%s %s vs %s, arrancan a %.1f px" % [
		" CONTROL (sin enemistad):" if _control else "",
		_a.get("worker_name"), _b.get("worker_name"), _dist_inicial])
	_fase = 1


func _juzgar() -> void:
	var va: Node = _a.get_node("VidaSocial")
	var vb: Node = _b.get_node("VidaSocial")

	# 1) Se alejan, y su destino de paseo apunta al lado contrario del otro. Lo
	#    segundo es lo que de verdad separa una riña de un saludo: la distancia sola
	#    no distingue, porque dos que se saludan también acaban separándose.
	var dist: float = _a.global_position.distance_to(_b.global_position)
	var hacia_fuera: int = 0
	for par in [[_a, _b], [_b, _a]]:
		var yo: Node2D = par[0]
		var otro: Node2D = par[1]
		var al_otro: Vector2 = otro.global_position - yo.global_position
		var al_destino: Vector2 = yo.get("_wander_target") - yo.global_position
		if al_destino.dot(al_otro) < 0.0:
			hacia_fuera += 1
	if _control:
		print("[DiagRiña] CONTROL: %.1f → %.1f px, %d/2 se alejan del otro (referencia)" % [
			_dist_inicial, dist, hacia_fuera])
		get_tree().quit()
		return
	if hacia_fuera < 2:
		_fallos.append("solo %d de 2 puso rumbo contrario al otro" % hacia_fuera)
	if dist <= _dist_inicial:
		_fallos.append("no se alejaron: %.1f px → %.1f px" % [_dist_inicial, dist])

	# 2) Ninguno se queda sentado en el banco del otro.
	if va._punto != null and va._punto == vb._punto:
		_fallos.append("comparten banco estando reñidos")

	# 3) Los destinos de paseo siguen dentro de la isla. Sin el recorte, la huida
	#    los mandaba andando fuera del mapa: no hay colisionadores que los frenen.
	for w in [_a, _b]:
		var rect: Rect2 = GridManager.get_zone_rect_at(w.get("_home_position"))
		if rect.size != Vector2.ZERO and not rect.has_point(w.get("_wander_target")):
			_fallos.append("%s huye fuera de su zona: %s no cae en %s" % [
				w.get("worker_name"), w.get("_wander_target"), rect])

	print("[DiagRiña] %.1f → %.1f px, %d/2 con rumbo contrario al otro" % [
		_dist_inicial, dist, hacia_fuera])
	for f in _fallos:
		print("[DiagRiña]   FALLO: %s" % f)
	print("[DiagRiña] %s" % ("OK" if _fallos.is_empty() else "KO (%d fallos)" % _fallos.size()))
	get_tree().quit()


## --- Modo mirador ------------------------------------------------------------

func _tick_mirador(delta: float) -> void:
	if _t < ESPERA_MUNDO:
		return
	if _pareja_rina.is_empty():
		_montar_mirador()
		return
	_recolocar -= delta
	if _recolocar <= 0.0:
		_recolocar = CADA
		_cruzar(_pareja_rina)
		_cruzar(_pareja_amiga)


func _montar_mirador() -> void:
	var ws: Array = []
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w) and w.get_node_or_null("VidaSocial") != null:
			ws.append(w)
	if ws.size() < 2:
		print("[Mirador] Hacen falta al menos 2 ayudantes, hay %d." % ws.size())
		_mirar = false
		return
	_pareja_rina = [ws[0], ws[1]]
	_pareja_amiga = [ws[2], ws[3]] if ws.size() >= 4 else []

	# Los ejes se fijan a mano en vez de dejarlos al azar: la afinidad sale de
	# cuántos comparten, así que opuestos = choque garantizado e iguales = amistad.
	_fijar(_pareja_rina[0], [false, false, false, false])
	_fijar(_pareja_rina[1], [true, true, true, true])
	_marcar(_pareja_rina[0], "REÑIDOS", Color(1.0, 0.42, 0.38))
	_marcar(_pareja_rina[1], "REÑIDOS", Color(1.0, 0.42, 0.38))
	if not _pareja_amiga.is_empty():
		_fijar(_pareja_amiga[0], [false, false, false, false])
		_fijar(_pareja_amiga[1], [false, false, false, false])
		_marcar(_pareja_amiga[0], "amigos", Color(0.55, 0.95, 0.72))
		_marcar(_pareja_amiga[1], "amigos", Color(0.55, 0.95, 0.72))

	# Se les planta junto al primero, cada pareja en su sitio, y la cámara encima.
	var base: Vector2 = _pareja_rina[0].global_position
	_pareja_rina[0].set("_home_position", base)
	_pareja_rina[1].set("_home_position", base)
	if not _pareja_amiga.is_empty():
		var b2: Vector2 = base + Vector2(0, 150)
		_pareja_amiga[0].set("_home_position", b2)
		_pareja_amiga[1].set("_home_position", b2)
	var cam := get_tree().get_first_node_in_group("zone_camera")
	if cam == null:
		cam = _buscar_camara(get_tree().current_scene)
	if cam != null and cam.has_method("follow_node"):
		cam.follow_node(_pareja_rina[0])

	print("[Mirador] REÑIDOS: %s vs %s" % [
		_pareja_rina[0].get("worker_name"), _pareja_rina[1].get("worker_name")])
	if _pareja_amiga.is_empty():
		print("[Mirador] Sin pareja de control: harían falta 4 ayudantes y hay %d." % ws.size())
	else:
		print("[Mirador] amigos:  %s y %s" % [
			_pareja_amiga[0].get("worker_name"), _pareja_amiga[1].get("worker_name")])
	print("[Mirador] Se cruzan cada %.0f s. Cierra la ventana para salir." % CADA)
	_recolocar = 1.0


## Pone a los dos pegados y con el saludo listo, para provocar el encuentro. Los
## roces se reponen cada vez: si no, la reconciliación al coincidir los iría
## bajando y a mitad de demostración dejarían de estar reñidos.
func _cruzar(par: Array) -> void:
	if par.size() < 2 or not is_instance_valid(par[0]) or not is_instance_valid(par[1]):
		return
	var va: Node = par[0].get_node("VidaSocial")
	var vb: Node = par[1].get_node("VidaSocial")
	if par == _pareja_rina:
		va._roces[vb._uid] = va.UMBRAL_CONFLICTO
		vb._roces[va._uid] = va.UMBRAL_CONFLICTO
	var centro: Vector2 = par[0].get("_home_position")
	par[0].global_position = centro - Vector2(va.GREET_RADIUS * 0.35, 0)
	par[1].global_position = centro + Vector2(va.GREET_RADIUS * 0.35, 0)
	par[0].velocity = Vector2(24, 0)
	par[1].velocity = Vector2(-24, 0)
	for v in [va, vb]:
		v._greet_cd = 0.0
		v._greet_scan = 0.0
		v._chat_pause = 0.0


func _fijar(w: Node2D, ejes: Array) -> void:
	var v: Node = w.get_node("VidaSocial")
	v._eje_ei = ejes[0]; v._eje_sn = ejes[1]; v._eje_tf = ejes[2]; v._eje_jp = ejes[3]


## Cartel sobre la cabeza, para saber quién es quién sin abrir ningún menú.
func _marcar(w: Node2D, texto: String, color: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.position = Vector2(-40, -62)
	l.size = Vector2(80, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 100
	w.add_child(l)


func _buscar_camara(n: Node):
	if n == null:
		return null
	if n is Camera2D and n.has_method("follow_node"):
		return n
	for c in n.get_children():
		var r = _buscar_camara(c)
		if r != null:
			return r
	return null
