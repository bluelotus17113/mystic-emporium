extends Node
## Spawnea efectos de partículas en posición arbitraria. No requiere assets:
## genera la textura de la partícula en runtime con un Gradient.

enum FX { COLLECT, CRAFT_DONE, UPGRADE, COINS, BUILD, RESEARCH_DONE, ACHIEVEMENT, ORDER_COMPLETE }

const TEX_SIZE: int = 8
var _world: Node = null
var _particle_tex: GradientTexture2D


func _ready() -> void:
	_particle_tex = _build_particle_texture()


func set_world(world: Node) -> void:
	_world = world


func _build_particle_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var fill := GradientTexture2D.new()
	fill.gradient = grad
	fill.width = TEX_SIZE
	fill.height = TEX_SIZE
	fill.fill = GradientTexture2D.FILL_RADIAL
	fill.fill_from = Vector2(0.5, 0.5)
	fill.fill_to = Vector2(0.5, 0.0)
	return fill


func _make_color_ramp(start: Color, end: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.set_color(1, end)
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 32
	return tex


const MAX_ACTIVE_VFX: int = 6

var _active_vfx: int = 0


func play(fx: int, world_pos: Vector2, parent: Node = null) -> void:
	# Cap de VFX simultáneos: si ya hay muchas partículas en pantalla, dropeamos
	# la nueva. Una cascada de 5 logros + pedido entregado al mismo tiempo no debe
	# congelar el frame creando 5 GPUParticles2D con 40+ partículas cada uno.
	if _active_vfx >= MAX_ACTIVE_VFX:
		return
	var target_parent: Node = parent if parent != null else _world
	if target_parent == null:
		return
	var particles := _build_particles(fx)
	target_parent.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	_active_vfx += 1
	# Auto cleanup after lifetime
	var t := get_tree().create_timer(particles.lifetime + 0.4)
	t.timeout.connect(func():
		_active_vfx = max(0, _active_vfx - 1)
		if is_instance_valid(particles):
			particles.queue_free())


func _build_particles(fx: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = _particle_tex
	p.amount = 16
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.5
	p.local_coords = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3(0, 50, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.6

	var start := Color.WHITE
	var end := Color(1, 1, 1, 0)

	match fx:
		FX.COLLECT:
			start = Color(0.6, 1.0, 0.6, 1)
			end = Color(0.4, 0.85, 0.4, 0)
			mat.gravity = Vector3(0, -30, 0)
			p.amount = 10
			p.lifetime = 0.5
		FX.CRAFT_DONE:
			start = Color(0.95, 0.7, 1.0, 1)
			end = Color(0.5, 0.3, 0.85, 0)
			mat.initial_velocity_min = 70.0
			mat.initial_velocity_max = 140.0
			mat.gravity = Vector3(0, -20, 0)
			p.amount = 24
			p.lifetime = 0.8
		FX.UPGRADE:
			start = Color(1.0, 0.95, 0.5, 1)
			end = Color(1.0, 0.7, 0.2, 0)
			mat.gravity = Vector3(0, -60, 0)
			p.amount = 28
			p.lifetime = 1.0
		FX.COINS:
			start = Color(1.0, 0.85, 0.3, 1)
			end = Color(0.85, 0.55, 0.1, 0)
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 140.0
			p.amount = 20
			p.lifetime = 0.7
		FX.BUILD:
			start = Color(0.85, 0.85, 0.95, 1)
			end = Color(0.5, 0.5, 0.6, 0)
			mat.gravity = Vector3(0, -10, 0)
			mat.initial_velocity_min = 30.0
			mat.initial_velocity_max = 70.0
			p.amount = 18
			p.lifetime = 0.6
		FX.RESEARCH_DONE:
			start = Color(0.6, 0.85, 1.0, 1)
			end = Color(0.3, 0.55, 1.0, 0)
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 120.0
			mat.gravity = Vector3(0, -40, 0)
			p.amount = 32
			p.lifetime = 1.1
		FX.ACHIEVEMENT:
			# Estrellas doradas explotando hacia arriba
			start = Color(1.0, 0.95, 0.4, 1)
			end = Color(1.0, 0.7, 0.0, 0)
			mat.initial_velocity_min = 100.0
			mat.initial_velocity_max = 180.0
			mat.gravity = Vector3(0, -80, 0)
			mat.scale_min = 1.0
			mat.scale_max = 2.2
			p.amount = 40
			p.lifetime = 1.4
			p.explosiveness = 0.9
		FX.ORDER_COMPLETE:
			# Corazones rosados suaves al completar pedido
			start = Color(1.0, 0.6, 0.85, 1)
			end = Color(0.85, 0.3, 0.55, 0)
			mat.initial_velocity_min = 50.0
			mat.initial_velocity_max = 100.0
			mat.gravity = Vector3(0, -50, 0)
			p.amount = 18
			p.lifetime = 0.9

	mat.color_ramp = _make_color_ramp(start, end)
	p.process_material = mat
	return p
