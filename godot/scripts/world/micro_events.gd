class_name MicroEvents
extends Node
## Pequeños sucesos cozy aleatorios que dan variedad y sorpresa amable.
## Ninguno castiga: monedas encontradas, propina, el gato trae un regalo.

var _timer: float = 40.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(55.0, 110.0)
	_fire()


func _fire() -> void:
	match randi() % 3:
		0:
			_coin_find()
		1:
			_cat_gift()
		_:
			_tip()


func _coin_find() -> void:
	var amount: int = randi_range(3, 9)
	InventoryManager.add_coins(amount)
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if proto != null:
		FloatingText.spawn(proto, "🪙 +%d" % amount, Color(1.0, 0.86, 0.36))
	NotificationManager.post("Encontraste %d⚜ en el suelo ✨" % amount, NotificationManager.Kind.INFO)


func _cat_gift() -> void:
	var cat: Node2D = get_tree().get_first_node_in_group("pets")
	var amount: int = randi_range(5, 14)
	InventoryManager.add_coins(amount)
	if cat != null:
		FloatingText.spawn(cat, "🎁 +%d" % amount, Color(1.0, 0.7, 0.8))
	NotificationManager.post("El gato te trajo un regalito (+%d⚜) 😽" % amount, NotificationManager.Kind.REWARD)


func _tip() -> void:
	var amount: int = randi_range(4, 12)
	InventoryManager.add_coins(amount)
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if proto != null:
		FloatingText.spawn(proto, "♥ +%d" % amount, Color(1.0, 0.55, 0.65))
	NotificationManager.post("Un cliente contento dejó propina (+%d⚜) ♥" % amount, NotificationManager.Kind.INFO)
