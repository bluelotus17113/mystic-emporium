class_name Critter
extends Sprite2D
## Bichito que deambula por un rect (zorro, ardilla…). Se voltea según dirección
## y hace un bob suave. Pausas ocasionales. Lo crea BiomeLife.

var _rect: Rect2 = Rect2()
var _target: Vector2 = Vector2.ZERO
var _speed: float = 30.0
var _pause: float = 0.0
var _bob: float = 0.0
var _day_only: bool = false


func setup(rect: Rect2, speed: float, day_only: bool = false) -> void:
	_rect = rect
	_speed = speed
	_day_only = day_only


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bob = randf() * TAU
	_pick()


func _process(delta: float) -> void:
	if _day_only:
		var day: float = 1.0 - CalendarManager.get_darkness()
		if day <= 0.1:
			visible = false
			return
		visible = true
		modulate.a = day
	_bob += delta * 6.0
	offset.y = sin(_bob) * 1.2
	if _pause > 0.0:
		_pause -= delta
		return
	var d: Vector2 = _target - global_position
	if d.length() < 10.0:
		_pick()
		_pause = randf_range(0.7, 2.4)
		return
	global_position += d.normalized() * _speed * delta
	flip_h = d.x < 0.0


func _pick() -> void:
	if _rect.size == Vector2.ZERO:
		return
	_target = Vector2(
		randf_range(_rect.position.x + 20.0, _rect.end.x - 20.0),
		randf_range(_rect.position.y + 20.0, _rect.end.y - 20.0))
