extends Node
## Trackea estadísticas globales y dispara logros cuando se cumplen umbrales.
## Persistido vía SaveManager.

signal stat_changed(stat_id: StringName, new_value: int)
signal achievement_unlocked(achievement_id: StringName, label: String)

var stats: Dictionary = {
	"items_collected_total": 0,
	"items_crafted_total": 0,
	"coins_earned_total": 0,
	"coins_spent_total": 0,
	"orders_completed": 0,
	"orders_expired": 0,
	"buildings_placed": 0,
	"upgrades_done": 0,
	"research_completed": 0,
	"workers_hired": 0,
	"events_survived": 0,
	"playtime_seconds": 0,
}

var _unlocked: Array[StringName] = []
var _playtime_accum: float = 0.0

# ponytail: cada logro lleva su recompensa. coins=instantáneo (1 vez), stars=PrestigeManager.
const ACHIEVEMENTS: Array = [
	{"id": &"first_collect", "label": "Primera Recolección", "stat": "items_collected_total", "threshold": 1, "coins": 25, "stars": 0},
	{"id": &"first_craft", "label": "Primer Crafteo", "stat": "items_crafted_total", "threshold": 1, "coins": 25, "stars": 0},
	{"id": &"first_sale", "label": "Primera Venta", "stat": "orders_completed", "threshold": 1, "coins": 50, "stars": 0},
	{"id": &"first_build", "label": "Primer Edificio", "stat": "buildings_placed", "threshold": 1, "coins": 30, "stars": 0},
	{"id": &"first_upgrade", "label": "Primera Mejora", "stat": "upgrades_done", "threshold": 1, "coins": 50, "stars": 0},
	{"id": &"first_research", "label": "Primera Investigación", "stat": "research_completed", "threshold": 1, "coins": 100, "stars": 0},
	{"id": &"shopkeeper", "label": "Tendero (10 ventas)", "stat": "orders_completed", "threshold": 10, "coins": 200, "stars": 1},
	{"id": &"merchant", "label": "Comerciante (50 ventas)", "stat": "orders_completed", "threshold": 50, "coins": 800, "stars": 2},
	{"id": &"tycoon", "label": "Magnate (200 ventas)", "stat": "orders_completed", "threshold": 200, "coins": 3000, "stars": 5},
	{"id": &"rich_50", "label": "Bolsillos Llenos (500 ⚜ ganados)", "stat": "coins_earned_total", "threshold": 500, "coins": 100, "stars": 0},
	{"id": &"rich_5k", "label": "Riqueza (5,000 ⚜ ganados)", "stat": "coins_earned_total", "threshold": 5000, "coins": 750, "stars": 1},
	{"id": &"rich_50k", "label": "Fortuna (50,000 ⚜ ganados)", "stat": "coins_earned_total", "threshold": 50000, "coins": 5000, "stars": 3},
	{"id": &"green_thumb", "label": "Pulgar Verde (100 recolecciones)", "stat": "items_collected_total", "threshold": 100, "coins": 150, "stars": 0},
	{"id": &"master_collector", "label": "Maestro Recolector (1000 recolecciones)", "stat": "items_collected_total", "threshold": 1000, "coins": 1500, "stars": 2},
	{"id": &"factory", "label": "Fábrica (100 crafteos)", "stat": "items_crafted_total", "threshold": 100, "coins": 500, "stars": 1},
	{"id": &"scholar", "label": "Estudioso (5 investigaciones)", "stat": "research_completed", "threshold": 5, "coins": 400, "stars": 1},
	{"id": &"architect", "label": "Arquitecto (20 edificios)", "stat": "buildings_placed", "threshold": 20, "coins": 600, "stars": 1},
	{"id": &"hr_pro", "label": "Recursos Humanos (5 ayudantes)", "stat": "workers_hired", "threshold": 5, "coins": 400, "stars": 1},
	{"id": &"hour_marathon", "label": "Maratón (1 hora jugada)", "stat": "playtime_seconds", "threshold": 3600, "coins": 500, "stars": 2},
	{"id": &"survivor", "label": "Sobreviviente (10 eventos)", "stat": "events_survived", "threshold": 10, "coins": 1000, "stars": 2},
]


