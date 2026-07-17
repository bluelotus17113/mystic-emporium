extends Node
## Objetos creados por el jugador con el editor Abracadabra. Cada objeto:
##   { id, name, type("solid"/"floor"), cost }  + un PNG 32x32 en user://.
## Se registran como BuildableData en el catálogo de BuildManager para que
## aparezcan en el menú de construcción y se coloquen/guarden como cualquiera.

signal object_created(id: StringName)

const DIR: String = "user://custom_objects/"
const MANIFEST: String = "user://custom_objects/manifest.json"
const CREATE_COST: int = 50
const CUSTOM_SCENE: String = "res://scenes/environment/custom_object.tscn"

var _objects: Dictionary = {}    # id(String) -> {name, type, cost}
var _textures: Dictionary = {}   # id(String) -> ImageTexture
var _buildables: Dictionary = {} # id(String) -> BuildableData
var _custom_scene: PackedScene = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_custom_scene = load(CUSTOM_SCENE)
	_load_manifest()


func get_object(id: StringName) -> Dictionary:
	return _objects.get(String(id), {})


func get_texture(id: StringName) -> Texture2D:
	return _textures.get(String(id))


func all_ids() -> Array:
	return _objects.keys()


func can_afford() -> bool:
	return InventoryManager.arcane_coins >= CREATE_COST


## Crea un objeto desde una Image 32x32. Cobra 50 monedas. Devuelve el id o "".
func create(obj_name: String, type: String, img: Image) -> StringName:
	if not InventoryManager.spend_coins(CREATE_COST):
		return &""
	var id: String = "custom_%d" % Time.get_unix_time_from_system()
	while _objects.has(id):
		id += "x"
	img.save_png(DIR + id + ".png")
	_objects[id] = {"name": obj_name.strip_edges() if obj_name.strip_edges() != "" else "Creación",
		"type": type, "cost": CREATE_COST}
	_textures[id] = ImageTexture.create_from_image(img)
	_save_manifest()
	_register(id)
	object_created.emit(StringName(id))
	return StringName(id)


## Registra todos los objetos en el catálogo de BuildManager (idempotente).
## Lo llama game_bootstrap tras set_catalog.
func register_all() -> void:
	for id in _objects.keys():
		_register(id)


func _register(id: String) -> void:
	if _buildables.has(id):
		return
	var data: Dictionary = _objects[id]
	var bd := BuildableData.new()
	bd.id = StringName("custom_" + id if not id.begins_with("custom_") else id)
	bd.id = StringName(id)
	bd.display_name = data.name
	bd.description = "Creación propia (Abracadabra)."
	bd.icon = _textures.get(id)
	bd.scene = _custom_scene
	bd.cost = int(data.get("cost", CREATE_COST))
	bd.allowed_zone = GameEnums.ZoneType.NONE  # cualquier zona
	bd.size = Vector2i(1, 1)
	bd.unlocked_by_default = true
	bd.is_decorative = true
	bd.decoration_category = &"custom"
	bd.custom_id = StringName(id)
	_buildables[id] = bd
	BuildManager.register_custom_buildable(bd)


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST):
		return
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for id in parsed.keys():
		var entry: Dictionary = parsed[id]
		var png: String = DIR + id + ".png"
		if not FileAccess.file_exists(png):
			continue
		var img := Image.load_from_file(png)
		if img == null:
			continue
		_objects[id] = {"name": entry.get("name", "Creación"),
			"type": entry.get("type", "solid"), "cost": int(entry.get("cost", CREATE_COST))}
		_textures[id] = ImageTexture.create_from_image(img)


func _save_manifest() -> void:
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_objects, "\t"))
	f.close()
