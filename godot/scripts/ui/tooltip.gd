extends PanelContainer
## Tooltip flotante que cualquier nodo puede pedir mostrar:
##   Tooltip.show_at(get_global_mouse_position(), "Texto…")
## Auto-oculta tras 6s o cuando se llama hide_tooltip().

@onready var label: Label = $Margin/Label

const AUTO_HIDE_DELAY: float = 6.0
var _hide_timer: float = 0.0


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_at(world_pos: Vector2, text: String) -> void:
	label.text = text
	show()
	# Wait one frame so layout updates size
	await get_tree().process_frame
	var screen_size: Vector2 = get_viewport_rect().size
	var offset := Vector2(12, -size.y - 12)
	var final_pos: Vector2 = world_pos + offset
	# Clamp inside screen
	final_pos.x = clamp(final_pos.x, 4, screen_size.x - size.x - 4)
	final_pos.y = clamp(final_pos.y, 4, screen_size.y - size.y - 4)
	global_position = final_pos
	_hide_timer = AUTO_HIDE_DELAY


func hide_tooltip() -> void:
	hide()
	_hide_timer = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		hide()
