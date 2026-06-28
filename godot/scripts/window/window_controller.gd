extends Node
## Manages the desktop-companion mode using Godot 4's DisplayServer.
## In Unity this required P/Invoke; here it is cross-platform out of the box.

signal mode_changed(is_compact: bool)

const COMPACT_HEIGHT: int = 360
const COMPACT_PADDING: int = 4
const EXPANDED_SIZE: Vector2i = Vector2i(1280, 720)

var _is_compact: bool = false
var _previous_position: Vector2i = Vector2i.ZERO
var _previous_size: Vector2i = EXPANDED_SIZE
var _previous_aspect: int = Window.CONTENT_SCALE_ASPECT_KEEP
## Optional: nodes whose visibility we toggle when entering compact mode.
## Set externally by the game scene (HUD canvas, etc.).
## ponytail: tipo Node (no CanvasItem) porque CanvasLayer NO extiende CanvasItem,
## así que el cast `as CanvasItem` devolvía null y el HUD seguía visible.
var main_ui_nodes: Array[Node] = []
var companion_node: Node2D = null


func register_main_ui(node: Node) -> void:
	if node != null and not main_ui_nodes.has(node) and "visible" in node:
		main_ui_nodes.append(node)


func register_companion(node: Node2D) -> void:
	companion_node = node
	if node != null:
		node.visible = _is_compact


func _toggle_main_ui(show: bool) -> void:
	for n in main_ui_nodes:
		if is_instance_valid(n) and "visible" in n:
			n.set("visible", show)


func _ready() -> void:
	# Cache the initial windowed state so we can restore it.
	_previous_position = DisplayServer.window_get_position()
	_previous_size = DisplayServer.window_get_size()


func toggle_compact_mode() -> void:
	if _is_compact:
		exit_compact_mode()
	else:
		enter_compact_mode()


func enter_compact_mode() -> void:
	if _is_compact:
		return
	_previous_position = DisplayServer.window_get_position()
	_previous_size = DisplayServer.window_get_size()

	var screen_index: int = DisplayServer.window_get_current_screen()
	# ponytail: usable_rect excluye la taskbar de Windows y la barra de Linux/Mac.
	# screen_get_size() solía taparse parcialmente por la taskbar al hacer dock abajo.
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed", false):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

	var compact_w: int = usable.size.x - COMPACT_PADDING * 2
	DisplayServer.window_set_size(Vector2i(compact_w, COMPACT_HEIGHT))
	DisplayServer.window_set_position(Vector2i(
		usable.position.x + COMPACT_PADDING,
		usable.position.y + usable.size.y - COMPACT_HEIGHT - COMPACT_PADDING
	))

	# ponytail: el proyecto usa stretch/aspect=keep (16:9). En el dock 1920x140 eso
	# letterboxea todo el contenido a una franja minúscula al centro. Pasamos a EXPAND
	# para que la UI compact ocupe el ancho real, y restauramos al salir.
	var root: Window = get_tree().root
	_previous_aspect = root.content_scale_aspect
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	_is_compact = true
	_toggle_main_ui(false)
	if companion_node != null and is_instance_valid(companion_node):
		companion_node.visible = true
		companion_node.global_position = Vector2(compact_w * 0.5, COMPACT_HEIGHT - 36)
	mode_changed.emit(true)


func exit_compact_mode() -> void:
	if not _is_compact:
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_size(_previous_size)
	DisplayServer.window_set_position(_previous_position)
	get_tree().root.content_scale_aspect = _previous_aspect

	_is_compact = false
	_toggle_main_ui(true)
	if companion_node != null and is_instance_valid(companion_node):
		companion_node.visible = false
	mode_changed.emit(false)


func is_compact() -> bool:
	return _is_compact


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_toggle_companion"):
		toggle_compact_mode()
