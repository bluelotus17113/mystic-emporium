extends Node2D
## Transeúnte: un NPC que cruza la recepción y se va (tráfico de fondo, sin
## pedido). Da sensación de tienda con vida. Lo crea VillageLife.

var _target: Vector2 = Vector2.ZERO
var _speed: float = 46.0
var _spr: AnimatedSprite2D = null


func setup(from: Vector2, to: Vector2, sheet_path: String) -> void:
	global_position = from
	_target = to
	_speed = randf_range(38.0, 58.0)
	_spr = AnimatedSprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -32)
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		queue_free()
		return
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_loop(&"walk", true)
	sf.set_animation_speed(&"walk", 8.0)
	for c in range(4):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * 64, 5 * 64, 64, 64)  # fila walk_side
		sf.add_frame(&"walk", at)
	_spr.sprite_frames = sf
	_spr.flip_h = to.x < from.x
	_spr.play(&"walk")
	add_child(_spr)
	CharShadow.attach(self)


func _process(delta: float) -> void:
	var d: Vector2 = _target - global_position
	if d.length() < 8.0:
		queue_free()
		return
	global_position += d.normalized() * _speed * delta
