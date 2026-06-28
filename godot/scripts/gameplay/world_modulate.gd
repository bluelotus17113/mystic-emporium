extends CanvasModulate
## Tinta el mundo según CalendarManager.time_of_day (0.0-1.0 = 24h del reloj real).
## Interpolación continua entre keyframes cozy → cambio suave minuto a minuto.

# (hora_normalizada, color) — interpolación lineal entre los segmentos.
const KEYFRAMES: Array = [
	[0.00, Color(0.30, 0.40, 0.65)],   # 00:00 noche profunda azul
	[0.22, Color(0.70, 0.55, 0.60)],   # 05:30 amanecer rosado
	[0.30, Color(1.00, 0.95, 0.88)],   # 07:00 mañana cálida
	[0.50, Color(1.00, 1.00, 1.00)],   # 12:00 día neutro
	[0.72, Color(1.00, 0.78, 0.60)],   # 17:30 atardecer naranja
	[0.85, Color(0.55, 0.50, 0.75)],   # 20:30 anochecer púrpura
	[0.95, Color(0.35, 0.42, 0.68)],   # 22:50 noche
	[1.00, Color(0.30, 0.40, 0.65)],   # 24:00 wrap a noche profunda
]

# Recalculamos a 5 fps (suficiente para algo que cambia en escala de minutos).
const UPDATE_INTERVAL: float = 0.2
var _accum: float = 0.0


func _ready() -> void:
	color = _color_for(CalendarManager.time_of_day)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	color = _color_for(CalendarManager.time_of_day)


func _color_for(t: float) -> Color:
	t = clamp(t, 0.0, 1.0)
	for i in range(KEYFRAMES.size() - 1):
		var a: Array = KEYFRAMES[i]
		var b: Array = KEYFRAMES[i + 1]
		if t >= a[0] and t <= b[0]:
			var span: float = b[0] - a[0]
			var k: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			return (a[1] as Color).lerp(b[1] as Color, k)
	return KEYFRAMES[0][1]
