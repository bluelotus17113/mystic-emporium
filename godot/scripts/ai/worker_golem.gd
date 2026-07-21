extends WorkerBase
## Golem: especializado en minerales (cristal de cuarzo y mena de hierro).


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.GOLEM
	preferred_resource_types = [
		GameEnums.ResourceType.CRYSTAL,
		GameEnums.ResourceType.IRON_ORE,
	]
	move_speed = 60.0
