extends PanelContainer
## Bloc de notas persistido en user://notes.txt. Autoguardado al editar tras 1s.

const PANEL_NAME: StringName = &"notes"
const NOTES_PATH: String = "user://notes.txt"
const AUTOSAVE_DELAY: float = 1.0

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var save_button: Button = $Margin/VBox/Header/SaveButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var text_edit: TextEdit = $Margin/VBox/TextEdit

var _autosave_timer: float = -1.0


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	save_button.pressed.connect(_save_now)
	text_edit.text_changed.connect(_on_text_changed)
	_load_from_disk()


func _process(delta: float) -> void:
	if _autosave_timer >= 0.0:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_save_now()


func _on_text_changed() -> void:
	_autosave_timer = AUTOSAVE_DELAY
	status_label.text = "Editando…"


func _save_now() -> void:
	var file := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if file == null:
		status_label.text = "Error guardando."
		return
	file.store_string(text_edit.text)
	file.close()
	status_label.text = "Guardado ✓"
	_autosave_timer = -1.0


func _load_from_disk() -> void:
	if not FileAccess.file_exists(NOTES_PATH):
		return
	var file := FileAccess.open(NOTES_PATH, FileAccess.READ)
	if file == null:
		return
	text_edit.text = file.get_as_text()
	file.close()
