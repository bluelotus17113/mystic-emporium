class_name NaturalLife
extends Node2D
## Vida del Patio Natural: (1) scatter decorativo determinista (rocas, arbustos,
## setas, juncos — assets minish_objects) y (2) maleza que crece sola con el
## tiempo y que los duendes cortan (es un ResourceNode HERB de un solo uso).
## Instalado por game_bootstrap; no requiere ediciones de escena.

# Árboles: van en una banda ordenada arriba de la zona, grandes.
const TREES: Array = [
	"res://art/sprites/minish_objects/flower_bush.png",
	"res://art/sprites/environment/decoration_apple_tree.png",
	"res://art/sprites/minish_objects/tree_dead.png",
]
const TREE_COUNT: int = 8
const TREE_TARGET_H: float = 108.0  ## alto objetivo en px → escala grande y uniforme
# Maleza de suelo: dispersa por debajo de la banda de árboles.
const CLUTTER: Array = [
	"res://art/sprites/minish_objects/bush.png",
	"res://art/sprites/minish_objects/mushroom_red.png",
	"res://art/sprites/environment/decoration_stone_cairn.png",
	"res://art/sprites/environment/decoration_fallen_log.png",
	"res://art/sprites/minish_objects/hay_bale.png",
]
const CLUTTER_COUNT: int = 14
# Briznas de pasto que se mecen al pisarlas.
const GRASS_TUFT: String = "res://art/sprites/environment/decoration_grass_tuft.png"
const GRASS_COUNT: int = 16
const WEED_SCENE: String = "res://scenes/environment/resource_node_weed.tscn"
const WEED_MAX: int = 8
const WEED_INTERVAL_MIN: float = 22.0
const WEED_INTERVAL_MAX: float = 42.0

var _rect: Rect2 = Rect2()
var _weed_timer: float = 12.0
var _weeds: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_rect = _nature_rect()
	if _rect.size == Vector2.ZERO:
		set_process(false)
		return
	_scatter_props()


func _nature_rect() -> Rect2:
	for zr in _find_regions(get_tree().current_scene):
		if zr.zone_type == GameEnums.ZoneType.NATURE:
			return Rect2(zr.global_position - zr.size * 0.5, zr.size)
	return Rect2()


func _find_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_regions(c))
	return out


func _scatter_props() -> void:
	# Determinista (seed fija): el patio se ve igual en cada partida.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260716
	_scatter_trees(rng)
	_scatter_clutter(rng)
	_scatter_grass(rng)
	_scatter_butterflies(rng)


## Contenedor con y_sort_enabled: los árboles se ordenan por Y con la
## protagonista y workers, así se puede caminar por detrás de ellos.
func _visual_parent() -> Node:
	var w: Node = get_tree().get_first_node_in_group("world_container")
	return w if w != null else self


## Árboles alineados en una banda superior de la zona, grandes y uniformes.
func _scatter_trees(rng: RandomNumberGenerator) -> void:
	var parent: Node = _visual_parent()
	var margin: float = 70.0
	var span: float = maxf(0.0, _rect.size.x - margin * 2.0)
	var band_top: float = _rect.position.y + 46.0
	for i in TREE_COUNT:
		var tex: Texture2D = load(TREES[rng.randi() % TREES.size()])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Reparto horizontal parejo con leve jitter; poca variación vertical.
		var t: float = (float(i) + 0.5) / float(TREE_COUNT)
		var x: float = _rect.position.x + margin + span * t + rng.randf_range(-26.0, 26.0)
		var y: float = band_top + rng.randf_range(0.0, 64.0)
		var k: float = TREE_TARGET_H / float(tex.get_height())
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		s.add_to_group("natural_visual")
		s.add_to_group("foliage")
		parent.add_child(s)
		s.global_position = Vector2(x, y)
		# Tronco sólido estrecho en la base: se puede pasar por detrás, no a través.
		SolidBase.attach(s, Vector2(maxf(20.0, tex.get_width() * k * 0.28), 12.0), Vector2(0, -2))


## Maleza/props menores dispersos por debajo de la banda de árboles.
func _scatter_clutter(rng: RandomNumberGenerator) -> void:
	var parent: Node = _visual_parent()
	var band_bottom: float = _rect.position.y + 150.0
	for i in CLUTTER_COUNT:
		var tex: Texture2D = load(CLUTTER[rng.randi() % CLUTTER.size()])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var x: float = rng.randf_range(_rect.position.x + 40.0, _rect.end.x - 40.0)
		var y: float = rng.randf_range(band_bottom, _rect.end.y - 30.0)
		var k: float = 1.4 if "mushroom" in tex.resource_path else 1.7
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		s.add_to_group("natural_visual")
		parent.add_child(s)
		s.global_position = Vector2(x, y)
		# props grandes bloquean el paso; setas no
		if "mushroom" not in tex.resource_path:
			SolidBase.attach(s, Vector2(tex.get_width() * k * 0.5, 12.0), Vector2(0, -2))


## Mariposas que revolotean por el patio de día.
func _scatter_butterflies(rng: RandomNumberGenerator) -> void:
	var parent: Node = _visual_parent()
	var tex: Texture2D = load("res://art/sprites/environment/butterfly.png")
	if tex == null:
		return
	var palette: Array = [Color(1, 1, 1), Color(1.0, 0.9, 0.7), Color(0.85, 0.9, 1.1), Color(1.05, 0.8, 0.9)]
	for i in 5:
		var b := Butterfly.new()
		b.texture = tex
		b.modulate = palette[rng.randi() % palette.size()]
		b.add_to_group("natural_visual")
		b.setup(_rect)
		parent.add_child(b)
		b.global_position = _random_point(rng)


## Briznas de pasto repartidas por todo el patio; se mecen al pisarlas.
func _scatter_grass(rng: RandomNumberGenerator) -> void:
	var parent: Node = _visual_parent()
	var tex: Texture2D = load(GRASS_TUFT)
	if tex == null:
		return
	for i in GRASS_COUNT:
		var g := GrassTuft.new()
		g.texture = tex
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.scale = Vector2(1.6, 1.6)
		g.add_to_group("natural_visual")
		g.add_to_group("foliage")
		parent.add_child(g)
		g.global_position = _random_point(rng)


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(_rect.position.x + 40.0, _rect.end.x - 40.0),
		rng.randf_range(_rect.position.y + 70.0, _rect.end.y - 30.0))


func _process(delta: float) -> void:
	_weed_timer -= delta
	if _weed_timer > 0.0:
		return
	_weed_timer = randf_range(WEED_INTERVAL_MIN, WEED_INTERVAL_MAX)
	_weeds = _weeds.filter(func(w): return is_instance_valid(w))
	if _weeds.size() >= WEED_MAX:
		return
	var weed: Node2D = load(WEED_SCENE).instantiate()
	add_child(weed)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	weed.global_position = _random_point(rng)
	weed.add_to_group("natural_visual")
	# Crece lentamente (45-70s) desde brote; no se puede cortar hasta madurar.
	weed.growing = true
	weed.scale = Vector2(0.15, 0.15)
	weed.modulate = Color(0.8, 1.0, 0.75, 0.9)
	var grow_time: float = randf_range(45.0, 70.0)
	var tw := weed.create_tween()
	tw.tween_property(weed, "scale", Vector2.ONE, grow_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(weed, "modulate", Color(1, 1, 1, 1), grow_time)
	tw.tween_callback(func():
		if is_instance_valid(weed):
			weed.growing = false)
	_weeds.append(weed)
