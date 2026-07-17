extends Control
## Indicador discreto de guardado: parpadea "💾 Guardado" cuando el juego
## autoguarda (cada 120s / al cambiar de día) o se guarda a mano.

var _label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = "💾 Guardado"
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_color", Color(0.82, 1.0, 0.85))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.modulate.a = 0.0
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	_label.position.y += 44.0
	if SaveManager.has_signal("game_saved"):
		SaveManager.game_saved.connect(_on_saved)


func _on_saved(_slot: int) -> void:
	var tw := create_tween()
	_label.modulate.a = 0.0
	tw.tween_property(_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.4)
	tw.tween_property(_label, "modulate:a", 0.0, 0.6)
