class_name VidaSocial
extends Node
## Toda la vida social de un ayudante: saludos al cruzarse, charlas y reuniones
## en los bancos. Vive como hijo del worker y guarda su propio estado.
##
## Se extrajo de `worker_base.gd` cuando ese fichero llegó a 1050 líneas con
## recolección, energía, descanso, sueño, siestas, combate, guardado, menú
## contextual y esto encima. Cada añadido social le sumaba diez o veinte líneas
## más a un sitio donde un fallo rompe cuatro sistemas a la vez y en silencio.
##
## El worker le delega y le pregunta; no conoce los detalles.

const GREET_RADIUS: float = 28.0
const GREET_COOLDOWN: float = 12.0
const GREET_EMOTES: Array = ["👋", "♪", "😀", "🤝"]
const CHAT_EMOTES: Array = ["😄", "💬", "♪", "🤝", "✨", "😆", "👍"]

## Amistad: tras este número de encuentros con el mismo ayudante, el saludo cambia.
## MEDIDO con --diagencuentros sobre una partida real: el par que se cruza pasa el
## ~4 % del tiempo dentro del radio, o sea un saludo cada ~25 s. Con el umbral en 5
## eran DOS MINUTOS para ser amigos, y eso vacía el gesto. A 15 son ~6 min para un
## par normal y ~3 para uno compatible (que suma de dos en dos).
##
## Ojo con el otro hallazgo de esa medición: solo 2 de 6 parejas llegaron a cruzarse.
## No vas a tener una isla donde todos se conocen, sino relaciones concretas entre los
## que comparten espacio. Subir el umbral no deja a nadie fuera: a quien no se cruza
## nunca ya le daba igual el número.
const UMBRAL_AMIGO: int = 15
const AMIGO_EMOTES: Array = ["💕", "🌟", "😊", "💖"]

## Personalidad MBTI por ejes. Cuatro bits al azar al nacer: con etiquetas harían
## falta 16×16=256 combinaciones de pareja; con ejes, la afinidad sale sola.
##   E/I  extrovertido / introvertido    (false=E, true=I)
##   S/N  sensorial / intuitivo          (false=S, true=N)
##   T/F  racional / emocional           (false=T, true=F)
##   J/P  planificador / espontáneo      (false=J, true=P)
const AFINIDAD_CONFLICTO_MAX: int = 1   ## 0 o 1 ejes compartidos → choque
const UMBRAL_CONFLICTO: int = 20         ## roces para enemistar. Más alto que la
                                          ## amistad a propósito: enemistarse penaliza
                                          ## la producción, así que debe costar más
                                          ## que hacerse amigo, que no da nada.
const CONFLICTO_EMOTES: Array = ["💢", "😤", "💥", "😠"]
const RECONCILIAR_POR_COINCIDENCIA: int = 2  ## roces que se borran al compartir banco
const AFINIDAD_ALTA: int = 3             ## 3+ ejes → amistad ×2 más rápida
const INC_AFINIDAD_ALTA: int = 2         ## extra por encuentro con afinidad alta

## Al elegir destino de paseo, una de cada tres veces se va a un banco. Más alto
## y viven ahí sentados; más bajo y no se ve nunca que los usen.
const PROB_SOCIAL: float = 0.34
const SOCIAL_MIN: float = 6.0
const SOCIAL_MAX: float = 12.0

var _w: Node2D = null            ## el ayudante del que cuelgo
var _greet_cd: float = 0.0
var _greet_scan: float = 0.0
var _chat_pause: float = 0.0     ## segundos parado charlando
var _punto: Node2D = null        ## banco ocupado, para soltarlo al irse
var _uid: String = ""           ## identificador único para la memoria de amistad
var _memoria: Dictionary = {}   ## uid del compañero → nº de encuentros
var _roces: Dictionary = {}     ## uid del compañero → nº de conflictos
var _eje_ei: bool = false       ## false=E, true=I
var _eje_sn: bool = false       ## false=S, true=N
var _eje_tf: bool = false       ## false=T, true=F
var _eje_jp: bool = false       ## false=J, true=P


static func crear(worker: Node2D) -> VidaSocial:
	var v := VidaSocial.new()
	v.name = "VidaSocial"
	v._w = worker
	## Identificador único: randi() + ticks. Suficiente para los ~40 workers
	## máximos de una partida. Se guarda y se carga para que la amistad sobreviva.
	v._uid = "%x%x" % [randi(), Time.get_ticks_usec()]
	v._eje_ei = randi() & 1 == 1
	v._eje_sn = randi() & 1 == 1
	v._eje_tf = randi() & 1 == 1
	v._eje_jp = randi() & 1 == 1
	worker.add_child(v)
	return v


