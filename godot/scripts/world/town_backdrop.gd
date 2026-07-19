class_name TownBackdrop
extends Node2D
## Ciudad decorativa (NO caminable) que rodea al Emporium: suelo empedrado con
## calles/plaza sobre hierba + casas top-down. Puramente estética: rellena el
## vacío para que el local se sienta dentro de un pueblo vivo. Vive en el grupo
## "town_visual" (se oculta al pasar al Patio Natural).

const GROUND_TEX := "res://art/sprites/environment/town/town_ground.png"
const TOWN_CENTER := Vector2(-800, 0)

## Posiciones (mundo) de las casas alrededor del Emporium. Evitan la banda del
## edificio jugable (y[-220,220]): una fila cercana al norte y otra al sur (se
## ven sin zoom, como casas vecinas), flancos, y algunas al fondo (con zoom out).
const HOUSE_SPOTS: Array[Vector2] = [
	# fila norte cercana — casas vecinas justo detrás del Emporium
	Vector2(-1650, -520), Vector2(-1050, -540), Vector2(-450, -520),
	Vector2(160, -540), Vector2(760, -520),
	# fila sur cercana — al otro lado de la calle
	Vector2(-1650, 520), Vector2(-1050, 540), Vector2(-450, 520),
	Vector2(160, 540), Vector2(760, 520),
	# flancos y fondo lejano (aparecen al hacer zoom out)
	Vector2(-2560, -40), Vector2(1060, -40),
	Vector2(-2200, -900), Vector2(700, 940),
]


func _ready() -> void:
	var parent: Node = get_tree().get_first_node_in_group("world_container")
	if parent == null:
		parent = get_tree().current_scene
	_add_ground(parent)
	_add_houses(parent)


func _add_ground(parent: Node) -> void:
	var tex: Texture2D = load(GROUND_TEX)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.name = "TownGround"
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(2, 2)
	s.position = TOWN_CENTER
	s.z_index = -20  # detrás de los fondos del Emporium (z=-10)
	s.add_to_group("town_visual")
	parent.add_child(s)


func _add_houses(parent: Node) -> void:
	for i in HOUSE_SPOTS.size():
		var idx: int = (i % 6) + 1
		var tex: Texture2D = load("res://art/sprites/environment/town/house_%d.png" % idx)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = "TownHouse%d" % i
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(2, 2)
		s.position = HOUSE_SPOTS[i]
		s.z_index = -12  # delante del suelo, detrás del Emporium; NPCs pasan por delante
		s.add_to_group("town_visual")
		parent.add_child(s)
