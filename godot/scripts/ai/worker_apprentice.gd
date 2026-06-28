extends WorkerBase
## Aprendiz: investiga en estaciones del tipo ARCANE_LIBRARY / ASTRO_OBSERVATORY.

@export var preferred_station_type: GameEnums.StationType = GameEnums.StationType.ARCANE_LIBRARY

const RESEARCH_TICK_INTERVAL: float = 0.5
var _research_tick: float = 0.0


func _ready() -> void:
	super()
	worker_type = GameEnums.WorkerType.APPRENTICE
	preferred_resource_type = GameEnums.ResourceType.NONE
	move_speed = 75.0


func _on_idle(delta: float) -> void:
	if ResearchManager.get_active() == null:
		# nothing to do — wander suave para no congelarse junto al spawn.
		_wander(delta)
		return
	target = WorkstationManager.get_closest_idle(global_position, preferred_station_type)
	if target != null:
		_change_state(GameEnums.WorkerState.FETCHING)
	else:
		_wander(delta)


func _on_arrived_at_target() -> void:
	if target == null:
		_change_state(GameEnums.WorkerState.IDLE)
		return
	_change_state(GameEnums.WorkerState.WORKING)
	_action_timer = INF  # we stop manually based on research progress
	_research_tick = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if state == GameEnums.WorkerState.WORKING:
		_research_tick += delta
		if _research_tick >= RESEARCH_TICK_INTERVAL:
			ResearchManager.add_progress(_research_tick)
			_research_tick = 0.0
		if ResearchManager.get_active() == null:
			_change_state(GameEnums.WorkerState.IDLE)
