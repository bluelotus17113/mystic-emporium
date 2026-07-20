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

var _target_pos: Vector2 = Vector2.ZERO
var _atk_cd: float = 0.0
var _spr: AnimatedSprite2D = null
var _hb: HealthBar = null


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


func _physics_process(delta: float) -> void:
	if _hb != null and not _hb.is_alive():
		return
	var d: Vector2 = _target_pos - global_position
	if d.length() <= attack_range:
		velocity = Vector2.ZERO
		_atk_cd -= delta
		if _atk_cd <= 0.0:
			_atk_cd = attack_interval
			SiegeManager.damage_base(attack_damage)
			_lunge(d.normalized())
	else:
		velocity = d.normalized() * speed
		move_and_slide()
	if _spr != null and absf(velocity.x) > 1.0:
		_spr.flip_h = velocity.x < 0.0


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
	AudioManager.play_beep(180.0, 0.14, -10.0)
	SiegeManager.on_enemy_died(self)
	queue_free()
