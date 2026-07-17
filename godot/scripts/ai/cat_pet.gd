extends CharacterBody2D
## Mascota de la tienda: gato que duerme cerca de la forja, pasea por su zona
## y a veces sigue a la protagonista. Pura vida ambiental, no bloquea nada.

enum State { SLEEP, WANDER, FOLLOW }

const WANDER_SPEED: float = 46.0
const FOLLOW_SPEED: float = 78.0
const SLEEP_MIN: float = 22.0
const SLEEP_MAX: float = 45.0
const AWAKE_MIN: float = 8.0
const AWAKE_MAX: float = 16.0

var state: State = State.SLEEP
var home_position: Vector2 = Vector2.ZERO
var _timer: float = 10.0
var _wander_target: Vector2 = Vector2.ZERO
var _facing: StringName = &"down"
var _facing_x: float = 1.0
var _zzz: Label = null
var _zzz_accum: float = 0.0

@onready var _spr: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("pets")
	CharShadow.attach(self, 18.0)
	home_position = global_position
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	_zzz = Label.new()
	_zzz.text = "💤"
	_zzz.position = Vector2(6.0, -44.0)
	_zzz.modulate.a = 0.0
	add_child(_zzz)


func _physics_process(delta: float) -> void:
	_timer -= delta
	match state:
		State.SLEEP:
			velocity = Vector2.ZERO
			_zzz_accum += delta
			if _zzz_accum >= 3.0:
				_zzz_accum = 0.0
				_puff_zzz()
			if _timer <= 0.0:
				_wake()
		State.WANDER:
			var dir: Vector2 = _wander_target - global_position
			if dir.length() < 6.0:
				velocity = Vector2.ZERO
				_pick_wander()
			else:
				velocity = dir.normalized() * WANDER_SPEED
				move_and_slide()
			if _timer <= 0.0:
				_go_sleep()
		State.FOLLOW:
			var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
			if proto == null:
				_go_sleep()
			else:
				var d: Vector2 = proto.global_position + Vector2(26, 10) - global_position
				if d.length() > 26.0:
					velocity = d.normalized() * FOLLOW_SPEED
					move_and_slide()
				else:
					velocity = Vector2.ZERO
			if _timer <= 0.0:
				_go_sleep()
	_update_anim()


func _wake() -> void:
	# Al despertar: 40% sigue a la protagonista, 60% pasea.
	_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
	if randf() < 0.4 and get_tree().get_first_node_in_group("protagonist") != null:
		state = State.FOLLOW
	else:
		state = State.WANDER
		_pick_wander()


func _go_sleep() -> void:
	state = State.SLEEP
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	global_position = global_position  # se duerme donde esté
	_zzz_accum = 0.0


func _pick_wander() -> void:
	var rect: Rect2 = GridManager.get_zone_rect_at(home_position)
	if rect.size == Vector2.ZERO:
		rect = Rect2(home_position - Vector2(90, 60), Vector2(180, 120))
	_wander_target = Vector2(
		randf_range(rect.position.x + 30.0, rect.end.x - 30.0),
		randf_range(rect.position.y + 60.0, rect.end.y - 24.0))


func _puff_zzz() -> void:
	var tw := create_tween()
	_zzz.position = Vector2(6.0, -44.0)
	tw.tween_property(_zzz, "modulate:a", 0.9, 0.3)
	tw.parallel().tween_property(_zzz, "position:y", -58.0, 1.6)
	tw.tween_property(_zzz, "modulate:a", 0.0, 0.5)


func _update_anim() -> void:
	if _spr == null or _spr.sprite_frames == null:
		return
	if state == State.SLEEP:
		if _spr.animation != &"sleep":
			_spr.play(&"sleep")
		return
	var moving: bool = velocity.length_squared() > 4.0
	if moving:
		if absf(velocity.x) > absf(velocity.y):
			_facing = &"side"
			_facing_x = signf(velocity.x)
		else:
			_facing = &"down" if velocity.y > 0.0 else &"up"
	_spr.flip_h = _facing == &"side" and _facing_x < 0.0
	var want: StringName = (&"walk_" if moving else &"idle_") + _facing
	if _spr.animation != want:
		_spr.play(want)
