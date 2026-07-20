extends Node2D
## Proyectil arcano de una torreta: viaja hacia un ogro y le hace daño al impactar.
## Dibujado por código (orbe brillante), sin assets. Lo crea SiegeTurret.

var _target: Node2D = null
var _damage: float = 10.0
var _speed: float = 260.0
var _last_dir: Vector2 = Vector2.RIGHT
var _life: float = 2.5


func setup(target: Node2D, damage: float) -> void:
	_target = target
	_damage = damage
	if target != null and is_instance_valid(target):
		_last_dir = (target.global_position - global_position).normalized()


func _ready() -> void:
	z_index = 40
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _target != null and is_instance_valid(_target):
		var to: Vector2 = _target.global_position + Vector2(0, -18)
		_last_dir = (to - global_position).normalized()
		if global_position.distance_to(to) < 12.0:
			_impact()
			return
	global_position += _last_dir * _speed * delta
	queue_redraw()


func _impact() -> void:
	if _target != null and is_instance_valid(_target) and _target.has_method("hit"):
		_target.hit(_damage)
	VFXManager.play(VFXManager.FX.BUILD, global_position)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.7, 0.9, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 1))
