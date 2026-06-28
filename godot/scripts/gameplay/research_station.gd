class_name ResearchStation
extends Node2D
## Estación que el Aprendiz usa para hacer progresar la investigación activa
## del ResearchManager. La diferencia con Workstation es que no consume
## ingredientes — solo "trabajo" del Aprendiz acumulado en el tiempo.

@export var station_type: GameEnums.StationType = GameEnums.StationType.ARCANE_LIBRARY


func _ready() -> void:
	add_to_group("research_stations")
	add_to_group("workstations")  # también para que WorkstationManager.get_closest_idle pueda usarse
	WorkstationManager.register(self)
	var area: Area2D = get_node_or_null("Area2D") as Area2D
	if area != null:
		area.input_event.connect(_on_area_input_event)


func _exit_tree() -> void:
	WorkstationManager.unregister(self)


func is_ready_to_work() -> bool:
	# Una ResearchStation siempre está "lista"; el cuello de botella es
	# si el ResearchManager tiene una investigación activa.
	return ResearchManager.get_active() != null


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ResearchManager.station_clicked.emit(self)
