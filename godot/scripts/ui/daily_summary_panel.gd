extends Control
## Resumen SEMANAL (hora real del PC). Antes saltaba cada 5 min de juego / cada
## día y oscurecía la pantalla: molestaba más que ayudaba. Ahora, una vez por
## semana real, aparece una tarjeta discreta en la esquina con lo acumulado en
## esos 7 días. No oscurece, no pausa, no bloquea el resto de la pantalla: solo
## una tarjeta descartable. El ancla temporal la persiste StatsManager.

const CHECK_INTERVAL: float = 5.0  ## cada cuánto (s reales) comprobamos si toca
const TRACK: Array = [
	{"id": "items_collected_total", "icon": "🌿", "label": "Recolectado"},
	{"id": "items_crafted_total", "icon": "⚗", "label": "Crafteado"},
	{"id": "orders_completed", "icon": "📦", "label": "Órdenes"},
	{"id": "coins_earned_total", "icon": "⚜", "label": "Ganado"},
	{"id": "coins_spent_total", "icon": "🪙", "label": "Gastado"},
	{"id": "buildings_placed", "icon": "🏗", "label": "Construido"},
]

var _check_t: float = 0.0
var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# No bloquea input: es una capa transparente; solo la tarjeta recibe clics.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	StatsManager.ensure_week_anchor()
	_build_ui()


func _build_ui() -> void:
	# Tarjeta anclada arriba-derecha, discreta.
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 0)
	_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.hide()
	add_child(_panel)

	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + s), 16)
	_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 8)
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	vb.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override(&"font_size", 18)
	header.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(_dismiss)
	header.add_child(close)

	vb.add_child(HSeparator.new())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	vb.add_child(_rows)


func _process(delta: float) -> void:
	if _panel.visible:
		return
	_check_t += delta
	if _check_t < CHECK_INTERVAL:
		return
	_check_t = 0.0
	if StatsManager.is_week_due():
		_show_summary()


func _show_summary() -> void:
	if _panel.visible:
		return
	var deltas: Dictionary = StatsManager.roll_week()  # también reancla la semana
	for c in _rows.get_children():
		c.queue_free()
	_title.text = "🗓 Resumen semanal"
	var any: bool = false
	for e in TRACK:
		var diff: int = int(deltas.get(e.id, 0))
		if diff == 0:
			continue
		any = true
		var row := Label.new()
		row.add_theme_font_size_override(&"font_size", 15)
		row.text = "%s  %s: %s%d" % [e.icon, e.label, ("+" if diff > 0 else ""), diff]
		_rows.add_child(row)
	if not any:
		var row := Label.new()
		row.text = "Una semana tranquila… nada que reportar."
		_rows.add_child(row)
	_slide_in()
	AudioManager.play_beep(660.0, 0.15, -12.0)


func _slide_in() -> void:
	_panel.show()
	_panel.reset_size()
	_panel.modulate.a = 0.0
	var off: float = _panel.position.x
	_panel.position.x = off + 40.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(_panel, "position:x", off, 0.35)


func _dismiss() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_panel.hide)