## --- Lo que el worker pregunta ---------------------------------------------

## ¿Está parado charlando? El worker congela su movimiento mientras sea true.
func esta_charlando() -> bool:
	return _chat_pause > 0.0


func consumir_charla(delta: float) -> void:
	_chat_pause = maxf(0.0, _chat_pause - delta)


## --- Saludos al cruzarse ----------------------------------------------------

## Se llama cada frame. Si pasa cerca de otro ayudante y no está en enfriamiento,
## arranca una charla.
func tick_saludos(delta: float) -> void:
	_greet_cd -= delta
	_greet_scan -= delta
	if _greet_cd > 0.0 or _greet_scan > 0.0:
		return
	_greet_scan = 0.4
	if _w.velocity.length_squared() < 4.0:
		return   # solo saluda quien va caminando: parados no se abordan
	for otro in _w.get_tree().get_nodes_in_group("workers"):
		if otro == _w or not is_instance_valid(otro) or not (otro as Node2D).visible:
			continue
		if _w.global_position.distance_to((otro as Node2D).global_position) < GREET_RADIUS:
			_iniciar(otro)
			return


func _iniciar(otro: Node) -> void:
	_registrar_encuentro(otro)
	_greet_cd = GREET_COOLDOWN
	_chat_pause = randf_range(0.8, 1.2)
	_w._face_toward((otro as Node2D).global_position)
	_w._puff_mood(_pick_greet_emote(otro))
	_seguir(randf_range(0.5, 0.8))
	if otro.has_method("_receive_chat"):
		otro._receive_chat(_w.global_position)


## Respuesta cuando otro nos aborda. La llama el worker, que es quien recibe el
## mensaje: así el contrato con quien saluda no cambia al mover esto de sitio.
func responder(desde: Vector2) -> void:
	if _chat_pause > 0.0:
		return
	_greet_cd = GREET_COOLDOWN
	_chat_pause = randf_range(0.8, 1.2)
	_w._face_toward(desde)
	_seguir(randf_range(0.25, 0.5))


## Suelta otra burbuja tras un retardo: es el "ida y vuelta" que hace que la
## charla parezca una conversación y no dos monólogos simultáneos.
func _seguir(delay: float) -> void:
	var t := _w.get_tree().create_timer(delay)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(_w):
			_w._puff_mood(CHAT_EMOTES[randi() % CHAT_EMOTES.size()]))


## --- Memoria de amistad ----------------------------------------------------

## Suma un encuentro con otro ayudante. Lo apunta en los dos lados para que la
## cuenta sea simétrica: si A saluda a B, ambos se recuerdan mutuamente.
func _registrar_encuentro(otro: Node) -> void:
	var otro_vs := _vs_de(otro)
	if otro_vs == null:
		return
	var af := afinidad_con(otro_vs)
	var otro_uid: String = otro_vs._uid
	# Afinidad baja → esto es un choque, no un saludo.
	if af <= AFINIDAD_CONFLICTO_MAX:
		_roces[otro_uid] = _roces.get(otro_uid, 0) + 1
		otro_vs._roces[_uid] = otro_vs._roces.get(_uid, 0) + 1
		return
	# Amistad normal, acelerada si comparten 3 o 4 ejes.
	var inc: int = INC_AFINIDAD_ALTA if af >= AFINIDAD_ALTA else 1
	_memoria[otro_uid] = _memoria.get(otro_uid, 0) + inc
	otro_vs._memoria[_uid] = otro_vs._memoria.get(_uid, 0) + inc


## Emoji de saludo: normal o de amigo según el historial con este compañero.
func _pick_greet_emote(otro: Node) -> String:
	var otro_vs := _vs_de(otro)
	if otro_vs == null:
		return GREET_EMOTES[randi() % GREET_EMOTES.size()]
	# Enemistados: emoji de conflicto pase lo que pase.
	if _roces.get(otro_vs._uid, 0) >= UMBRAL_CONFLICTO:
		return CONFLICTO_EMOTES[randi() % CONFLICTO_EMOTES.size()]
	# Amigos: emoji cálido.
	if _memoria.get(otro_vs._uid, 0) >= UMBRAL_AMIGO:
		return AMIGO_EMOTES[randi() % AMIGO_EMOTES.size()]
	# Afinidad baja sin llegar al umbral de conflicto → todavía es un roce.
	if afinidad_con(otro_vs) <= AFINIDAD_CONFLICTO_MAX:
		return CONFLICTO_EMOTES[randi() % CONFLICTO_EMOTES.size()]
	return GREET_EMOTES[randi() % GREET_EMOTES.size()]


## Busca el componente VidaSocial de otro worker.
func _vs_de(worker: Node) -> VidaSocial:
	return worker.get_node_or_null("VidaSocial") as VidaSocial


