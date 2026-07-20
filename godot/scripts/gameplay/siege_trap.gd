extends Node2D
## Trampa de púas arcana (buildable): durante un asedio daña a los ogros que
## pisan su radio, con un pulso periódico. Fuera del asedio está inactiva.

const TEX := "res://art/sprites/environment/siege_trap.png"
const RADIUS: float = 62.0
const DAMAGE: float = 9.0
const INTERVAL: float = 0.85

var _cd: float = 0.0
var _pulse: float = 0.0
var _spr: Sprite2D = null


func _ready() -> void:
	add_to_group("siege_traps")
	z_index = -1  # en el suelo, bajo los personajes
	_spr = Sprite2D.new()
	_spr.texture = load(TEX)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)


func _process(delta: float) -> void:
	_pulse += delta
	if _spr != null:
		if SiegeManager.is_active():
			var g: float = 0.75 + 0.25 * sin(_pulse * 4.0)  # brilla "armada"
			_spr.modulate = Color(g + 0.25, g * 0.7, g + 0.35, 1.0)
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
		if global_position.distance_to(n.global_position) <= RADIUS and n.has_method("hit"):
			n.hit(DAMAGE)
			hit_any = true
	if hit_any:
		_cd = INTERVAL
		VFXManager.play(VFXManager.FX.BUILD, global_position)
		AudioManager.play_beep(320.0, 0.06, -18.0)
