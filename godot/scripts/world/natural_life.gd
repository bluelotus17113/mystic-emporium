class_name NaturalLife
extends Node2D
## Vida del Patio Natural: (1) scatter decorativo determinista (rocas, arbustos,
## setas, juncos — assets minish_objects) y (2) maleza que crece sola con el
## tiempo y que los duendes cortan (es un ResourceNode HERB de un solo uso).
## Instalado por game_bootstrap; no requiere ediciones de escena.

const SCATTER: Array = [
	"res://art/sprites/minish_objects/bush.png",
	"res://art/sprites/minish_objects/flower_bush.png",
	"res://art/sprites/minish_objects/mushroom_red.png",
	"res://art/sprites/environment/decoration_stone_cairn.png",
	"res://art/sprites/environment/decoration_fallen_log.png",
	"res://art/sprites/minish_objects/hay_bale.png",
	"res://art/sprites/minish_objects/tree_dead.png",
]
const SCATTER_COUNT: int = 22
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
	for i in SCATTER_COUNT:
		var tex: Texture2D = load(SCATTER[rng.randi() % SCATTER.size()])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = _random_point(rng)
		# escala acorde al mundo: setas/flores menores, resto x1.8
		var k: float = 1.4 if "mushroom" in tex.resource_path else 1.8
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, -tex.get_height() * 0.5 + 4)
		s.add_to_group("natural_visual")
		add_child(s)
		# props grandes bloquean el paso; setas/flores no
		if not ("mushroom" in tex.resource_path or "flower" in tex.resource_path):
			SolidBase.attach(s, Vector2(tex.get_width() * k * 0.55, 12.0), Vector2(0, -2))


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
