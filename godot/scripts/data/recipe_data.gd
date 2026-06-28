@tool
class_name RecipeData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Ingredients & Output")
@export var ingredients: Array[ItemData] = []
@export var ingredient_quantities: Array[int] = []
@export var output_item: ItemData
@export var output_quantity: int = 1

@export_group("Crafting")
@export var crafting_time: float = 5.0
@export var required_station_type: GameEnums.StationType = GameEnums.StationType.CAULDRON
@export var unlocked_by_default: bool = false
@export_range(1, 5) var tier: int = 1


func get_ingredient_pairs() -> Array:
	var pairs: Array = []
	var n: int = min(ingredients.size(), ingredient_quantities.size())
	for i in n:
		pairs.append({"item": ingredients[i], "qty": ingredient_quantities[i]})
	return pairs
