class_name ZoneDoor
extends Area2D
## Puerta clicable entre dos zonas contiguas. Al hacer clic, la maga camina
## hasta ella y la "cruza": destello + reubicación en la puerta hermana de la
## zona destino + la cámara la acompaña. Sustituye al arrastre para viajar.
## Las instala game_bootstrap (_spawn_zone_doors), no requiere edición de escena.

const TEX_CLOSED: String = "res://art/tiles/wall/door_madera_cerrada.png"
const TEX_OPEN: String = "res://art/tiles/wall/door_madera_abierta.png"
const DOOR_SCALE: float = 1.6

var target_zone: StringName = &""   ## zona a la que lleva
var my_zone: StringName = &""       ## zona en la que está
var _sprite: Sprite2D = null
var _hover: bool = false


func setup(mine: StringName, target: StringName) -> void:
	my_zone = mine
	target_zone = target


func _ready() -> void:
	add_to_group("zone_doors")
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX_CLOSED)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(DOOR_SCALE, DOOR_SCALE)
	_sprite.offset = Vector2(0, -32)  # base de la puerta al origen (Y-sort por la base)
	add_child(_sprite)
	z_index = 0
	input_pickable = true
	monitoring = false
	monitorable = false
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64) * DOOR_SCALE
	col.shape = shape
	col.position = Vector2(0, -32.0 * DOOR_SCALE)
	add_child(col)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))


func _set_hover(on: bool) -> void:
	_hover = on
	if _sprite != null:
		_sprite.modulate = Color(1.25, 1.2, 1.05) if on else Color.WHITE


func _on_input_event(_vp: Node, event: InputEvent, _idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _build_mode_active():
		return
	var proto: Node = get_tree().get_first_node_in_group("protagonist")
	if proto != null and proto.has_method("walk_through_door"):
		proto.call("walk_through_door", self)
		get_viewport().set_input_as_handled()


func _build_mode_active() -> bool:
	return BuildManager.is_active() or BuildManager.is_move_active() \
			or BuildManager.is_demolish_active() or BuildManager.is_copy_active()


## Abre la hoja un instante (feedback al cruzarla) y la vuelve a cerrar.
func open_flash() -> void:
	if _sprite == null:
		return
	_sprite.texture = load(TEX_OPEN)
	AudioManager.play_named(&"doorbell", 0.1)
	var t := create_tween()
	t.tween_interval(1.3)
	t.tween_callback(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.texture = load(TEX_CLOSED))
