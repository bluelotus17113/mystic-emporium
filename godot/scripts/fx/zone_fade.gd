extends CanvasLayer
## Fundido corto al cambiar de zona: suaviza el salto de cámara con un velo
## que aparece y se desvanece. Escucha zone_camera.zone_changed.

var _rect: ColorRect = null


func _ready() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.color = Color(0.06, 0.05, 0.09)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate = Color(1, 1, 1, 0)
	add_child(_rect)
	await get_tree().process_frame
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_signal("zone_changed"):
		cam.zone_changed.connect(_on_zone_changed)


func _on_zone_changed(_zone_name: StringName) -> void:
	_rect.modulate.a = 0.5
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
