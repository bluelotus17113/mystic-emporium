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

@export_group("Rewards")
@export var recipe_to_unlock: RecipeData
@export var buildable_to_unlock: BuildableData
@export_range(1, 5) var tier: int = 1
