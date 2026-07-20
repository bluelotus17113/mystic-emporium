extends Node2D
## Trampa buildable: durante un asedio daña a los ogros que pisan su radio, con un
## pulso periódico. Parametrizable por escena (púas / fuego). Inactiva en calma.

@export var tex_path: String = "res://art/sprites/environment/siege_trap.png"
@export var radius: float = 62.0
@export var damage: float = 9.0
@export var interval: float = 0.85
@export var glow_tint: Color = Color(1.0, 0.75, 1.1, 1.0)
@export var display_name: String = "Trampa"

const MAX_LEVEL: int = 3
var _level: int = 1
var _cd: float = 0.0
var _pulse: float = 0.0
var _spr: Sprite2D = null


func _ready() -> void:
	add_to_group("siege_traps")
	z_index = -1  # en el suelo, bajo los personajes
	_spr = Sprite2D.new()
	_spr.texture = load(tex_path)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_setup_click()


func _setup_click() -> void:
	var area := Area2D.new()
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 20.0
	cs.shape = circ
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(func(_vp, ev, _idx):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if BuildManager.is_active() or BuildManager.is_move_active() \
					or BuildManager.is_demolish_active() or BuildManager.is_copy_active():
				return
			_open_menu()
			get_viewport().set_input_as_handled())


func _open_menu() -> void:
	var menu: Node = get_tree().get_first_node_in_group("entity_menu")
	if menu == null or not menu.has_method("open_for"):
		return
	var actions: Array = []
	if _level < MAX_LEVEL:
		actions.append({"text": "⬆ Mejorar (%d ⚜)" % _upgrade_cost(), "cb": Callable(self, "upgrade")})
	menu.open_for(self, "%s · Nv %d" % [display_name, _level], actions, Callable(self, "_stats_data"), _spr.texture if _spr != null else null)


func _upgrade_cost() -> int:
	return 55 * _level


func upgrade() -> void:
	if _level >= MAX_LEVEL:
		return
	if not InventoryManager.spend_coins(_upgrade_cost()):
		NotificationManager.post("Faltan monedas para mejorar.", NotificationManager.Kind.INFO)
		return
	_level += 1
	_apply_level_bonus()
	VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	AudioManager.play_named(&"level_up")


func _apply_level_bonus() -> void:
	damage *= 1.45
	radius *= 1.1


func get_upgrade_level() -> int:
	return _level


## Reaplica las mejoras al cargar el save (sin cobrar).
func set_upgrade_level(lvl: int) -> void:
	lvl = clampi(lvl, 1, MAX_LEVEL)
	while _level < lvl:
		_level += 1
		_apply_level_bonus()


func _stats_data() -> Array:
	return [
		{"label": "Nivel", "text": "%d/%d" % [_level, MAX_LEVEL]},
		{"label": "Daño", "text": "%d" % int(round(damage))},
		{"label": "Radio", "text": "%d" % int(round(radius))},
	]


func _process(delta: float) -> void:
	_pulse += delta
	if _spr != null:
		if SiegeManager.is_active():
			var g: float = 0.75 + 0.25 * sin(_pulse * 4.0)
			_spr.modulate = Color(glow_tint.r * g, glow_tint.g * g, glow_tint.b * g, 1.0)
		else:
			_spr.modulate = Color(1, 1, 1, 0.7)
	if not SiegeManager.is_active():
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var hit_any: bool = false
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		var n: Node2D = e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if global_position.distance_to(n.global_position) <= radius and n.has_method("hit"):
			n.hit(damage)
			hit_any = true
	if hit_any:
		_cd = interval
		VFXManager.play(VFXManager.FX.BUILD, global_position)
		AudioManager.play_beep(320.0, 0.06, -18.0)
