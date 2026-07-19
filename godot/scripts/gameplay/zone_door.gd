class_name ZoneDoor
extends Area2D
## Portal mágico de piso entre dos zonas contiguas. Al hacer clic, la maga
## camina hasta él y lo "cruza": destello + reubicación en el portal hermano de
## la zona destino + la cámara la acompaña. Sustituye al arrastre para viajar.
##
## Es un VFX dibujado por código (anillos translúcidos que giran, aplanados al
## suelo): minimalista y transparente, deja ver el suelo. Los instala
## game_bootstrap (_spawn_zone_doors), no requiere edición de escena.

const R: float = 26.0            ## radio del portal en px
const SQUASH: float = 0.6        ## achatado vertical (perspectiva de suelo)
const ROT_SPEED: float = 0.9     ## giro del anillo interior (rad/s)
const PULSE_SPEED: float = 2.2

# Colores VFX (paleta arcana).
const C_RING: Color = Color(0.45, 0.9, 0.95)   ## turquesa
const C_INNER: Color = Color(0.8, 0.65, 1.0)   ## lavanda
const C_FILL: Color = Color(0.62, 0.43, 1.0)   ## púrpura

var target_zone: StringName = &""   ## zona a la que lleva
var my_zone: StringName = &""       ## zona en la que está
var _hover: bool = false
var _t: float = 0.0
var _flash_t: float = 0.0


func setup(mine: StringName, target: StringName) -> void:
	my_zone = mine
	target_zone = target


func _ready() -> void:
	add_to_group("zone_doors")
	_t = randf() * TAU  # cada portal gira/pulsa con su propio desfase
	z_index = -1        # VFX de suelo: sobre el fondo, bajo los personajes
	# Blend aditivo: los anillos brillan y el suelo se ve a través.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	input_pickable = true
	monitoring = false
	monitorable = false
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = R
	col.shape = shape
	add_child(col)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
	queue_redraw()


func _draw() -> void:
	# Intensidad base: sube al pasar el mouse y con el destello de activación.
	var a: float = 0.85
	if _hover:
		a = 1.15
	if _flash_t > 0.0:
		a = 1.0 + 1.6 * clampf(_flash_t / 0.5, 0.0, 1.0)
	a *= 0.9 + 0.15 * sin(_t * PULSE_SPEED)
	# Aplanar todo al plano del suelo (elipse).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	# Relleno muy tenue: deja ver el suelo.
	draw_circle(Vector2.ZERO, R, Color(C_FILL.r, C_FILL.g, C_FILL.b, 0.09 * a))
	# Anillo exterior.
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 40, Color(C_RING.r, C_RING.g, C_RING.b, 0.7 * a), 1.6, true)
	# Anillo interior en segmentos, girando.
	var seg: int = 10
	for i in seg:
		if i % 2 == 0:
			continue
		var a0: float = _t * ROT_SPEED + i * TAU / float(seg)
		draw_arc(Vector2.ZERO, R * 0.62, a0, a0 + TAU / float(seg), 6,
			Color(C_INNER.r, C_INNER.g, C_INNER.b, 0.65 * a), 1.4, true)
	# Chispas orbitando en sentido contrario.
	var dots: int = 6
	for i in dots:
		var ang: float = -_t * 0.8 + i * TAU / float(dots)
		var p: Vector2 = Vector2(cos(ang), sin(ang)) * R * 0.85
		draw_circle(p, 1.5, Color(C_RING.r, C_RING.g, C_RING.b, 0.85 * a))
	# Brillo central.
	draw_circle(Vector2.ZERO, R * 0.16, Color(1.0, 1.0, 1.0, 0.45 * a))


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
