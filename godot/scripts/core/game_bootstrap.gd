extends Node2D
## Boot-time setup for the main game scene: loads .tres catalogs and feeds them
## to the relevant AutoLoad managers, wires the workstation's recipe list, etc.

## Preload de scripts de data para que las clases estén disponibles
## cuando cargamos .tres con TypedArrays (Array[ItemData], Array[ResearchData], etc.).
const _ItemDataScript = preload("res://scripts/data/item_data.gd")
const _RecipeDataScript = preload("res://scripts/data/recipe_data.gd")
const _OrderDataScript = preload("res://scripts/data/order_data.gd")
const _ResearchDataScript = preload("res://scripts/data/research_data.gd")
const _BuildableDataScript = preload("res://scripts/data/buildable_data.gd")

const ITEMS_DIR: String = "res://data/items/"
const RECIPES_DIR: String = "res://data/recipes/"
const RESEARCH_DIR: String = "res://data/research/"
const BUILDABLES_DIR: String = "res://data/buildables/"
const ORDERS_DIR: String = "res://data/orders/"
const CUSTOMER_SCENE_PATH: String = "res://scenes/characters/customer.tscn"
const WORKER_DUENDE_PATH: String = "res://scenes/characters/worker_duende.tscn"
const WORKER_GOLEM_PATH: String = "res://scenes/characters/worker_golem.tscn"
const WORKER_APPRENTICE_PATH: String = "res://scenes/characters/worker_apprentice.tscn"
const WORKER_LENADOR_PATH: String = "res://scenes/characters/worker_lenador.tscn"
const WORKER_ESPIRITU_PATH: String = "res://scenes/characters/worker_espiritu.tscn"

@export var initial_recipes_for_cauldron: Array[RecipeData] = []
@export var generator_panel_path: NodePath
@export var hud_canvas_path: NodePath
@export var desktop_companion_path: NodePath

var _items_catalog: Array[ItemData] = []
var _recipes_catalog: Array[RecipeData] = []
var _orders_catalog: Array[OrderData] = []
var _research_catalog: Array[ResearchData] = []
var _buildables_catalog: Array[BuildableData] = []


func _ready() -> void:
	_load_all_catalogs()
	_wire_managers()
	_wire_scene_objects()
	_wire_audio_hooks()
	print("[Bootstrap] Items: %d | Recipes: %d | Orders: %d | Research: %d | Buildables: %d" % [
		_items_catalog.size(),
		_recipes_catalog.size(),
		_orders_catalog.size(),
		_research_catalog.size(),
		_buildables_catalog.size(),
	])
	# Consumir pending load (Continuar desde main_menu). Hacer aquí garantiza
	# que current_scene = main_game y todos los managers están cableados.
	if SaveManager.pending_load_slot >= 0:
		var slot: int = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
		SaveManager.load_game(slot)


## Conecta SFX a eventos de gameplay (progresion, construcción, UI).
## Centralizado aquí para mantener los managers desacoplados del audio.
func _wire_audio_hooks() -> void:
	# Progresion. Usamos call_deferred para que cascadas (varios logros + misión + pedido
	# en el mismo frame) no spawneen todo el audio + VFX simultáneamente y congelen.
	StatsManager.achievement_unlocked.connect(func(_id, _label):
		AudioManager.call_deferred(&"play_named", &"achievement_unlock")
		var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
		if proto != null:
			VFXManager.call_deferred(&"play", VFXManager.FX.ACHIEVEMENT, proto.global_position + Vector2(0, -32)))
	ResearchManager.research_completed.connect(func(_research):
		AudioManager.call_deferred(&"play_named", &"research_complete"))
	OrderManager.order_completed.connect(func(_order):
		var counter: Node2D = get_tree().get_first_node_in_group("customer_counter")
		if counter != null:
			VFXManager.call_deferred(&"play", VFXManager.FX.ORDER_COMPLETE, counter.global_position + Vector2(0, -16)))
	# Construcción
	BuildManager.placement_completed.connect(func(_buildable, _pos):
		AudioManager.play_named(&"build_place"))
	# Notificaciones (toast). Las notif genéricas ahora viven en el log del panel
	# Diario y no disparan audio. Los logros ya tocan su propio achievement_unlock.
	# Solo dejamos un ding discreto para ALERTs críticos (que sí salen como toast).
	if NotificationManager.has_signal(&"notification_posted"):
		NotificationManager.notification_posted.connect(func(_text, kind):
			if kind == NotificationManager.Kind.ALERT:
				AudioManager.call_deferred(&"play_named", &"notification"))
	# Workstation upgraded → level_up (cada workstation se autocablea cuando se registra)
	WorkstationManager.workstation_registered.connect(_hook_workstation_audio)
	for ws in WorkstationManager._stations:
		_hook_workstation_audio(ws)
	# Panel abre/cierra → ui_open / ui_close
	UIManager.panel_opened.connect(func(_panel):
		AudioManager.play_named(&"ui_open"))
	UIManager.panel_closed.connect(func(_panel):
		AudioManager.play_named(&"ui_close"))
	# HUD buttons → ui_click (+ hover en ActionBar)
	call_deferred("_hook_ui_buttons")


