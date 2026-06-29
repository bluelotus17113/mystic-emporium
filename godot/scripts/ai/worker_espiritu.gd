extends WorkerBase
## Espíritu: recoge materiales raros (agua arcana, polvo lunar, amatista,
## esencia espiritual, lingote de hierro). Pensado para mid/end-game.


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.ESPIRITU
	preferred_resource_types = [
		GameEnums.ResourceType.ARCANE_WATER,
		GameEnums.ResourceType.MOON_DUST,
		GameEnums.ResourceType.AMETHYST_FRAGMENT,
		GameEnums.ResourceType.SPIRIT_ESSENCE,
		GameEnums.ResourceType.IRON_INGOT,
	]
	move_speed = 95.0
