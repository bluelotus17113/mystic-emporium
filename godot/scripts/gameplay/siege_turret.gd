extends Node2D
## Torreta de defensa (buildable): durante un asedio apunta al ogro más cercano en
## rango y dispara proyectiles arcanos. Fuera del asedio está tranquila (cozy).

const PROJECTILE := preload("res://scripts/gameplay/siege_projectile.gd")
const TEX := "res://art/sprites/environment/siege_turret.png"

var fire_range: float = 200.0
var fire_interval: float = 0.9
var damage: float = 14.0
var _cd: float = 0.0
var _spr: Sprite2D = null


func _ready() -> void:
	add_to_group("siege_turrets")
	_spr = Sprite2D.new()
	_spr.texture = load(TEX)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -16)
	add_child(_spr)


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
	p.setup(target, damage)
	AudioManager.play_beep(720.0, 0.06, -16.0)
	if _spr != null:
		var tw := create_tween()
		tw.tween_property(_spr, "scale", Vector2(1.15, 0.9), 0.05)
		tw.tween_property(_spr, "scale", Vector2.ONE, 0.12)
