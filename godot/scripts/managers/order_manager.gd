extends Node
## Permite hasta MAX_ACTIVE_ORDERS pedidos activos. Cada pedido tiene su propio
## cliente NPC. La UI elige cuál entregar (por defecto el primero entregable).

signal order_generated(order: OrderData)
signal order_completed(order: OrderData)
signal order_expired(order: OrderData)
signal customer_arrived(customer)
signal queue_changed

const BASE_CAPACITY: int = 3
## ponytail: capacidad = base + sillas colocadas. Mantengo `MAX_ACTIVE_ORDERS` como compat
## por si algún consumer lo lee directo (HUD, etc.); ahora apunta a _get_capacity().
const MAX_ACTIVE_ORDERS: int = 3  # deprecated, lee `get_capacity()`

class ActiveOrder:
	var data: OrderData
	var customer: Node = null
	var counter_slot: int = -1
	var chair: Node = null  ## CustomerChair asignada (null = espera en counter slot)
	var completed: bool = false  ## guard contra doble entrega mientras el cliente camina al exit


var _possible_orders: Array[OrderData] = []
var _active: Array[ActiveOrder] = []

# Wired by game_bootstrap at scene load.
var customer_scene: PackedScene = null
var spawn_point: Node2D = null
var counter_point: Node2D = null
var exit_point: Node2D = null

@export var auto_generate: bool = true
@export var time_between_orders: float = 8.0
var _timer: float = 0.0


func set_catalog(catalog: Array[OrderData]) -> void:
	_possible_orders = catalog.duplicate()


func _process(delta: float) -> void:
	if not auto_generate or _possible_orders.is_empty():
		return
	if _active.size() >= get_capacity():
		return
	_timer += delta
	if _timer >= time_between_orders:
		_timer = 0.0
		generate_new_order()


func get_capacity() -> int:
	return BASE_CAPACITY + get_tree().get_nodes_in_group("customer_chairs").size()


func _find_free_chair() -> Node:
	for c in get_tree().get_nodes_in_group("customer_chairs"):
		if is_instance_valid(c) and not c.occupied:
			return c
	return null


const PROCEDURAL_CHANCE: float = 0.4  ## 40% de las órdenes son generadas al vuelo

func generate_new_order() -> OrderData:
	if _active.size() >= get_capacity():
		return null
	var order_data: OrderData = null
	# ponytail: 40% procedurales si hay recetas unlocked, 60% catálogo fijo.
	# Si no hay catálogo Y no hay recetas, no spawnea nada.
	if randf() < PROCEDURAL_CHANCE:
		order_data = _make_procedural_order()
	if order_data == null:
		# Filtrar catálogo por reputación actual.
		var eligible: Array[OrderData] = []
		var rep: int = InventoryManager.reputation
		for o in _possible_orders:
			if o != null and o.min_reputation <= rep:
				eligible.append(o)
		if not eligible.is_empty():
			order_data = eligible.pick_random()
	if order_data == null:
		return null
	var entry := ActiveOrder.new()
	entry.data = order_data
	entry.counter_slot = _next_free_slot()
	_active.append(entry)
	_spawn_customer_for(entry)
	order_generated.emit(order_data)
	queue_changed.emit()
	print("[Order] New: %d x %s (slot %d)" % [order_data.requested_quantity, order_data.requested_item.display_name, entry.counter_slot])
	return order_data


func _next_free_slot() -> int:
	var used: Array[int] = []
	for a in _active:
		used.append(a.counter_slot)
	for i in MAX_ACTIVE_ORDERS:
		if not used.has(i):
			return i
	return 0


