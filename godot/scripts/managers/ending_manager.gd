extends Node
## Detecta cuando se craftea la receta legendaria final (Estrella del Emporio).
## Persiste el flag para que la celebración solo se dispare la primera vez,
## y registra el achievement de "Emporio Completado".

signal emporium_completed

const LEGENDARY_RECIPE_ID: StringName = &"recipe_estrella_emporio"
const LEGENDARY_ITEM_ID: StringName = &"estrella_emporio"

var emporium_completed_flag: bool = false


func _ready() -> void:
	# Defer connect — los managers se hookean tras boot
	call_deferred("_wire_signals")


func _wire_signals() -> void:
	# Hookear a todas las workstations futuras y existentes
	for ws in get_tree().get_nodes_in_group("workstations"):
		_connect_workstation(ws)
	WorkstationManager.workstation_clicked.connect(func(_w): _refresh_connections())


func _refresh_connections() -> void:
	# Reconectar workstations nuevas (las viejas dedupean automáticamente con is_connected)
	for ws in get_tree().get_nodes_in_group("workstations"):
		_connect_workstation(ws)


func _connect_workstation(ws: Node) -> void:
	if ws == null or not ws.has_signal(&"craft_completed"):
		return
	if ws.craft_completed.is_connected(_on_craft_completed):
		return
	ws.craft_completed.connect(_on_craft_completed)


func _on_craft_completed(recipe: RecipeData) -> void:
	if recipe == null or recipe.id != LEGENDARY_RECIPE_ID:
		return
	if emporium_completed_flag:
		return
	emporium_completed_flag = true
	StatsManager.bump("emporium_legendaries_crafted", 1)
	emporium_completed.emit()
	NotificationManager.post("✨ ¡EMPORIO COMPLETADO! ✨ Has forjado la Estrella del Emporio. Eres maestra del oficio.", NotificationManager.Kind.REWARD)


func get_save_state() -> Dictionary:
	return {"completed": emporium_completed_flag}


func load_save_state(data: Dictionary) -> void:
	emporium_completed_flag = bool(data.get("completed", false))
