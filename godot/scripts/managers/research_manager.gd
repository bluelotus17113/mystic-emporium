extends Node

signal research_started(research: ResearchData)
signal research_progress(research: ResearchData, percent: float)
signal research_completed(research: ResearchData)
signal station_clicked(station)

var _all_research: Array[ResearchData] = []
var _completed: Array[ResearchData] = []
var _active_research: ResearchData = null
var _progress: float = 0.0
var _items_catalog: Array[ItemData] = []


func set_catalog(catalog: Array[ResearchData]) -> void:
	_all_research = catalog.duplicate()


func set_item_catalog(catalog: Array[ItemData]) -> void:
	_items_catalog = catalog.duplicate()


func _find_item(id: StringName) -> ItemData:
	for i in _items_catalog:
		if i != null and i.id == id:
			return i
	return null


## Devuelve la lista de items requeridos resueltos: [{item, qty, have, ok}].
func get_required_items_for(r: ResearchData) -> Array:
	var out: Array = []
	if r == null:
		return out
	var n: int = min(r.required_item_ids.size(), r.required_item_qty.size())
	for i in n:
		var item: ItemData = _find_item(StringName(r.required_item_ids[i]))
		var qty: int = int(r.required_item_qty[i])
		var have: int = InventoryManager.get_item_count(item) if item != null else 0
		out.append({"item": item, "qty": qty, "have": have, "ok": have >= qty})
	return out


func can_afford(r: ResearchData) -> bool:
	if r == null:
		return false
	if InventoryManager.arcane_coins < r.coin_cost:
		return false
	for req in get_required_items_for(r):
		if not req.ok:
			return false
	return true


func get_available_for_station(station_type: GameEnums.StationType) -> Array[ResearchData]:
	# La Biblioteca actúa como centro universal: muestra TODAS las investigaciones
	# disponibles (cualquier station temática). Las otras stations filtran a su rama.
	# Así la distribución temática (alquimia→caldero, etc) queda visible en la
	# Biblioteca como árbol global y también accesible desde cada workshop.
	var is_library: bool = station_type == GameEnums.StationType.ARCANE_LIBRARY
	var result: Array[ResearchData] = []
	for r in _all_research:
		if r in _completed:
			continue
		if not is_library and r.required_station_type != station_type:
			continue
		if not _prereqs_met(r):
			continue
		# ponytail: oculta research sin recompensa hasta que el buildable/recipe destino exista
		if r.recipe_to_unlock == null and r.buildable_to_unlock == null:
			continue
		result.append(r)
	return result


func _prereqs_met(r: ResearchData) -> bool:
	for prereq in r.prerequisites:
		if prereq not in _completed:
			return false
	return true


func is_completed(r: ResearchData) -> bool:
	return r in _completed


func start_research(r: ResearchData) -> bool:
	if r == null or r in _completed or not _prereqs_met(r):
		return false
	# Validar items ANTES de cobrar coins. Si falta material, fallar SILENCIOSAMENTE:
	# la UI del research panel ya muestra ✓/✗ por item y deshabilita el botón.
	# Postear ALERT acá causa spam cuando IdleAutomationManager intenta cada tick.
	var reqs: Array = get_required_items_for(r)
	for req in reqs:
		if not req.ok:
			return false
	if not InventoryManager.spend_coins(r.coin_cost):
		return false
	# Consumir materiales (ya validamos arriba que están disponibles).
	for req in reqs:
		if req.item != null:
			InventoryManager.remove_item(req.item, req.qty)
	_active_research = r
	_progress = 0.0
	research_started.emit(r)
	return true


func add_progress(seconds: float) -> void:
	if _active_research == null:
		return
	_progress += seconds
	research_progress.emit(_active_research, clamp(_progress / _active_research.research_time, 0.0, 1.0))
	if _progress >= _active_research.research_time:
		_complete_active()


func _complete_active() -> void:
	var r: ResearchData = _active_research
	_completed.append(r)
	_active_research = null
	_progress = 0.0
	if r.recipe_to_unlock != null:
		RecipeManager.unlock_recipe(r.recipe_to_unlock)
	if r.buildable_to_unlock != null:
		BuildManager.unlock_buildable(r.buildable_to_unlock)
	var lib_pos := Vector2.ZERO
	for s in get_tree().get_nodes_in_group("research_stations"):
		if is_instance_valid(s):
			lib_pos = s.global_position
			break
	VFXManager.play(VFXManager.FX.RESEARCH_DONE, lib_pos)
	AudioManager.play_beep(1320.0, 0.18, -10.0)
	research_completed.emit(r)


func get_active() -> ResearchData:
	return _active_research


func get_active_progress_percent() -> float:
	if _active_research == null:
		return 0.0
	return clamp(_progress / _active_research.research_time, 0.0, 1.0)


func get_save_state() -> Dictionary:
	var completed_ids: Array = []
	for r in _completed:
		if r != null:
			completed_ids.append(String(r.id))
	return {
		"completed": completed_ids,
		"active_id": String(_active_research.id) if _active_research != null else "",
		"progress": _progress,
	}


func load_save_state(data: Dictionary) -> void:
	_completed.clear()
	var completed_ids: Array = data.get("completed", [])
	for sid in completed_ids:
		var r := _find_by_id(StringName(sid))
		if r != null:
			_completed.append(r)
			# Reaplicar los unlocks para que recetas/buildables persistan al cargar.
			if r.recipe_to_unlock != null:
				RecipeManager.unlock_recipe(r.recipe_to_unlock)
			if r.buildable_to_unlock != null:
				BuildManager.unlock_buildable(r.buildable_to_unlock)
	var active_id: String = data.get("active_id", "")
	if active_id != "":
		_active_research = _find_by_id(StringName(active_id))
		_progress = data.get("progress", 0.0)
	else:
		_active_research = null
		_progress = 0.0


func _find_by_id(id: StringName) -> ResearchData:
	for r in _all_research:
		if r != null and r.id == id:
			return r
	return null


func reset_for_prestige() -> void:
	_completed.clear()
	_active_research = null
	_progress = 0.0
