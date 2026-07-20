extends Node2D
## Trofeo de Asedio (decorativo): recompensa por ganar tu primer asedio. Late con
## un brillo dorado sutil.

const TEX := "res://art/sprites/environment/siege_trophy.png"
var _spr: Sprite2D = null
var _t: float = 0.0


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = load(TEX)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -22)
	add_child(_spr)


func _process(delta: float) -> void:
	if _spr == null:
		return
	_t += delta
	var g: float = 0.5 + 0.5 * sin(_t * 2.0)
	_spr.self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 1.15, 0.7), g * 0.45)
