extends Control
## Resumen de jornada: cada SHIFT_SECONDS de juego muestra un panel con lo
## producido/ganado desde el último resumen (deltas de StatsManager). Es
## descartable y no pausa el juego. Un "día" real (CalendarManager) también
## dispara el resumen si ocurre antes.

const SHIFT_SECONDS: float = 300.0  ## 5 minutos de juego = una jornada
const TRACK: Array = [
	{"id": "items_collected_total", "icon": "🌿", "label": "Recolectado"},
	{"id": "items_crafted_total", "icon": "⚗", "label": "Crafteado"},
	{"id": "orders_completed", "icon": "📦", "label": "Órdenes"},
	{"id": "coins_earned_total", "icon": "⚜", "label": "Ganado"},
	{"id": "coins_spent_total", "icon": "🪙", "label": "Gastado"},
	{"id": "buildings_placed", "icon": "🏗", "label": "Construido"},
]

var _t: float = 0.0
var _shift: int = 1
var _snapshot: Dictionary = {}
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_snapshot = _capture()
	if CalendarManager.has_signal("day_changed"):
		CalendarManager.day_changed.connect(func(_d, _s): _show_summary())


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_dismiss())
	_dim.hide()
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.hide()
	add_child(_panel)

	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + s), 16)
	_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 8)
	margin.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 20)
	vb.add_child(_title)
	vb.add_child(HSeparator.new())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	vb.add_child(_rows)
	vb.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "Continuar ▶"
	close.pressed.connect(_dismiss)
	vb.add_child(close)


func _capture() -> Dictionary:
	var d: Dictionary = {}
	for e in TRACK:
		d[e.id] = StatsManager.get_stat(e.id)
	return d


func _process(delta: float) -> void:
	if _panel.visible:
		return
	_t += delta
	if _t >= SHIFT_SECONDS:
		_show_summary()


func _show_summary() -> void:
	if _panel.visible:
		return
	_t = 0.0
	for c in _rows.get_children():
		c.queue_free()
	var day_txt: String = ""
	if CalendarManager.has_method("get_clock_string"):
		day_txt = "  ·  Día %d" % CalendarManager.current_day
	_title.text = "☕ Fin de jornada %d%s" % [_shift, day_txt]
	var any: bool = false
	for e in TRACK:
		var diff: int = StatsManager.get_stat(e.id) - int(_snapshot.get(e.id, 0))
		if diff == 0:
			continue
		any = true
		var row := Label.new()
		row.add_theme_font_size_override(&"font_size", 15)
		row.text = "%s  %s: %s%d" % [e.icon, e.label, ("+" if diff > 0 else ""), diff]
		_rows.add_child(row)
	if not any:
		var row := Label.new()
		row.text = "Una jornada tranquila… nada que reportar."
		_rows.add_child(row)
	_dim.show()
	_panel.show()
	_panel.reset_size()
	AudioManager.play_beep(660.0, 0.15, -10.0)


func _dismiss() -> void:
	_panel.hide()
	_dim.hide()
	_shift += 1
	_snapshot = _capture()
	_t = 0.0
