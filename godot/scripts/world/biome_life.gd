class_name BiomeLife
extends Node2D
## Puebla los biomas del patio: props estáticos (pino nevado, cactus, rocas,
## setas de cueva), nenúfares en el estanque, y fauna (zorro, libélulas).
## Lo instala game_bootstrap. Determinista (semilla fija).

const ENV: String = "res://art/sprites/environment/"


func _ready() -> void:
	await get_tree().process_frame
	var map: Node = get_tree().get_first_node_in_group("biome_map")
	if map == null or not map.has_method("biome_world_rect"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260718
	var parent: Node = get_tree().get_first_node_in_group("world_container")
	if parent == null:
		parent = self
	# Props por bioma: (asset, bioma, cantidad, escala).
	_scatter(parent, rng, map, "biome_pine_snow", "snow", 14, 1.8)
	_scatter(parent, rng, map, "biome_cactus", "desert", 10, 1.6)
	_scatter(parent, rng, map, "biome_rock", "quarry", 12, 1.7)
	_scatter(parent, rng, map, "biome_cave_mushroom", "quarry", 7, 1.5)
	_scatter(parent, rng, map, "biome_cave_mushroom", "arcane", 6, 1.5)
	# Nenúfares en el estanque.
	_scatter_rect(parent, rng, map.pond_world_rect(), "biome_lilypad", 7, 1.6, false)
	# Fauna por bioma.
	var forest: Rect2 = map.biome_world_rect("forest").merge(map.biome_world_rect("meadow"))
	var pond: Rect2 = map.pond_world_rect()
	_critters(parent, rng, "critter_fox", forest, 2, 1.7, 44.0, true)
	_critters(parent, rng, "critter_bird", forest, 6, 1.2, 58.0, true)
	_critters(parent, rng, "critter_squirrel", forest, 3, 1.3, 40.0, true)
	_critters(parent, rng, "critter_frog", pond.grow(24.0), 3, 1.3, 16.0, false)
	_spawn_dragonflies(parent, rng, pond)
	_pond_shimmer(parent, pond)


func _scatter(parent: Node, rng: RandomNumberGenerator, map: Node, asset: String, biome: String, n: int, k: float) -> void:
	_scatter_rect(parent, rng, map.biome_world_rect(biome), asset, n, k, true)


func _scatter_rect(parent: Node, rng: RandomNumberGenerator, rect: Rect2, asset: String, n: int, k: float, solid: bool) -> void:
	if rect.size == Vector2.ZERO:
		return
	var tex: Texture2D = load(ENV + asset + ".png")
	if tex == null:
		return
	for i in n:
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		s.add_to_group("natural_visual")
		parent.add_child(s)
		s.global_position = Vector2(
			rng.randf_range(rect.position.x + 30.0, rect.end.x - 30.0),
			rng.randf_range(rect.position.y + 40.0, rect.end.y - 30.0))
		if solid:
			SolidBase.attach(s, Vector2(maxf(18.0, tex.get_width() * k * 0.4), 10.0), Vector2(0, -2))


## Grupo de bichos de un tipo deambulando por un rect.
func _critters(parent: Node, rng: RandomNumberGenerator, asset: String, rect: Rect2, n: int, k: float, speed: float, day_only: bool) -> void:
	if rect.size == Vector2.ZERO:
		return
	var tex: Texture2D = load(ENV + asset + ".png")
	if tex == null:
		return
	for i in n:
		var c := Critter.new()
		c.texture = tex
		c.scale = Vector2(k, k)
		c.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		c.add_to_group("natural_visual")
		c.setup(rect, speed * rng.randf_range(0.8, 1.2), day_only)
		parent.add_child(c)
		c.global_position = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))


## Brillo/oleaje suave sobre el estanque (agua "viva").
func _pond_shimmer(parent: Node, pond: Rect2) -> void:
	if pond.size == Vector2.ZERO:
		return
	var p := GPUParticles2D.new()
	p.texture = CharShadow._tex()
	p.position = pond.get_center()
	p.amount = 14
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.local_coords = false
	p.z_index = 1
	p.add_to_group("natural_visual")
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = pond.size.x * 0.42
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 4.0
	mat.scale_min = 0.06
	mat.scale_max = 0.13
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.97, 1.0, 0.0))
	g.set_color(0.5, Color(0.9, 0.98, 1.0, 0.55))
	g.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	mat.color_ramp = ramp
	p.process_material = mat
	p.emitting = true
	parent.add_child(p)


func _spawn_dragonflies(parent: Node, rng: RandomNumberGenerator, pond: Rect2) -> void:
	if pond.size == Vector2.ZERO:
		return
	var tex: Texture2D = load(ENV + "butterfly.png")  # reutiliza sheet, tintado azul = libélula
	if tex == null:
		return
	for i in 5:
		var d := Butterfly.new()
		d.texture = tex
		d.modulate = Color(0.6, 0.9, 1.1)  # cian = libélula
		d.add_to_group("natural_visual")
		d.setup(pond.grow(20.0))
		parent.add_child(d)
		d.global_position = Vector2(rng.randf_range(pond.position.x, pond.end.x), rng.randf_range(pond.position.y, pond.end.y))
