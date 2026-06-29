extends WorkerBase
## Leñador: especializado en madera arcana y mena de hierro (raws de Patio Natural).


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.LENADOR
	preferred_resource_types = [
		GameEnums.ResourceType.ARCANE_WOOD,
		GameEnums.ResourceType.IRON_ORE,
	]
	move_speed = 80.0
