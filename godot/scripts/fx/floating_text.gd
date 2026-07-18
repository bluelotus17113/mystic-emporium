class_name FloatingText
extends RefCounted
## Texto flotante que sube y se desvanece (p.ej. "+3 🌿", "+50 ⚜").
## Estático: FloatingText.spawn(nodo_mundo, "+3 🌿", color). Se autolibera.


static func spawn(host: Node2D, text: String, color: Color = Color(1, 1, 1)) -> void:
	if host == null or not host.is_inside_tree():
		return
	var parent: Node = host.get_parent()
	if parent == null:
		return
	var holder := Node2D.new()
	holder.z_index = 60
	parent.add_child(holder)
	holder.global_position = host.global_position + Vector2(0, -38)
	var l := Label.new()
	l.text = text
	l.size = Vector2(96, 22)
	l.position = Vector2(-48, -11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override(&"outline_size", 5)
	holder.add_child(l)
	# Pequeño "pop" inicial + subida + fade.
	holder.scale = Vector2(0.6, 0.6)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "position:y", holder.position.y - 24.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.tween_callback(holder.queue_free)
