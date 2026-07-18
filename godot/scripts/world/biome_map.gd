extends Sprite2D
## Patio Natural: un mapa grande verde uniforme (pradera), lienzo en blanco para
## que el jugador cree biomas/decore con tiles decorativos. Variación natural
## suave (parches de hierba oscura, alguna calva de tierra, flores). Se compone
## una vez a un solo ImageTexture (estático, barato).

const T: int = 16
const COLS: int = 120  # 120×72 → 1920×1152 arte → ×2 = 3840×2304 mundo
const ROWS: int = 72
const DIR: String = "res://art/tiles/minish/"
const WCELL: float = 32.0  # px de mundo por celda (16 arte × 2 escala)


func _ready() -> void:
	add_to_group("biome_map")
	centered = false
	region_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(2, 2)
	position = ZoneExpansionManager.map_rect().position
	texture = _compose()


func _h(x: int, y: int, s: int) -> int:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return (n ^ (n >> 16)) % 100


## Todo el patio es una pradera; devolvemos "meadow" en cualquier punto.
func biome_at_world(_pos: Vector2) -> String:
	return "meadow"


func _cells_to_rect(c0: int, r0: int, c1: int, r1: int) -> Rect2:
	var o: Vector2 = ZoneExpansionManager.map_rect().position
	return Rect2(o.x + c0 * WCELL, o.y + r0 * WCELL, (c1 - c0) * WCELL, (r1 - r0) * WCELL)


func pond_world_rect() -> Rect2:
	return Rect2()


## Rect de dispersión: todo el patio (con margen).
func biome_world_rect(_biome: String) -> Rect2:
	return _cells_to_rect(4, 4, COLS - 4, ROWS - 4)


## Tile de cada celda: pradera con variación natural suave.
func _tile_at(col: int, row: int) -> String:
	# Parches de hierba más oscura (ruido de baja frecuencia, suaves).
	if _h(col / 6, row / 6, 21) < 18 and _h(col, row, 22) < 62:
		return "grass_dark"
	var v: int = _h(col, row, 11)
	if v < 2:
		return "grass_flowers"  # florecitas muy dispersas
	if v < 40:
		return "grass2"
	return "grass"


func _compose() -> ImageTexture:
	var cache: Dictionary = {}
	for n in ["grass", "grass2", "grass_flowers", "grass_dark", "dirt"]:
		var tex: Texture2D = load(DIR + n + ".png")
		if tex == null:
			continue
		var img: Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		cache[n] = img
	var fallback: Image = cache.get("grass")
	var out := Image.create(COLS * T, ROWS * T, false, Image.FORMAT_RGBA8)
	for row in ROWS:
		for col in COLS:
			var img: Image = cache.get(_tile_at(col, row), fallback)
			if img != null:
				out.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(col * T, row * T))
	return ImageTexture.create_from_image(out)
