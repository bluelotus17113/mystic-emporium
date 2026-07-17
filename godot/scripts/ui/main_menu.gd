extends Control

const MAIN_GAME_SCENE: String = "res://scenes/world/main_game.tscn"

@onready var continue_button: Button = $CenterRoot/VBox/ContinueButton
@onready var continue_info: Label = $CenterRoot/VBox/ContinueInfo
@onready var new_game_button: Button = $CenterRoot/VBox/NewGameButton
@onready var quit_button: Button = $CenterRoot/VBox/QuitButton


func _ready() -> void:
	SaveManager.mark_world_ready(false)
	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	quit_button.pressed.connect(_on_quit)
	_refresh_continue_info()


func _refresh_continue_info() -> void:
	if not SaveManager.has_save():
		continue_info.text = "—  sin partida guardada"
		return
	# ponytail: usamos los metadata del save para previsualizar el run sin cargarlo.
	var meta: Dictionary = SaveManager.get_slot_metadata(SaveManager.current_slot)
	if not meta.get("exists", false):
		continue_info.text = "—"
		return
	continue_info.text = "Día %d  ·  %s ⚜  ·  %s ★" % [
		int(meta.get("day", 1)),
		NumFormat.short(int(meta.get("coins", 0))),
		NumFormat.short(int(meta.get("reputation", 0))),
	]


func _on_continue() -> void:
	# Diferimos la carga: game_bootstrap consume pending_load_slot al final
	# de su _ready, cuando la escena main_game ya existe y los managers están
	# cableados. Cargar aquí adjuntaba los buildings al main_menu (escena que
	# muere en el siguiente frame).
	SaveManager.pending_load_slot = SaveManager.current_slot
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)


func _on_new_game() -> void:
	# ponytail: confirmación si ya hay save (evita sobrescribirlo por mistake).
	if not SaveManager.has_save():
		_start_new()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nueva partida"
	dialog.dialog_text = "Esto borrará tu partida guardada. ¿Continuar?"
	dialog.ok_button_text = "Sí, nueva partida"
	dialog.cancel_button_text = "Cancelar"
	add_child(dialog)
	dialog.confirmed.connect(_start_new)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _start_new() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file(MAIN_GAME_SCENE)


func _on_quit() -> void:
	get_tree().quit()
