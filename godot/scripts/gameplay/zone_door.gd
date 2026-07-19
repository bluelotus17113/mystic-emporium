class_name ZoneDoor
extends Area2D
## Portal mágico de piso entre dos zonas contiguas. Al hacer clic, la maga
## camina hasta él y lo "cruza": destello + reubicación en el portal hermano de
## la zona destino + la cámara la acompaña. Sustituye al arrastre para viajar.
## Es un decal de suelo (gira y pulsa). Los instala game_bootstrap
## (_spawn_zone_doors), no requiere edición de escena.

const TEX: String = "res://art/sprites/environment/zone_portal.png"
const PORTAL_SCALE: float = 0.8
const ROT_SPEED: float = 0.7    ## rad/s del remolino
const PULSE_SPEED: float = 2.2

var target_zone: StringName = &""   ## zona a la que lleva
var my_zone: StringName = &""       ## zona en la que está
var _sprite: Sprite2D = null
var _hover: bool = false
var _t: float = 0.0
var _flash_t: float = 0.0


func setup(mine: StringName, target: StringName) -> void:
	my_zone = mine
	target_zone = target


func _ready() -> void:
	add_to_group("zone_doors")
	_t = randf() * TAU  # cada portal pulsa/gira con su propio desfase
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PORTAL_SCALE, PORTAL_SCALE)
	add_child(_sprite)
	z_index = -1  # decal de suelo: sobre el fondo, bajo los personajes
	input_pickable = true
	monitoring = false
	monitorable = false
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0 * PORTAL_SCALE
	col.shape = shape
	add_child(col)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	_sprite.rotation += delta * ROT_SPEED
	var pulse: float = 1.0 + 0.07 * sin(_t * PULSE_SPEED)
	_sprite.scale = Vector2(PORTAL_SCALE * pulse, PORTAL_SCALE * pulse)
	if _flash_t > 0.0:
		# Destello de activación: brillo alto que decae a normal.
		_flash_t -= delta
		var k: float = clampf(_flash_t / 0.5, 0.0, 1.0)
		_sprite.modulate = Color.WHITE.lerp(Color(2.2, 2.0, 2.6), k)
	elif _hover:
		_sprite.modulate = Color(1.3, 1.25, 1.1)
	else:
		var b: float = 0.9 + 0.16 * sin(_t * PULSE_SPEED)
		_sprite.modulate = Color(b * 1.05, b * 0.95, b * 1.18)


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


## Destello mágico al cruzarlo (feedback de activación).
func open_flash() -> void:
	_flash_t = 0.5
	AudioManager.play_named(&"bubble", 0.12)
