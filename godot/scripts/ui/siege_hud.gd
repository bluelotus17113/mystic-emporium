extends Control
## Banner del asedio en el HUD: oleada actual, vida del cultivo (base) y ogros
## restantes. Sólo visible durante un asedio. Construido por código.

var _title: Label = null
var _wave_lbl: Label = null
var _enemies_lbl: Label = null
var _bar_bg: ColorRect = null
var _bar_fill: ColorRect = null
var _poll: float = 0.0
var _last_ratio: float = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 96.0  # bajo el reloj superior
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.08, 0.10, 0.92)
	sb.border_color = Color(0.92, 0.42, 0.36, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(9)
	panel.add_theme_stylebox_override(&"panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 3)
	panel.add_child(vb)
	_title = _mklabel(vb, "🏰 ¡ASEDIO!", 16)
	_wave_lbl = _mklabel(vb, "", 13)

	var brow := HBoxContainer.new()
	brow.add_theme_constant_override(&"separation", 6)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(brow)
	var seed_lbl := Label.new()
	seed_lbl.text = "🌱"
	seed_lbl.add_theme_font_size_override(&"font_size", 15)
	brow.add_child(seed_lbl)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.5)
	_bar_bg.custom_minimum_size = Vector2(220, 12)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.45, 0.9, 0.45)
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(220, 12)
	_bar_bg.add_child(_bar_fill)
	brow.add_child(_bar_bg)

	_enemies_lbl = _mklabel(vb, "", 12)
	hide()
	SiegeManager.siege_started.connect(_on_started)
	SiegeManager.wave_changed.connect(_on_wave)
	SiegeManager.base_hp_changed.connect(_on_base_hp)
	SiegeManager.siege_ended.connect(_on_ended)


func _mklabel(parent: Node, txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override(&"font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _on_started() -> void:
	_title.text = "🏰 ¡ASEDIO!"
	show()


func _on_wave(w: int, total: int) -> void:
	_wave_lbl.text = "🌊 Oleada %d / %d" % [w, total]


func _on_base_hp(hp: float, max_hp: float) -> void:
	_last_ratio = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	_apply_bar()


func _apply_bar() -> void:
	if _bar_bg == null or _bar_fill == null:
		return
	var w: float = maxf(_bar_bg.size.x, _bar_bg.custom_minimum_size.x)
	_bar_fill.size = Vector2(w * _last_ratio, 12.0)
	if _last_ratio > 0.5:
		_bar_fill.color = Color(0.45, 0.9, 0.45)
	elif _last_ratio > 0.25:
		_bar_fill.color = Color(0.95, 0.8, 0.3)
	else:
		_bar_fill.color = Color(0.95, 0.35, 0.3)


func _on_ended(won: bool) -> void:
	_title.text = "🏆 ¡Asedio repelido!" if won else "💥 El cultivo cayó…"
	_wave_lbl.text = ""
	_enemies_lbl.text = ""
	get_tree().create_timer(3.5).timeout.connect(hide)


func _process(delta: float) -> void:
	if not visible:
		return
	_apply_bar()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.3
	if SiegeManager.is_active():
		_enemies_lbl.text = "Ogros restantes: %d" % SiegeManager.enemies_left()
