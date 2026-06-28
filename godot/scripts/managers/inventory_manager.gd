extends Node

signal coins_changed(new_amount: int)
signal item_changed(item: ItemData, new_quantity: int)
signal inventory_full(item: ItemData)
signal reputation_changed(new_amount: int)

const STARTING_COINS: int = 50

var arcane_coins: int = STARTING_COINS:
	set(value):
		var clamped: int = max(0, value)
		if clamped == arcane_coins:
			return
		arcane_coins = clamped
		coins_changed.emit(arcane_coins)

var reputation: int = 0:
	set(value):
		var clamped: int = max(0, value)
		if clamped == reputation:
			return
		reputation = clamped
		reputation_changed.emit(reputation)

## item id (StringName) -> quantity
var items: Dictionary = {}
## item id -> ItemData (cache for lookups)
var item_lookup: Dictionary = {}

var max_capacity: int = 200

# Cache para evitar O(n) en cada get_total_count()
var _cached_total: int = 0
var _cache_dirty: bool = true


func _ready() -> void:
	coins_changed.emit(arcane_coins)
	reputation_changed.emit(reputation)


func add_reputation(amount: int) -> void:
	reputation += amount


func add_item(item: ItemData, qty: int = 1) -> bool:
	if item == null or qty <= 0:
		return false
	var current_total: int = get_total_count()
	if current_total + qty > max_capacity:
		inventory_full.emit(item)
		return false
	var new_qty: int = items.get(item.id, 0) + qty
	items[item.id] = new_qty
	item_lookup[item.id] = item
	_cached_total += qty
	item_changed.emit(item, new_qty)
	return true


func remove_item(item: ItemData, qty: int = 1) -> bool:
	if item == null or qty <= 0:
		return false
	var have: int = items.get(item.id, 0)
	if have < qty:
		return false
	var new_qty: int = have - qty
	if new_qty == 0:
		items.erase(item.id)
	else:
		items[item.id] = new_qty
	_cached_total -= qty
	item_changed.emit(item, new_qty)
	return true


func get_item_count(item: ItemData) -> int:
	if item == null:
		return 0
	return items.get(item.id, 0)


## Vende qty unidades de un ítem por su base_value. Devuelve coins ganadas (0 si falla).
func sell_item(item: ItemData, qty: int = 1) -> int:
	if item == null or qty <= 0:
		return 0
	var have: int = items.get(item.id, 0)
	if have <= 0:
		return 0
	qty = min(qty, have)
	if not remove_item(item, qty):
		return 0
	var gain: int = item.base_value * qty
	add_coins(gain)
	return gain


## Vende todo el inventario por base_value. Devuelve coins totales ganadas.
func sell_all() -> int:
	var total: int = 0
	for id in items.keys().duplicate():
		var qty: int = items[id]
		var item: ItemData = item_lookup.get(id)
		if item == null or qty <= 0:
			continue
		total += sell_item(item, qty)
	return total


func has_items(required: Array) -> bool:
	for pair in required:
		var needed_item: ItemData = pair.get("item")
		var needed_qty: int = pair.get("qty", 0)
		if needed_item == null or get_item_count(needed_item) < needed_qty:
			return false
	return true


func consume_items(required: Array) -> bool:
	if not has_items(required):
		return false
	for pair in required:
		remove_item(pair.item, pair.qty)
	return true


func get_total_count() -> int:
	if _cache_dirty:
		var total: int = 0
		for qty in items.values():
			total += qty
		_cached_total = total
		_cache_dirty = false
	return _cached_total


func add_coins(amount: int) -> void:
	# ponytail: el multiplicador de prestigio aplica solo a GANANCIA, no a gasto.
	# Si en algún sitio se pasa amount negativo (refund), evitamos amplificarlo.
	if amount > 0:
		amount = int(amount * PrestigeManager.get_coin_multiplier())
		AudioManager.play_named(&"coin")
	arcane_coins += amount


func reset_for_prestige() -> void:
	arcane_coins = STARTING_COINS
	items.clear()
	_cache_dirty = true
	_cached_total = 0
	reputation = 0
	max_capacity = 200
	coins_changed.emit(arcane_coins)
	reputation_changed.emit(reputation)


func spend_coins(amount: int) -> bool:
	if amount <= 0 or arcane_coins < amount:
		return false
	arcane_coins -= amount
	return true


func get_save_state() -> Dictionary:
	return {
		"arcane_coins": arcane_coins,
		"items": items.duplicate(),
		"max_capacity": max_capacity,
		"reputation": reputation,
	}


func load_save_state(data: Dictionary) -> void:
	arcane_coins = data.get("arcane_coins", STARTING_COINS)
	items = data.get("items", {}).duplicate()
	max_capacity = data.get("max_capacity", 200)
	reputation = data.get("reputation", 0)
	_cache_dirty = true
	# Note: item_lookup must be rebuilt by re-loading ItemData resources at boot.
	coins_changed.emit(arcane_coins)
	reputation_changed.emit(reputation)
