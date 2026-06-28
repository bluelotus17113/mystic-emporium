class_name StorageChest
extends Node2D
## Edificio que aumenta la capacidad del inventario central al construirse.

@export var capacity_bonus: int = 100


func _ready() -> void:
	add_to_group("storage")
	InventoryManager.max_capacity += capacity_bonus
	print("[Storage] +%d capacidad (total: %d)" % [capacity_bonus, InventoryManager.max_capacity])


func _exit_tree() -> void:
	# Avoid de-bonus during scene tear-down (game closing). Only refund if game is running.
	# SceneTree no tiene is_inside_tree(); usamos current_scene como proxy de "app viva".
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	InventoryManager.max_capacity = max(50, InventoryManager.max_capacity - capacity_bonus)
