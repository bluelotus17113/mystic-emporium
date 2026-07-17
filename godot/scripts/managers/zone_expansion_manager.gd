extends Node
## Maneja la expansión gradual del Patio Natural.
## El jugador arranca con un patio chico (lvl 0) y va comprando ampliaciones.

signal natural_level_changed(new_level: int)

# ponytail: layout horizontal puro. Anchor a la izquierda x=1000, crece hacia la derecha.
# Altura fija 400 (cabe en companion mode strip y en ventana normal). Filosofía idle:
# el patio es una franja horizontal que el jugador puede pasear con la rueda/raton.
const NATURAL_LEFT_X: float = -6400.0
const NATURAL_HEIGHT: float = 400.0
const NATURAL_LEVELS: Array = [
	{"width": 800.0,  "cost": 0,     "label": "Pequeño"},
	{"width": 1300.0, "cost": 150,   "label": "Mediano"},
	{"width": 1900.0, "cost": 500,   "label": "Grande"},
	{"width": 2600.0, "cost": 1500,  "label": "Vasto"},
	{"width": 3400.0, "cost": 4000,  "label": "Inmenso"},
	{"width": 4500.0, "cost": 10000, "label": "Bosque"},
]


func get_size_for(level: int) -> Vector2:
	return Vector2(NATURAL_LEVELS[level].width, NATURAL_HEIGHT)


func get_center_for(level: int) -> Vector2:
	# Left-anchored: center_x = NATURAL_LEFT_X + width/2
	return Vector2(NATURAL_LEFT_X + NATURAL_LEVELS[level].width * 0.5, 0)

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
