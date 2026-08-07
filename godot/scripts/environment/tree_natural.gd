class_name TreeNatural
extends ResourceNode
## Árbol del Patio Natural: decorado que además se puede talar, mover y comprar.
##
## Es un ResourceNode de MADERA ARCANA, pero nace CERRADO a los workers
## (`auto_register = false`). Si no, el leñador vería 40 árboles como recurso y
## arrasaría el patio él solo en cuanto lo contratas. Solo se abre cuando el
## jugador da la orden desde el menú del leñador, y entonces se comporta como
## cualquier otro nodo: el leñador lo reserva, camina y lo cosecha.
##
## Al talarlo deja un tocón en su sitio, que es un prop normal y se puede
## demoler desde el menú de construcción.

## especie -> [textura, madera que da, ancho del tronco]
const ESPECIES: Dictionary = {
	&"roble":  ["res://art/sprites/environment/tree_oak.png", 4, 0.28],
	&"abedul": ["res://art/sprites/environment/tree_birch.png", 3, 0.22],
	&"pino":   ["res://art/sprites/environment/tree_pine.png", 3, 0.24],
	&"cerezo": ["res://art/sprites/environment/tree_cherry.png", 3, 0.26],
}
const MADERA: String = "res://data/items/madera_arcana.tres"
const TOCON: String = "res://art/sprites/environment/decoration_log_stump.png"
const ALTO_OBJETIVO: float = 140.0
## El punto de orden Y se empuja al borde delantero del tronco: así los
## personajes se ocultan limpio al pasar por detrás. Igual que en NaturalLife.
const EMPUJE_ORDEN: float = 12.0

@export var especie: StringName = &"roble"

var _copa: TreeWind = null


func _ready() -> void:
	var datos: Array = ESPECIES.get(especie, ESPECIES[&"roble"])
	var tex: Texture2D = load(datos[0])
	if tex == null:
		super()
		return
	resource_type = GameEnums.ResourceType.ARCANE_WOOD
	yield_quantity = datos[1]
	free_on_collect = true
	auto_register = false          # decorado hasta que se ordene talarlo
	if item_data == null:
		item_data = load(MADERA)

	var k: float = ALTO_OBJETIVO / float(tex.get_height())
	_copa = TreeWind.new()
	_copa.texture = tex
	_copa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_copa.scale = Vector2(k, k)
	_copa.phase = global_position.x * 0.008
	_copa.amp = randf_range(0.035, 0.06)
	_copa.offset = Vector2(0, -tex.get_height() * 0.5 + 4 - EMPUJE_ORDEN / k)
	add_child(_copa)

	# El colisionador va sobre el tronco visible, compensando el empuje del orden.
	# Se adjunta ANTES de super(): SolidBase.attach no hace nada si ya existe uno,
	# así el de ResourceNode (offset fijo 0,4) no lo pisa.
	solid_size = Vector2(maxf(20.0, tex.get_width() * k * datos[2]), 12.0)
	SolidBase.attach(self, solid_size, Vector2(0, -2 - EMPUJE_ORDEN / k))
	super()
	add_to_group("arboles_talables")
	add_to_group("natural_visual")
	add_to_group("foliage")            # tinte de estación (SeasonFX)
	add_to_group(SunShadows.GRUPO)
	collected.connect(_al_talar)


## Marca este árbol como talable: a partir de aquí el leñador lo ve.
func marcar_para_talar() -> void:
	if auto_register:
		return          # ya estaba marcado
	abrir_a_workers()
	if _copa != null:
		_copa.modulate = Color(1.0, 0.86, 0.72)   # tinte cálido: "va a caer"
	FloatingText.spawn(self, "🪓 marcado", Color(1.0, 0.85, 0.5))


## Vuelve a ser decorado. Si un leñador ya lo tenía reservado se le suelta, para
## que no se quede caminando hacia un árbol que ya no es objetivo.
func desmarcar() -> void:
	if not auto_register:
		return
	auto_register = false
	ResourceManager.unregister_node(self)
	_reserved_by = null
	if _copa != null:
		_copa.modulate = Color.WHITE


func esta_marcado() -> bool:
	return auto_register


func _al_talar(_n: ResourceNode) -> void:
	var padre: Node = get_parent()
	if padre == null:
		return
	var tex: Texture2D = load(TOCON)
	if tex == null:
		return
	var tocon := Sprite2D.new()
	tocon.texture = tex
	tocon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tocon.scale = Vector2(2, 2)
	tocon.offset = Vector2(0, -tex.get_height() * 0.5)
	for g in ["natural_visual", SunShadows.GRUPO]:
		tocon.add_to_group(g)
	padre.add_child(tocon)
	tocon.global_position = global_position
	AudioManager.play_beep(180.0, 0.18, -9.0)
