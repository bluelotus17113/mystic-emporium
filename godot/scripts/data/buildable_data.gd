@tool
class_name BuildableData
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Build")
@export var scene: PackedScene
@export var cost: int = 50
@export var allowed_zone: GameEnums.ZoneType = GameEnums.ZoneType.WORKSHOP
@export var size: Vector2i = Vector2i(1, 1)
@export var unlocked_by_default: bool = false
@export var is_decorative: bool = false
## Sub-categoría dentro del tab Decoración: "wall" / "floor" / "table" / "nature"
@export var decoration_category: StringName = &""
## Si > 0, se desbloquea cuando el Patio Natural alcanza este nivel.
## Aplica encima de unlocked_by_default (false + min_natural_level=2 = unlock al lvl 2).
@export var min_natural_level: int = 0
## Si no está vacío, es un objeto creado por el jugador (Abracadabra). La escena
## colocada lee su textura desde CustomObjectManager por este id.
@export var custom_id: StringName = &""
