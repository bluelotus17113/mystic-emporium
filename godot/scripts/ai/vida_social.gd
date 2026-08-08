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


static func crear(worker: Node2D) -> VidaSocial:
	var v := VidaSocial.new()
	v.name = "VidaSocial"
	v._w = worker
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
	_greet_cd = GREET_COOLDOWN
	_chat_pause = randf_range(0.8, 1.2)
	_w._face_toward((otro as Node2D).global_position)
	_w._puff_mood(GREET_EMOTES[randi() % GREET_EMOTES.size()])
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


func _exit_tree() -> void:
	soltar()
