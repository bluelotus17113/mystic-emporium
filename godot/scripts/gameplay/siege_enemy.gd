class_name SiegeEnemy
extends CharacterBody2D
## Ogro del asedio: aparece por la izquierda del patio, avanza hacia la base
## (el cultivo) y la ataca al llegar. Las torretas/aliados lo dañan. Al morir da
## monedas. Animaciones PixelLab (ogre_walk / ogre_attack).

const WALK_TEX := "res://art/sprites/characters/ogre_walk.png"

var speed: float = 34.0
var attack_range: float = 46.0
var attack_damage: float = 8.0
var attack_interval: float = 1.1
var coin_reward: int = 12

const DIVERT_RADIUS: float = 130.0  ## se desvía a atacar defensores dentro de este radio
const AVOID_COMMIT: float = 0.5     ## rodea obstáculos siguiendo la pared un instante

var _target_pos: Vector2 = Vector2.ZERO
var _atk_cd: float = 0.0
var _spr: AnimatedSprite2D = null
var _hb: HealthBar = null
var _atk_target: Node2D = null  ## worker/torreta que ataca (null = avanza a la base)
var _retarget_cd: float = 0.0
var _avoid_dir: Vector2 = Vector2.ZERO
var _avoid_time: float = 0.0


func setup(target_pos: Vector2, hp: float, spd: float, dmg: float, reward: int) -> void:
	_target_pos = target_pos
	speed = spd
	attack_damage = dmg
	coin_reward = reward
	if _hb != null:
		_hb.setup(hp, -48.0, false)


func _ready() -> void:
	add_to_group("siege_enemies")
	z_index = 0
	_spr = AnimatedSprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -30)
	_spr.sprite_frames = _make_frames()
	_spr.play(&"walk")
	add_child(_spr)
	CharShadow.attach(self, 20.0)
	_hb = HealthBar.new()
	add_child(_hb)
	if _hb.max_hp <= 0.0:
		_hb.setup(60.0, -48.0, false)
	_hb.died.connect(_die)
	# colisión de cuerpo (para que las torretas no se solapen y el slide funcione)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	col.shape = circ
	col.position = Vector2(0, -6)
	add_child(col)


func _make_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	_add_anim(sf, &"walk", WALK_TEX, 4, 7.0, true)
	return sf


func _add_anim(sf: SpriteFrames, anim: StringName, path: String, count: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = load(path)
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, fps)
	if tex == null:
		return
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame(anim, at)


## Recibe daño (lo llama el proyectil / aliados).
func hit(damage: float) -> void:
	if _hb != null:
		_hb.take_damage(damage)
		modulate = Color(1.6, 1.2, 1.2)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)
		AudioManager.play_positional(&"ogre_hit", global_position, 0.18)


func _physics_process(delta: float) -> void:
	if _hb != null and not _hb.is_alive():
		return
	_retarget_cd -= delta
	if _atk_target != null and not _is_valid_target(_atk_target):
		_atk_target = null
	if _retarget_cd <= 0.0:
		_retarget_cd = 0.3
		_pick_attack_target()
	# Objetivo de movimiento: un defensor cercano si lo hay, si no la base.
	var goal: Vector2 = _atk_target.global_position if _atk_target != null else _target_pos
	var d: Vector2 = goal - global_position
	if d.length() <= attack_range:
		velocity = Vector2.ZERO
		_atk_cd -= delta
		if _atk_cd <= 0.0:
			_atk_cd = attack_interval
			if _atk_target != null and _atk_target.has_method("hit"):
				_atk_target.hit(attack_damage)
			elif _atk_target == null:
				SiegeManager.damage_base(attack_damage)
			_lunge(d.normalized())
	else:
		_drive(goal, delta)
	if _spr != null and absf(velocity.x) > 1.0:
		_spr.flip_h = velocity.x < 0.0


## Avanza hacia `goal` esquivando obstáculos: al chocar, sigue la tangente de la
## pared hacia el lado que acerca al objetivo (rodea piedras/árboles en vez de
## quedarse recto). Mismo steering ligero que los workers.
func _drive(goal: Vector2, delta: float) -> void:
	var desired: Vector2 = (goal - global_position).normalized()
	var move_dir: Vector2 = desired
	if _avoid_time > 0.0:
		_avoid_time -= delta
		move_dir = (_avoid_dir * 0.85 + desired * 0.35).normalized()
	velocity = move_dir * speed
	move_and_slide()
	var col := get_last_slide_collision()
	if col != null:
		var n: Vector2 = col.get_normal()
		if desired.dot(-n) > 0.2:
			var t1 := Vector2(-n.y, n.x)
			var t2 := -t1
			_avoid_dir = t1 if t1.dot(desired) > t2.dot(desired) else t2
			_avoid_time = AVOID_COMMIT
	elif _avoid_time <= 0.0:
		_avoid_dir = Vector2.ZERO


## Busca el defensor (worker/torreta) más cercano dentro de DIVERT_RADIUS.
func _pick_attack_target() -> void:
	var best: Node2D = null
	var best_d: float = DIVERT_RADIUS
	for grp in ["workers", "siege_turrets", "protagonist"]:
		for n in get_tree().get_nodes_in_group(grp):
			var n2: Node2D = n as Node2D
			if not _is_valid_target(n2):
				continue
			var dist: float = global_position.distance_to(n2.global_position)
			if dist < best_d:
				best_d = dist
				best = n2
	_atk_target = best


func _is_valid_target(n: Node2D) -> bool:
	if n == null or not is_instance_valid(n) or not n.has_method("hit"):
		return false
	if n.has_method("is_downed") and n.is_downed():
		return false
	return true


## Golpe: como el frame de ataque salió feo, hacemos un embiste procedural
## (el sprite se lanza hacia la base y vuelve).
func _lunge(dir: Vector2) -> void:
	if _spr == null:
		return
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(0, -30) + dir * 10.0, 0.09)
	tw.tween_property(_spr, "position", Vector2(0, -30), 0.16)


func _die() -> void:
	InventoryManager.add_coins(coin_reward)
	VFXManager.play(VFXManager.FX.BUILD, global_position)
	AudioManager.play_positional(&"ogre_die", global_position, 0.12)
	SiegeManager.on_enemy_died(self)
	queue_free()