func _spawn_customer_for(entry: ActiveOrder) -> void:
	if customer_scene == null or spawn_point == null or counter_point == null or exit_point == null:
		return
	var c = customer_scene.instantiate()
	if c == null:
		return
	spawn_point.get_parent().add_child(c)
	c.global_position = spawn_point.global_position
	# ponytail: si hay silla libre, el cliente va a esa silla concreta; si no, slot del counter.
	var chair := _find_free_chair()
	var target_point: Node2D = counter_point
	var counter_offset := Vector2.ZERO
	if chair != null:
		chair.reserve()
		entry.chair = chair
		target_point = chair
	else:
		counter_offset = Vector2(0, (entry.counter_slot - 1) * 28.0)
	c.setup(entry.data, target_point, exit_point)
	c.set("counter_offset", counter_offset)
	c.arrived_at_counter.connect(_on_customer_arrived)
	c.left.connect(_on_customer_left.bind(entry))
	c.expired.connect(_on_customer_expired.bind(entry))
	entry.customer = c
	# ponytail: el cliente vive en Recepción — añadir al grupo recepcion_visual
	# para que solo se vea cuando el camera está en esa zona.
	c.add_to_group("recepcion_visual")
	var cam = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		c.visible = cam.get_current_zone().name == &"recepcion"


const HISTORY_LIMIT: int = 12
var _history: Array = []  # [{item_id, item_name, qty, coin, rep, personality, tier, delivered, ts}]


func _on_customer_arrived(customer) -> void:
	customer_arrived.emit(customer)


func _on_customer_expired(customer, entry: ActiveOrder) -> void:
	# Solo registramos como perdido si el customer realmente NO recibió su pedido.
	# entry.completed se setea ANTES de que el customer empiece a irse contento.
	if entry == null or entry.completed:
		return
	_record_history(entry, false)
	if _active.has(entry):
		order_expired.emit(entry.data)


func _record_history(entry: ActiveOrder, delivered: bool) -> void:
	if entry == null or entry.data == null or entry.data.requested_item == null:
		return
	var pers_id: String = "normal"
	if entry.customer != null and is_instance_valid(entry.customer) and "personality" in entry.customer:
		pers_id = String(entry.customer.personality.id)
	_history.push_front({
		"item_id": String(entry.data.requested_item.id),
		"item_name": entry.data.requested_item.display_name,
		"qty": entry.data.requested_quantity,
		"coin": entry.data.coin_reward,
		"rep": entry.data.reputation_reward,
		"personality": pers_id,
		"tier": entry.data.tier,
		"delivered": delivered,
		"ts": Time.get_unix_time_from_system(),
	})
	while _history.size() > HISTORY_LIMIT:
		_history.pop_back()


func get_history() -> Array:
	return _history.duplicate()


func _on_customer_left(_customer, entry: ActiveOrder) -> void:
	# El cliente llegó al exit point. Si la orden ya fue marcada como completed,
	# la entry ya fue removida en try_complete_at — esto es un no-op.
	if entry.chair != null and is_instance_valid(entry.chair):
		entry.chair.release()
		entry.chair = null
	if _active.has(entry):
		_active.erase(entry)
		queue_changed.emit()


func get_active_orders() -> Array:
	return _active.duplicate()


func get_active_count() -> int:
	return _active.size()


func get_current_order() -> OrderData:
	# Compat shim: devuelve la primera orden activa NO completada.
	for a in _active:
		if not a.completed and a.data != null:
			return a.data
	return null


func get_current_customer():
	for a in _active:
		if not a.completed and a.customer != null:
			return a.customer
	return null


func find_deliverable_order_index() -> int:
	# Devuelve el indice del order entregable de mayor tier (VIPs primero).
	# A igual tier, gana el primero en cola (orden de llegada).
	var best_idx: int = -1
	var best_tier: int = -1
	for i in _active.size():
		var a: ActiveOrder = _active[i]
		if a.completed:
			continue
		if a.data == null or a.data.requested_item == null:
			continue
		if InventoryManager.get_item_count(a.data.requested_item) < a.data.requested_quantity:
			continue
		if a.data.tier > best_tier:
			best_tier = a.data.tier
			best_idx = i
	return best_idx


