extends Control
## Menú contextual que aparece al hacer clic izquierdo sobre una entidad
## (worker, gato…). Muestra acciones; por ahora "Seguir con la cámara".
## Se cierra al elegir una opción o al hacer clic fuera.

var _target: Node2D = null
var _panel: PanelContainer
var _title: Label
var _follow_btn: Button


func _ready() -> void:
	add_to_group("entity_menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # fondo captura clics fuera
	# Fondo invisible que cierra al hacer clic.
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(180, 0)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 4)
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_left", 8)
	m.add_theme_constant_override(&"margin_top", 6)
	m.add_theme_constant_override(&"margin_right", 8)
	m.add_theme_constant_override(&"margin_bottom", 6)
	_panel.add_child(m)
	m.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 14)
	vb.add_child(_title)
	vb.add_child(HSeparator.new())
	_follow_btn = Button.new()
	_follow_btn.text = "🔎 Seguir con la cámara"
	_follow_btn.pressed.connect(_on_follow)
	vb.add_child(_follow_btn)
	hide()


func open_for(node: Node2D, title: String) -> void:
	if node == null:
		return
	_target = node
	_title.text = title
	show()
	_panel.reset_size()
	await get_tree().process_frame
	# Colocar junto al ratón, dentro de la pantalla.
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = _panel.size
	_panel.position = Vector2(min(mp.x, vp.x - sz.x - 8), min(mp.y, vp.y - sz.y - 8))


func close() -> void:
	_target = null
	hide()


func _on_follow() -> void:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("follow_node") and _target != null and is_instance_valid(_target):
		cam.follow_node(_target)
	close()
