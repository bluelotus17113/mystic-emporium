extends CharacterBody2D
## Protagonista Minish: movimiento 8-dir + animación de caminado 4-dir.
## Anima manualmente desde los strips (sin SpriteFrames) para robustez.

const SPEED: float = 70.0
const FRAME_TIME: float = 0.12
const DIR = "res://art/sprites/characters/minish/"

@onready var sprite: Sprite2D = $Sprite2D

var _idle: Dictionary = {}
var _walk: Dictionary = {}
var _dir: String = "south"
var _frame: int = 0
var _timer: float = 0.0


func _ready() -> void:
	for d in ["south", "north", "east", "west"]:
		_idle[d] = load(DIR + "prota_%s.png" % d)
		_walk[d] = load(DIR + "prota_walk_%s.png" % d)
	sprite.texture = _idle["south"]
	sprite.region_enabled = false


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	velocity = input.normalized() * SPEED
	move_and_slide()

	if input.length() > 0.1:
		# dirección dominante
		if absf(input.x) > absf(input.y):
			_dir = "east" if input.x > 0 else "west"
		else:
			_dir = "south" if input.y > 0 else "north"
		_timer += delta
		if _timer >= FRAME_TIME:
			_timer = 0.0
			_frame = (_frame + 1) % 4
		_set_walk_frame()
	else:
		_frame = 0
		sprite.region_enabled = false
		sprite.texture = _idle[_dir]


func _set_walk_frame() -> void:
	sprite.texture = _walk[_dir]
	sprite.region_enabled = true
	sprite.region_rect = Rect2(_frame * 32, 0, 32, 32)
