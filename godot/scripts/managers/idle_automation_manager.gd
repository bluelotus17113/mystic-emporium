extends Node
## Centro de decisiones para el modo IDLE: hace que el emporio se juegue solo.
## Toggleable por subsistema (craft / research / upgrade / buy_workers / auto_orders).
##
## Cada N segundos evalúa el estado del juego y dispara acciones óptimas.

signal automation_toggled(key: StringName, on: bool)

const TICK_INTERVAL: float = 1.5
const UPGRADE_RESERVE_RATIO: float = 1.5  ## Solo mejora si coins >= cost * 1.5
const WORKER_AUTO_BUY_RESERVE: int = 50    ## Coins reserva tras compra

@export var auto_craft: bool = true
@export var auto_research: bool = true
@export var auto_upgrade: bool = true
@export var auto_buy_workers: bool = false
@export var auto_orders: bool = true  ## ProtagonistAI ya hace esto, exponemos toggle.

var _tick_timer: float = 0.0
var _items_for_orders: Dictionary = {}  # item_id -> {qty: int, max_tier: int}


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		_tick()


func _tick() -> void:
	_refresh_orders_needs()
	if auto_craft:
		_drive_crafting()
	if auto_orders:
		_drive_delivery()
	if auto_research:
		_drive_research()
	if auto_upgrade:
		_drive_upgrades()
	if auto_buy_workers:
		_drive_worker_purchase()


# ---------- Pedidos activos: qué items se necesitan ----------

func _refresh_orders_needs() -> void:
	_items_for_orders.clear()
	for entry in OrderManager.get_active_orders():
		var order: OrderData = entry.data
		if order == null or order.requested_item == null:
			continue
		var needed: int = order.requested_quantity - InventoryManager.get_item_count(order.requested_item)
		if needed <= 0:
			continue
		var iid: StringName = order.requested_item.id
		var cur: Dictionary = _items_for_orders.get(iid, {"qty": 0, "max_tier": 0})
		cur.qty += needed
		cur.max_tier = max(cur.max_tier, order.tier)
		_items_for_orders[iid] = cur


# ---------- Auto-Craft ----------

func _drive_crafting() -> void:
	# Para cada estación lista, busca la mejor receta:
	#  1) que produzca un item para el pedido actual (priority high)
	#  2) cuyos ingredientes tengamos
	#  3) o produzca un ingrediente intermedio necesario
	for ws in get_tree().get_nodes_in_group("workstations"):
		if ws == null or not is_instance_valid(ws):
			continue
		if not (ws is Workstation):
			continue
		var station := ws as Workstation
		if not station.auto_craft_enabled:
			continue
		if not station.is_ready_to_work():
			continue
		var best: RecipeData = _pick_best_recipe_for(station)
		if best != null:
			station.start_craft(best)


func _pick_best_recipe_for(station: Workstation) -> RecipeData:
	var recipes: Array[RecipeData] = station.get_filtered_recipes()
	if recipes.is_empty():
		return null
	# Score: higher if matches an order or unlocks a chain we need.
	var best: RecipeData = null
	var best_score: int = 0
	for r in recipes:
		if not InventoryManager.has_items(r.get_ingredient_pairs()):
			continue
		var score: int = 1
		# Priority 1: item directamente pedido. Peso = qty × (1 + tier×0.5) para que
		# un VIP (tier 5) tenga ~3.5× más prioridad que un cliente común (tier 1).
		if r.output_item != null and _items_for_orders.has(r.output_item.id):
			var need: Dictionary = _items_for_orders[r.output_item.id]
			score += int(100 * need.qty * (1.0 + need.max_tier * 0.5))
		# Priority 2: item intermedio que necesitamos
		if r.output_item != null and _is_intermediate_for_orders(r.output_item):
			score += 30
		# Priority 3: valor del output (preferir items caros)
		if r.output_item != null:
			score += r.output_item.base_value
		if score > best_score:
			best_score = score
			best = r
	return best


func _is_intermediate_for_orders(item: ItemData) -> bool:
	# Recorre el catálogo de recetas: ¿algún output que necesitamos usa este item como ingrediente?
	for needed_id in _items_for_orders.keys():
		var target_item: ItemData = InventoryManager.item_lookup.get(needed_id)
		if target_item == null:
			continue
		# Buscar receta que produzca target_item y consuma item
		for r in RecipeManager.get_unlocked_recipes():
			if r.output_item == null or r.output_item.id != needed_id:
				continue
			for pair in r.get_ingredient_pairs():
				if pair.item != null and pair.item.id == item.id:
					return true
	return false


