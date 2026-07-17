class_name FootDust
extends RefCounted
## Puf de polvo bajo los pies al caminar. Estático: FootDust.spawn(personaje).
## Autolibera al terminar el one-shot. Se parentea al mismo contenedor que el
## personaje para heredar y-sort/zona; z_index bajo para quedar bajo los pies.

const _TEX_PATH: String = "res://art/sprites/fx/dust_dot.png"
static var _tex: Texture2D = null


static func spawn(host: Node2D) -> void:
	if host == null or not host.is_inside_tree():
		return
	var parent: Node = host.get_parent()
	if parent == null:
		return
	if _tex == null:
		_tex = load(_TEX_PATH)
	var p := CPUParticles2D.new()
	p.texture = _tex
	p.z_index = -2
	p.one_shot = true
	p.emitting = true
	p.amount = 5
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.damping_min = 8.0
	p.damping_max = 14.0
	p.color = Color(0.86, 0.78, 0.62, 0.7)
	parent.add_child(p)
	p.global_position = host.global_position + Vector2(0, -2)
	p.finished.connect(p.queue_free)
