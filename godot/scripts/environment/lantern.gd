extends Node2D
## Farol: poste con cabeza que enciende un resplandor cálido de noche.
## La intensidad sigue la hora real (CalendarManager.time_of_day) con un leve
## parpadeo de llama. Construible y también colocable por el bootstrap.

const LAMP_TEX: String = "res://art/sprites/environment/decoration_lantern.png"
const GLOW_TEX: String = "res://art/sprites/fx/lantern_glow.png"
const UPDATE_INTERVAL: float = 0.1

var _glow: Sprite2D = null
var _accum: float = 0.0
var _phase: float = 0.0
var _flick_seed: float = 0.0


func _ready() -> void:
	add_to_group("lanterns")
	add_to_group("warm_spot")
	_phase = randf() * TAU
	_flick_seed = randf() * 100.0
	var lamp := Sprite2D.new()
	lamp.texture = load(LAMP_TEX)
	lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamp.scale = Vector2(2, 2)
	lamp.offset = Vector2(0, -17)  # pivote en la base (para y-sort por pies)
	add_child(lamp)

	_glow = Sprite2D.new()
	_glow.texture = load(GLOW_TEX)
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.position = Vector2(0, -52)  # centro de la cabeza del farol
	_glow.scale = Vector2(1.6, 1.6)
	_glow.z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(1, 0.85, 0.55, 0.0)
	add_child(_glow)

	SolidBase.attach(self, Vector2(10.0, 8.0), Vector2(0, -2))
	_apply(_darkness())


func _process(delta: float) -> void:
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	_apply(_darkness())


func _apply(dark: float) -> void:
	if _glow == null:
		return
	if dark <= 0.02:
		_glow.visible = false
		return
	_glow.visible = true
	var t: float = Time.get_ticks_msec() / 1000.0
	# Parpadeo de llama: seno lento + rápido, nunca apaga del todo.
	var flick: float = 0.82 + 0.10 * sin(t * 3.0 + _phase) + 0.08 * sin(t * 11.0 + _flick_seed)
	_glow.modulate.a = clampf(dark * flick, 0.0, 1.0) * 0.9


func _darkness() -> float:
	return CalendarManager.get_darkness()
