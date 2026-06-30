@tool
class_name ResearchData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Requirements")
@export var prerequisites: Array[ResearchData] = []
@export var required_station_type: GameEnums.StationType = GameEnums.StationType.ARCANE_LIBRARY
@export var research_time: float = 30.0
@export var coin_cost: int = 100
## Materiales que se consumen al iniciar la investigación. Pares paralelos:
## required_item_ids[i] se consume en required_item_qty[i] unidades.
@export var required_item_ids: PackedStringArray = PackedStringArray()
@export var required_item_qty: PackedInt32Array = PackedInt32Array()

@export_group("Rewards")
@export var recipe_to_unlock: RecipeData
## Recetas extra desbloqueadas al completar (para que una investigación agrupe
## varias recetas temáticamente, p.ej. "Encantamiento Maestro" → 3 amuletos T4).
@export var extra_recipes_to_unlock: Array[RecipeData] = []
@export var buildable_to_unlock: BuildableData
@export_range(1, 5) var tier: int = 1
