extends Node2D
## Trampa buildable: durante un asedio daña a los ogros que pisan su radio, con un
## pulso periódico. Parametrizable por escena (púas / fuego). Inactiva en calma.

@export var tex_path: String = "res://art/sprites/environment/siege_trap.png"
@export var radius: float = 62.0
@export var damage: float = 9.0
@export var interval: float = 0.85
@export var glow_tint: Color = Color(1.0, 0.75, 1.1, 1.0)

var _cd: float = 0.0
var _pulse: float = 0.0
var _spr: Sprite2D = null


func _ready() -> void:
	add_to_group("siege_traps")
	z_index = -1  # en el suelo, bajo los personajes
	_spr = Sprite2D.new()
	_spr.texture = load(tex_path)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)


func _process(delta: float) -> void:
	_pulse += delta
	if _spr != null:
		if SiegeManager.is_active():
			var g: float = 0.75 + 0.25 * sin(_pulse * 4.0)
			_spr.modulate = Color(glow_tint.r * g, glow_tint.g * g, glow_tint.b * g, 1.0)
		else:
			_spr.modulate = Color(1, 1, 1, 0.7)
	if not SiegeManager.is_active():
		return
	_cd -= delta
	if _cd > 0.0:
		return
	var hit_any: bool = false
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		var n: Node2D = e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if global_position.distance_to(n.global_position) <= radius and n.has_method("hit"):
			n.hit(damage)
			hit_any = true
	if hit_any:
		_cd = interval
		VFXManager.play(VFXManager.FX.BUILD, global_position)
		AudioManager.play_beep(320.0, 0.06, -18.0)
