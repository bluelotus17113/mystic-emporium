class_name Wind
## Viento global compartido por toda la vegetación del patio. Un único nodo
## (NaturalLife) llama a Wind.update(delta) cada frame; árboles y hierba leen
## Wind.sway() para mecerse en sincronía —mismo viento para todos, con desfase
## por posición— más ráfagas suaves e irregulares. Sin assets ni shaders.

static var time: float = 0.0
static var _gust: float = 0.0


## Avanza el tiempo del viento y calcula la envolvente de ráfaga (0..1).
## Dos senos desincronizados → ráfagas que suben y bajan de forma irregular.
static func update(delta: float) -> void:
	time += delta
	var g: float = 0.5 + 0.5 * sin(time * 0.5) * sin(time * 0.13 + 0.7)
	_gust = clampf(g, 0.0, 1.0)


## Balanceo (~-1.3..1.3) para una planta con su 'phase' propio. 'speed' es la
## frecuencia base del vaivén; la ráfaga global modula la amplitud para que
## todo el patio "respire" a la vez.
static func sway(phase: float, speed: float = 1.5) -> float:
	return sin(time * speed + phase) * (0.55 + 0.75 * _gust)
