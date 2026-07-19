extends Node
## Árbol de mejoras del local: nodos que dan bonificaciones globales permanentes
## (precio de venta, velocidad de crafteo, vigor de los ayudantes, reputación).
## Se compran con monedas ⚜, suben de nivel con coste creciente y algunos
## requieren tener otro previo. Otros sistemas leen los multiplicadores:
##   OrderManager  → sale_multiplier() / rep_multiplier()
##   Workstation   → craft_speed_multiplier()
##   WorkerBase    → vigor_multiplier()

signal upgrades_changed

## Definición del árbol. effect ∈ {sale, craft, vigor, rep}. req = id previo que
## debe tener nivel ≥ 1 para desbloquear (o &"" si es de base).
const UPGRADES: Array = [
	{"id": &"prices", "name": "Buen Ojo Comercial", "icon": "💰",
	 "desc": "+8% monedas por venta", "effect": &"sale",
	 "per_level": 0.08, "base_cost": 150, "growth": 1.7, "max": 5, "req": &""},
	{"id": &"speed", "name": "Manos Ágiles", "icon": "⚡",
	 "desc": "+8% velocidad de crafteo", "effect": &"craft",
	 "per_level": 0.08, "base_cost": 180, "growth": 1.7, "max": 5, "req": &""},
	{"id": &"vigor", "name": "Té Energizante", "icon": "☕",
	 "desc": "Los ayudantes se cansan 10% más lento", "effect": &"vigor",
	 "per_level": 0.10, "base_cost": 200, "growth": 1.8, "max": 4, "req": &""},
	{"id": &"reputation", "name": "Fama del Emporium", "icon": "⭐",
	 "desc": "+10% reputación por venta", "effect": &"rep",
	 "per_level": 0.10, "base_cost": 400, "growth": 1.8, "max": 4, "req": &"prices"},
	{"id": &"charm", "name": "Ambiente Acogedor", "icon": "🕯️",
	 "desc": "+6% monedas por venta (acumula)", "effect": &"sale",
	 "per_level": 0.06, "base_cost": 500, "growth": 1.9, "max": 4, "req": &"vigor"},
	{"id": &"mastery", "name": "Maestría Arcana", "icon": "🔮",
	 "desc": "+10% velocidad de crafteo (acumula)", "effect": &"craft",
	 "per_level": 0.10, "base_cost": 600, "growth": 1.9, "max": 4, "req": &"speed"},
]

var _levels: Dictionary = {}  # id(StringName) -> int


func _def(id: StringName) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


func level_of(id: StringName) -> int:
	return int(_levels.get(id, 0))


func is_maxed(id: StringName) -> bool:
	var d: Dictionary = _def(id)
	return not d.is_empty() and level_of(id) >= int(d["max"])


## Desbloqueada si no tiene requisito, o si el requisito ya tiene nivel ≥ 1.
func is_unlocked(id: StringName) -> bool:
	var d: Dictionary = _def(id)
	if d.is_empty():
		return false
	var req: StringName = d["req"]
	return req == &"" or level_of(req) >= 1


## Coste del siguiente nivel: base * growth^nivel_actual.
func cost_of(id: StringName) -> int:
	var d: Dictionary = _def(id)
	if d.is_empty():
		return 0
	return int(round(float(d["base_cost"]) * pow(float(d["growth"]), float(level_of(id)))))


func can_buy(id: StringName) -> bool:
	return is_unlocked(id) and not is_maxed(id) and InventoryManager.arcane_coins >= cost_of(id)


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	if not InventoryManager.spend_coins(cost_of(id)):
		return false
	_levels[id] = level_of(id) + 1
	upgrades_changed.emit()
	var d: Dictionary = _def(id)
	NotificationManager.post("%s %s ¡mejorado! (Nv %d)" % [d.get("icon", ""), d.get("name", ""), level_of(id)],
		NotificationManager.Kind.INFO)
	AudioManager.play_beep(720.0, 0.12, -10.0)
	return true


## Suma de bonificaciones de un efecto (per_level * nivel de cada nodo).
func _sum_effect(effect: StringName) -> float:
	var total: float = 0.0
	for u in UPGRADES:
		if u["effect"] == effect:
			total += float(u["per_level"]) * float(level_of(u["id"]))
	return total


func sale_multiplier() -> float:
	return 1.0 + _sum_effect(&"sale")


func craft_speed_multiplier() -> float:
	return 1.0 + _sum_effect(&"craft")


func rep_multiplier() -> float:
	return 1.0 + _sum_effect(&"rep")


## <1.0: los ayudantes gastan energía más lento (se multiplica el drenaje).
func vigor_multiplier() -> float:
	return maxf(0.2, 1.0 - _sum_effect(&"vigor"))


func get_save_state() -> Dictionary:
	var out: Dictionary = {}
	for id in _levels:
		out[String(id)] = int(_levels[id])
	return {"levels": out}


func load_save_state(data: Dictionary) -> void:
	_levels.clear()
	var lv: Dictionary = data.get("levels", {})
	for sid in lv:
		_levels[StringName(sid)] = int(lv[sid])
	upgrades_changed.emit()


func reset_for_prestige() -> void:
	_levels.clear()
	upgrades_changed.emit()
