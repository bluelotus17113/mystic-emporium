class_name BreathPuff
extends RefCounted
## Pequeño vaho blanco que sube desde la cara de un personaje (invierno).
## Estático: BreathPuff.spawn(personaje, offset_cabeza). Se autolibera.

static var _tex: Texture2D = null


static func spawn(host: Node2D, head_offset: Vector2 = Vector2(0, -30)) -> void:
	if host == null or not host.is_inside_tree():
		return
	var parent: Node = host.get_parent()
	if parent == null:
		return
	if _tex == null:
		_tex = CharShadow._tex()
	var p := GPUParticles2D.new()
	p.texture = _tex
	p.amount = 4
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.8
	p.z_index = 10
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.4, -1, 0)
	mat.spread = 20.0
	mat.gravity = Vector3(0, -8, 0)
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.scale_min = 0.06
	mat.scale_max = 0.12
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.97, 1.0, 0.5))
	grad.set_color(1, Color(0.9, 0.95, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	p.local_coords = false
	parent.add_child(p)
	p.global_position = host.global_position + head_offset
	p.emitting = true
	p.finished.connect(p.queue_free)
