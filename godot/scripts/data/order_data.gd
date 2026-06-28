@tool
class_name OrderData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var requested_item: ItemData
@export var requested_quantity: int = 1
@export var coin_reward: int = 25
@export var reputation_reward: int = 1
@export var time_limit: float = 0.0  ## 0 = sin limite
@export_range(1, 5) var tier: int = 1
@export var min_reputation: int = 0  ## solo aparece si InventoryManager.reputation >= este valor