func try_complete_at(index: int) -> bool:
	if index < 0 or index >= _active.size():
		return false
	var entry: ActiveOrder = _active[index]
	if entry.completed:
		return false  # ya entregada, esperando que el cliente salga
	var order: OrderData = entry.data
	if order == null:
		return false
	var needed: Array = [{"item": order.requested_item, "qty": order.requested_quantity}]
	# Marcar antes de consumir para que cualquier signal en cascada vea el estado correcto.
	entry.completed = true
	if not InventoryManager.consume_items(needed):
		entry.completed = false  # rollback: no había stock suficiente
		return false
	# Quitar de la cola activa inmediatamente — el cliente sigue caminando al exit
	# pero la orden ya no debe aparecer en get_active_orders/find_deliverable_order_index.
	_active.erase(entry)
	var coin_mult: float = EventManager.get_coin_multiplier()
	var rep_bonus: int = EventManager.get_rep_bonus()
	# ponytail: la personalidad del cliente stackea sobre el evento activo.
	var pers_coin: float = 1.0
	var pers_rep: float = 1.0
	if entry.customer != null and is_instance_valid(entry.customer) and entry.customer.has_method("get_coin_mult"):
		pers_coin = entry.customer.get_coin_mult()
		pers_rep = entry.customer.get_rep_mult()
	InventoryManager.add_coins(int(order.coin_reward * coin_mult * pers_coin))
	InventoryManager.add_reputation(int((order.reputation_reward + rep_bonus) * pers_rep))
	if entry.customer != null and is_instance_valid(entry.customer):
		_spawn_reaction_emoji(entry.customer.global_position, "♥", Color(1.0, 0.45, 0.55))
		entry.customer.leave()
	if counter_point != null:
		VFXManager.play(VFXManager.FX.COINS, counter_point.global_position)
	AudioManager.play_named(&"order_complete")
	# ponytail: queue_changed primero para que _refresh_all del HUD pinte el siguiente
	# pedido (o "Order: —") ANTES de que _on_order_completed muestre "✓ entregada".
	# Invertido causaba que el feedback de entrega se borrara en el mismo frame.
	_record_history(entry, true)
	queue_changed.emit()
	order_completed.emit(order)
	print("[Order] Completed → +%d coins (queue=%d)" % [order.coin_reward, _active.size()])
	return true


func try_complete_current() -> bool:
	# Compat shim: intenta entregar el primer pedido entregable.
	var idx: int = find_deliverable_order_index()
	if idx == -1:
		return false
	return try_complete_at(idx)


func reset_for_prestige() -> void:
	# Despawn cualquier cliente activo y limpia la cola.
	for entry in _active:
		if entry.customer != null and is_instance_valid(entry.customer):
			entry.customer.queue_free()
		if entry.chair != null and is_instance_valid(entry.chair):
			entry.chair.release()
	_active.clear()
	_timer = 0.0
	queue_changed.emit()


func expire_order(entry: ActiveOrder) -> void:
	if entry == null or not _active.has(entry):
		return
	order_expired.emit(entry.data)
	if entry.customer != null and is_instance_valid(entry.customer):
		entry.customer.leave()


func _make_procedural_order() -> OrderData:
	# ponytail: construye OrderData al vuelo desde una receta unlocked.
	# qty 1-3 (los tiers altos pesan menos para no romper economía).
	var recipes: Array[RecipeData] = RecipeManager.get_unlocked_recipes()
	var pool: Array = []
	for r in recipes:
		if r == null or r.output_item == null:
			continue
		pool.append(r.output_item)
	if pool.is_empty():
		return null
	var item: ItemData = pool.pick_random()
	var tier: int = max(1, item.tier)
	var max_qty: int = max(1, 4 - tier)
	var qty: int = randi() % max_qty + 1
	var data := OrderData.new()
	data.id = StringName("proc_%d_%s" % [Time.get_ticks_msec(), item.id])
	data.display_name = "Pedido espontáneo: %s" % item.display_name
	data.requested_item = item
	data.requested_quantity = qty
	data.tier = tier
	data.coin_reward = int(item.base_value * qty * (1.0 + tier * 0.3))
	data.reputation_reward = max(1, tier)
	data.time_limit = 0.0
	data.min_reputation = 0
	return data


