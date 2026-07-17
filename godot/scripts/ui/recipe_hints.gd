class_name RecipeHints
## Tooltips ricos para recetas: estado de cada ingrediente (✔/✘ según
## inventario) y, si falta, la cadena de dónde conseguirlo (receta+estación
## que lo produce, o recolección en el mundo).


static func tooltip_for(recipe: RecipeData) -> String:
	if recipe == null:
		return ""
	var lines: PackedStringArray = []
	lines.append("%s  (tier %d)" % [recipe.display_name, recipe.tier])
	if recipe.description != "":
		lines.append(recipe.description)
	lines.append("")
	for pair in recipe.get_ingredient_pairs():
		var item: ItemData = pair.item
		if item == null:
			continue
		var have: int = InventoryManager.get_item_count(item)
		var ok: bool = have >= pair.qty
		lines.append("%s %d× %s  —  tienes %d" % ["✔" if ok else "✘", pair.qty, item.display_name, have])
		if not ok:
			lines.append("    ↳ %s" % _source_of(item))
	lines.append("")
	lines.append("⏱ %.0f s  →  %d× %s" % [recipe.crafting_time, recipe.output_quantity,
		recipe.output_item.display_name if recipe.output_item != null else "?"])
	return "\n".join(lines)


static func _source_of(item: ItemData) -> String:
	# ¿Alguna receta lo produce? (desbloqueada primero; si no, cualquiera)
	var locked_hint: RecipeData = null
	for r in RecipeManager.get_all_recipes():
		if r.output_item != item:
			continue
		if RecipeManager.is_unlocked(r):
			return "se craftea: «%s» en %s" % [r.display_name, _station_name(r.required_station_type)]
		if locked_hint == null:
			locked_hint = r
	if locked_hint != null:
		return "receta bloqueada: «%s» (%s) — investiga para desbloquear" % [
			locked_hint.display_name, _station_name(locked_hint.required_station_type)]
	return "se recolecta en el mundo (nodos y generadores de recursos)"


static func _station_name(t: GameEnums.StationType) -> String:
	match t:
		GameEnums.StationType.CAULDRON: return "Caldero"
		GameEnums.StationType.MYSTIC_FORGE: return "Forja Mística"
		GameEnums.StationType.ENCHANTING_TABLE: return "Mesa de Encantamiento"
		GameEnums.StationType.SCRIBE_DESK: return "Escritorio de Escriba"
		GameEnums.StationType.SUMMONING_CIRCLE: return "Círculo de Invocación"
		GameEnums.StationType.ARCANE_LIBRARY: return "Biblioteca Arcana"
		GameEnums.StationType.ASTRO_OBSERVATORY: return "Observatorio"
		_: return "estación"
