extends Node2D
## Torreta de defensa (buildable): durante un asedio apunta al ogro más cercano en
## rango y dispara proyectiles. Parametrizable por escena (torreta normal / de
## escarcha que ralentiza). Fuera del asedio está tranquila (cozy).

const PROJECTILE := preload("res://scripts/gameplay/siege_projectile.gd")

@export var tex_path: String = "res://art/sprites/environment/siege_turret.png"
@export var fire_range: float = 200.0
@export var fire_interval: float = 0.9
@export var damage: float = 14.0
@export var slow_factor: float = 1.0   ## <1.0 = ralentiza al impactar (torreta de escarcha)
@export var slow_dur: float = 1.6
@export var proj_color: Color = Color(0.7, 0.9, 1.0)
@export var aoe_radius: float = 0.0   ## >0 = daño en área (mortero)
@export var max_hp: float = 90.0
@export var display_name: String = "Torreta"

const MAX_LEVEL: int = 3
var _level: int = 1
var _cd: float = 0.0
var _spr: Sprite2D = null
var _hb: HealthBar = null


func _ready() -> void:
	add_to_group("siege_turrets")
	_spr = Sprite2D.new()
	_spr.texture = load(tex_path)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -16)
	add_child(_spr)
	_hb = HealthBar.new()
	add_child(_hb)
	_hb.setup(max_hp, -44.0, false)
	_hb.died.connect(_destroyed)
	_setup_click()


## Recibe daño de un ogro (la torreta puede ser destruida durante el asedio).
func hit(amount: float) -> void:
	if _hb == null:
		return
	_hb.take_damage(amount)
	if _spr != null:
		_spr.modulate = Color(1.6, 1.2, 1.2)
		create_tween().tween_property(_spr, "modulate", Color.WHITE, 0.18)


func _destroyed() -> void:
	VFXManager.play(VFXManager.FX.BUILD, global_position)
	AudioManager.play_beep(160.0, 0.16, -8.0)
	if GridManager.has_method("remove_area"):
		GridManager.remove_area(self)
	queue_free()


func _process(delta: float) -> void:
	if not SiegeManager.is_active():
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var target: Node2D = _nearest_enemy()
	if target == null:
		return
	_cd = fire_interval
	_fire(target)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = fire_range
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		var n: Node2D = e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _fire(target: Node2D) -> void:
	var p := PROJECTILE.new()
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(p)
	p.global_position = global_position + Vector2(0, -22)
	p.setup(target, damage, slow_factor, slow_dur, proj_color, aoe_radius)
	AudioManager.play_beep(720.0, 0.06, -16.0)
	if _spr != null:
		var tw := create_tween()
		tw.tween_property(_spr, "scale", Vector2(1.15, 0.9), 0.05)
		tw.tween_property(_spr, "scale", Vector2.ONE, 0.12)


# ---------- Mejora al hacer clic ----------

func _setup_click() -> void:
	var area := Area2D.new()
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 22.0
	cs.shape = circ
	cs.position = Vector2(0, -14)
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
	return 70 * _level


func upgrade() -> void:
	if _level >= MAX_LEVEL:
		return
	if not InventoryManager.spend_coins(_upgrade_cost()):
		NotificationManager.post("Faltan monedas para mejorar.", NotificationManager.Kind.INFO)
		return
	_level += 1
	damage *= 1.4
	fire_range *= 1.08
	if aoe_radius > 0.0:
		aoe_radius *= 1.12
	if _hb != null:
		_hb.max_hp *= 1.25
		_hb.hp = _hb.max_hp
	VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	AudioManager.play_named(&"level_up")


func _stats_data() -> Array:
	var out: Array = [
		{"label": "Nivel", "text": "%d/%d" % [_level, MAX_LEVEL]},
		{"label": "Daño", "text": "%d" % int(round(damage))},
		{"label": "Rango", "text": "%d" % int(round(fire_range))},
	]
	if aoe_radius > 0.0:
		out.append({"label": "Área", "text": "%d" % int(round(aoe_radius))})
	if slow_factor < 1.0:
		out.append({"label": "Ralentiza", "text": "%d%%" % int(round((1.0 - slow_factor) * 100.0))})
	return out
