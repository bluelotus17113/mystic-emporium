extends Node2D
## Personaje animado que aparece en modo compañero. Patrulla horizontalmente,
## reacciona a clics (saltito + bocadillo de notificación), permite drag & drop,
## y muestra alertas del juego como burbujas flotantes.

signal companion_clicked

@export var patrol_speed: float = 35.0
@export var patrol_margin: float = 60.0
@export var jump_strength: float = 14.0

var _patrol_direction: int = 1
var _vertical_offset: float = 0.0
var _vertical_velocity: float = 0.0
var _bob_phase: float = 0.0

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@onready var sprite_root: Node2D = $SpriteRoot
@onready var body: Polygon2D = $SpriteRoot/Body
@onready var bubble: PanelContainer = $Bubble
@onready var bubble_label: Label = $Bubble/Margin/Label
@onready var area: Area2D = $Area

var _bubble_timer: float = 0.0
const BUBBLE_DURATION: float = 4.0


func _ready() -> void:
	bubble.hide()
	area.input_event.connect(_on_area_input)
	# Hooks de notificaciones desde managers
	OrderManager.order_generated.connect(_on_order_generated)
	OrderManager.order_completed.connect(_on_order_completed)
	ResearchManager.research_completed.connect(_on_research_completed)
	InventoryManager.inventory_full.connect(_on_inventory_full)


func _process(delta: float) -> void:
	if _is_dragging:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		global_position = mouse_pos + _drag_offset
	else:
		_update_patrol(delta)
		_update_idle_animation(delta)
	_update_gravity(delta)
	_update_bubble_timer(delta)


func _update_patrol(delta: float) -> void:
	global_position.x += _patrol_direction * patrol_speed * delta
	var screen_size: Vector2i = DisplayServer.window_get_size()
	if global_position.x > screen_size.x - patrol_margin:
		_patrol_direction = -1
		sprite_root.scale.x = -1
	elif global_position.x < patrol_margin:
		_patrol_direction = 1
		sprite_root.scale.x = 1


func _update_idle_animation(delta: float) -> void:
	_bob_phase += delta * 4.0
	sprite_root.position.y = sin(_bob_phase) * 1.5


func _update_gravity(delta: float) -> void:
	if _vertical_offset > 0.0 or _vertical_velocity != 0.0:
		_vertical_velocity -= 40.0 * delta
		_vertical_offset += _vertical_velocity * delta * 6.0
		if _vertical_offset <= 0.0:
			_vertical_offset = 0.0
			_vertical_velocity = 0.0
		sprite_root.position.y += -_vertical_offset


func _update_bubble_timer(delta: float) -> void:
	if not bubble.visible:
		return
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		bubble.hide()


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and event.double_click:
				companion_clicked.emit()
			elif event.pressed:
				_is_dragging = true
				_drag_offset = global_position - get_viewport().get_mouse_position()
				_jump()
			elif not event.pressed:
				_is_dragging = false


func _jump() -> void:
	_vertical_velocity = jump_strength


func say(message: String, duration: float = BUBBLE_DURATION) -> void:
	bubble_label.text = message
	bubble.show()
	_bubble_timer = duration


func _on_order_generated(order: OrderData) -> void:
	if order == null or order.requested_item == null:
		return
	say("¡Pedido!\n%d × %s" % [order.requested_quantity, order.requested_item.display_name])


func _on_order_completed(_o: OrderData) -> void:
	say("¡Pedido entregado!")


func _on_research_completed(r: ResearchData) -> void:
	if r != null:
		say("Completada:\n%s" % r.display_name)


func _on_inventory_full(item: ItemData) -> void:
	say("Inventario lleno\n%s" % (item.display_name if item != null else ""))
