extends CanvasLayer
## Overlay con la lista de teclas. Toggle con Tab o ?.

const SECTIONS: Array = [
	["Paneles", [
		["I", "Inventario"],
		["B", "Construir"],
		["Tab / ?", "Mostrar/ocultar esta ayuda"],
		["Esc", "Pausa / cerrar panel"],
	]],
	["Construcción", [
		["Click izq / Enter", "Colocar / demoler"],
		["R", "Rotar 90° (decoraciones 1×1)"],
		["Esc", "Cancelar modo construcción"],
	]],
	["Cámara y zonas", [
		["1 / 2 / 3", "Saltar a Natural / Taller / Recepción"],
		["Q / A", "Zona anterior"],
		["E / D", "Zona siguiente"],
		["Rueda ratón", "Pan horizontal en Patio Natural"],
		["Click derecho", "Arrastrar lateral en Patio"],
		["Borde de pantalla", "Pan automático lateral en Patio"],
	]],
	["Modo Compañero", [
		["F12", "Activar / desactivar modo compañero"],
	]],
]

var _panel: PanelContainer


func _ready() -> void:
	layer = 100
	_build_panel()
	visible = false


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -280
	_panel.offset_top = -240
	_panel.offset_right = 280
	_panel.offset_bottom = 240
	_panel.add_theme_stylebox_override(&"panel", _make_panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 20)
	margin.add_theme_constant_override(&"margin_top", 16)
	margin.add_theme_constant_override(&"margin_right", 20)
	margin.add_theme_constant_override(&"margin_bottom", 16)
	_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "⌨️  Atajos de teclado"
	title.add_theme_font_size_override(&"font_size", 20)
	title.modulate = Color(1, 0.92, 0.6, 1)
	v.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.78, 0.66, 0.36, 0.4)
	v.add_child(divider)

	for section in SECTIONS:
		var header := Label.new()
		header.text = "✦ " + section[0]
		header.add_theme_font_size_override(&"font_size", 13)
		header.modulate = Color(0.78, 0.66, 0.36, 1)
		v.add_child(header)
		for entry in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 12)
			var k := Label.new()
			k.text = entry[0]
			k.custom_minimum_size = Vector2(170, 0)
			k.add_theme_font_size_override(&"font_size", 12)
			k.modulate = Color(1, 0.85, 0.5, 1)
			row.add_child(k)
			var d := Label.new()
			d.text = entry[1]
			d.add_theme_font_size_override(&"font_size", 12)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(d)
			v.add_child(row)

	var hint := Label.new()
	hint.text = "Pulsa Tab o ? de nuevo para cerrar."
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.modulate = Color(0.7, 0.7, 0.85, 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.12, 0.08, 0.97)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = Color(0.78, 0.66, 0.36, 0.9)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.shadow_color = Color(0.55, 0.35, 0.95, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	return sb


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_QUESTION:
			visible = not visible
			get_viewport().set_input_as_handled()
