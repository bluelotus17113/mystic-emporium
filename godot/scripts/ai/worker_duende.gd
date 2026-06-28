extends WorkerBase
## Duende: especializado en hierbas (resource type HERB).


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.DUENDE
	preferred_resource_type = GameEnums.ResourceType.HERB
	move_speed = 90.0
