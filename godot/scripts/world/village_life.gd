class_name VillageLife
extends Node2D
## Tráfico de fondo en la recepción: transeúntes que cruzan de vez en cuando.
## Más frecuentes de día, casi ninguno de noche (ritmo del pueblo).

const PASSERBY := preload("res://scripts/ai/passerby.gd")
const SKINS: Array = [
	"npc_aldeano", "npc_comerciante", "npc_nino_curioso", "npc_bardo", "npc_druida",
	"npc_elfo_bosque", "npc_halfling", "npc_pirata", "npc_cocinero", "npc_doctor",
	"npc_aventurero_novato", "npc_caballero", "npc_enano_forjador",
]

var _rect: Rect2 = Rect2()
var _timer: float = 6.0


func _ready() -> void:
	await get_tree().process_frame
	for zr in _find_zone_regions(get_tree().current_scene):
		if zr.zone_type == GameEnums.ZoneType.RECEPTION:
			_rect = Rect2(zr.global_position - zr.size * 0.5, zr.size)
			break
	if _rect.size == Vector2.ZERO:
		set_process(false)


func _find_zone_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_zone_regions(c))
	return out


func _process(delta: float) -> void:
	# Ritmo del día: casi nada de noche, más al mediodía.
	var day: float = 1.0 - CalendarManager.get_darkness()
	_timer -= delta * (0.15 + day)
	if _timer > 0.0:
		return
	_timer = randf_range(9.0, 20.0)
	_spawn_passerby()


func _spawn_passerby() -> void:
	var parent: Node = get_tree().get_first_node_in_group("world_container")
	if parent == null:
		return
	var y: float = randf_range(_rect.position.y + _rect.size.y * 0.55, _rect.end.y - 30.0)
	var left_to_right: bool = randf() < 0.5
	var from := Vector2(_rect.position.x - 40.0, y)
	var to := Vector2(_rect.end.x + 40.0, y)
	if not left_to_right:
		var t := from; from = to; to = t
	var skin: String = SKINS.pick_random()
	var path: String = "res://art/sprites/characters/%s_anim.png" % skin
	if not ResourceLoader.exists(path):
		return
	var p := PASSERBY.new()
	p.add_to_group("recepcion_visual")
	parent.add_child(p)
	p.setup(from, to, path)
	p.visible = _in_reception()


func _in_reception() -> bool:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	return cam != null and cam.has_method("get_current_zone") and cam.get_current_zone().name == &"recepcion"
