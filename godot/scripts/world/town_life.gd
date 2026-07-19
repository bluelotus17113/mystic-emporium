class_name TownLife
extends Node2D
## Vida callejera del pueblo decorativo: un grupo de NPCs que deambulan por las
## calles alrededor del Emporium (además de los transeúntes de la recepción de
## VillageLife). Da sensación de aldea viva. Sólo estético.

const TOWN_NPC := preload("res://scripts/ai/town_npc.gd")
const COUNT: int = 9

## Bandas caminables (mundo) = avenidas empedradas del town_ground. Evitan la
## banda del edificio jugable para que los NPCs no crucen por dentro del local.
const STREETS: Array[Rect2] = [
	Rect2(-2600, -740, 3600, 150),   # avenida norte
	Rect2(-2600, 300, 3600, 200),    # avenida sur
	Rect2(-1340, 300, 1100, 430),    # plaza central (sur)
]

## Skins reutilizados de la librería de NPCs Minish (art/sprites/characters).
const SKINS: Array = [
	"npc_aldeano", "npc_comerciante", "npc_nino_curioso", "npc_bardo", "npc_druida",
	"npc_elfo_bosque", "npc_halfling", "npc_cocinero", "npc_doctor", "npc_enano_forjador",
	"npc_aventurero_novato", "npc_caballero", "npc_periodista", "npc_princesa", "npc_hada_visitante",
]


func _ready() -> void:
	await get_tree().process_frame
	var parent: Node = get_tree().get_first_node_in_group("world_container")
	if parent == null:
		return
	var indoor: bool = _in_town()
	for i in COUNT:
		var skin: String = SKINS.pick_random()
		var path: String = "res://art/sprites/characters/%s_anim.png" % skin
		if not ResourceLoader.exists(path):
			continue
		var npc := TOWN_NPC.new()
		npc.add_to_group("town_visual")
		parent.add_child(npc)
		npc.setup(STREETS, path)
		npc.visible = indoor


func _in_town() -> bool:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	return cam != null and cam.has_method("get_current_zone") and cam.get_current_zone().name != &"natural"
