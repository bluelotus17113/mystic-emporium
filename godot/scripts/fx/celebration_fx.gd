extends Node2D
## Celebración al completar un pedido: confeti + corazón sobre el mostrador.
## Escucha OrderManager.order_completed. Lo instala game_bootstrap.

const CONFETTI: Array = [
	Color(1.0, 0.5, 0.6), Color(1.0, 0.85, 0.4), Color(0.55, 0.85, 1.0),
	Color(0.7, 1.0, 0.6), Color(0.85, 0.7, 1.0),
]


func _ready() -> void:
	await get_tree().process_frame
	if OrderManager.has_signal("order_completed"):
		OrderManager.order_completed.connect(_on_order_completed)


func _on_order_completed(_order) -> void:
	var pos: Vector2 = _counter_position()
	_burst(pos)
	var anchor := Node2D.new()
	anchor.global_position = pos
	add_child(anchor)
	FloatingText.spawn(anchor, "♥", Color(1.0, 0.55, 0.65))
	anchor.queue_free()


func _counter_position() -> Vector2:
	var m: Node = get_tree().get_first_node_in_group("customer_counter")
	if m is Node2D:
		return (m as Node2D).global_position + Vector2(0, -24)
	var proto: Node = get_tree().get_first_node_in_group("protagonist")
	if proto is Node2D:
		return (proto as Node2D).global_position
	return Vector2.ZERO


func _burst(pos: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.texture = CharShadow._tex()
	p.position = pos
	p.amount = 18
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.95
	p.z_index = 50
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 55.0
	mat.gravity = Vector3(0, 140, 0)
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.scale_min = 0.08
	mat.scale_max = 0.16
	var grad := Gradient.new()
	grad.set_color(0, CONFETTI[randi() % CONFETTI.size()])
	grad.set_color(1, CONFETTI[randi() % CONFETTI.size()])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	p.emitting = true
	add_child(p)
	p.finished.connect(p.queue_free)
