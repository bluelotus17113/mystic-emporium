extends PointLight2D
## Luz cálida con parpadeo orgánico (velas/fuego). Suma ruido suave a la energía
## y un leve temblor de escala para que el charco de luz "respire".

@export var base_energy: float = 1.0
@export var flicker_amount: float = 0.18      ## amplitud del parpadeo (0-1)
@export var flicker_speed: float = 7.0        ## Hz aprox
@export var breathe_scale: float = 0.04       ## temblor de radio

var _t: float = 0.0
var _seed: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_seed = randf() * 100.0
	_base_scale = texture_scale * Vector2.ONE if texture_scale != 0.0 else Vector2.ONE
	energy = base_energy


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	# ruido pseudo-Perlin barato: suma de dos senoidales desfasadas
	var n: float = 0.6 * sin(_t + _seed) + 0.4 * sin(_t * 1.7 + _seed * 2.3)
	energy = base_energy * (1.0 + flicker_amount * n)
	texture_scale = maxf(0.05, texture_scale + 0.0)  # no-op guard
	# temblor de radio via scale del propio nodo (afecta el charco)
	var s: float = 1.0 + breathe_scale * n
	scale = Vector2(s, s)