## --- Personalidad MBTI por ejes --------------------------------------------

## Siglas: cuatro letras a partir de los ejes (ej. "INTJ").
func sigla() -> String:
	var s := ""
	s += "I" if _eje_ei else "E"
	s += "N" if _eje_sn else "S"
	s += "F" if _eje_tf else "T"
	s += "P" if _eje_jp else "J"
	return s


## Ejes compartidos con otro ayudante: 0 (opuestos) a 4 (idénticos).
func afinidad_con(otro: VidaSocial) -> int:
	var n := 0
	if _eje_ei == otro._eje_ei: n += 1
	if _eje_sn == otro._eje_sn: n += 1
	if _eje_tf == otro._eje_tf: n += 1
	if _eje_jp == otro._eje_jp: n += 1
	return n


## ¿Hay enemistad declarada con este otro?
func enemistado_con(otro: VidaSocial) -> bool:
	return _roces.get(otro._uid, 0) >= UMBRAL_CONFLICTO


## ¿Hay algún enemigo cerca? El worker lo consulta para aplicarse una
## penalización de velocidad mientras esté rodeado de conflictos.
func rodeado_de_enemigos(radio: float = 200.0) -> bool:
	for w in _w.get_tree().get_nodes_in_group("workers"):
		if w == _w or not is_instance_valid(w):
			continue
		if _w.global_position.distance_to((w as Node2D).global_position) > radio:
			continue
		var ovs := _vs_de(w)
		if ovs != null and enemistado_con(ovs):
			return true
	return false


## --- Persistencia ----------------------------------------------------------

func get_save_state() -> Dictionary:
	return {
		"uid": _uid,
		"memoria": _memoria.duplicate(),
		"ejes": [_eje_ei, _eje_sn, _eje_tf, _eje_jp],
		"roces": _roces.duplicate(),
	}


func load_save_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	_uid = str(data.get("uid", _uid))
	_memoria = {}
	var mem: Dictionary = data.get("memoria", {})
	for k in mem.keys():
		_memoria[str(k)] = int(mem[k])
	var ejes: Array = data.get("ejes", [])
	if ejes.size() >= 4:
		_eje_ei = bool(ejes[0]); _eje_sn = bool(ejes[1])
		_eje_tf = bool(ejes[2]); _eje_jp = bool(ejes[3])
	_roces = {}
	var roc: Dictionary = data.get("roces", {})
	for k in roc.keys():
		_roces[str(k)] = int(roc[k])


## --- Reuniones en los bancos ------------------------------------------------

## ¿Se va a un banco en vez de a un punto al azar? Devuelve dónde plantarse y
## cuánto quedarse, o un `activo: false` si no toca.
##
## Solo se llama desde el paseo, y eso es deliberado: el worker deambula porque
## no encontró recursos libres, o sea que ese tiempo ya estaba perdido. Así
## socializar no le quita ni un segundo a la producción.
func buscar_reunion() -> Dictionary:
	if _punto != null or randf() >= PROB_SOCIAL:
		return {"activo": false}
	var p: Node2D = PuntoSocial.mas_cercano(_w.global_position)
	if p == null or not p.has_method("enter"):
		return {"activo": false}
	_punto = p
	_w._puff_mood(CHAT_EMOTES[randi() % CHAT_EMOTES.size()])
	_reconciliar_si_toca(p)
	return {
		"activo": true,
		"destino": p.enter(_w),
		"duracion": randf_range(SOCIAL_MIN, SOCIAL_MAX),
	}


## Suelta el banco. Sin esto, quien se va a recolectar deja su plaza tomada y el
## banco acaba "lleno" sin nadie sentado.
func soltar() -> void:
	if _punto == null:
		return
	if is_instance_valid(_punto) and _punto.has_method("leave"):
		_punto.leave(_w)
	_punto = null


## Si hay un enemigo en este mismo banco, la coincidencia rebaja los roces:
## estar sentados juntos pese a todo es el gesto que deshace la enemistad.
func _reconciliar_si_toca(punto: Node2D) -> void:
	for w in _w.get_tree().get_nodes_in_group("workers"):
		if w == _w or not is_instance_valid(w):
			continue
		var ovs := _vs_de(w)
		if ovs == null or ovs._punto != punto:
			continue
		if _roces.get(ovs._uid, 0) < UMBRAL_CONFLICTO:
			continue
		_roces[ovs._uid] = maxi(0, _roces[ovs._uid] - RECONCILIAR_POR_COINCIDENCIA)
		ovs._roces[_uid] = maxi(0, ovs._roces.get(_uid, 0) - RECONCILIAR_POR_COINCIDENCIA)
		_w._puff_mood("🌿")


func _exit_tree() -> void:
	soltar()
