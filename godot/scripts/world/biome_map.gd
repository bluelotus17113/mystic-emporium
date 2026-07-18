extends Sprite2D
## Mapa de biomas del Patio Natural: compone un mapa grande (2D, ~20× el patio
## viejo) pintando tiles por bioma según su geografía —norte nevado, sur
## desértico, este pradera de inicio, oeste bosque/cantera/claro, estanque al
## centro-sur. Se compone una vez a un solo ImageTexture (estático, barato).

const T: int = 16      # px por tile en el arte
const COLS: int = 120  # 120×72 tiles → 1920×1152 arte → ×2 = 3840×2304 mundo (~28×)
const ROWS: int = 72
const DIR: String = "res://art/tiles/minish/"

# Bioma → lista ponderada de tiles (variantes con ruido).
const BIOMES: Dictionary = {
	"snow":    ["snow", "snow", "snow", "snow", "snow_grass", "ice"],
	"desert":  ["desert_cracked", "desert_cracked", "desert_cracked", "sand", "dry_grass"],
	"meadow":  ["grass", "grass", "grass2", "grass", "grass_flowers"],
	"forest":  ["grass_dark", "grass_dark", "grass_dark", "grass", "dirt"],
	"quarry":  ["dirt_dark", "dirt_dark", "cave_floor", "dirt", "dirt_dark"],
	"arcane":  ["grass_dark", "grass", "grass_dark", "grass_flowers"],
}


func _ready() -> void:
	add_to_group("biome_map")
	centered = false
	region_enabled = false  # el nodo heredaba región recortada del fondo viejo
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(2, 2)
	position = ZoneExpansionManager.map_rect().position  # esquina sup-izq
	texture = _compose()


const WCELL: float = 32.0  # px de mundo por celda (16 arte × 2 escala)

func _cell_of(pos: Vector2) -> Vector2i:
	var o: Vector2 = ZoneExpansionManager.map_rect().position
	return Vector2i(floori((pos.x - o.x) / WCELL), floori((pos.y - o.y) / WCELL))


## Bioma en una posición del mundo ("snow"/"desert"/"meadow"/"forest"/"quarry"/
## "arcane"/"pond"). Útil para huellas, fauna y props por bioma.
func biome_at_world(pos: Vector2) -> String:
	var c: Vector2i = _cell_of(pos)
	var col: int = clampi(c.x, 0, COLS - 1)
	var row: int = clampi(c.y, 0, ROWS - 1)
	if Vector2(col, row).distance_to(POND_C) < POND_R and _biome_at(col, row) in ["meadow", "forest"]:
		return "pond"
	return _biome_at(col, row)


func _cells_to_rect(c0: int, r0: int, c1: int, r1: int) -> Rect2:
	var o: Vector2 = ZoneExpansionManager.map_rect().position
	return Rect2(o.x + c0 * WCELL, o.y + r0 * WCELL, (c1 - c0) * WCELL, (r1 - r0) * WCELL)


func pond_world_rect() -> Rect2:
	return _cells_to_rect(int(POND_C.x - POND_R), int(POND_C.y - POND_R),
			int(POND_C.x + POND_R), int(POND_C.y + POND_R))


## Rect aproximado (mundo) de un bioma, para dispersar fauna/props dentro.
func biome_world_rect(biome: String) -> Rect2:
	var tr0: int = 24
	var tr1: int = ROWS - 24
	match biome:
		"snow": return _cells_to_rect(4, 2, COLS - 4, 14)
		"desert": return _cells_to_rect(4, ROWS - 14, COLS - 4, ROWS - 2)
		"meadow": return _cells_to_rect(COLS - 28, tr0, COLS - 4, tr1)
		"forest": return _cells_to_rect(COLS - 60, tr0, COLS - 32, tr1)
		"quarry": return _cells_to_rect(COLS - 93, tr0, COLS - 64, tr1)
		"arcane": return _cells_to_rect(6, tr0, COLS - 97, tr1)
	return _cells_to_rect(COLS - 28, tr0, COLS - 4, tr1)


func _h(x: int, y: int, s: int) -> int:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	return (n ^ (n >> 16)) % 100


## Bioma en una celda según latitud (norte/sur) y longitud (este/oeste), con
## bordes ondulados por ruido para que no sean líneas rectas.
func _biome_at(col: int, row: int) -> String:
	var jitter_n: int = (_h(col, 0, 7) % 8) - 4
	var jitter_s: int = (_h(col, 1, 9) % 8) - 4
	# Latitud (row 0 = norte).
	if row < 16 + jitter_n:
		return "snow"
	if row < 24 + jitter_n:
		return "snow" if (_h(col, row, 3) < 45) else _temperate(col)  # transición nieve
	if row > ROWS - 16 + jitter_s:
		return "desert"
	if row > ROWS - 24 + jitter_s:
		return "desert" if (_h(col, row, 4) < 45) else _temperate(col)  # transición desierto
	return _temperate(col)


## Longitud en la banda templada (col 0 = oeste, COLS-1 = este/inicio).
func _temperate(col: int) -> String:
	if col > COLS - 30:
		return "meadow"      # este: pradera de inicio (junto a la tienda)
	if col > COLS - 62:
		return "forest"      # centro: bosque
	if col > COLS - 95:
		return "quarry"      # oeste: cantera
	return "arcane"          # extremo oeste: claro arcano


func _pick(biome: String, col: int, row: int) -> String:
	var variants: Array = BIOMES.get(biome, BIOMES["meadow"])
	return variants[_h(col, row, 11) % variants.size()]


## Estanque: un blob de agua en el centro-sur templado.
const POND_C := Vector2(COLS - 44, 38)
const POND_R := 11.0

func _tile_at(col: int, row: int) -> String:
	var d: float = Vector2(col, row).distance_to(POND_C)
	# Solo hay estanque si la celda es templada (no en nieve/desierto).
	if d < POND_R and _biome_at(col, row) in ["meadow", "forest"]:
		if d < POND_R - 4.0:
			return "water_deep"
		return "water"
	return _pick(_biome_at(col, row), col, row)


func _compose() -> ImageTexture:
	var cache: Dictionary = {}
	var need: Array = ["snow", "ice", "snow_grass", "desert_cracked", "dry_grass",
		"sand", "grass", "grass2", "grass_flowers", "grass_dark", "dirt", "dirt_dark",
		"cave_floor", "water", "water_deep"]
	for n in need:
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
			var tname: String = _tile_at(col, row)
			var img: Image = cache.get(tname, fallback)
			if img != null:
				out.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(col * T, row * T))
	return ImageTexture.create_from_image(out)
