extends Node2D
## Fuente de luz cálida decorativa (vela, chimenea…): sprite + resplandor
## aditivo con parpadeo de llama. Siempre emite algo (base_glow) y sube de
## noche (night_glow * oscuridad). Configurable por @export desde la escena.

const GLOW_TEX: String = "res://art/sprites/fx/lantern_glow.png"
const UPDATE_INTERVAL: float = 0.1

@export var tex_path: String = ""
@export var sprite_offset: Vector2 = Vector2.ZERO  ## en px de textura (pivote en la base)
@export var glow_scale: float = 0.5
@export var glow_offset: Vector2 = Vector2(0, -24)
@export var base_glow: float = 0.4    ## resplandor de día (llama encendida)
@export var night_glow: float = 0.45  ## extra al anochecer
@export var glow_color: Color = Color(1, 0.82, 0.5)
@export var solid: bool = false
@export var solid_size: Vector2 = Vector2(16, 10)

var _glow: Sprite2D = null
var _accum: float = 0.0
var _phase: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_seed = randf() * 100.0
	if tex_path != "":
		var spr := Sprite2D.new()
		spr.texture = load(tex_path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(2, 2)
		spr.offset = sprite_offset
		add_child(spr)
	_glow = Sprite2D.new()
	_glow.texture = load(GLOW_TEX)
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.scale = Vector2(glow_scale, glow_scale)
	_glow.position = glow_offset
	_glow.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, base_glow)
	add_child(_glow)
	if solid:
		SolidBase.attach(self, solid_size, Vector2(0, -2))
	_apply()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	_apply()


func _apply() -> void:
	if _glow == null:
		return
	var dark: float = CalendarManager.get_darkness()
	var t: float = Time.get_ticks_msec() / 1000.0
	var flick: float = 0.85 + 0.10 * sin(t * 3.0 + _phase) + 0.08 * sin(t * 11.0 + _seed)
	_glow.modulate.a = clampf((base_glow + night_glow * dark) * flick, 0.0, 1.0)
