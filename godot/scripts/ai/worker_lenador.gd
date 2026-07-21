extends WorkerBase
## Leñador: especializado en madera arcana (raw del Patio Natural).
## La mena de hierro es tarea del Gólem (minerales).


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.LENADOR
	preferred_resource_types = [
		GameEnums.ResourceType.ARCANE_WOOD,
	]
	move_speed = 80.0
