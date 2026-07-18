extends Node2D
## Casa de Duendes (3×3): hasta CAP workers entran a descansar. Al ocupar, sale
## humo y de noche brilla la ventana. Expone puerta y aforo para worker_base.

const CAP: int = 5
const GLOW_TEX: String = "res://art/sprites/fx/lantern_glow.png"

var occupants: int = 0
var _smoke: GPUParticles2D = null
var _glow: Sprite2D = null
var _badge: Label = null
var _accum: float = 0.0


func _ready() -> void:
	if modulate.a < 0.9:  # fantasma de previsualización: solo mostrar el sprite
		return
	add_to_group("worker_house")
	add_to_group("warm_spot")   # también sirve como refugio cálido
	# Colisión: bloquea el cuerpo de la casa (deja libre la fila de la puerta).
	SolidBase.attach(self, Vector2(84.0, 34.0), Vector2(0, 6))
	_setup_fx()


func _setup_fx() -> void:
	# Humo por la parte alta (sombrero) cuando hay alguien dentro.
	_smoke = GPUParticles2D.new()
	_smoke.texture = CharShadow._tex()
	_smoke.position = Vector2(0, -74)
	_smoke.amount = 8
	_smoke.lifetime = 2.2
	_smoke.emitting = false
	_smoke.z_index = 2
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0.2, -1, 0)
	m.gravity = Vector3(0, -14, 0)
	m.spread = 18.0
	m.initial_velocity_min = 5.0
	m.initial_velocity_max = 11.0
	m.scale_min = 0.14
	m.scale_max = 0.26
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.9, 0.45))
	g.set_color(1, Color(0.8, 0.8, 0.85, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp
	_smoke.process_material = m
	add_child(_smoke)
	# Brillo cálido en la ventana/puerta de noche.
	_glow = Sprite2D.new()
	_glow.texture = load(GLOW_TEX)
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.position = Vector2(0, 18)
	_glow.scale = Vector2(0.5, 0.5)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.modulate = Color(1, 0.82, 0.5, 0.0)
	_glow.z_index = 1
	add_child(_glow)
	# Badge de aforo (visible solo cuando hay ocupantes).
	_badge = Label.new()
	_badge.position = Vector2(-16, -104)
	_badge.add_theme_font_size_override(&"font_size", 13)
	_badge.add_theme_color_override(&"font_color", Color(1, 1, 0.85))
	_badge.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_badge.add_theme_constant_override(&"outline_size", 4)
	_badge.z_index = 30
	_badge.visible = false
	add_child(_badge)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.15:
		return
	_accum = 0.0
	if _glow != null:
		var dark: float = CalendarManager.get_darkness()
		var occ: float = 0.4 + 0.6 * (float(occupants) / float(CAP))
		_glow.modulate.a = clampf((0.25 + 0.7 * dark) * occ, 0.0, 1.0)


func door_point() -> Vector2:
	return global_position + Vector2(0, 46)  # frente de la puerta (abajo)


func has_room() -> bool:
	return occupants < CAP


func enter(_w: Node) -> void:
	occupants = mini(CAP, occupants + 1)
	_refresh()


func leave(_w: Node) -> void:
	occupants = maxi(0, occupants - 1)
	_refresh()


func _refresh() -> void:
	if _smoke != null:
		_smoke.emitting = occupants > 0
	if _badge != null:
		_badge.visible = occupants > 0
		_badge.text = "💤 %d/%d" % [occupants, CAP]
