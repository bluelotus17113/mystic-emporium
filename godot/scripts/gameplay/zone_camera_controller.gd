extends Camera2D
## Controla la cámara para alternar entre las 3 zonas. Cada zona tiene su centro y zoom.
## El switch se hace con flechas A/D, Q/E, o botones de la HUD.

signal zone_changed(zone_name: StringName)

# ponytail: Natural usa pos/zoom dinámicos vía _refresh_natural_zone() del manager.
# Los valores aquí son fallback iniciales.
var ZONES: Array = [
	{"name": &"natural",   "label": "Patio Natural", "pos": Vector2(-6000, 0), "zoom": 1.5},
	{"name": &"taller",    "label": "Taller",        "pos": Vector2(-1315, 0), "zoom": 1.15},
	{"name": &"recepcion", "label": "Recepción",     "pos": Vector2(-300, 0),  "zoom": 1.3},
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
var follow_protagonist: bool = false
var follow_target: Node2D = null  ## nodo a seguir (protagonista o worker)
var _zone_center: Vector2 = Vector2.ZERO
var _zone_half_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	ZoneExpansionManager.natural_level_changed.connect(_on_natural_level_changed)
	_refresh_natural_config(ZoneExpansionManager.natural_level)
	var z: Dictionary = ZONES[_current_index]
	position = z.pos
	zoom = Vector2(z.zoom, z.zoom)
	_apply_bounds(z.name)
	call_deferred("_apply_zone_visibility", z.name)
	# Ambiente sonoro por zona (fuego en taller, aves en patio…)
	zone_changed.connect(AudioManager.on_zone_changed)
	AudioManager.call_deferred("on_zone_changed", z.name)


func _on_natural_level_changed(level: int) -> void:
	_refresh_natural_config(level)
	if get_current_zone().name == &"natural":
		_apply_bounds(&"natural")


func _refresh_natural_config(_level: int) -> void:
	# Mapa de biomas 2D: la vista arranca en la pradera de inicio (borde derecho)
	# y se explora libremente con pan en las 4 direcciones.
	ZONES[0].pos = ZoneExpansionManager.starter_view()
	ZONES[0].zoom = 1.3


## Fija centro/medio-tamaño para el clamp de paneo. En Natural = el mapa entero
## (roam libre); en interior = el rect de la zona.
func _apply_bounds(zname: StringName) -> void:
	if zname == &"natural":
		_zone_center = ZoneExpansionManager.map_center()
		_zone_half_size = ZoneExpansionManager.map_rect().size * 0.5
	else:
		_zone_center = get_current_zone().pos
		_zone_half_size = _get_zone_half_size(zname)


func toggle_follow() -> void:
	# Botón del HUD: alterna seguir a la protagonista.
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if follow_target == proto and proto != null:
		stop_follow()
	else:
		follow_node(proto)


## Sigue a cualquier nodo con zoom cercano (workers, protagonista, gato…).
func follow_node(node: Node2D) -> void:
	if node == null:
		return
	follow_target = node
	follow_protagonist = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "zoom", Vector2(2.1, 2.1), 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func stop_follow() -> void:
	follow_target = null
	follow_protagonist = false
	var z: Dictionary = get_current_zone()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", _zone_center if _zone_center != Vector2.ZERO else z.pos, 0.4)
	_tween.tween_property(self, "zoom", Vector2(z.zoom, z.zoom), 0.4)


func is_following() -> bool:
	return follow_target != null


func _process(delta: float) -> void:
	if follow_target != null:
		if not is_instance_valid(follow_target):
			stop_follow()
			return
		position = position.lerp(follow_target.global_position + Vector2(0, -16), 0.12)
		return
	if get_current_zone().name != &"natural":
		return
	# Mapa de biomas: pan en las 4 direcciones con el borde del ratón.
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport_rect().size
	var pan_x: float = -1.0 if mp.x < EDGE_SCROLL_MARGIN else (1.0 if mp.x > vp.x - EDGE_SCROLL_MARGIN else 0.0)
	var pan_y: float = -1.0 if mp.y < EDGE_SCROLL_MARGIN else (1.0 if mp.y > vp.y - EDGE_SCROLL_MARGIN else 0.0)
	if pan_x == 0.0 and pan_y == 0.0:
		return
	position.x += pan_x * EDGE_SCROLL_SPEED * delta / zoom.x
	position.y += pan_y * EDGE_SCROLL_SPEED * delta / zoom.y
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
	follow_target = null
	follow_protagonist = false
	_goto_index((_current_index + 1) % ZONES.size())


func prev_zone() -> void:
	follow_target = null
	follow_protagonist = false
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
	_apply_bounds(z.name)
	# ponytail: visibility-toggle por grupos, mutuamente exclusivos. Cada zona muestra
	# solo sus nodos; gameplay sigue corriendo (los generadores no necesitan estar
	# visibles para tickear), solo cambiamos lo que se renderiza.
	_apply_zone_visibility(z.name)
	zone_changed.emit(z.name)


func _apply_zone_visibility(_zone_name: StringName) -> void:
	# Las tres áreas (Taller, Recepción, Patio Natural) permanecen SIEMPRE visibles:
	# es un solo mundo continuo, sin pop-in/out al cambiar de zona. Lo que está
	# fuera del encuadre lo descarta el propio render (culling), así que no cuesta.
	for grp in ["taller_visual", "recepcion_visual", "natural_visual"]:
		for n in get_tree().get_nodes_in_group(grp):
			n.visible = true


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


## Zoom libre con la rueda (multiplicativo, clamp). Cancela el follow si estaba.
func _zoom_by(factor: float) -> void:
	if is_following():
		stop_follow()
	var z: float = clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp_to_zone_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q, KEY_A: prev_zone()
			KEY_E, KEY_D: next_zone()
			KEY_1: goto_zone(&"natural")
			KEY_2: goto_zone(&"taller")
			KEY_3: goto_zone(&"recepcion")
	# Rueda = zoom libre en cualquier zona.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / ZOOM_STEP)
			return
	# Arrastre derecho = pan horizontal solo en Natural; otras zonas son fijas.
	if get_current_zone().name != &"natural":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_is_panning = event.pressed
	elif event is InputEventMouseMotion and _is_panning:
		position.x -= event.relative.x / zoom.x
		position.y -= event.relative.y / zoom.y
		_clamp_to_zone_bounds()


