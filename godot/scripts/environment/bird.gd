class_name Bird
extends Sprite2D
## Pajarito que se posa en la copa de un árbol, pía y da saltitos. Si la
## protagonista o un worker se acercan, sale volando en un arco hasta otro
## árbol. De noche se recoge (no visible). La crea NaturalLife.

enum St { PERCH, FLY }

const SHEET: String = "res://art/sprites/environment/bird_fly.png"
const FRAME: int = 48           ## ancho/alto de cada frame en la hoja
const FLY_FRAMES: Array = [0, 1, 2, 1]  ## ciclo de aleteo
const FOLD_FRAME: int = 3       ## alas plegadas (posado)
const FLAP_FPS: float = 14.0    ## velocidad de aleteo al volar
const FLUTTER_FPS: float = 9.0  ## aleteo suave y breve al despegar/aterrizar

const TWEET_MIN: float = 3.5
const TWEET_MAX: float = 8.0
const PERCH_MIN: float = 6.0   ## cada cuánto cambia de árbol por su cuenta
const PERCH_MAX: float = 16.0
const STARTLE_RADIUS: float = 74.0
const FLY_TIME: float = 1.1
const ARC_HEIGHT: float = 70.0

var _rect: Rect2 = Rect2()
var _st: int = St.PERCH
var _tweet_cd: float = 0.0
var _perch_cd: float = 0.0
var _scan_cd: float = 0.0
var _bob_t: float = 0.0
var _anim_t: float = 0.0     ## acumulador de frames de aleteo
var _flutter: float = 0.0    ## aleteo breve estando posado (al piar/aterrizar)
var _fly_t: float = 0.0
var _fly_from: Vector2 = Vector2.ZERO
var _fly_to: Vector2 = Vector2.ZERO
var _tweet: Label = null


func setup(rect: Rect2) -> void:
	_rect = rect


func _ready() -> void:
	add_to_group("natural_visual")
	texture = load(SHEET)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	_set_frame(FOLD_FRAME)
	scale = Vector2(0.55, 0.55)
	z_index = 3
	_tweet = Label.new()
	_tweet.text = "♪"
	_tweet.position = Vector2(2, -22)
	_tweet.modulate.a = 0.0
	_tweet.z_index = 20
	add_child(_tweet)
	_tweet_cd = randf_range(TWEET_MIN, TWEET_MAX)
	_perch_cd = randf_range(PERCH_MIN, PERCH_MAX)
	global_position = _pick_perch()


func _process(delta: float) -> void:
	# De noche los pájaros se recogen.
	if CalendarManager.get_darkness() > 0.55:
		visible = false
		return
	visible = true
	var base_off: float = -FRAME * 0.5
	match _st:
		St.PERCH:
			_bob_t += delta * 3.0
			offset = Vector2(0, base_off + sin(_bob_t) * 1.2)
			# Alas plegadas; al piar o recién aterrizar, un aleteo breve.
			if _flutter > 0.0:
				_flutter -= delta
				_anim_t += delta * FLUTTER_FPS
				_set_frame(FLY_FRAMES[int(_anim_t) % FLY_FRAMES.size()])
			else:
				_set_frame(FOLD_FRAME)
			_tweet_cd -= delta
			if _tweet_cd <= 0.0:
				_tweet_cd = randf_range(TWEET_MIN, TWEET_MAX)
				_puff("♪")
				_flutter = 0.45
				_anim_t = 0.0
			_scan_cd -= delta
			if _scan_cd <= 0.0:
				_scan_cd = 0.25
				if _intruder_near():
					_flee(true)
					return
			_perch_cd -= delta
			if _perch_cd <= 0.0:
				_perch_cd = randf_range(PERCH_MIN, PERCH_MAX)
				_flee(false)
		St.FLY:
			# Aleteo continuo mientras vuela.
			_anim_t += delta * FLAP_FPS
			_set_frame(FLY_FRAMES[int(_anim_t) % FLY_FRAMES.size()])
			offset = Vector2(0, base_off)
			_fly_t += delta / FLY_TIME
			if _fly_t >= 1.0:
				global_position = _fly_to
				_flutter = 0.5  # aleteo breve al posarse
				_anim_t = 0.0
				_st = St.PERCH
				return
			var p: Vector2 = _fly_from.lerp(_fly_to, _fly_t)
			p.y -= sin(_fly_t * PI) * ARC_HEIGHT
			global_position = p
			flip_h = _fly_to.x < _fly_from.x


func _set_frame(i: int) -> void:
	region_rect = Rect2(i * FRAME, 0, FRAME, FRAME)


func _flee(startled: bool) -> void:
	_fly_from = global_position
	_fly_to = _pick_perch()
	_fly_t = 0.0
	_st = St.FLY
	if startled:
		_puff("!")


## Un punto de posado: la copa de un árbol al azar; si no hay, un punto alto.
func _pick_perch() -> Vector2:
	var trees: Array = []
	for n in get_tree().get_nodes_in_group("foliage"):
		if n is TreeWind and is_instance_valid(n):
			trees.append(n)
	if not trees.is_empty():
		var t: Node2D = trees[randi() % trees.size()] as Node2D
		return t.global_position + Vector2(randf_range(-16.0, 16.0), -randf_range(58.0, 88.0))
	if _rect.size == Vector2.ZERO:
		return global_position
	return Vector2(
		randf_range(_rect.position.x + 40.0, _rect.end.x - 40.0),
		randf_range(_rect.position.y + 40.0, _rect.position.y + _rect.size.y * 0.4))


func _intruder_near() -> bool:
	for g in ["protagonist", "workers"]:
		for n in get_tree().get_nodes_in_group(g):
			var n2: Node2D = n as Node2D
			if n2 != null and is_instance_valid(n2) and n2.visible \
					and global_position.distance_to(n2.global_position) < STARTLE_RADIUS:
				return true
	return false


func _puff(txt: String) -> void:
	if _tweet == null:
		return
	_tweet.text = txt
	var base_y: float = -22.0
	_tweet.position.y = base_y
	_tweet.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tweet, "modulate:a", 0.9, 0.2)
	tw.parallel().tween_property(_tweet, "position:y", base_y - 12.0, 1.2)
	tw.tween_property(_tweet, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _tweet.position.y = base_y)
