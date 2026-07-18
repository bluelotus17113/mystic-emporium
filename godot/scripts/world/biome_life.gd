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
	# Fauna.
	_spawn_fox(parent, rng, map)
	_spawn_dragonflies(parent, rng, map.pond_world_rect())


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


func _spawn_fox(parent: Node, rng: RandomNumberGenerator, map: Node) -> void:
	var tex: Texture2D = load(ENV + "critter_fox.png")
	if tex == null:
		return
	var rect: Rect2 = map.biome_world_rect("forest").merge(map.biome_world_rect("meadow"))
	for i in 2:
		var fox := Critter.new()
		fox.texture = tex
		fox.scale = Vector2(1.7, 1.7)
		fox.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		fox.add_to_group("natural_visual")
		fox.setup(rect, rng.randf_range(34.0, 50.0), true)
		parent.add_child(fox)
		fox.global_position = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))


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
