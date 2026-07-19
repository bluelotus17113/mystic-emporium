extends Node2D
## NPC ambiental del pueblo: deambula entre puntos de las calles empedradas y
## hace pausas ocasionales. Decorativo (no interactivo). Lo crea TownLife y vive
## en el grupo "town_visual" (visible mientras estás en el Emporium/pueblo).

var _spr: AnimatedSprite2D = null
var _speed: float = 44.0
var _target: Vector2 = Vector2.ZERO
var _streets: Array = []          ## Array[Rect2] con las bandas caminables
var _pause: float = 0.0


func setup(streets: Array, sheet_path: String) -> void:
	_streets = streets
	global_position = _rand_point()
	_target = _rand_point()
	_speed = randf_range(30.0, 52.0)
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		queue_free()
		return
	_spr = AnimatedSprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -32)
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
	_spr.play(&"walk")
	add_child(_spr)
	CharShadow.attach(self)


func _rand_point() -> Vector2:
	if _streets.is_empty():
		return global_position
	var r: Rect2 = _streets[randi() % _streets.size()]
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


func _process(delta: float) -> void:
	if not visible:
		return  # no gastamos en NPCs de un pueblo que no se está viendo
	if _pause > 0.0:
		_pause -= delta
		if _spr != null:
			_spr.pause()
		return
	if _spr != null and not _spr.is_playing():
		_spr.play(&"walk")
	var d: Vector2 = _target - global_position
	if d.length() < 6.0:
		_target = _rand_point()
		if randf() < 0.35:
			_pause = randf_range(0.6, 2.4)
		return
	global_position += d.normalized() * _speed * delta
	if _spr != null and absf(d.x) > 1.0:
		_spr.flip_h = d.x < 0.0