func _hook_workstation_audio(station: Node) -> void:
	if station == null or not station.has_signal(&"upgraded"):
		return
	if not station.upgraded.is_connected(_on_workstation_upgraded):
		station.upgraded.connect(_on_workstation_upgraded)


func _on_workstation_upgraded(_new_level: int) -> void:
	AudioManager.play_named(&"level_up")


func _hook_ui_buttons() -> void:
	# Recorre el HUD y conecta cada Button al ui_click sfx.
	var hud: Node = get_tree().get_first_node_in_group("hud_root")
	if hud == null:
		# fallback: busca en hud_canvas_path
		if hud_canvas_path != NodePath(""):
			hud = get_node_or_null(hud_canvas_path)
	if hud == null:
		return
	_attach_click_recursive(hud)
	# Hover solo en ActionBar (los 9 botones principales).
	var action_bar: Node = hud.get_node_or_null("Root/ActionBar")
	if action_bar != null:
		for child in action_bar.get_children():
			if child is Button:
				var b: Button = child as Button
				if not b.mouse_entered.is_connected(_play_ui_hover):
					b.mouse_entered.connect(_play_ui_hover)


func _attach_click_recursive(node: Node) -> void:
	if node is Button:
		var b: Button = node as Button
		if not b.pressed.is_connected(_play_ui_click):
			b.pressed.connect(_play_ui_click)
	for child in node.get_children():
		_attach_click_recursive(child)


func _play_ui_click() -> void:
	AudioManager.play_named(&"ui_click")


func _play_ui_hover() -> void:
	AudioManager.play_named(&"ui_hover")


func _load_all_catalogs() -> void:
	_load_typed(_items_catalog, ITEMS_DIR, "ItemData")
	_load_typed(_recipes_catalog, RECIPES_DIR, "RecipeData")
	_load_typed(_orders_catalog, ORDERS_DIR, "OrderData")
	_load_typed(_research_catalog, RESEARCH_DIR, "ResearchData")
	_load_typed(_buildables_catalog, BUILDABLES_DIR, "BuildableData")


func _load_typed(target: Array, path: String, expected_class: String) -> void:
	for res in _load_resources_from_dir(path):
		if res == null:
			continue
		var script = res.get_script()
		if script == null or script.get_global_name() != expected_class:
			push_warning("[Bootstrap] %s: skipping resource with mismatched class (expected %s)" % [path, expected_class])
			continue
		target.append(res)


