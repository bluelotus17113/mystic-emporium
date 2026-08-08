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


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--diagrina=control":
			_control = true


func _process(delta: float) -> void:
	_t += delta
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
	if false:
		print("[DiagRiña] CONTROL: distancia %.1f → %.1f px (referencia)" % [_dist_inicial, dist])
		get_tree().quit()
		return
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
