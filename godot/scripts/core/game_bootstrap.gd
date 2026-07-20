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
	SaveManager.mark_world_ready(true)
	# Partículas ambientales por zona (luciérnagas/polvo/destellos).
	var ambience := ZoneAmbience.new()
	ambience.name = "ZoneAmbience"
	add_child(ambience)
	# Ambiente nocturno: luciérnagas/grillos/ventanas que se encienden de noche.
	var nightfx := NightFX.new()
	nightfx.name = "NightFX"
	add_child(nightfx)
	# Detalles de estación (pétalos/hojas/nieve + tinte del follaje).
	var seasonfx := SeasonFX.new()
	seasonfx.name = "SeasonFX"
	add_child(seasonfx)
	# Fundido suave al cambiar de zona.
	var zfade := preload("res://scripts/fx/zone_fade.gd").new()
	zfade.name = "ZoneFade"
	add_child(zfade)
	# Confeti + corazón al completar pedidos.
	var celeb := preload("res://scripts/fx/celebration_fx.gd").new()
	celeb.name = "CelebrationFX"
	add_child(celeb)
	# Tráfico de fondo en la recepción (transeúntes) + micro-eventos cozy.
	var village := VillageLife.new()
	village.name = "VillageLife"
	add_child(village)
	var micro := MicroEvents.new()
	micro.name = "MicroEvents"
	add_child(micro)
	# Panel del árbol de mejoras del local (se auto-registra en UIManager).
	var ui_canvas: Node = get_tree().current_scene.get_node_or_null("UICanvas")
	if ui_canvas != null:
		var up_panel: Control = preload("res://scripts/ui/emporium_upgrade_panel.gd").new()
		up_panel.name = "EmporiumUpgradePanel"
		ui_canvas.add_child(up_panel)
	call_deferred("_spawn_cat")
	# Vida del patio natural: scatter de props + maleza que crece sola.
	var nlife := NaturalLife.new()
	nlife.name = "NaturalLife"
	add_child(nlife)
	call_deferred("_spawn_default_lanterns")
	call_deferred("_spawn_zone_doors")
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


## Faroles por defecto: dos por zona (se encienden solos de noche).
func _spawn_default_lanterns() -> void:
	# Solo en partida nueva: si ya hay faroles (cargados del save o movidos/
	# borrados por el jugador), no volver a spawnearlos ni revivir los borrados.
	if not get_tree().get_nodes_in_group("lanterns").is_empty():
		return
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		return
	var scene: PackedScene = load("res://scenes/environment/decorations/decoration_lantern.tscn")
	if scene == null:
		return
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	var cur: StringName = &""
	if cam != null and cam.has_method("get_current_zone"):
		cur = cam.get_current_zone().name
	for zr in _find_zone_regions(get_tree().current_scene):
		var info: Array = _zone_name_group(zr.zone_type)
		if info.is_empty():
			continue
		for off in [Vector2(-zr.size.x * 0.34, -zr.size.y * 0.18), Vector2(zr.size.x * 0.34, -zr.size.y * 0.18)]:
			var lan: Node2D = scene.instantiate()
			world.add_child(lan)
			lan.global_position = zr.global_position + off
			lan.add_to_group(info[1])
			lan.visible = (cur == &"" or cur == info[0])
			# Registrar en el grid → se puede mover/demoler/copiar como cualquier objeto.
			# cost 0: al ser gratis, no da reembolso al demolerlos.
			BuildManager.register_prebuilt(lan, lan.global_position, &"deco_lantern", 0)


## Puertas entre zonas contiguas (recepción↔taller, taller↔patio). La maga las
## cruza con un clic y viaja sola, sin arrastrarla. Se colocan en la pared
## trasera del lado que mira al vecino.
func _spawn_zone_doors() -> void:
	if not get_tree().get_nodes_in_group("zone_doors").is_empty():
		return
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		return
	# Mapear nombre de zona -> su ZoneRegion (centro y tamaño).
	var regions: Dictionary = {}
	for zr in _find_zone_regions(get_tree().current_scene):
		var info: Array = _zone_name_group(zr.zone_type)
		if not info.is_empty():
			regions[info[0]] = zr
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	var cur: StringName = &""
	if cam != null and cam.has_method("get_current_zone"):
		cur = cam.get_current_zone().name
	# Adyacencias: [zona, destino]. Cada par tiene su puerta de vuelta.
	var links: Array = [
		[&"recepcion", &"taller"],
		[&"taller", &"recepcion"],
		[&"taller", &"natural"],
		[&"natural", &"taller"],
	]
	for link in links:
		var mine: StringName = link[0]
		var target: StringName = link[1]
		var zr: ZoneRegion = regions.get(mine)
		var tzr: ZoneRegion = regions.get(target)
		if zr == null or tzr == null:
			continue
		# Lado hacia el vecino: si el destino está a la izquierda, portal a la izquierda.
		var dir: float = -1.0 if tzr.global_position.x < zr.global_position.x else 1.0
		var edge_x: float = zr.global_position.x + dir * (zr.size.x * 0.5 - 70.0)
		var floor_y: float = zr.global_position.y + zr.size.y * 0.16
		var door := ZoneDoor.new()
		door.live = true  # portal real (no fantasma)
		door.setup(mine, target)
		world.add_child(door)
		door.global_position = Vector2(edge_x, floor_y)
		var info: Array = _zone_name_group(zr.zone_type)
		door.add_to_group(info[1])  # *_visual → se oculta/enseña con la zona
		door.visible = (cur == &"" or cur == mine)


