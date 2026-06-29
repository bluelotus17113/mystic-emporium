extends PanelContainer
## Indicador grande de evento activo. Muestra icono + nombre + bonus
## explícito + countdown numérico + barra. El borde pulsa con el color
## del evento mientras está activo para mayor visibilidad.

const EVENT_VISUALS: Dictionary = {
	&"festival_lunar":    {"icon": "🌙", "color": Color(0.55, 0.75, 1.00, 1),  "bonus": "+50% coins en pedidos"},
	&"eclipse_arcano":    {"icon": "🌑", "color": Color(0.65, 0.45, 0.95, 1),  "bonus": "Generadores 40% más rápidos"},
	&"inspeccion_gremio": {"icon": "📜", "color": Color(0.95, 0.85, 0.45, 1),  "bonus": "+3 reputación por pedido"},
	&"asalto_bandidos":   {"icon": "⚔",  "color": Color(0.95, 0.45, 0.45, 1),  "bonus": "Duendes defienden la tienda"},
	&"tormenta_arcana":   {"icon": "⚡", "color": Color(0.55, 0.95, 0.85, 1),  "bonus": "Crafteo 2× más rápido"},
}

@onready var icon_label: Label = $Margin/VBox/HeaderRow/Icon
@onready var title_label: Label = $Margin/VBox/HeaderRow/TitleBox/Label
@onready var bonus_label: Label = $Margin/VBox/HeaderRow/TitleBox/BonusLabel
@onready var countdown_label: Label = $Margin/VBox/HeaderRow/CountdownLabel
@onready var bar: ProgressBar = $Margin/VBox/Bar

var _pulse_t: float = 0.0
var _base_style: StyleBoxFlat = null
var _current_color: Color = Color(1, 0.85, 0.45, 1)


func _ready() -> void:
	hide()
	_base_style = get_theme_stylebox(&"panel") as StyleBoxFlat
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_ended.connect(_on_event_ended)


func _process(delta: float) -> void:
	if not visible:
		return
	var def_id: StringName = EventManager.get_active_event_id()
	if def_id == &"":
		_on_event_ended(&"")
		return
	var total: float = _get_total_duration(def_id)
	var remaining: float = EventManager.get_active_remaining()
	bar.value = (remaining / total) * 100.0 if total > 0.0 else 0.0
	countdown_label.text = _format_time(remaining)
	# Pulso del borde para que el indicador "respire" y sea imposible perder.
	_pulse_t += delta * 3.0
	var pulse: float = 0.5 + 0.5 * sin(_pulse_t)
	if _base_style != null:
		var glow: Color = _current_color
		glow.a = 0.55 + 0.35 * pulse
		_base_style.shadow_color = glow
		_base_style.border_color = _current_color.lerp(Color.WHITE, 0.15 * pulse)


func _on_event_started(id: StringName, lbl: String) -> void:
	var visuals: Dictionary = EVENT_VISUALS.get(id, {"icon": "🌟", "color": Color(1, 0.85, 0.45, 1), "bonus": ""})
	_current_color = visuals.color
	icon_label.text = visuals.icon
	title_label.text = lbl
	title_label.add_theme_color_override(&"font_color", visuals.color)
	bonus_label.text = visuals.bonus
	countdown_label.add_theme_color_override(&"font_color", visuals.color)
	bar.value = 100.0
	# Aplicar color del evento al fill de la barra y al borde del panel.
	var fill_style := bar.get_theme_stylebox(&"fill")
	if fill_style is StyleBoxFlat:
		(fill_style as StyleBoxFlat).bg_color = visuals.color
	if _base_style != null:
		_base_style.border_color = visuals.color
		_base_style.shadow_color = Color(visuals.color.r, visuals.color.g, visuals.color.b, 0.55)
	# Entrada con tween de slide + scale.
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.85, 0.85)
	show()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35)


func _on_event_ended(_id: StringName) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.9, 0.9), 0.3)
	tw.chain().tween_callback(hide)


func _get_total_duration(def_id: StringName) -> float:
	for d in EventManager.EVENT_DEFINITIONS.values():
		if d.id == def_id:
			return float(d.duration)
	return 1.0


func _format_time(seconds: float) -> String:
	var s: int = int(ceil(max(0.0, seconds)))
	var m: int = s / 60
	var rem: int = s % 60
	return "%d:%02d" % [m, rem]
