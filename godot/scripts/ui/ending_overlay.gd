extends CanvasLayer
## Pantalla de celebración cuando se craftea la Estrella del Emporio.

@onready var panel: PanelContainer = $Panel
@onready var dim: ColorRect = $Dim
@onready var star: Label = $Panel/Margin/VBox/Star
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	EndingManager.emporium_completed.connect(_on_emporium_completed)


func _on_emporium_completed() -> void:
	visible = true
	# Animación: fade-in del dim + pop del panel + estrella rotando+pulsando
	dim.modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "modulate:a", 1.0, 0.5)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.8)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	# Estrella pulsando indefinidamente
	_start_star_pulse()


func _start_star_pulse() -> void:
	var tw := create_tween().set_loops().set_parallel(false)
	tw.tween_property(star, "scale", Vector2(1.15, 1.15), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(star, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _close() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(dim, "modulate:a", 0.0, 0.3)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func(): visible = false)
