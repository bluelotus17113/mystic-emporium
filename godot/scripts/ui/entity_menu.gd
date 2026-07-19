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
var _stats_box: VBoxContainer
var _stats_getter: Callable = Callable()
var _stat_rows: Array = []
var _stats_cd: float = 0.0


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
	# Bloque de stats (barras vivas): entre el título y las acciones.
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override(&"separation", 3)
	_vb.add_child(_stats_box)
	var follow_btn := Button.new()
	follow_btn.text = "🔎 Seguir con la cámara"
	follow_btn.pressed.connect(_on_follow)
	_vb.add_child(follow_btn)
	_extra_box = VBoxContainer.new()
	_extra_box.add_theme_constant_override(&"separation", 4)
	_vb.add_child(_extra_box)
	hide()


func open_for(node: Node2D, title: String, actions: Array = [], stats_getter: Callable = Callable()) -> void:
	if node == null:
		return
	_target = node
	_title.text = title
	_stats_getter = stats_getter
	_build_stats()
	_rebuild_extra(actions)
	show()
	_panel.reset_size()
	await get_tree().process_frame
	_update_stats()  # ahora que las barras tienen tamaño real
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = _panel.size
	_panel.position = Vector2(min(mp.x, vp.x - sz.x - 8), min(mp.y, vp.y - sz.y - 8))


## Refresca las barras mientras el menú esté abierto (la energía cambia sola).
func _process(delta: float) -> void:
	if not visible or not _stats_getter.is_valid():
		return
	_stats_cd -= delta
	if _stats_cd > 0.0:
		return
	_stats_cd = 0.2
	if _target == null or not is_instance_valid(_target):
		close()
		return
	_update_stats()


const _BAR_H: float = 9.0

func _build_stats() -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	_stat_rows.clear()
	if not _stats_getter.is_valid():
		_stats_box.hide()
		return
	_stats_box.show()
	var data: Array = _stats_getter.call()
	for st in data:
		if not (st is Dictionary):
			continue
		if st.has("ratio"):
			var row := VBoxContainer.new()
			row.add_theme_constant_override(&"separation", 1)
			var head := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = String(st.get("label", ""))
			name_lbl.add_theme_font_size_override(&"font_size", 12)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val_lbl := Label.new()
			val_lbl.add_theme_font_size_override(&"font_size", 12)
			head.add_child(name_lbl)
			head.add_child(val_lbl)
			row.add_child(head)
			var bg := ColorRect.new()
			bg.color = Color(0, 0, 0, 0.38)
			bg.custom_minimum_size = Vector2(0, _BAR_H)
			var fill := ColorRect.new()
			fill.position = Vector2.ZERO
			bg.add_child(fill)
			row.add_child(bg)
			_stats_box.add_child(row)
			_stat_rows.append({"type": "bar", "bg": bg, "fill": fill, "val": val_lbl})
		else:
			var lbl := Label.new()
			lbl.text = "%s: %s" % [String(st.get("label", "")), String(st.get("text", ""))]
			lbl.add_theme_font_size_override(&"font_size", 12)
			_stats_box.add_child(lbl)
			_stat_rows.append({"type": "text", "lbl": lbl})


func _update_stats() -> void:
	if not _stats_getter.is_valid() or _target == null or not is_instance_valid(_target):
		return
	var data: Array = _stats_getter.call()
	for i in mini(data.size(), _stat_rows.size()):
		var st: Dictionary = data[i]
		var row: Dictionary = _stat_rows[i]
		if row["type"] == "bar":
			var bg: ColorRect = row["bg"]
			var fill: ColorRect = row["fill"]
			var ratio: float = clampf(float(st.get("ratio", 0.0)), 0.0, 1.0)
			fill.color = st.get("color", Color(0.5, 0.8, 0.4))
			fill.size = Vector2(bg.size.x * ratio, _BAR_H)
			(row["val"] as Label).text = String(st.get("value_text", ""))
		else:
			(row["lbl"] as Label).text = "%s: %s" % [String(st.get("label", "")), String(st.get("text", ""))]


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
	_stats_getter = Callable()
	hide()


func _on_follow() -> void:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("follow_node") and _target != null and is_instance_valid(_target):
		cam.follow_node(_target)
	close()