func _find_zone_regions(root: Node) -> Array:
	var out: Array = []
	if root is ZoneRegion:
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_zone_regions(c))
	return out


func _zone_name_group(zt: int) -> Array:
	match zt:
		GameEnums.ZoneType.NATURE: return [&"natural", "natural_visual"]
		GameEnums.ZoneType.WORKSHOP: return [&"taller", "taller_visual"]
		GameEnums.ZoneType.RECEPTION: return [&"recepcion", "recepcion_visual"]
		_: return []


## Mascota de la tienda: duerme junto a la primera workstation del taller.
func _spawn_cat() -> void:
	var cat: Node2D = load("res://scenes/characters/cat.tscn").instantiate()
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		world = self
	world.add_child(cat)
	var anchor: Node2D = null
	for ws in get_tree().get_nodes_in_group("workstations"):
		anchor = ws as Node2D
		break
	cat.global_position = (anchor.global_position + Vector2(52, 26)) if anchor != null else Vector2(-1000, 120)
	cat.home_position = cat.global_position
	cat.add_to_group("taller_visual")


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
	# Objetos creados por el jugador (Abracadabra): registrarlos en el catálogo.
	CustomObjectManager.register_all()
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
	# Los ayudantes comprados se invocan en el Patio Natural (ahí recolectan).
	if not ShopManager.worker_purchased.is_connected(_on_worker_purchased):
		ShopManager.worker_purchased.connect(_on_worker_purchased)

	# Wire WindowController main/companion (for compact mode)
	if hud_canvas_path != NodePath(""):
		var hud: Node = get_node_or_null(hud_canvas_path)
		if hud != null:
			WindowController.register_main_ui(hud)
	# Las demás capas de UI (paneles de clientes, atajos, viñeta) viven en
	# CanvasLayers aparte; también deben ocultarse en compact mode para que no
	# se vean por detrás del companion.
	for canvas_name in ["UICanvas", "HotkeyLegend", "VignetteLayer"]:
		var canvas: Node = get_node_or_null(canvas_name)
		if canvas != null:
			WindowController.register_main_ui(canvas)
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
	# Registrar el mapeo en ResourceManager para que generadores construidos
	# en runtime puedan auto-asignar su item_data via assign_item_to_generator.
	for t in item_by_type:
		ResourceManager.register_type_item(t, item_by_type[t])
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
	# Invocar dentro del Patio Natural (ahí recolectan recursos). Punto al azar
	# dentro del rect de la zona, con margen para no pegarse a los bordes.
	var rect: Rect2 = GridManager.get_zone_rect(GameEnums.ZoneType.NATURE)
	if rect.size != Vector2.ZERO:
		return Vector2(
			randf_range(rect.position.x + 60.0, rect.end.x - 60.0),
			randf_range(rect.position.y + 80.0, rect.end.y - 60.0))
	# Fallback: cerca del protagonista o el centro del mundo.
	var proto: Node2D = get_tree().get_first_node_in_group("protagonist")
	if proto != null:
		return proto.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	return Vector2.ZERO


## Ayudante recién comprado: pertenece al Patio Natural (grupo visual + visible
## solo si la cámara está en esa zona). Su home_position (deferido en _ready) ya
## queda en el patio porque lo posicionamos antes de emitir worker_purchased.
func _on_worker_purchased(_worker_type: int, instance: Node2D) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.add_to_group("natural_visual")
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		instance.visible = cam.get_current_zone().name == &"natural"


func _find_item_by_id(id: StringName) -> ItemData:
	for i in _items_catalog:
		if i.id == id:
			return i
	return null




