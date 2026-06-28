@tool
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var category: GameEnums.ItemCategory = GameEnums.ItemCategory.PRIMARY
@export var base_value: int = 1
@export_range(1, 5) var tier: int = 1  ## 1-5: filtra qué se desbloquea por progresión
