extends CanvasLayer
## Menú de pausa flotante. Activado con tecla `ui_pause` (Esc por defecto).
## Detiene la simulación con get_tree().paused = true.

@onready var panel: PanelContainer = $Panel
@onready var run_info: Label = $Panel/Margin/VBox/RunInfo
@onready var resume_button: Button = $Panel/Margin/VBox/ResumeButton
@onready var save_button: Button = $Panel/Margin/VBox/SaveButton
@onready var menu_button: Button = $Panel/Margin/VBox/MenuButton
@onready var quit_button: Button = $Panel/Margin/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(resume)
	save_button.pressed.connect(_on_save)
	menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)


func _refresh_run_info() -> void:
	run_info.text = "Día %d  ·  %s ⚜  ·  %s ★" % [
		CalendarManager.current_day,
		NumFormat.short(InventoryManager.arcane_coins),
		NumFormat.short(InventoryManager.reputation),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle()


func toggle() -> void:
	if visible:
		resume()
	else:
		pause()


func pause() -> void:
	_refresh_run_info()
	show()
	get_tree().paused = true


func resume() -> void:
	hide()
	get_tree().paused = false


func _on_save() -> void:
	SaveManager.save_game()
	NotificationManager.post("Partida guardada en slot %d" % SaveManager.current_slot, NotificationManager.Kind.SUCCESS)


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()
