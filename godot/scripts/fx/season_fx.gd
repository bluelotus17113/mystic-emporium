class_name SeasonFX
extends Node2D
## Detalles de estación (CalendarManager.current_season) en el patio natural:
## partículas que caen (pétalos/hojas/nieve) + tinte del follaje.
## Verano queda limpio (solo tinte cálido). Reacciona a season_changed.

var _rect: Rect2 = Rect2()
var _emitter: GPUParticles2D = null


func _ready() -> void:
	await get_tree().process_frame
	for zr in _find_zone_regions(get_tree().current_scene):
		if zr.zone_type == GameEnums.ZoneType.NATURE:
			_rect = Rect2(zr.global_position - zr.size * 0.5, zr.size)
			break
	if _rect.size == Vector2.ZERO:
		return
	_apply_season(CalendarManager.current_season)
	# El follaje (NaturalLife) puede crearse en el mismo frame; re-tinta al poco
	# para asegurar que los árboles/pasto ya existen.
	get_tree().create_timer(0.6).timeout.connect(func(): _tint_foliage(CalendarManager.current_season))
	if CalendarManager.has_signal("season_changed"):
		CalendarManager.season_changed.connect(_apply_season)


func _find_zone_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_zone_regions(c))
	return out


func _apply_season(season: int) -> void:
	_rebuild_emitter(season)
	_tint_foliage(season)


func _rebuild_emitter(season: int) -> void:
	if _emitter != null and is_instance_valid(_emitter):
		_emitter.queue_free()
		_emitter = null
	var cfg: Dictionary = _season_particle(season)
	if cfg.is_empty():
		return
	var p := GPUParticles2D.new()
	p.texture = CharShadow._tex()
	p.amount = cfg.amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	# Emite desde una banda por encima del patio; cae hacia abajo.
	p.position = Vector2(_rect.get_center().x, _rect.position.y - 10.0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(_rect.size.x * 0.5, 8.0, 0)
	mat.gravity = Vector3(0, cfg.fall, 0)
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 12.0
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = cfg.drift
	mat.scale_min = cfg.scale * 0.7
	mat.scale_max = cfg.scale
	var grad := Gradient.new()
	grad.set_color(0, cfg.color)
	grad.set_color(1, Color(cfg.color.r, cfg.color.g, cfg.color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	p.emitting = true
	p.add_to_group("natural_visual")
	add_child(p)
	_emitter = p


func _season_particle(season: int) -> Dictionary:
	match season:
		CalendarManager.Season.SPRING:
			return {"amount": 14, "color": Color(1.0, 0.75, 0.85, 0.9), "fall": 22.0, "drift": 0.9, "scale": 0.12}
		CalendarManager.Season.AUTUMN:
			return {"amount": 16, "color": Color(0.95, 0.6, 0.3, 0.95), "fall": 30.0, "drift": 1.1, "scale": 0.14}
		CalendarManager.Season.WINTER:
			return {"amount": 22, "color": Color(0.95, 0.98, 1.0, 0.95), "fall": 26.0, "drift": 0.6, "scale": 0.11}
		_:
			return {}  # verano: despejado


func _tint_foliage(season: int) -> void:
	var tint: Color
	match season:
		CalendarManager.Season.SPRING: tint = Color(0.96, 1.05, 0.92)
		CalendarManager.Season.SUMMER: tint = Color(1.06, 1.0, 0.85)
		CalendarManager.Season.AUTUMN: tint = Color(1.18, 0.86, 0.55)
		CalendarManager.Season.WINTER: tint = Color(0.86, 0.92, 1.08)
		_: tint = Color.WHITE
	for n in get_tree().get_nodes_in_group("foliage"):
		if n is CanvasItem:
			(n as CanvasItem).modulate = tint
