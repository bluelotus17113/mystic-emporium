extends PanelContainer
## Pequeño indicador que aparece cuando hay un evento activo del EventManager.
## Muestra el nombre + barra de tiempo restante.

@onready var label: Label = $HBox/Label
@onready var bar: ProgressBar = $HBox/Bar


func _ready() -> void:
	hide()
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_ended.connect(_on_event_ended)


func _process(_delta: float) -> void:
	if not visible:
		return
	var def_id: StringName = EventManager.get_active_event_id()
	if def_id == &"":
		hide()
		return
	var total: float = EventManager.EVENT_DEFINITIONS.values().filter(
		func(d): return d.id == def_id
	)[0].duration
	var remaining: float = EventManager.get_active_remaining()
	bar.value = (remaining / total) * 100.0


func _on_event_started(_id: StringName, lbl: String) -> void:
	label.text = "🌟 " + lbl
	bar.value = 100.0
	show()


func _on_event_ended(_id: StringName) -> void:
	hide()
