extends Sprite2D
## Patio Natural: una ISLA. Pradera uniforme (lienzo en blanco para que el jugador
## cree biomas/decore con tiles decorativos) rodeada de costa y mar abierto.
##
## El mar no es adorno: la vista se sale del mapa por los bordes —en `starter_view()`
## la cámara queda pegada al canto derecho y asoma ~150 px— y eso antes era una banda
## negra. Ahora es agua, así que el límite del patio se lee como "esto es una isla"
## en vez de como un fallo.
##
## Se compone una vez a un solo ImageTexture (estático, barato), más un `Sprite2D`
## de agua profunda repetida detrás que cubre cualquier posición de cámara.

const T: int = 16
const COLS: int = 120  # 120×72 → 1920×1152 arte → ×2 = 3840×2304 mundo
const ROWS: int = 72
const DIR: String = "res://art/tiles/minish/"
const WCELL: float = 32.0  # px de mundo por celda (16 arte × 2 escala)

## Celdas de mar compuestas alrededor de la pradera. Solo tienen que dar para la
## orilla y el bajío: de ahí hacia fuera se encarga el mar repetido de detrás.
const MARGEN: int = 10
## Cuánto se sale la tierra del rect original, para que la costa no sea un
## rectángulo perfecto. SIEMPRE hacia fuera: hacia dentro se comería patio jugable.
const BULTO_MAX: int = 4
## Celdas de agua clara antes de pasar a la profunda.
const BAJIO: int = 3
## Cuánto se extiende el mar de fondo más allá del mapa. Múltiplo de WCELL para
## que no se vea la costura con el agua profunda de la textura compuesta.
## Generoso a propósito: el zoom del patio es dinámico (baja hasta ~0.25 en el
## último nivel, y el telón de nubes lo abre otro 26%), así que la vista llega
## mucho más lejos de lo que parece. Cuesta un quad y una textura de 16×16.
const MAR_EXTRA: float = 4096.0


func _ready() -> void:
	add_to_group("biome_map")
	centered = false
	region_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(2, 2)
	# La textura crece por los cuatro lados, así que el sprite arranca antes. Sin
	# compensarlo, la pradera se desplazaría respecto a la rejilla del juego.
	position = ZoneExpansionManager.map_rect().position - Vector2(MARGEN, MARGEN) * WCELL
	texture = _compose()
	_crear_mar()


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


## Rect de dispersión: la pradera con margen. Deliberadamente NO incluye la costa:
## la fauna y los props no deben aparecer en la orilla ni flotando en el mar.
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


## ¿Hay tierra en esta celda del lienzo ampliado? Las coordenadas llevan el margen
## incluido: (0,0) es la esquina de la textura, no la de la pradera.
func _es_tierra(cx: int, cy: int) -> bool:
	var col: int = cx - MARGEN
	var row: int = cy - MARGEN
	if col >= 0 and col < COLS and row >= 0 and row < ROWS:
		return true
	var fuera_x: int = maxi(0, maxi(-col, col - (COLS - 1)))
	var fuera_y: int = maxi(0, maxi(-row, row - (ROWS - 1)))
	# Ondas de baja frecuencia a lo largo de la costa, distintas en cada eje.
	var bx: int = 1 + _h(col / 5, 0, 31) * BULTO_MAX / 100
	var by: int = 1 + _h(0, row / 5, 37) * BULTO_MAX / 100
	if fuera_x > 0 and fuera_y > 0:
		# Esquina redondeada: es lo que evita que la isla parezca una caja.
		return fuera_x + fuera_y <= mini(bx, by)
	if fuera_x > 0:
		return fuera_x <= bx
	return fuera_y <= by


## Distancia en celdas de una celda de agua a la tierra más cercana (tope BAJIO+2).
func _dist_a_tierra(cx: int, cy: int) -> int:
	for d in range(1, BAJIO + 2):
		for dx in range(-d, d + 1):
			for dy in range(-d, d + 1):
				if absi(dx) != d and absi(dy) != d:
					continue  # solo el anillo exterior de ese radio
				if _es_tierra(cx + dx, cy + dy):
					return d
	return BAJIO + 2


## Tile de orilla para una celda de TIERRA que da al mar, según por dónde le da.
## Los tiles están nombrados por dónde queda el agua: shore_S es hierba arriba y
## agua abajo, así que va en el canto sur de la isla.
func _orilla(cx: int, cy: int) -> String:
	if not _es_tierra(cx, cy + 1):
		return "shore_S"
	if not _es_tierra(cx, cy - 1):
		return "shore_N"
	if not _es_tierra(cx + 1, cy):
		return "shore_E"
	if not _es_tierra(cx - 1, cy):
		return "shore_W"
	return ""


func _compose() -> ImageTexture:
	var cache: Dictionary = {}
	for n in ["grass", "grass2", "grass_flowers", "grass_dark", "dirt",
			"shore_N", "shore_S", "shore_E", "shore_W",
			"water_0", "water_1", "water_deep"]:
		var tex: Texture2D = load(DIR + n + ".png")
		if tex == null:
			continue
		var img: Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		cache[n] = img
	var fallback: Image = cache.get("grass")
	var ancho: int = COLS + 2 * MARGEN
	var alto: int = ROWS + 2 * MARGEN
	var out := Image.create(ancho * T, alto * T, false, Image.FORMAT_RGBA8)
	for cy in alto:
		for cx in ancho:
			var nombre: String
			if _es_tierra(cx, cy):
				nombre = _orilla(cx, cy)
				if nombre == "":
					nombre = _tile_at(cx - MARGEN, cy - MARGEN)
			elif _dist_a_tierra(cx, cy) <= BAJIO:
				# Bajío: dos tonos claros mezclados, para que no sea una plancha lisa.
				nombre = "water_1" if _h(cx, cy, 41) < 45 else "water_0"
			else:
				nombre = "water_deep"
			var img: Image = cache.get(nombre, fallback)
			if img != null:
				out.blit_rect(img, Rect2i(0, 0, T, T), Vector2i(cx * T, cy * T))
	return ImageTexture.create_from_image(out)


## Mar abierto detrás de todo: una sola textura de agua profunda repetida. Cubre
## cualquier sitio al que llegue la cámara, así que por lejos que se vaya el
## jugador nunca vuelve a asomarse el fondo negro.
func _crear_mar() -> void:
	var tex: Texture2D = load(DIR + "water_deep.png")
	if tex == null:
		return
	var mar := Sprite2D.new()
	mar.name = "MarExterior"
	mar.texture = tex
	mar.centered = false
	mar.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mar.scale = Vector2(2, 2)
	mar.z_index = z_index - 1
	var r: Rect2 = ZoneExpansionManager.map_rect().grow(MAR_EXTRA)
	mar.region_enabled = true
	mar.region_rect = Rect2(0, 0, r.size.x * 0.5, r.size.y * 0.5)  # ×0.5 por la escala
	mar.position = r.position
	# Sin esto el océano se vería también en el Taller y en Recepción: el
	# controlador de cámara enseña y esconde por este grupo.
	mar.add_to_group("natural_visual")
	mar.visible = visible
	get_parent().add_child.call_deferred(mar)