func _ready() -> void:
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	InventoryManager.coins_changed.connect(_on_coins_changed)
	OrderManager.order_completed.connect(_on_order_completed)
	OrderManager.order_expired.connect(_on_order_expired)
	BuildManager.placement_completed.connect(_on_placement_completed)
	ResearchManager.research_completed.connect(_on_research_completed)
	ShopManager.worker_purchased.connect(_on_worker_purchased)
	EventManager.event_ended.connect(_on_event_ended)


var _last_coins: int = -1

func _on_coins_changed(amount: int) -> void:
	if _last_coins == -1:
		_last_coins = amount
		return
	var diff: int = amount - _last_coins
	if diff > 0:
		bump("coins_earned_total", diff)
	elif diff < 0:
		bump("coins_spent_total", -diff)
	_last_coins = amount


func _on_order_completed(_o: OrderData) -> void:
	bump("orders_completed", 1)


func _on_order_expired(_o: OrderData) -> void:
	bump("orders_expired", 1)


func _on_placement_completed(_b: BuildableData, _pos: Vector2) -> void:
	bump("buildings_placed", 1)


func _on_research_completed(_r: ResearchData) -> void:
	bump("research_completed", 1)


func _on_worker_purchased(_t: int, _i) -> void:
	bump("workers_hired", 1)


func _on_event_ended(_id: StringName) -> void:
	bump("events_survived", 1)


func _process(delta: float) -> void:
	_playtime_accum += delta
	if _playtime_accum >= 1.0:
		var secs: int = int(_playtime_accum)
		_playtime_accum -= secs
		bump("playtime_seconds", secs)


func bump(stat_id: String, amount: int = 1) -> void:
	if not stats.has(stat_id):
		stats[stat_id] = 0
	stats[stat_id] += amount
	stat_changed.emit(StringName(stat_id), stats[stat_id])
	_check_achievements()


func get_stat(stat_id: String) -> int:
	return stats.get(stat_id, 0)


var _checking: bool = false

func _check_achievements() -> void:
	# ponytail: guard contra recursión sincrónica. add_coins en la rama de recompensa
	# emite coins_changed → _on_coins_changed → bump → _check_achievements otra vez,
	# explotando en cascada toasts/audio en un solo frame y congelando la UI.
	if _checking:
		return
	_checking = true
	for ach in ACHIEVEMENTS:
		if ach.id in _unlocked:
			continue
		var current: int = stats.get(ach.stat, 0)
		if current >= ach.threshold:
			_unlocked.append(ach.id)
			var coins: int = ach.get("coins", 0)
			var stars: int = ach.get("stars", 0)
			var reward_txt: String = ""
			# Deferir add_coins para que la cascada no ocurra en la misma pila.
			if coins > 0:
				InventoryManager.call_deferred("add_coins", coins)
				reward_txt += " +%d⚜" % coins
			if stars > 0:
				PrestigeManager.stars += stars
				PrestigeManager.lifetime_stars += stars
				reward_txt += " +%d★" % stars
			NotificationManager.post("🏆 Logro: %s%s" % [ach.label, reward_txt], NotificationManager.Kind.REWARD)
			AudioManager.play_beep(1480.0, 0.2, -8.0)
			achievement_unlocked.emit(ach.id, ach.label)
	_checking = false


func is_achievement_unlocked(id: StringName) -> bool:
	return id in _unlocked


func get_unlocked_achievements() -> Array[StringName]:
	return _unlocked.duplicate()


func get_save_state() -> Dictionary:
	return {
		"stats": stats.duplicate(),
		"unlocked": _unlocked.duplicate(),
	}


func load_save_state(data: Dictionary) -> void:
	stats = data.get("stats", stats).duplicate()
	_unlocked.assign(data.get("unlocked", []))


func reset_for_prestige() -> void:
	# ponytail: mantenemos los achievements y playtime históricos. Solo reseteo
	# contadores que el jugador acumula "por run".
	stats["items_collected_total"] = 0
	stats["items_crafted_total"] = 0
	stats["orders_completed"] = 0
	stats["orders_expired"] = 0
	stats["buildings_placed"] = 0
	stats["upgrades_done"] = 0
	stats["research_completed"] = 0