func _load_resources_from_dir(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# En builds exportados los .tres se renombran a .tres.remap. Limpiar el sufijo.
			var clean: String = file_name
			if clean.ends_with(".remap"):
				clean = clean.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var res: Resource = load(path + clean)
				if res != null:
					result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _wire_managers() -> void:
	OrderManager.set_catalog(_orders_catalog)
	ResearchManager.set_catalog(_research_catalog)
	ResearchManager.set_item_catalog(_items_catalog)
	RecipeManager.set_catalog(_recipes_catalog)
	BuildManager.set_catalog(_buildables_catalog)
	BuildManager.unlock_default_buildables(_buildables_catalog)
	# Cuando el Patio Natural sube de nivel, desbloqueamos los buildables gated.
	ZoneExpansionManager.natural_level_changed.connect(BuildManager.apply_natural_level_unlocks)

	# Wire customer pipeline
	var customer_scene = load(CUSTOMER_SCENE_PATH)
	OrderManager.customer_scene = customer_scene
	OrderManager.spawn_point = get_tree().get_first_node_in_group("customer_spawn")
	OrderManager.counter_point = get_tree().get_first_node_in_group("customer_counter")
	OrderManager.exit_point = get_tree().get_first_node_in_group("customer_exit")

	# Wire shop pipeline
	ShopManager.register_worker_scene(GameEnums.WorkerType.DUENDE, load(WORKER_DUENDE_PATH))
	ShopManager.register_worker_scene(GameEnums.WorkerType.GOLEM, load(WORKER_GOLEM_PATH))
	ShopManager.register_worker_scene(GameEnums.WorkerType.APPRENTICE, load(WORKER_APPRENTICE_PATH))
	ShopManager.register_worker_scene(GameEnums.WorkerType.LENADOR, load(WORKER_LENADOR_PATH))
	ShopManager.register_worker_scene(GameEnums.WorkerType.ESPIRITU, load(WORKER_ESPIRITU_PATH))
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		world = get_node_or_null("World")
	ShopManager.spawn_container = world
	ShopManager.spawn_position_provider = Callable(self, "_spawn_position_for_worker")

	# Wire WindowController main/companion (for compact mode)
	if hud_canvas_path != NodePath(""):
		var hud: Node = get_node_or_null(hud_canvas_path)
		if hud != null:
			WindowController.register_main_ui(hud)
	if desktop_companion_path != NodePath(""):
		var companion: Node2D = get_node_or_null(desktop_companion_path) as Node2D
		if companion != null:
			WindowController.register_companion(companion)


func _wire_scene_objects() -> void:
	# Hand workstations their starting recipes (filtered by station type)
	for ws in get_tree().get_nodes_in_group("workstations"):
		var station := ws as Workstation
		if station == null:
			continue
		var matching: Array[RecipeData] = []
		for r in _recipes_catalog:
			if r != null and r.required_station_type == station.station_type:
				matching.append(r)
		for r in matching:
			if r not in station.available_recipes:
				station.available_recipes.append(r)

	# Wire generators -> their ItemData (best guess by resource_type)
	var item_by_type: Dictionary = {
		GameEnums.ResourceType.HERB: _find_item_by_id(&"hierba_lunar"),
		GameEnums.ResourceType.CRYSTAL: _find_item_by_id(&"cristal_cuarzo"),
		GameEnums.ResourceType.IRON_ORE: _find_item_by_id(&"mena_hierro"),
		GameEnums.ResourceType.ARCANE_WOOD: _find_item_by_id(&"madera_arcana"),
		GameEnums.ResourceType.SPIRIT_ESSENCE: _find_item_by_id(&"esencia_espiritual"),
		GameEnums.ResourceType.ARCANE_WATER: _find_item_by_id(&"agua_arcana"),
		GameEnums.ResourceType.MOON_DUST: _find_item_by_id(&"polvo_lunar"),
		GameEnums.ResourceType.AMETHYST_FRAGMENT: _find_item_by_id(&"fragmento_amatista"),
		GameEnums.ResourceType.IRON_INGOT: _find_item_by_id(&"lingote_hierro"),
	}
	for g in get_tree().get_nodes_in_group("generators"):
		var gen := g as ResourceGenerator
		if gen == null:
			continue
		if gen.item_data == null:
			gen.item_data = item_by_type.get(gen.resource_type)
		# Connect click to GeneratorPanel if available
		if generator_panel_path != NodePath(""):
			var panel: Node = get_node_or_null(generator_panel_path)
			if panel != null and panel.has_method("on_generator_clicked"):
				if not gen.clicked.is_connected(panel.on_generator_clicked):
					gen.clicked.connect(panel.on_generator_clicked)


func _spawn_position_for_worker() -> Vector2:
	# Spawn near the protagonist or the world center as fallback
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if proto != null:
		return proto.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	return Vector2.ZERO


func _find_item_by_id(id: StringName) -> ItemData:
	for i in _items_catalog:
		if i.id == id:
			return i
	return null
