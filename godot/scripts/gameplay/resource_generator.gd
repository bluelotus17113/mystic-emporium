class_name ResourceGenerator
extends Node2D

signal upgraded(new_level: int)
signal clicked(generator)

@export var item_data: ItemData
@export var resource_type: GameEnums.ResourceType = GameEnums.ResourceType.HERB
@export var resource_node_scene: PackedScene
@export var generation_cooldown: float = 6.0
@export var yield_per_node: int = 1

@export_group("Upgrades")
@export var current_level: int = 1
@export var upgrade_cost: int = 120
@export var cooldown_multiplier: float = 1.0
const UPGRADE_COOLDOWN_REDUCTION: float = 0.88
const UPGRADE_COST_MULTIPLIER: float = 1.9
const MAX_LEVEL: int = 5

@export_group("Zone Gating")
## ponytail: el generador solo se activa cuando el patio Natural alcanza este nivel.
@export var min_natural_level: int = 0

@onready var spawn_point: Marker2D = $SpawnPoint if has_node("SpawnPoint") else null

var _current_node: ResourceNode = null
var _timer: float = 0.0
var _waiting: bool = true
var _hover_label: Label = null


func _ready() -> void:
	add_to_group("generators")
	# Auto-asignar item_data si falta (necesario para generadores construidos en
	# runtime; el wire inicial del bootstrap solo cubre los que existen al cargar).
	ResourceManager.assign_item_to_generator(self)
	var area: Area2D = get_node_or_null("Area2D") as Area2D
	if area != null:
		area.input_event.connect(_on_area_input_event)
		area.mouse_entered.connect(_on_hover_enter)
		area.mouse_exited.connect(_on_hover_exit)
	ZoneExpansionManager.natural_level_changed.connect(_on_natural_level_changed)
	_apply_gating(ZoneExpansionManager.natural_level)
	_build_hover_label()
	# Defer initial spawn so parent finishes mounting its children first.
	call_deferred("_try_generate")


func _build_hover_label() -> void:
	_hover_label = Label.new()
	_hover_label.position = Vector2(-60, -70)
	_hover_label.custom_minimum_size = Vector2(120, 0)
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.add_theme_font_size_override(&"font_size", 11)
	_hover_label.add_theme_color_override(&"font_color", Color(1, 0.95, 0.7, 1))
	_hover_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_hover_label.add_theme_constant_override(&"outline_size", 4)
	_hover_label.visible = false
	_hover_label.z_index = 100
	add_child(_hover_label)


func _on_hover_enter() -> void:
	if _hover_label != null:
		_hover_label.visible = true
		_refresh_hover_text()


func _on_hover_exit() -> void:
	if _hover_label != null:
		_hover_label.visible = false


func _refresh_hover_text() -> void:
	if _hover_label == null or not _hover_label.visible:
		return
	var name_txt: String = item_data.display_name if item_data != null else "Recurso"
	var lines: Array[String] = []
	lines.append("%s · Nv %d" % [name_txt, current_level])
	if _current_node != null and is_instance_valid(_current_node) and _current_node.is_available():
		lines.append("✓ Listo para recolectar")
	else:
		var remaining: float = max(0.0, get_effective_cooldown() - _timer)
		lines.append("⏱ %.1fs" % remaining)
	lines.append("📦 %d/cosecha" % yield_per_node)
	if current_level < MAX_LEVEL:
		lines.append("⬆ %d⚜" % upgrade_cost)
	_hover_label.text = "\n".join(lines)


func _on_natural_level_changed(new_level: int) -> void:
	var was_active: bool = visible
	_apply_gating(new_level)
	if visible and not was_active:
		VFXManager.play(VFXManager.FX.UPGRADE, global_position)


func _apply_gating(level: int) -> void:
	# ponytail: locked = alpha 0 (invisible pero el nodo sigue existiendo). Combina bien con
	# el visibility-toggle por zona del ZoneCameraController (la zona controla `visible`,
	# el gating controla `modulate.a`). Effective: visible solo si zona ON + level OK.
	var unlocked: bool = level >= min_natural_level
	modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0)
	set_process(unlocked)
	if _current_node != null and is_instance_valid(_current_node):
		_current_node.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func get_effective_cooldown() -> float:
	return generation_cooldown * cooldown_multiplier


func try_upgrade() -> bool:
	if current_level >= MAX_LEVEL:
		return false
	if not InventoryManager.spend_coins(upgrade_cost):
		return false
	current_level += 1
	cooldown_multiplier *= UPGRADE_COOLDOWN_REDUCTION
	# Bonus de yield en niveles clave (3 y 5) para que la mejora se sienta tangible
	# además del cooldown reducido. Curva: lvl 1→1, lvl 2→1, lvl 3→2, lvl 4→2, lvl 5→3.
	if current_level == 3 or current_level == 5:
		yield_per_node += 1
	upgrade_cost = int(upgrade_cost * UPGRADE_COST_MULTIPLIER)
	VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	AudioManager.play_beep(1240.0, 0.15, -10.0)
	StatsManager.bump("upgrades_done", 1)
	upgraded.emit(current_level)
	return true


func _process(delta: float) -> void:
	if _hover_label != null and _hover_label.visible:
		_refresh_hover_text()
	if _current_node != null and _current_node.is_available():
		# Node still there, nothing to do
		return
	if _waiting:
		_timer += delta
		if _timer >= get_effective_cooldown():
			_timer = 0.0
			_try_generate()


func _try_generate() -> void:
	if resource_node_scene == null:
		_waiting = true
		return
	_current_node = resource_node_scene.instantiate() as ResourceNode
	if _current_node == null:
		_waiting = true
		return
	_current_node.item_data = item_data if item_data != null else _current_node.item_data
	_current_node.resource_type = resource_type
	_current_node.yield_quantity = yield_per_node
	_current_node.set_generator_owner(self)
	var parent_node := get_parent()
	if parent_node == null:
		_waiting = true
		return
	parent_node.add_child(_current_node)
	# ponytail: el resource node pertenece al patio — heredamos el grupo del generator
	# para que el camera zone-toggle lo oculte cuando el jugador está en Taller/Recepción.
	_current_node.add_to_group("natural_visual")
	var cam = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		_current_node.visible = cam.get_current_zone().name == &"natural"
	var spawn_pos: Vector2 = global_position
	if spawn_point != null:
		spawn_pos = spawn_point.global_position
	_current_node.global_position = spawn_pos
	_waiting = false


func on_node_collected(_node: ResourceNode) -> void:
	_current_node = null
	_waiting = true
	_timer = 0.0
