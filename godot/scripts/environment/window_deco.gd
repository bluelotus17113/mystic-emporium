extends Node2D
## Ventana decorativa de pared: vidrio azulado de día, resplandor cálido de
## noche (sigue CalendarManager.get_darkness). Construible; sin colisión.

const WIN_TEX: String = "res://art/sprites/environment/decoration_window.png"
const GLOW_TEX: String = "res://art/sprites/fx/lantern_glow.png"
const UPDATE_INTERVAL: float = 0.12

var _glow: Sprite2D = null
var _accum: float = 0.0


func _ready() -> void:
	var w := Sprite2D.new()
	w.texture = load(WIN_TEX)
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.scale = Vector2(2, 2)
	add_child(w)

	_glow = Sprite2D.new()
	_glow.texture = load(GLOW_TEX)
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.scale = Vector2(0.42, 0.42)
	_glow.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(1, 0.86, 0.55, 0.0)
	add_child(_glow)
	_apply(CalendarManager.get_darkness())


func _process(delta: float) -> void:
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	_apply(CalendarManager.get_darkness())


func _apply(dark: float) -> void:
	if _glow == null:
		return
	if dark <= 0.02:
		_glow.visible = false
	else:
		_glow.visible = true
		_glow.modulate.a = dark * 0.8
