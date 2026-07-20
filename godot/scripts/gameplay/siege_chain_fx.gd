extends Node2D
## Efecto del rayo en cadena: dibuja arcos eléctricos irregulares entre los puntos
## alcanzados durante un instante y se autodestruye. Lo crea la Torreta de Rayo.

var _points: PackedVector2Array = PackedVector2Array()
var _life: float = 0.18
const LIFE: float = 0.18


func setup(points: PackedVector2Array) -> void:
	_points = points
	queue_redraw()


func _ready() -> void:
	z_index = 45
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate.a = clampf(_life / LIFE, 0.0, 1.0)


func _draw() -> void:
	for i in range(_points.size() - 1):
		_bolt(to_local(_points[i]), to_local(_points[i + 1]))


func _bolt(a: Vector2, b: Vector2) -> void:
	var segs: int = 6
	var pts := PackedVector2Array()
	var perp: Vector2 = (b - a).orthogonal().normalized()
	for s in range(segs + 1):
		var t: float = float(s) / float(segs)
		var p: Vector2 = a.lerp(b, t)
		if s > 0 and s < segs:
			p += perp * randf_range(-6.0, 6.0)
		pts.append(p)
	draw_polyline(pts, Color(0.8, 0.9, 1.0, 0.4), 5.0)
	draw_polyline(pts, Color(1.0, 1.0, 0.6, 0.95), 2.0)
