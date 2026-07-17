extends PanelContainer
## Barra de herramientas del modo obra: Catálogo · Mover · Rotar · Demoler.
## Visible mientras el catálogo esté abierto o cualquier herramienta activa.

@onready var _catalog_btn: Button = $Margin/HBox/CatalogBtn
@onready var _move_btn: Button = $Margin/HBox/MoveBtn
@onready var _rotate_btn: Button = $Margin/HBox/RotateBtn
@onready var _demolish_btn: Button = $Margin/HBox/DemolishBtn
@onready var _exit_btn: Button = $Margin/HBox/ExitBtn

var _copy_btn: Button = null
var _panel_open: bool = false
var _mode: StringName = &""


func _ready() -> void:
	hide()
	# Botón Copiar (clonar un objeto colocado) — creado en código para no editar
	# la escena; se inserta antes del botón Salir.
	_copy_btn = Button.new()
	_copy_btn.text = "⧉ Copiar"
	_copy_btn.toggle_mode = true
	_copy_btn.tooltip_text = "Clic sobre un objeto para clonarlo y estampar copias"
	var hbox: Node = _exit_btn.get_parent()
	hbox.add_child(_copy_btn)
	hbox.move_child(_copy_btn, _exit_btn.get_index())
	_copy_btn.pressed.connect(func():
		if BuildManager.is_copy_active():
			BuildManager.exit_copy_mode()
		else:
			UIManager.close_active()
			BuildManager.enter_copy_mode())
	_catalog_btn.pressed.connect(func():
		BuildManager.exit_move_mode()
		BuildManager.exit_rotate_mode()
		BuildManager.exit_demolish_mode()
		UIManager.open(&"build"))
	_move_btn.pressed.connect(func():
		if BuildManager.is_move_active():
			BuildManager.exit_move_mode()
		else:
			UIManager.close_active()
			BuildManager.enter_move_mode())
	_rotate_btn.pressed.connect(func():
		if BuildManager.is_rotate_active():
			BuildManager.exit_rotate_mode()
		else:
			UIManager.close_active()
			BuildManager.enter_rotate_mode())
	_demolish_btn.pressed.connect(func():
		if BuildManager.is_demolish_active():
			BuildManager.exit_demolish_mode()
		else:
			UIManager.close_active()
			BuildManager.enter_demolish_mode())
	_exit_btn.pressed.connect(func():
		BuildManager.exit_build_mode()
		BuildManager.exit_move_mode()
		BuildManager.exit_rotate_mode()
		BuildManager.exit_demolish_mode()
		BuildManager.exit_copy_mode()
		if UIManager.is_open(&"build"):
			UIManager.close_active()
		_panel_open = false
		_refresh())
	UIManager.panel_opened.connect(func(n: StringName):
		if n == &"build":
			_panel_open = true
		else:
			_panel_open = false
		_refresh())
	UIManager.panel_closed.connect(func(n: StringName):
		if n == &"build":
			_panel_open = false
		_refresh())
	BuildManager.tool_mode_changed.connect(func(m: StringName):
		_mode = m
		_refresh())


func _refresh() -> void:
	visible = _panel_open or _mode != &""
	_move_btn.set_pressed_no_signal(_mode == &"move")
	_rotate_btn.set_pressed_no_signal(_mode == &"rotate")
	_demolish_btn.set_pressed_no_signal(_mode == &"demolish")
	if _copy_btn != null:
		_copy_btn.set_pressed_no_signal(_mode == &"copy")
	# pista contextual en tooltip del botón activo
	match _mode:
		&"move":
			_move_btn.tooltip_text = "Clic: agarrar/soltar · Esc: cancelar"
		&"rotate":
			_rotate_btn.tooltip_text = "Clic sobre una decoración 1x1 para rotarla"
		_:
			pass
