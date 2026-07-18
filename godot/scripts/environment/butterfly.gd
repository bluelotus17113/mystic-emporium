class_name Butterfly
extends Sprite2D
## Mariposa que revolotea por el patio natural de día (se esconde de noche).
## Aletea alternando 2 frames y vaga entre puntos aleatorios de la zona.

var _rect: Rect2 = Rect2()
var _target: Vector2 = Vector2.ZERO
var _speed: float = 26.0
var _flap: float = 0.0


func setup(rect: Rect2) -> void:
	_rect = rect


func _ready() -> void:
	add_to_group("butterfly")  # el gato las persigue
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	region_rect = Rect2(0, 0, 8, 8)
	scale = Vector2(2, 2)
	z_index = 4
	_speed = randf_range(20.0, 34.0)
	_flap = randf() * 10.0
	_pick()


func _process(delta: float) -> void:
	var day: float = 1.0 - CalendarManager.get_darkness()
	if day <= 0.05:
		visible = false
		return
	visible = true
	modulate.a = day
	# aleteo: alterna entre los dos frames de 8px
	_flap += delta * 14.0
	region_rect = Rect2(0.0 if int(_flap) % 2 == 0 else 8.0, 0, 8, 8)
	var d: Vector2 = _target - global_position
	if d.length() < 10.0:
		_pick()
	else:
		global_position += d.normalized() * _speed * delta
		flip_h = d.x < 0.0


func _pick() -> void:
	if _rect.size == Vector2.ZERO:
		return
	_target = Vector2(
		randf_range(_rect.position.x + 30.0, _rect.end.x - 30.0),
		randf_range(_rect.position.y + 50.0, _rect.end.y - 30.0))