# ---------- Auto-Delivery ----------

func _drive_delivery() -> void:
	# Garantiza que un order entregable se complete aunque el ProtagonistAI esté
	# DRAGGING, en otra zona o muerto. El protagonist sigue haciendo su teleport
	# visual cuando puede — si llega tarde, OrderManager.completed flag evita doble.
	# Múltiples entregas por tick: si hay stock para varios, los entregamos todos.
	var safety: int = 0
	while safety < OrderManager.get_active_count():
		safety += 1
		var idx: int = OrderManager.find_deliverable_order_index()
		if idx < 0:
			return
		if not OrderManager.try_complete_at(idx):
			return


# ---------- Auto-Research ----------

func _drive_research() -> void:
	if ResearchManager.get_active() != null:
		return
	# Toma cualquier investigación de la primera estación de research disponible.
	var stations: Array = get_tree().get_nodes_in_group("research_stations")
	if stations.is_empty():
		return
	for s in stations:
		if not is_instance_valid(s):
			continue
		var available: Array[ResearchData] = ResearchManager.get_available_for_station(s.station_type)
		# Empezar la más barata que podamos pagar.
		available.sort_custom(func(a, b): return a.coin_cost < b.coin_cost)
		for r in available:
			# can_afford chequea coins + items requeridos. Sin esto, intentaríamos
			# cada tick aunque falten materiales y el start fallaría en bucle.
			if ResearchManager.can_afford(r):
				if ResearchManager.start_research(r):
					return


# ---------- Auto-Upgrade ----------

func _drive_upgrades() -> void:
	# Mejora generadores y estaciones de menor nivel cuando hay coins de sobra.
	var candidates: Array = []
	for g in get_tree().get_nodes_in_group("generators"):
		if g != null and "current_level" in g and "upgrade_cost" in g:
			if g.current_level < ResourceGenerator.MAX_LEVEL:
				candidates.append(g)
	for ws in get_tree().get_nodes_in_group("workstations"):
		if ws is Workstation and ws.current_level < Workstation.MAX_LEVEL:
			candidates.append(ws)
	candidates.sort_custom(func(a, b): return a.upgrade_cost < b.upgrade_cost)
	for c in candidates:
		var reserve: float = c.upgrade_cost * UPGRADE_RESERVE_RATIO
		if InventoryManager.arcane_coins >= reserve:
			c.try_upgrade()
			return  # uno por tick para no quemar coins de golpe


# ---------- Auto-Buy Workers ----------

func _drive_worker_purchase() -> void:
	# Si hay muchos pedidos esperando, comprar más ayudantes (capacity).
	var active: int = OrderManager.get_active_count()
	if active < 2:
		return
	# Comprar el ayudante más barato si tenemos coins de sobra.
	var types: Array = [GameEnums.WorkerType.DUENDE, GameEnums.WorkerType.GOLEM, GameEnums.WorkerType.APPRENTICE]
	types.sort_custom(func(a, b): return ShopManager.get_price(a) < ShopManager.get_price(b))
	for t in types:
		var price: int = ShopManager.get_price(t)
		if InventoryManager.arcane_coins >= price + WORKER_AUTO_BUY_RESERVE:
			ShopManager.try_buy(t)
			return


# ---------- Public toggles ----------

func set_auto(key: StringName, on: bool) -> void:
	match key:
		&"craft": auto_craft = on
		&"research": auto_research = on
		&"upgrade": auto_upgrade = on
		&"buy_workers": auto_buy_workers = on
		&"orders": auto_orders = on
	automation_toggled.emit(key, on)


func get_auto(key: StringName) -> bool:
	match key:
		&"craft": return auto_craft
		&"research": return auto_research
		&"upgrade": return auto_upgrade
		&"buy_workers": return auto_buy_workers
		&"orders": return auto_orders
		_: return false


func get_save_state() -> Dictionary:
	return {
		"craft": auto_craft,
		"research": auto_research,
		"upgrade": auto_upgrade,
		"buy_workers": auto_buy_workers,
		"orders": auto_orders,
	}


func load_save_state(data: Dictionary) -> void:
	auto_craft = data.get("craft", true)
	auto_research = data.get("research", true)
	auto_upgrade = data.get("upgrade", true)
	auto_buy_workers = data.get("buy_workers", false)
	auto_orders = data.get("orders", true)
