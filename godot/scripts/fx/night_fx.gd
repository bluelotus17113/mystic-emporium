class_name NightFX
extends Node2D
## Ambiente nocturno gobernado por CalendarManager.get_darkness():
## - Patio natural: luciérnagas extra + destellos + grillos (volumen por noche).
## - Taller: ventanas cálidas que se encienden de noche.
## Lo instala game_bootstrap. Se apaga solo de día.

const UPDATE_INTERVAL: float = 0.15
const GLOW_TEX: String = "res://art/sprites/fx/lantern_glow.png"
const WINDOW_TEX: String = "res://art/sprites/environment/window_lit.png"
const CRICKETS: String = "res://audio/sfx/ambient_crickets.wav"

var _accum: float = 0.0
var _fade: Array = []          # [{node, max}] → alpha = darkness * max
var _cricket: AudioStreamPlayer2D = null


func _ready() -> void:
	await get_tree().process_frame
	var seen: Dictionary = {}
	for zr in _find_zone_regions(get_tree().current_scene):
		if seen.has(zr.zone_type):
			continue
		seen[zr.zone_type] = true
		var rect := Rect2(zr.global_position - zr.size * 0.5, zr.size)
		match zr.zone_type:
			GameEnums.ZoneType.NATURE:
				_setup_natural(rect)
			GameEnums.ZoneType.WORKSHOP:
				_setup_workshop(rect)
	_apply(CalendarManager.get_darkness())


func _find_zone_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_zone_regions(c))
	return out


func _setup_natural(rect: Rect2) -> void:
	# Luciérnagas extra (más brillantes que las de ZoneAmbience).
	var fire := _radial_emitter(rect, 16, Color(0.85, 1.0, 0.5, 0.95), Color(0.5, 0.95, 0.35, 0.0), 12.0, true, 0.16)
	fire.add_to_group("natural_visual")
	add_child(fire)
	_fade.append({"node": fire, "max": 1.0})
	# Destellos tenues tipo "polvo de luna".
	var spark := _radial_emitter(rect, 10, Color(0.85, 0.9, 1.0, 0.8), Color(0.8, 0.85, 1.0, 0.0), 3.0, false, 0.07)
	spark.add_to_group("natural_visual")
	add_child(spark)
	_fade.append({"node": spark, "max": 0.8})
	# Grillos: audio posicional en el centro del patio, volumen por oscuridad.
	_cricket = AudioStreamPlayer2D.new()
	var s: AudioStream = load(CRICKETS)
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cricket.stream = s
	_cricket.position = rect.get_center()
	_cricket.max_distance = 1200.0
	_cricket.volume_db = -80.0
	_cricket.autoplay = true
	add_child(_cricket)


func _setup_workshop(rect: Rect2) -> void:
	var glow_tex: Texture2D = load(GLOW_TEX)
	var win_tex: Texture2D = load(WINDOW_TEX)
	var wall_y: float = rect.position.y + 52.0
	for off in [-rect.size.x * 0.28, rect.size.x * 0.28]:
		var holder := Node2D.new()
		holder.add_to_group("taller_visual")
		add_child(holder)
		holder.global_position = Vector2(rect.get_center().x + off, wall_y)
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.scale = Vector2(0.9, 0.9)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.modulate = Color(1, 0.85, 0.55)
		holder.add_child(glow)
		var win := Sprite2D.new()
		win.texture = win_tex
		win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		win.scale = Vector2(2, 2)
		holder.add_child(win)
		_fade.append({"node": holder, "max": 1.0})


## Emisor radial reutilizable (partículas suaves sin assets).
func _radial_emitter(rect: Rect2, amount: int, c0: Color, c1: Color, vel: float, turb: bool, scale: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = CharShadow._tex()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.position = rect.get_center()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rect.size.x * 0.5, rect.size.y * 0.5, 0)
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = vel * 0.4
	mat.initial_velocity_max = vel
	mat.turbulence_enabled = turb
	if turb:
		mat.turbulence_noise_strength = 0.7
	mat.scale_min = scale * 0.7
	mat.scale_max = scale
	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.set_color(1, c1)
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	p.emitting = true
	return p


func _process(delta: float) -> void:
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	_apply(CalendarManager.get_darkness())


func _apply(dark: float) -> void:
	for e in _fade:
		var n: CanvasItem = e.node
		if not is_instance_valid(n):
			continue
		if dark <= 0.02:
			n.visible = false
		else:
			n.visible = true
			n.modulate.a = dark * float(e.max)
	if _cricket != null:
		_cricket.volume_db = lerpf(-34.0, -11.0, dark) if dark > 0.03 else -80.0
