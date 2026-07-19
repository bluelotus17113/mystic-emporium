extends Control
## Panel del árbol de mejoras del local. Construido por código; se auto-registra
## en UIManager como &"upgrades" y lo abre el botón del HUD. Lista los nodos de
## EmporiumUpgradeManager con nivel, efecto, coste y botón de compra.

const PANEL_NAME: StringName = &"upgrades"

var _rows_box: VBoxContainer
var _rows: Dictionary = {}   # id -> {"buy": Button, "cost": Label}


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # ocupa TODO el viewport
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Clic en el fondo (fuera del panel) → cerrar.
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			UIManager.close_active())

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Centrado explícito (anclas al centro + crecer en ambas direcciones): robusto
	# frente a la animación de apertura de UIManager.
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.20, 0.98)
	sb.border_color = Color(0.55, 0.42, 0.68, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override(&"panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "🏪 Mejoras del Local"
	title.add_theme_font_size_override(&"font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Bonificaciones permanentes para tu Emporium"
	subtitle.add_theme_font_size_override(&"font_size", 12)
	subtitle.modulate = Color(1, 1, 1, 0.7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override(&"separation", 8)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	vb.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.pressed.connect(func(): UIManager.close_active())
	vb.add_child(close_btn)

	hide()
	visibility_changed.connect(func():
		if visible:
			_build())
	EmporiumUpgradeManager.upgrades_changed.connect(_build)
	InventoryManager.coins_changed.connect(func(_a: int):
		if visible:
			_refresh_affordability())


func _build() -> void:
	if _rows_box == null:
		return
	for c in _rows_box.get_children():
		c.queue_free()
	_rows.clear()
	for u in EmporiumUpgradeManager.UPGRADES:
		_rows_box.add_child(_make_row(u))
	_refresh_affordability()


func _make_row(u: Dictionary) -> Control:
	var id: StringName = u["id"]
	var lvl: int = EmporiumUpgradeManager.level_of(id)
	var maxl: int = int(u["max"])
	var unlocked: bool = EmporiumUpgradeManager.is_unlocked(id)

	var row := PanelContainer.new()
	var rb := StyleBoxFlat.new()
	rb.bg_color = Color(0.22, 0.17, 0.28, 0.9) if unlocked else Color(0.14, 0.12, 0.16, 0.9)
	rb.set_corner_radius_all(7)
	rb.set_content_margin_all(9)
	row.add_theme_stylebox_override(&"panel", rb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override(&"separation", 10)
	row.add_child(hb)

	var icon := Label.new()
	icon.text = String(u["icon"]) if unlocked else "🔒"
	icon.add_theme_font_size_override(&"font_size", 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 1)
	hb.add_child(info)
	var head := Label.new()
	head.text = "%s   Nv %d/%d" % [String(u["name"]), lvl, maxl]
	head.add_theme_font_size_override(&"font_size", 15)
	info.add_child(head)
	var desc := Label.new()
	desc.text = String(u["desc"])
	desc.add_theme_font_size_override(&"font_size", 12)
	desc.modulate = Color(1, 1, 1, 0.78)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(230, 0)
	info.add_child(desc)
	if not unlocked:
		var req := Label.new()
		var req_def: Dictionary = EmporiumUpgradeManager._def(u["req"])
		req.text = "Requiere: %s" % String(req_def.get("name", "—"))
		req.add_theme_font_size_override(&"font_size", 11)
		req.modulate = Color(1.0, 0.7, 0.5, 0.9)
		info.add_child(req)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(right)
	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override(&"font_size", 13)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(cost_lbl)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 0)
	buy.pressed.connect(func(): EmporiumUpgradeManager.buy(id))
	right.add_child(buy)

	_rows[id] = {"buy": buy, "cost": cost_lbl}
	return row


## Actualiza coste/estado de los botones sin reconstruir (barato en cada moneda).
func _refresh_affordability() -> void:
	for id in _rows:
		var buy: Button = _rows[id]["buy"]
		var cost_lbl: Label = _rows[id]["cost"]
		if EmporiumUpgradeManager.is_maxed(id):
			cost_lbl.text = "MÁX"
			cost_lbl.modulate = Color(0.6, 0.9, 0.6)
			buy.text = "✓"
			buy.disabled = true
			continue
		if not EmporiumUpgradeManager.is_unlocked(id):
			cost_lbl.text = "🔒"
			cost_lbl.modulate = Color(1, 1, 1, 0.5)
			buy.text = "Bloqueado"
			buy.disabled = true
			continue
		var cost: int = EmporiumUpgradeManager.cost_of(id)
		var can: bool = InventoryManager.arcane_coins >= cost
		cost_lbl.text = "%d ⚜" % cost
		cost_lbl.modulate = Color(1.0, 0.9, 0.5) if can else Color(0.9, 0.5, 0.5)
		buy.text = "Mejorar"
		buy.disabled = not can
