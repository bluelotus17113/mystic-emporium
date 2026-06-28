extends PanelContainer
## Lista de tareas persistida en user://todo.json.

const PANEL_NAME: StringName = &"todo"
const TODO_PATH: String = "user://todo.json"

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var add_input: LineEdit = $Margin/VBox/AddRow/AddInput
@onready var add_button: Button = $Margin/VBox/AddRow/AddButton
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var stats_label: Label = $Margin/VBox/StatsLabel

var tasks: Array = []  # Array of { "text": String, "done": bool }


func _ready() -> void:
	var standalone: bool = "--todo" in OS.get_cmdline_user_args()
	if standalone:
		close_button.pressed.connect(func(): get_tree().quit())
		get_tree().get_root().close_requested.connect(func(): get_tree().quit())
	else:
		UIManager.register_panel(PANEL_NAME, self)
		close_button.pressed.connect(UIManager.close_active)
	add_button.pressed.connect(_on_add)
	add_input.text_submitted.connect(func(_t): _on_add())
	_load()
	_rebuild()


func _on_add() -> void:
	var t: String = add_input.text.strip_edges()
	if t.is_empty():
		return
	tasks.append({"text": t, "done": false})
	add_input.text = ""
	_save()
	_rebuild()


func _rebuild() -> void:
	for child in list.get_children():
		child.queue_free()
	if tasks.is_empty():
		var empty := Label.new()
		empty.text = "(sin tareas)"
		empty.modulate = Color(0.7, 0.7, 0.7, 1)
		list.add_child(empty)
	else:
		for i in tasks.size():
			list.add_child(_build_row(i))
	_update_stats()


func _build_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var task: Dictionary = tasks[index]
	var check := CheckBox.new()
	check.button_pressed = task.done
	check.toggled.connect(_on_toggle.bind(index))
	row.add_child(check)

	var label := Label.new()
	label.text = task.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if task.done:
		label.modulate = Color(0.6, 0.6, 0.65, 1)
	row.add_child(label)

	var del := Button.new()
	del.text = "✕"
	del.pressed.connect(_on_delete.bind(index))
	row.add_child(del)
	return row


func _on_toggle(pressed: bool, index: int) -> void:
	if index < 0 or index >= tasks.size():
		return
	tasks[index]["done"] = pressed
	_save()
	_rebuild()


func _on_delete(index: int) -> void:
	if index < 0 or index >= tasks.size():
		return
	tasks.remove_at(index)
	_save()
	_rebuild()


func _update_stats() -> void:
	var done: int = 0
	for t in tasks:
		if t.done:
			done += 1
	stats_label.text = "%d / %d completadas" % [done, tasks.size()]


func _save() -> void:
	var file := FileAccess.open(TODO_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(tasks))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(TODO_PATH):
		return
	var file := FileAccess.open(TODO_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_ARRAY:
		tasks = parsed
