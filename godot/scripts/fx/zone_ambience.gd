class_name ZoneAmbience
extends Node2D
## Partículas ambientales por zona (sin assets: texturas radiales runtime).
## Natural: luciérnagas verdes lentas · Taller: motas de polvo dorado ·
## Recepción: destellos suaves. Cada emisor se une al grupo <zona>_visual
## para que la cámara lo muestre/oculte con el resto de la zona.
## Lo instala game_bootstrap en runtime: no requiere ediciones de escena.

const ZONE_GROUP: Dictionary = {
	GameEnums.ZoneType.NATURE: "natural_visual",
	GameEnums.ZoneType.WORKSHOP: "taller_visual",
	GameEnums.ZoneType.RECEPTION: "recepcion_visual",
}


func _ready() -> void:
	# Esperar un frame: los ZoneRegion se registran en su propio _ready.
	await get_tree().process_frame
	var seen: Dictionary = {}
	for zr in _find_zone_regions(get_tree().current_scene):
		if seen.has(zr.zone_type):
			continue
		seen[zr.zone_type] = true
		var rect := Rect2(zr.global_position - zr.size * 0.5, zr.size)
		var p := _make_emitter(zr.zone_type, rect)
		if p != null:
			add_child(p)


func _find_zone_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_zone_regions(c))
	return out


func _make_emitter(zone: GameEnums.ZoneType, rect: Rect2) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = CharShadow._tex()  # radial suave compartida
	p.amount = 14
	p.lifetime = 7.0
	p.preprocess = 7.0  # que ya haya partículas al entrar a la zona
	p.local_coords = false
	p.position = rect.get_center()

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rect.size.x * 0.5, rect.size.y * 0.5, 0)
	mat.gravity = Vector3.ZERO
	var start: Color; var end: Color
	match zone:
		GameEnums.ZoneType.NATURE:
			# luciérnagas: verdes, erráticas, parpadeo vía alpha del ramp
			start = Color(0.75, 1.0, 0.45, 0.85); end = Color(0.45, 0.9, 0.3, 0.0)
			mat.initial_velocity_min = 4.0; mat.initial_velocity_max = 12.0
			mat.turbulence_enabled = true
			mat.turbulence_noise_strength = 0.7
			mat.scale_min = 0.10; mat.scale_max = 0.18
			p.amount = 12
		GameEnums.ZoneType.WORKSHOP:
			# motas de polvo dorado flotando hacia arriba muy lento
			start = Color(1.0, 0.88, 0.55, 0.5); end = Color(1.0, 0.8, 0.4, 0.0)
			mat.gravity = Vector3(0, -3.5, 0)
			mat.initial_velocity_min = 1.0; mat.initial_velocity_max = 4.0
			mat.scale_min = 0.07; mat.scale_max = 0.13
			p.amount = 16
		GameEnums.ZoneType.RECEPTION:
			# destellos arcanos suaves
			start = Color(0.8, 0.7, 1.0, 0.55); end = Color(0.6, 0.85, 1.0, 0.0)
			mat.initial_velocity_min = 2.0; mat.initial_velocity_max = 6.0
			mat.gravity = Vector3(0, -2.0, 0)
			mat.scale_min = 0.08; mat.scale_max = 0.14
			p.amount = 12
		_:
			return null
	var grad := Gradient.new()
	grad.set_color(0, start)
	grad.set_color(1, end)
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	p.emitting = true
	p.add_to_group(ZONE_GROUP.get(zone, ""))
	return p
