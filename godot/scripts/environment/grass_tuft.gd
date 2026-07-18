class_name GrassTuft
extends Sprite2D
## Brizna de pasto decorativa que se mece cuando un personaje pasa por encima.
## La crea NaturalLife; detecta cuerpos con un Area2D y hace un wobble elástico.

var _busy: bool = false
var _phase: float = -1.0  ## desfase de viento (se toma de la posición al 1er frame)
const WIND_AMP: float = 0.11    ## la hierba se mece más que los árboles (~6°)
const WIND_SPEED: float = 2.3   ## y más rápido: sensación de brizna ligera


func _ready() -> void:
	# Pivote en la base para que el meneo salga desde el suelo, no del centro.
	offset = Vector2(0, -texture.get_height() * 0.5)
	var area := Area2D.new()
	area.monitoring = true
	area.monitorable = false
	area.collision_mask = 0x7FFFFFFF  # cualquier capa: detecta protagonista y workers
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0
	cs.shape = c
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


## Meneo ambiental por viento: mientras nadie la pisa, la brizna se inclina con
## el viento global. El wobble al pisarla (_wobble) tiene prioridad vía _busy.
func _process(_delta: float) -> void:
	if _busy:
		return
	if _phase < 0.0:
		_phase = global_position.x * 0.02
	rotation = Wind.sway(_phase, WIND_SPEED) * WIND_AMP


func _on_body_entered(body: Node) -> void:
	if _busy or not (body is CharacterBody2D):
		return
	_wobble(body.global_position.x <= global_position.x)


func _wobble(from_left: bool) -> void:
	_busy = true
	var dir: float = 1.0 if from_left else -1.0
	var tw := create_tween()
	tw.tween_property(self, "rotation", dir * 0.35, 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation", dir * -0.16, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation", 0.0, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _busy = false)
