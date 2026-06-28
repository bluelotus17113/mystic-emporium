extends WorkerBase
## Golem: especializado en minerales (cristales, hierro).


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.GOLEM
	preferred_resource_type = GameEnums.ResourceType.CRYSTAL
	move_speed = 60.0
