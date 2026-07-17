extends CharacterBody2D
## Mascota de la tienda: gato con comportamientos variados — dormir, pasear,
## sentarse, acicalarse, jugar (abalanzarse) y seguir a la protagonista.
## Clic izquierdo → menú contextual (seguir con la cámara). Emotes sueltos.

enum State { SLEEP, WANDER, SIT, GROOM, PLAY, FOLLOW }

const WANDER_SPEED: float = 42.0
const FOLLOW_SPEED: float = 78.0
const POUNCE_SPEED: float = 150.0
const SLEEP_MIN: float = 20.0
const SLEEP_MAX: float = 40.0
const AWAKE_MIN: float = 8.0
const AWAKE_MAX: float = 16.0
const EMOTES: Array = ["♥", "🐾", "🐟", "✨", "🧶", "😽"]

var state: State = State.SLEEP
var home_position: Vector2 = Vector2.ZERO
var _timer: float = 10.0
var _wander_target: Vector2 = Vector2.ZERO
var _facing: StringName = &"down"
var _facing_x: float = 1.0
var _zzz: Label = null
var _emote: Label = null
var _zzz_accum: float = 0.0
var _emote_accum: float = 0.0
var _pounces: int = 0
var _bob_t: float = 0.0

@onready var _spr: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("pets")
	CharShadow.attach(self, 14.0)
	home_position = global_position
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	_zzz = _make_bubble("💤", Vector2(6.0, -40.0))
	_emote = _make_bubble("♥", Vector2(4.0, -44.0))
	_setup_click_area()
	_emote_accum = randf_range(4.0, 9.0)


func _make_bubble(txt: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.modulate.a = 0.0
	l.z_index = 20
	add_child(l)
	return l


func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	cs.shape = circ
	cs.position = Vector2(0, -12)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(func(_vp, ev, _idx):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if BuildManager.is_active() or BuildManager.is_move_active() \
					or BuildManager.is_demolish_active():
				return
			var menu: Node = get_tree().get_first_node_in_group("entity_menu")
			if menu != null and menu.has_method("open_for"):
				menu.open_for(self, "🐱 Gato")
				get_viewport().set_input_as_handled())


func _physics_process(delta: float) -> void:
	_timer -= delta
	_maybe_emote(delta)
	match state:
		State.SLEEP:
			velocity = Vector2.ZERO
			_zzz_accum += delta
			if _zzz_accum >= 3.0:
				_zzz_accum = 0.0
				_puff(_zzz)
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
				_next_activity()
		State.SIT:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_next_activity()
		State.GROOM:
			velocity = Vector2.ZERO
			_bob_t += delta * 6.0
			if _timer <= 0.0:
				_next_activity()
		State.PLAY:
			var d: Vector2 = _wander_target - global_position
			if d.length() < 8.0:
				_pounces -= 1
				if _pounces <= 0:
					_next_activity()
				else:
					_pick_wander()
					_squash()
			else:
				velocity = d.normalized() * POUNCE_SPEED
				move_and_slide()
		State.FOLLOW:
			var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
			if proto == null:
				_go_sleep()
			else:
				var pd: Vector2 = proto.global_position + Vector2(24, 12) - global_position
				velocity = pd.normalized() * FOLLOW_SPEED if pd.length() > 26.0 else Vector2.ZERO
				if pd.length() > 26.0:
					move_and_slide()
			if _timer <= 0.0:
				_go_sleep()
	_update_anim()


func _wake() -> void:
	_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
	_next_activity(true)


func _next_activity(just_woke: bool = false) -> void:
	_timer = randf_range(AWAKE_MIN, AWAKE_MAX)
	var roll: float = randf()
	var has_proto: bool = get_tree().get_first_node_in_group("protagonist") != null
	if not just_woke and roll < 0.22:
		_go_sleep()
	elif roll < 0.42 and has_proto:
		state = State.FOLLOW
	elif roll < 0.58:
		state = State.SIT
	elif roll < 0.74:
		state = State.GROOM
		_bob_t = 0.0
		_puff(_emote, "😽")
	elif roll < 0.9:
		state = State.PLAY
		_pounces = randi_range(2, 4)
		_pick_wander()
		_squash()
	else:
		state = State.WANDER
		_pick_wander()


func _go_sleep() -> void:
	state = State.SLEEP
	_timer = randf_range(SLEEP_MIN, SLEEP_MAX)
	_zzz_accum = 0.0
	scale = Vector2.ONE


func _pick_wander() -> void:
	var rect: Rect2 = GridManager.get_zone_rect_at(home_position)
	if rect.size == Vector2.ZERO:
		rect = Rect2(home_position - Vector2(90, 60), Vector2(180, 120))
	_wander_target = Vector2(
		randf_range(rect.position.x + 30.0, rect.end.x - 30.0),
		randf_range(rect.position.y + 60.0, rect.end.y - 24.0))


func _squash() -> void:
	var tw := create_tween()
	scale = Vector2(1.25, 0.75)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _maybe_emote(delta: float) -> void:
	if state == State.SLEEP or state == State.PLAY:
		return
	_emote_accum -= delta
	if _emote_accum <= 0.0:
		_emote_accum = randf_range(6.0, 14.0)
		_puff(_emote, EMOTES[randi() % EMOTES.size()])


func _puff(lbl: Label, txt: String = "") -> void:
	if lbl == null:
		return
	if txt != "":
		lbl.text = txt
	var base_y: float = lbl.position.y
	lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 0.95, 0.3)
	tw.parallel().tween_property(lbl, "position:y", base_y - 14.0, 1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): lbl.position.y = base_y)


func _update_anim() -> void:
	if _spr == null or _spr.sprite_frames == null:
		return
	if state == State.SLEEP:
		if _spr.animation != &"sleep":
			_spr.play(&"sleep")
		return
	if state == State.GROOM:
		# acicalado: idle abajo con un bob de cabeza (via scale)
		_spr.flip_h = false
		if _spr.animation != &"idle_down":
			_spr.play(&"idle_down")
		scale = Vector2(1.0, 1.0 + sin(_bob_t) * 0.06)
		return
	if state == State.SIT:
		if _spr.animation != &"idle_down":
			_spr.play(&"idle_down")
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
