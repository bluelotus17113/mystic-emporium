extends Node
## Registro de recetas (RecipeData) disponibles. Las recetas con
## `unlocked_by_default = true` arrancan desbloqueadas. ResearchManager las
## desbloquea dinámicamente al completar investigaciones.
##
## Workstation.get_filtered_recipes() ahora consulta a este manager.

signal recipe_unlocked(recipe: RecipeData)

var _catalog: Array[RecipeData] = []
var _unlocked: Array[RecipeData] = []


func set_catalog(catalog: Array[RecipeData]) -> void:
	_catalog = catalog.duplicate()
	# Inicializar las unlocked_by_default
	for r in _catalog:
		if r != null and r.unlocked_by_default and not _unlocked.has(r):
			_unlocked.append(r)


func unlock_recipe(r: RecipeData) -> void:
	if r == null or _unlocked.has(r):
		return
	_unlocked.append(r)
	recipe_unlocked.emit(r)
	NotificationManager.post("Receta desbloqueada: %s" % r.display_name, NotificationManager.Kind.SUCCESS)


func is_unlocked(r: RecipeData) -> bool:
	return r in _unlocked


func get_unlocked_recipes() -> Array[RecipeData]:
	return _unlocked.duplicate()


func get_all_recipes() -> Array[RecipeData]:
	return _catalog.duplicate()


func find_recipe_by_id(id: StringName) -> RecipeData:
	for r in _catalog:
		if r != null and r.id == id:
			return r
	return null


func get_unlocked_for_station(station_type: GameEnums.StationType) -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for r in _unlocked:
		if r.required_station_type == station_type:
			result.append(r)
	return result


func get_save_state() -> Dictionary:
	var ids: Array[String] = []
	for r in _unlocked:
		ids.append(str(r.id))
	return {"unlocked_ids": ids}


func load_save_state(data: Dictionary) -> void:
	var ids: Array = data.get("unlocked_ids", [])
	_unlocked.clear()
	for r in _catalog:
		if str(r.id) in ids or r.unlocked_by_default:
			_unlocked.append(r)


func reset_for_prestige() -> void:
	_unlocked.clear()
	for r in _catalog:
		if r != null and r.unlocked_by_default:
			_unlocked.append(r)
