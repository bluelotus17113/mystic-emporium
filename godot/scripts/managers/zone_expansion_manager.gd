extends Node
## Maneja la expansión gradual del Patio Natural.
## El jugador arranca con un patio chico (lvl 0) y va comprando ampliaciones.

signal natural_level_changed(new_level: int)

# El Patio Natural es un mapa 2D grande (map_rect) que se ve entero (pradera).
# Comprar "expansión" agranda la porción USABLE (donde se camina/construye), que
# crece DENTRO de la pradera visible: anclada al borde derecho (la pradera de
# inicio) y centrada en vertical, se agranda hacia la izquierda/arriba/abajo
# hasta cubrir todo el mapa. Así el terreno comprado siempre cae sobre pradera
# iluminada (nunca en la zona oscura fuera del mapa).
const NATURAL_LEFT_X: float = -6400.0  # (legado; ya no ancla la zona usable)
const NATURAL_HEIGHT: float = 400.0    # (legado)
const MAP_MARGIN: float = 40.0         # margen interno respecto al borde del mapa
const NATURAL_LEVELS: Array = [
	{"width": 900.0,  "height": 520.0,  "cost": 0,     "label": "Pradera"},
	{"width": 1250.0, "height": 700.0,  "cost": 120,   "label": "Claro"},
	{"width": 1650.0, "height": 920.0,  "cost": 350,   "label": "Bosquecillo"},
	{"width": 2100.0, "height": 1180.0, "cost": 800,   "label": "Arboleda"},
	{"width": 2600.0, "height": 1460.0, "cost": 1800,  "label": "Espesura"},
	{"width": 3150.0, "height": 1760.0, "cost": 4000,  "label": "Fronda"},
	{"width": 3600.0, "height": 2050.0, "cost": 9000,  "label": "Selva"},
	{"width": 4000.0, "height": 2400.0, "cost": 20000, "label": "Bosque Ancestral"},
]


## --- Mapa de biomas 2D (Fase 2) ---------------------------------------------
## El patio deja de ser una franja: ahora es un mapa grande explorable en las 4
## direcciones. Borde derecho (inicio, tras la tienda pero muy a su izquierda) y
## crece hacia izquierda/arriba/abajo. NO se solapa con el edificio (x≈-1843..0).
const MAP_RIGHT_X: float = -5600.0
const MAP_W: float = 3840.0   # 120 cols × 16px × 2
const MAP_H: float = 2304.0   # 72 rows × 16px × 2

func map_rect() -> Rect2:
	return Rect2(MAP_RIGHT_X - MAP_W, -MAP_H * 0.5, MAP_W, MAP_H)

func map_center() -> Vector2:
	return map_rect().get_center()

## Vista inicial: centro de la porción usable inicial (pradera de inicio).
func starter_view() -> Vector2:
	return natural_rect(0).get_center()


## Porción USABLE del patio para un nivel: sub-rect de la pradera visible,
## anclado al borde derecho y centrado en vertical, que crece hacia la
## izquierda/arriba/abajo. Se recorta al mapa (con margen) para no salirse.
func natural_rect(level: int) -> Rect2:
	var m: Rect2 = map_rect()
	var d: Dictionary = NATURAL_LEVELS[clamp(level, 0, NATURAL_LEVELS.size() - 1)]
	var w: float = minf(float(d.width), m.size.x - 2.0 * MAP_MARGIN)
	var h: float = minf(float(d.height), m.size.y - 2.0 * MAP_MARGIN)
	var right: float = m.end.x - MAP_MARGIN
	var cy: float = m.get_center().y
	return Rect2(Vector2(right - w, cy - h * 0.5), Vector2(w, h))


func get_size_for(level: int) -> Vector2:
	return natural_rect(level).size


func get_center_for(level: int) -> Vector2:
	return natural_rect(level).get_center()

var natural_level: int = 0


func get_current_data() -> Dictionary:
	return NATURAL_LEVELS[clamp(natural_level, 0, NATURAL_LEVELS.size() - 1)]


func get_next_cost() -> int:
	if natural_level + 1 >= NATURAL_LEVELS.size():
		return -1  # maxed
	return int(NATURAL_LEVELS[natural_level + 1].cost)


func is_max_level() -> bool:
	return natural_level + 1 >= NATURAL_LEVELS.size()


func can_expand() -> bool:
	if is_max_level():
		return false
	return InventoryManager.arcane_coins >= get_next_cost()


func expand_natural() -> bool:
	if not can_expand():
		return false
	var cost: int = get_next_cost()
	if not InventoryManager.spend_coins(cost):
		return false
	natural_level += 1
	NotificationManager.post("🌳 Patio ampliado a '%s'!" % get_current_data().label, NotificationManager.Kind.SUCCESS)
	AudioManager.play_beep(720.0, 0.18, -10.0)
	natural_level_changed.emit(natural_level)
	return true


func get_save_state() -> Dictionary:
	return {"natural_level": natural_level}


func load_save_state(data: Dictionary) -> void:
	natural_level = clamp(int(data.get("natural_level", 0)), 0, NATURAL_LEVELS.size() - 1)
	natural_level_changed.emit(natural_level)


func reset_for_prestige() -> void:
	natural_level = 0
	natural_level_changed.emit(natural_level)