func get_save_state() -> Dictionary:
	# Persiste timer + cada activa. Los clientes (nodos en escena) NO se serializan:
	# al cargar se respawnean desde spawn_point como recién llegados. Esto pierde
	# su posición de caminata pero conserva la orden y los rewards intactos.
	var active: Array = []
	for a in _active:
		if a == null or a.data == null:
			continue
		var item_id: String = ""
		if a.data.requested_item != null:
			item_id = String(a.data.requested_item.id)
		var is_proc: bool = String(a.data.id).begins_with("proc_")
		var entry := {
			"id": String(a.data.id),
			"slot": a.counter_slot,
			"completed": a.completed,
			"is_procedural": is_proc,
		}
		if is_proc:
			entry["item_id"] = item_id
			entry["display_name"] = a.data.display_name
			entry["qty"] = a.data.requested_quantity
			entry["coin"] = a.data.coin_reward
			entry["rep"] = a.data.reputation_reward
			entry["tier"] = a.data.tier
			entry["time_limit"] = a.data.time_limit
			entry["min_rep"] = a.data.min_reputation
		active.append(entry)
	return {"timer": _timer, "active": active, "history": _history.duplicate()}


func load_save_state(data: Dictionary) -> void:
	# Limpiar estado actual (clientes residuales + entradas) antes de restaurar.
	for entry in _active:
		if entry.customer != null and is_instance_valid(entry.customer):
			entry.customer.queue_free()
		if entry.chair != null and is_instance_valid(entry.chair):
			entry.chair.release()
	_active.clear()
	_timer = float(data.get("timer", 0.0))
	_history = data.get("history", []).duplicate()
	for entry in data.get("active", []):
		var order_data: OrderData = null
		if bool(entry.get("is_procedural", false)):
			order_data = _rebuild_procedural(entry)
		else:
			var oid := StringName(entry.get("id", ""))
			for o in _possible_orders:
				if o != null and o.id == oid:
					order_data = o
					break
		if order_data == null:
			continue
		var ao := ActiveOrder.new()
		ao.data = order_data
		ao.counter_slot = int(entry.get("slot", _next_free_slot()))
		ao.completed = bool(entry.get("completed", false))
		_active.append(ao)
		# Respawnear cliente solo si la pipeline ya fue cableada y no estaba completed.
		if not ao.completed and customer_scene != null and spawn_point != null:
			_spawn_customer_for(ao)
	queue_changed.emit()


func _rebuild_procedural(entry: Dictionary) -> OrderData:
	var item_id := StringName(entry.get("item_id", ""))
	var item: ItemData = _find_item_by_id(item_id)
	if item == null:
		return null
	var d := OrderData.new()
	d.id = StringName(entry.get("id", ""))
	d.display_name = entry.get("display_name", "")
	d.requested_item = item
	d.requested_quantity = int(entry.get("qty", 1))
	d.coin_reward = int(entry.get("coin", 0))
	d.reputation_reward = int(entry.get("rep", 0))
	d.tier = int(entry.get("tier", 1))
	d.time_limit = float(entry.get("time_limit", 0.0))
	d.min_reputation = int(entry.get("min_rep", 0))
	return d


func _find_item_by_id(id: StringName) -> ItemData:
	for o in _possible_orders:
		if o != null and o.requested_item != null and o.requested_item.id == id:
			return o.requested_item
	for r in RecipeManager.get_all_recipes():
		if r == null:
			continue
		if r.output_item != null and r.output_item.id == id:
			return r.output_item
		for pair in r.get_ingredient_pairs():
			var ing: ItemData = pair.get("item")
			if ing != null and ing.id == id:
				return ing
	return null


func _spawn_reaction_emoji(world_pos: Vector2, emoji: String, color: Color) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var label := Label.new()
	label.text = emoji
	label.add_theme_font_size_override(&"font_size", 32)
	label.modulate = color
	label.z_index = 100
	label.position = world_pos + Vector2(-10, -52)
	scene.add_child(label)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 36, 1.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 1.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(label.queue_free)
