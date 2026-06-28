extends Node
## Enruta el ejecutable a una de varias "apps" según argumentos de línea de comandos.
## --pomodoro → ventana standalone del Pomodoro
## --todo     → ventana standalone del Todo
## (ningún arg) → juego principal

const GAME_SCENE: String = "res://scenes/world/main_game.tscn"
const POMODORO_SCENE: String = "res://scenes/standalone/pomodoro_app.tscn"
const TODO_SCENE: String = "res://scenes/standalone/todo_app.tscn"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: String = GAME_SCENE
	var win_title: String = "Mystic Emporium Automata"
	var win_size: Vector2i = Vector2i(1280, 720)
	for a in args:
		if a == "--pomodoro":
			target = POMODORO_SCENE
			win_title = "Pomodoro"
			win_size = Vector2i(360, 340)
		elif a == "--todo":
			target = TODO_SCENE
			win_title = "Tareas"
			win_size = Vector2i(440, 460)
	if target != GAME_SCENE:
		DisplayServer.window_set_title(win_title)
		DisplayServer.window_set_size(win_size)
		DisplayServer.window_set_min_size(Vector2i(280, 240))
	get_tree().change_scene_to_file.call_deferred(target)
