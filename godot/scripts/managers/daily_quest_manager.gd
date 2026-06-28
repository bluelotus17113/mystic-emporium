extends Node
## Una misión diaria al día. Sincronizada con la fecha del PC vía CalendarManager.
## La quest se genera cuando cambia el día del sistema. Recompensa: estrellas + coins.

signal quest_generated(quest: Dictionary)
signal quest_completed(quest: Dictionary)

const QUEST_TEMPLATES: Array = [
	# tipo: "complete_orders" | "earn_coins" | "craft_items" | "build_anything" | "research"
	{"type": "complete_orders", "target": 5,  "label": "Entrega 5 pedidos hoy",         "coins": 200, "stars": 1},
	{"type": "complete_orders", "target": 10, "label": "Entrega 10 pedidos hoy",        "coins": 500, "stars": 2},
	{"type": "earn_coins",      "target": 500,"label": "Gana 500 ⚜ hoy",                "coins": 100, "stars": 1},
	{"type": "earn_coins",      "target": 2000,"label": "Gana 2000 ⚜ hoy",              "coins": 400, "stars": 2},
	{"type": "craft_items",     "target": 10, "label": "Craftea 10 items hoy",          "coins": 250, "stars": 1},
	{"type": "craft_items",     "target": 30, "label": "Craftea 30 items hoy",          "coins": 600, "stars": 2},
	{"type": "build_anything",  "target": 2,  "label": "Construye 2 edificios hoy",     "coins": 150, "stars": 1},
	{"type": "research",        "target": 1,  "label": "Completa 1 investigación hoy",  "coins": 300, "stars": 1},
]

var current_quest: Dictionary = {}  ## vacío = no hay quest activa
var current_progress: int = 0
var _baseline: Dictionary = {}  ## stat name → valor al spawnear la quest, para diff


func _ready() -> void:
	call_deferred("_late_init")


func _late_init() -> void:
	CalendarManager.day_changed.connect(_on_day_changed)
	# Si no hay quest activa al arrancar, generar una.
	if current_quest.is_empty():
		_generate()


func _on_day_changed(_d: int, _s: int) -> void:
	_generate()


func _generate() -> void:
	current_quest = QUEST_TEMPLATES.pick_random().duplicate()
	current_progress = 0
	_baseline = {
		"orders_completed": StatsManager.get_stat("orders_completed"),
		"coins_earned_total": StatsManager.get_stat("coins_earned_total"),
		"items_crafted_total": StatsManager.get_stat("items_crafted_total"),
		"buildings_placed": StatsManager.get_stat("buildings_placed"),
		"research_completed": StatsManager.get_stat("research_completed"),
	}
	NotificationManager.post("📋 Misión diaria: %s" % current_quest.label, NotificationManager.Kind.INFO)
	quest_generated.emit(current_quest)


var _poll_accum: float = 0.0

func _process(_delta: float) -> void:
	# ponytail: el progreso de la quest se computa contra StatsManager. Polleando 2Hz
	# es indistinguible visualmente del 60Hz y libera ciclos.
	_poll_accum += _delta
	if _poll_accum < 0.5:
		return
	_poll_accum = 0.0
	if current_quest.is_empty():
		return
	var stat: String = _stat_for_type(current_quest.type)
	if stat == "":
		return
	current_progress = StatsManager.get_stat(stat) - _baseline.get(stat, 0)
	if current_progress >= current_quest.target:
		_complete()


func _stat_for_type(quest_type: String) -> String:
	match quest_type:
		"complete_orders": return "orders_completed"
		"earn_coins": return "coins_earned_total"
		"craft_items": return "items_crafted_total"
		"build_anything": return "buildings_placed"
		"research": return "research_completed"
		_: return ""


func _complete() -> void:
	var coins: int = current_quest.get("coins", 0)
	var stars: int = current_quest.get("stars", 0)
	if coins > 0:
		InventoryManager.add_coins(coins)
	if stars > 0:
		PrestigeManager.stars += stars
		PrestigeManager.lifetime_stars += stars
	NotificationManager.post("✅ Misión diaria completada! +%d⚜ +%d★" % [coins, stars], NotificationManager.Kind.REWARD)
	AudioManager.play_beep(1760.0, 0.25, -8.0)
	quest_completed.emit(current_quest)
	current_quest = {}  ## next refresh viene en el cambio de día


func get_progress_text() -> String:
	if current_quest.is_empty():
		return "Misión completada ✓ (próxima al cambiar el día)"
	return "%s · %d/%d" % [current_quest.label, current_progress, current_quest.target]


func get_save_state() -> Dictionary:
	return {
		"current_quest": current_quest,
		"baseline": _baseline,
	}


func load_save_state(data: Dictionary) -> void:
	current_quest = data.get("current_quest", {})
	_baseline = data.get("baseline", {})


func reset_for_prestige() -> void:
	current_quest = {}
	_baseline.clear()
	_generate()
