extends Node
## Maneja la compra de nuevos ayudantes. La escena raíz (main_game) los engancha
## proveyendo el contenedor en el que aparecen y los PackedScene de cada tipo.

signal worker_purchased(worker_type: int, instance)
signal purchase_failed(reason: String)

const DEFAULT_PRICES: Dictionary = {
	GameEnums.WorkerType.DUENDE: 60,
	GameEnums.WorkerType.GOLEM: 120,
	GameEnums.WorkerType.APPRENTICE: 100,
	GameEnums.WorkerType.LENADOR: 180,
	GameEnums.WorkerType.ESPIRITU: 450,
}

var prices: Dictionary = DEFAULT_PRICES.duplicate()
var worker_scenes: Dictionary = {}  # WorkerType -> PackedScene
var spawn_container: Node = null
var spawn_position_provider: Callable = Callable()


func _ready() -> void:
	pass


func register_worker_scene(worker_type: int, scene: PackedScene) -> void:
	worker_scenes[worker_type] = scene


func get_price(worker_type: int) -> int:
	return prices.get(worker_type, 999999)


func try_buy(worker_type: int) -> void:
	print("[Shop] try_buy called for type=%d. scenes registered=%d, container=%s, coins=%d, price=%d" % [
		worker_type, worker_scenes.size(), str(spawn_container), InventoryManager.arcane_coins, get_price(worker_type)
	])
	if not worker_scenes.has(worker_type):
		purchase_failed.emit("No hay escena registrada para ese tipo.")
		print("[Shop] FAIL: scene not registered for type %d" % worker_type)
		return
	if spawn_container == null:
		purchase_failed.emit("No hay contenedor configurado.")
		print("[Shop] FAIL: spawn_container is null")
		return
	var cost: int = get_price(worker_type)
	if InventoryManager.arcane_coins < cost:
		purchase_failed.emit("Coins insuficientes (necesitas %d ⚜)." % cost)
		print("[Shop] FAIL: not enough coins")
		return
	if not InventoryManager.spend_coins(cost):
		purchase_failed.emit("No se pudo descontar coins.")
		print("[Shop] FAIL: spend_coins returned false")
		return

	var scene: PackedScene = worker_scenes[worker_type]
	# Defensa: si el load del PackedScene falló (ej. sprites sin .import generado),
	# el valor es null. instantiate() sobre null crashea el juego, así que abortamos.
	if scene == null:
		purchase_failed.emit("Escena del worker no se pudo cargar. Reiniciá Godot.")
		# Reembolsar las coins porque ya las gastamos arriba.
		InventoryManager.add_coins(cost)
		print("[Shop] FAIL: scene is null for type %d (load failed)" % worker_type)
		return
	var instance = scene.instantiate()
	if instance == null:
		purchase_failed.emit("No se pudo instanciar el worker.")
		InventoryManager.add_coins(cost)
		print("[Shop] FAIL: instantiate returned null for type %d" % worker_type)
		return
	spawn_container.add_child(instance)
	if spawn_position_provider.is_valid():
		instance.global_position = spawn_position_provider.call()

	var name_str: String = NameGenerator.random_for_type(worker_type)
	# Increase price for next purchase
	prices[worker_type] = int(cost * 1.4)
	worker_purchased.emit(worker_type, instance)
	print("[Shop] +%s (%s) por %d ⚜" % [_type_name(worker_type), name_str, cost])


func _type_name(worker_type: int) -> String:
	match worker_type:
		GameEnums.WorkerType.DUENDE: return "Duende"
		GameEnums.WorkerType.GOLEM: return "Gólem"
		GameEnums.WorkerType.APPRENTICE: return "Aprendiz"
		GameEnums.WorkerType.LENADOR: return "Leñador"
		GameEnums.WorkerType.ESPIRITU: return "Espíritu"
		_: return "Ayudante"


func get_save_state() -> Dictionary:
	# Precios serializados como dict con keys string (JSON no acepta int keys).
	var price_save: Dictionary = {}
	for k in prices.keys():
		price_save[str(k)] = int(prices[k])
	var workers: Array = []
	for w in get_tree().get_nodes_in_group("workers"):
		if not is_instance_valid(w):
			continue
		workers.append({
			"type": int(w.worker_type),
			"x": w.global_position.x,
			"y": w.global_position.y,
			# Identidad y progresión (nombre, nivel, XP, rasgo, energía).
			"state": w.get_save_dict() if w.has_method("get_save_dict") else {},
		})
	return {"prices": price_save, "workers": workers}


func load_save_state(data: Dictionary) -> void:
	# Restaurar precios escalados.
	var price_save: Dictionary = data.get("prices", {})
	for k in price_save.keys():
		prices[int(k)] = int(price_save[k])
	# Limpiar workers actuales (los del .tscn base) antes de respawnear los guardados.
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w):
			w.queue_free()
	if spawn_container == null:
		return
	for entry in data.get("workers", []):
		var wt: int = int(entry.get("type", 0))
		if not worker_scenes.has(wt):
			continue
		var inst = worker_scenes[wt].instantiate()
		spawn_container.add_child(inst)
		inst.global_position = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		# Restaura identidad/progresión DESPUÉS de add_child (su _ready ya sorteó
		# nombre/rasgo aleatorios; aquí los sobreescribimos con los guardados).
		if inst.has_method("apply_save_dict"):
			inst.apply_save_dict(entry.get("state", {}))
