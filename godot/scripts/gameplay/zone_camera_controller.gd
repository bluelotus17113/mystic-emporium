extends Camera2D
## Controla la cámara para alternar entre las 3 zonas. Cada zona tiene su centro y zoom.
## El switch se hace con flechas A/D, Q/E, o botones de la HUD.

signal zone_changed(zone_name: StringName)

# ponytail: Natural usa pos/zoom dinámicos vía _refresh_natural_zone() del manager.
# Los valores aquí son fallback iniciales.
var ZONES: Array = [
	{"name": &"natural",   "label": "Patio Natural", "pos": Vector2(1400, 0),  "zoom": 1.5},
	{"name": &"taller",    "label": "Taller",        "pos": Vector2(-1500, 0), "zoom": 1.0},
	{"name": &"recepcion", "label": "Recepción",     "pos": Vector2(-300, 0),  "zoom": 1.2},
]

const TWEEN_DURATION: float = 0.45
const PAN_BOUND_MARGIN: float = 200.0  ## cuánto puedes salirte del rect de la zona
const EDGE_SCROLL_MARGIN: float = 35.0  ## px desde el borde para activar pan automático
const EDGE_SCROLL_SPEED: float = 900.0  ## world units / seg (compensado por zoom)
const ZOOM_STEP: float = 1.12
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 2.5

var _current_index: int = 1  ## arranca en Taller (centro)
var _tween: Tween = null
var _is_panning: bool = false
var _zone_center: Vector2 = Vector2.ZERO
var _zone_half_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	ZoneExpansionManager.natural_level_changed.connect(_on_natural_level_changed)
	_refresh_natural_config(ZoneExpansionManager.natural_level)
	var z: Dictionary = ZONES[_current_index]
	position = z.pos
	zoom = Vector2(z.zoom, z.zoom)
	_zone_center = z.pos
	_zone_half_size = _get_zone_half_size(z.name)
	call_deferred("_apply_zone_visibility", z.name)


func _on_natural_level_changed(level: int) -> void:
	_refresh_natural_config(level)
	if get_current_zone().name == &"natural":
		_zone_half_size = ZoneExpansionManager.get_size_for(level) * 0.5
		_zone_center = ZONES[0].pos


func _refresh_natural_config(level: int) -> void:
	var size: Vector2 = ZoneExpansionManager.get_size_for(level)
	# Filosofía idle: zoom para que se vea toda la altura. La anchura se navega panneando.
	var z: float = clamp(600.0 / size.y, 0.7, 2.0)
	ZONES[0].pos = ZoneExpansionManager.get_center_for(level)
	ZONES[0].zoom = z


func _process(delta: float) -> void:
	if get_current_zone().name != &"natural":
		return
	# ponytail: filosofía idle horizontal — solo paneo lateral, nada vertical.
	var mouse_x: float = get_viewport().get_mouse_position().x
	var vp_w: float = get_viewport_rect().size.x
	var pan_x: float = -1.0 if mouse_x < EDGE_SCROLL_MARGIN else (1.0 if mouse_x > vp_w - EDGE_SCROLL_MARGIN else 0.0)
	if pan_x == 0.0:
		return
	position.x += pan_x * EDGE_SCROLL_SPEED * delta / zoom.x
	_clamp_to_zone_bounds()


func _clamp_to_zone_bounds() -> void:
	var min_p: Vector2 = _zone_center - _zone_half_size - Vector2(PAN_BOUND_MARGIN, PAN_BOUND_MARGIN)
	var max_p: Vector2 = _zone_center + _zone_half_size + Vector2(PAN_BOUND_MARGIN, PAN_BOUND_MARGIN)
	position = position.clamp(min_p, max_p)


func goto_zone(zone_name: StringName) -> void:
	for i in ZONES.size():
		if ZONES[i].name == zone_name:
			_goto_index(i)
			return


func next_zone() -> void:
	_goto_index((_current_index + 1) % ZONES.size())


func prev_zone() -> void:
	_goto_index((_current_index - 1 + ZONES.size()) % ZONES.size())


func _goto_index(i: int) -> void:
	if i == _current_index:
		return
	_current_index = i
	var z: Dictionary = ZONES[i]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", z.pos, TWEEN_DURATION)
	_tween.tween_property(self, "zoom", Vector2(z.zoom, z.zoom), TWEEN_DURATION)
	# Cargar bounds del rect de la zona para constraint de paneo (solo Natural lo usa).
	_zone_center = z.pos
	_zone_half_size = _get_zone_half_size(z.name)
	# ponytail: visibility-toggle por grupos, mutuamente exclusivos. Cada zona muestra
	# solo sus nodos; gameplay sigue corriendo (los generadores no necesitan estar
	# visibles para tickear), solo cambiamos lo que se renderiza.
	_apply_zone_visibility(z.name)
	zone_changed.emit(z.name)


func _apply_zone_visibility(zone_name: StringName) -> void:
	for zn in [&"natural", &"taller", &"recepcion"]:
		var on: bool = zone_name == zn
		for n in get_tree().get_nodes_in_group(String(zn) + "_visual"):
			n.visible = on


func _get_zone_half_size(zone_name: StringName) -> Vector2:
	# Lookup contra los ZoneRegion en el árbol; si no encuentra, default al ancho de viewport.
	var zones_node: Node = get_tree().get_first_node_in_group("world_container")
	if zones_node != null:
		zones_node = zones_node.get_parent().get_node_or_null("Zones")
	if zones_node != null:
		for c in zones_node.get_children():
			if c is ZoneRegion and c.label_text.to_lower().contains(String(zone_name)):
				return c.size * 0.5
	return Vector2(600, 400)


func get_current_zone() -> Dictionary:
	return ZONES[_current_index]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q, KEY_A: prev_zone()
			KEY_E, KEY_D: next_zone()
			KEY_1: goto_zone(&"natural")
			KEY_2: goto_zone(&"taller")
			KEY_3: goto_zone(&"recepcion")
	# ponytail: rueda/drag = pan horizontal solo en Natural; otras zonas son fijas.
	if get_current_zone().name != &"natural":
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				position.x += 120.0 / zoom.x
				_clamp_to_zone_bounds()
			MOUSE_BUTTON_WHEEL_UP:
				position.x -= 120.0 / zoom.x
				_clamp_to_zone_bounds()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_is_panning = event.pressed
	elif event is InputEventMouseMotion and _is_panning:
		position.x -= event.relative.x / zoom.x
		_clamp_to_zone_bounds()


