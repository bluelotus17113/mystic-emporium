class_name CharShadow
## Sombra "blob" bajo los personajes: elipse suave generada en runtime
## (sin assets). Hace que los pies "pisen" el suelo en vez de flotar.

static var _tex_cache: GradientTexture2D = null


static func attach(body: Node2D, width: float = 22.0) -> void:
	if body == null or body.get_node_or_null("BlobShadow") != null:
		return
	# Los personajes renderizan por encima de props/scatter (z 0).
	body.z_index = max(body.z_index, 2)
	var s := Sprite2D.new()
	s.name = "BlobShadow"
	s.texture = _tex()
	# textura 32x32 radial → escalar a elipse (ancho x ~40% de alto)
	s.scale = Vector2(width / 32.0, width * 0.42 / 32.0)
	s.modulate = Color(0.05, 0.03, 0.08, 0.35)
	s.position = Vector2(0, -2)  # bajo los pies (los frames de walk llevan los pies ~3px más arriba)
	s.show_behind_parent = true
	s.z_index = -1
	body.add_child(s)


static func _tex() -> GradientTexture2D:
	if _tex_cache != null:
		return _tex_cache
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = grad
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	_tex_cache = t
	return t
