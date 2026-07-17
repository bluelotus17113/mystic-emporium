extends Control
## Menú contextual al hacer clic izquierdo sobre una entidad (worker, gato…).
## Siempre ofrece "Seguir con la cámara"; open_for admite acciones extra:
##   {"text": String, "cb": Callable}                          → botón simple
##   {"rename": true, "text": String, "get": Callable, "set": Callable} → renombrar
## Se cierra al elegir una opción o al hacer clic fuera.

var _target: Node2D = null
var _panel: PanelContainer
var _vb: VBoxContainer
var _title: Label
var _extra_box: VBoxContainer


func _ready() -> void:
	add_to_group("entity_menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(190, 0)
	add_child(_panel)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override(&"separation", 4)
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_left", 8)
	m.add_theme_constant_override(&"margin_top", 6)
	m.add_theme_constant_override(&"margin_right", 8)
	m.add_theme_constant_override(&"margin_bottom", 6)
	_panel.add_child(m)
	m.add_child(_vb)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 14)
	_vb.add_child(_title)
	_vb.add_child(HSeparator.new())
	var follow_btn := Button.new()
	follow_btn.text = "🔎 Seguir con la cámara"
	follow_btn.pressed.connect(_on_follow)
	_vb.add_child(follow_btn)
	_extra_box = VBoxContainer.new()
	_extra_box.add_theme_constant_override(&"separation", 4)
	_vb.add_child(_extra_box)
	hide()


func open_for(node: Node2D, title: String, actions: Array = []) -> void:
	if node == null:
		return
	_target = node
	_title.text = title
	_rebuild_extra(actions)
	show()
	_panel.reset_size()
	await get_tree().process_frame
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = _panel.size
	_panel.position = Vector2(min(mp.x, vp.x - sz.x - 8), min(mp.y, vp.y - sz.y - 8))


func _rebuild_extra(actions: Array) -> void:
	for c in _extra_box.get_children():
		c.queue_free()
	for a in actions:
		if not (a is Dictionary):
			continue
		if a.get("rename", false):
			_add_rename_row(a)
		else:
			var b := Button.new()
			b.text = String(a.get("text", "Acción"))
			var cb: Callable = a.get("cb", Callable())
			b.pressed.connect(func():
				if cb.is_valid():
					cb.call()
				close())
			_extra_box.add_child(b)


func _add_rename_row(a: Dictionary) -> void:
	var btn := Button.new()
	btn.text = String(a.get("text", "✏ Renombrar"))
	var getter: Callable = a.get("get", Callable())
	var setter: Callable = a.get("set", Callable())
	btn.pressed.connect(func():
		btn.hide()
		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(160, 0)
		if getter.is_valid():
			edit.text = String(getter.call())
		edit.select_all()
		_extra_box.add_child(edit)
		edit.grab_focus()
		var commit := func():
			if setter.is_valid():
				setter.call(edit.text)
			close()
		edit.text_submitted.connect(func(_t): commit.call())
		var ok := Button.new()
		ok.text = "✔ Guardar"
		ok.pressed.connect(func(): commit.call())
		_extra_box.add_child(ok)
		_panel.reset_size())
	_extra_box.add_child(btn)


func close() -> void:
	_target = null
	hide()


func _on_follow() -> void:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("follow_node") and _target != null and is_instance_valid(_target):
		cam.follow_node(_target)
	close()
