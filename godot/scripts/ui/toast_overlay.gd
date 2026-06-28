extends CanvasLayer
## Muestra notificaciones flotantes en la esquina superior derecha.
## Cada toast vive 4s y desaparece. Apila hasta MAX_VISIBLE.

const MAX_VISIBLE: int = 3
const TOAST_LIFETIME: float = 4.0
const FADE_OUT: float = 0.6

@onready var stack: VBoxContainer = $Stack


func _ready() -> void:
	NotificationManager.notification_posted.connect(_on_notification_posted)
	WindowController.mode_changed.connect(_on_mode_changed)


func _on_mode_changed(is_compact: bool) -> void:
	if is_compact:
		for c in stack.get_children():
			c.queue_free()


const MAX_SPAWN_PER_FRAME: int = 1
var _spawned_this_frame: int = 0


func _process(_delta: float) -> void:
	_spawned_this_frame = 0


func _on_notification_posted(text: String, kind: int) -> void:
	# En companion mode no mostramos toasts (la UI compact ya saturaría con avisos).
	if WindowController.is_compact():
		return
	# ponytail: cap por frame. Si un evento (cascada de logros) dispara 10 notificaciones,
	# solo materializamos 3 toasts; el resto queda en log. Evita frame-hang.
	if _spawned_this_frame >= MAX_SPAWN_PER_FRAME:
		print("[Toast] dropped (rate limit): %s" % text)
		return
	_spawned_this_frame += 1
	var toast := _build_toast(text, kind)
	stack.add_child(toast)
	stack.move_child(toast, 0)
	# Cull old
	while stack.get_child_count() > MAX_VISIBLE:
		var oldest: Node = stack.get_child(stack.get_child_count() - 1)
		oldest.queue_free()
	# Auto-dismiss
	var tween := create_tween()
	tween.tween_interval(TOAST_LIFETIME)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(func(): if is_instance_valid(toast): toast.queue_free())


func _build_toast(text: String, kind: int) -> Control:
	var panel := PanelContainer.new()
	panel.modulate = Color(1, 1, 1, 0.95)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var icon := Label.new()
	icon.text = _icon_for(kind)
	icon.add_theme_font_size_override("font_size", 18)
	icon.modulate = _color_for(kind)
	hbox.add_child(icon)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(label)
	return panel


func _icon_for(kind: int) -> String:
	match kind:
		NotificationManager.Kind.SUCCESS: return "✓"
		NotificationManager.Kind.WARNING: return "⚠"
		NotificationManager.Kind.ALERT: return "✖"
		NotificationManager.Kind.REWARD: return "⚜"
		_: return "•"


func _color_for(kind: int) -> Color:
	match kind:
		NotificationManager.Kind.SUCCESS: return Color(0.5, 0.95, 0.5, 1)
		NotificationManager.Kind.WARNING: return Color(1.0, 0.8, 0.3, 1)
		NotificationManager.Kind.ALERT: return Color(1.0, 0.45, 0.45, 1)
		NotificationManager.Kind.REWARD: return Color(1.0, 0.85, 0.3, 1)
		_: return Color(0.7, 0.85, 1.0, 1)
