extends CanvasLayer
## Companion mode estilo Metro/Win8: status compacto + grid 3×2 de tiles coloridas
## + ContentPanel a la derecha + deliver flotante.

const TILE_MIN: int = 60

# Cada tile: id, icono, label, color metro
const TILES: Array = [
	{"id": &"inventory",    "icon": "🎒", "label": "Inventario", "color": Color(0.95, 0.55, 0.30)},
	{"id": &"orders",       "icon": "📋", "label": "Pedidos",    "color": Color(0.30, 0.55, 0.95)},
	{"id": &"build",        "icon": "🔨", "label": "Construir",  "color": Color(0.78, 0.55, 0.25)},
	{"id": &"shop",         "icon": "🛒", "label": "Tienda",     "color": Color(0.30, 0.78, 0.55)},
	{"id": &"achievements", "icon": "🏆", "label": "Logros",     "color": Color(0.95, 0.78, 0.35)},
	{"id": &"stats",        "icon": "📊", "label": "Stats",      "color": Color(0.42, 0.72, 0.45)},
	{"id": &"todo",         "icon": "✓",  "label": "Tareas",     "color": Color(0.30, 0.78, 0.72)},
	{"id": &"pomodoro",     "icon": "🍅", "label": "Pomodoro",   "color": Color(0.90, 0.35, 0.40)},
	{"id": &"album",        "icon": "📔", "label": "Álbum",      "color": Color(0.72, 0.52, 0.35)},
	{"id": &"wardrobe",     "icon": "👗", "label": "Armario",    "color": Color(0.85, 0.45, 0.65)},
	{"id": &"zone",         "icon": "🌳", "label": "Zona",       "color": Color(0.65, 0.40, 0.85)},
	{"id": &"exit",         "icon": "⇱",  "label": "Salir",      "color": Color(0.55, 0.55, 0.65)},
]

@onready var menu_column: PanelContainer = $MenuColumn
@onready var resize_handle: Panel = $ResizeHandle
@onready var status_coins: Label = $MenuColumn/MenuMargin/MenuVBox/ProfileCard/ProfileVBox/StatusBox/CoinsRow/CoinsValue
@onready var status_items: Label = $MenuColumn/MenuMargin/MenuVBox/ProfileCard/ProfileVBox/StatusBox/ItemsRow/ItemsValue
@onready var status_rep: Label = $MenuColumn/MenuMargin/MenuVBox/ProfileCard/ProfileVBox/StatusBox/RepRow/RepValue
@onready var capacity_bar: ProgressBar = $MenuColumn/MenuMargin/MenuVBox/ProfileCard/ProfileVBox/StatusBox/ItemsRow/CapacityBar
@onready var day_label: Label = $MenuColumn/MenuMargin/MenuVBox/ProfileCard/ProfileVBox/ProfileHBox/NameVBox/DayLabel
@onready var tile_grid: GridContainer = $MenuColumn/MenuMargin/MenuVBox/TileGrid
@onready var content_panel: PanelContainer = $ContentPanel
@onready var content_title: Label = $ContentPanel/ContentMargin/ContentVBox/ContentTitle
@onready var content_body: VBoxContainer = $ContentPanel/ContentMargin/ContentVBox/ContentScroll/ContentBody
@onready var deliver_panel: PanelContainer = $DeliverPanel
@onready var order_label: Label = $DeliverPanel/DeliverMargin/DeliverVBox/OrderLabel
@onready var deliver_button: Button = $DeliverPanel/DeliverMargin/DeliverVBox/DeliverButton
@onready var quest_label: Label = $DeliverPanel/DeliverMargin/DeliverVBox/QuestLabel

var _current_section: StringName = &""
var _refresh_accum: float = 0.0
var _tile_refs: Dictionary = {}  # id -> Button
var _widget_pids: Dictionary = {}  # id -> int (PID del proceso lanzado)
var _resizing: bool = false
const MENU_MIN_WIDTH: float = 240.0
const MENU_MAX_WIDTH: float = 720.0

const WIDGET_CLI_ARG: Dictionary = {
	&"todo": "--todo",
	&"pomodoro": "--pomodoro",
}


func _ready() -> void:
	hide()
	WindowController.mode_changed.connect(_on_mode_changed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	InventoryManager.item_changed.connect(_on_item_changed)
	InventoryManager.reputation_changed.connect(_on_rep_changed)
	OrderManager.order_generated.connect(_on_order_generated)
	OrderManager.order_completed.connect(_on_order_completed)
	OrderManager.queue_changed.connect(_refresh_all)
	deliver_button.pressed.connect(_on_deliver_pressed)
	tile_grid.resized.connect(_resize_tiles)
	resize_handle.gui_input.connect(_on_resize_handle_input)
	menu_column.resized.connect(_sync_handle)
	_build_tiles()
	_refresh_all()
	call_deferred("_resize_tiles")
	call_deferred("_sync_handle")


func _sync_handle() -> void:
	var w: float = menu_column.size.x
	resize_handle.offset_left = w - 6
	resize_handle.offset_right = w


func _on_resize_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resizing = true
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _resizing:
		return
	if event is InputEventMouseMotion:
		var new_w: float = clamp(event.global_position.x, MENU_MIN_WIDTH, MENU_MAX_WIDTH)
		menu_column.offset_right = new_w
		content_panel.offset_left = new_w + 10
		_sync_handle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_resizing = false
		get_viewport().set_input_as_handled()


func _resize_tiles() -> void:
	if _tile_refs.is_empty():
		return
	var cols: int = tile_grid.columns
	var sep: int = tile_grid.get_theme_constant(&"h_separation")
	var avail: float = tile_grid.size.x - sep * (cols - 1)
	var side: int = max(TILE_MIN, int(avail / cols))
	for tile in _tile_refs.values():
		tile.custom_minimum_size = Vector2(side, side)


func _build_tiles() -> void:
	for child in tile_grid.get_children():
		child.queue_free()
	_tile_refs.clear()
	for spec in TILES:
		var tile := _make_tile(spec)
		tile_grid.add_child(tile)
		_tile_refs[spec.id] = tile


func _make_tile(spec: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_MIN, TILE_MIN)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.tooltip_text = spec.label
	btn.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override(&"font_hover_color", Color(1, 1, 1, 1))
	# StyleBox cozy: esquinas redondeadas, gradiente sutil, sombra
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = spec.color
	sb_normal.border_color = spec.color.lightened(0.3)
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 2
	sb_normal.corner_radius_top_left = 16
	sb_normal.corner_radius_top_right = 16
	sb_normal.corner_radius_bottom_right = 16
	sb_normal.corner_radius_bottom_left = 16
	sb_normal.content_margin_left = 6
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_right = 6
	sb_normal.content_margin_bottom = 6
	sb_normal.shadow_color = Color(0, 0, 0, 0.35)
	sb_normal.shadow_size = 4
	sb_normal.shadow_offset = Vector2(0, 2)
	sb_normal.anti_aliasing = true
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = spec.color.lightened(0.18)
	sb_hover.border_color = Color(1, 0.95, 0.55, 1)
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 3
	sb_hover.shadow_color = spec.color.lightened(0.5)
	sb_hover.shadow_color.a = 0.45
	sb_hover.shadow_size = 6
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = spec.color.darkened(0.18)
	sb_pressed.shadow_offset = Vector2(0, 0)
	sb_pressed.shadow_size = 2
	var sb_focus := sb_hover.duplicate() as StyleBoxFlat
	sb_focus.border_color = Color(1, 0.95, 0.55, 0.8)
	btn.add_theme_stylebox_override(&"normal", sb_normal)
	btn.add_theme_stylebox_override(&"hover", sb_hover)
	btn.add_theme_stylebox_override(&"pressed", sb_pressed)
	btn.add_theme_stylebox_override(&"focus", sb_focus)
	# Layout: icono grande + label abajo (autowrap)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override(&"separation", 0)
	btn.add_child(vb)
	var icon := Label.new()
	icon.text = spec.icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override(&"font_size", 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon)
	var lbl := Label.new()
	lbl.text = spec.label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override(&"font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
	btn.pressed.connect(_on_tile_pressed.bind(spec))
	btn.mouse_entered.connect(_tile_hover.bind(btn, true))
	btn.mouse_exited.connect(_tile_hover.bind(btn, false))
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	return btn


func _tile_hover(btn: Button, entering: bool) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06) if entering else Vector2.ONE, 0.16)


func _on_tile_pressed(spec: Dictionary) -> void:
	match spec.id:
		&"exit":
			WindowController.toggle_compact_mode()
		&"zone":
			var cam: Node = get_tree().get_first_node_in_group("zone_camera")
			if cam != null and cam.has_method("next_zone"):
				cam.next_zone()
			_refresh_zone_tile()
		&"build", &"shop":
			# Cierra ContentPanel si estaba abierto y muestra el panel modal grande.
			if content_panel.visible:
				_close_content()
			UIManager.toggle(spec.id)
		&"todo", &"pomodoro":
			_on_widget_section(spec)
		_:
			_on_section(spec.id, "%s  %s" % [spec.icon, spec.label])


func _on_widget_section(spec: Dictionary) -> void:
	var id: StringName = spec.id
	if _widget_pids.has(id) and OS.is_process_running(_widget_pids[id]):
		OS.kill(_widget_pids[id])
		_widget_pids.erase(id)
		AudioManager.play_soft(420.0, 0.14, -24.0)
		return
	_launch_widget_process(spec)


func _launch_widget_process(spec: Dictionary) -> void:
	var id: StringName = spec.id
	var cli_arg: String = WIDGET_CLI_ARG.get(id, "")
	if cli_arg.is_empty():
		return
	var exe: String = OS.get_executable_path()
	var args: PackedStringArray = []
	if OS.has_feature("editor"):
		# En el editor, lanzar el binario de Godot apuntando al proyecto
		args.append("--path")
		args.append(ProjectSettings.globalize_path("res://"))
	args.append("--")
	args.append(cli_arg)
	var pid: int = OS.create_process(exe, args)
	if pid > 0:
		_widget_pids[id] = pid
		AudioManager.play_soft(560.0, 0.18, -22.0)
	else:
		push_warning("[CompactUI] Failed to launch process for %s" % id)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.4:
		return
	_refresh_accum = 0.0
	quest_label.text = "📋 " + DailyQuestManager.get_progress_text()
	if day_label != null:
		var season_names: Array = ["Primavera", "Verano", "Otoño", "Invierno"]
		var s: int = clamp(CalendarManager.current_season, 0, 3)
		day_label.text = "✦ Día %d · %s" % [CalendarManager.current_day, season_names[s]]


func _on_mode_changed(is_compact: bool) -> void:
	visible = is_compact
	if is_compact:
		_refresh_all()
	else:
		_current_section = &""
		content_panel.visible = false


func _refresh_all() -> void:
	_on_coins_changed(InventoryManager.arcane_coins)
	_update_capacity()
	status_rep.text = "★ %s" % NumFormat.short(InventoryManager.reputation)
	var order: OrderData = OrderManager.get_current_order()
	if order != null and order.requested_item != null:
		_on_order_generated(order)
	else:
		order_label.text = "Order: —"
		deliver_button.disabled = true
	_refresh_zone_tile()
	_refresh_deliver_button()
	if _current_section != &"":
		_populate_section(_current_section)


func _refresh_deliver_button() -> void:
	var order: OrderData = OrderManager.get_current_order()
	if order == null or order.requested_item == null:
		deliver_button.disabled = true
		return
	deliver_button.disabled = InventoryManager.get_item_count(order.requested_item) < order.requested_quantity


func _refresh_zone_tile() -> void:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam == null or not cam.has_method("get_current_zone"):
		return
	var tile: Button = _tile_refs.get(&"zone")
	if tile == null:
		return
	var icon_label: Label = tile.get_child(0).get_child(0) if tile.get_child_count() > 0 else null
	if icon_label == null:
		return
	match cam.get_current_zone().name:
		&"natural": icon_label.text = "🌳"
		&"taller": icon_label.text = "🔨"
		&"recepcion": icon_label.text = "🏛"


func _on_coins_changed(amount: int) -> void:
	status_coins.text = NumFormat.short(amount)
	_refresh_deliver_button()


func _update_capacity() -> void:
	var total: int = InventoryManager.get_total_count()
	var cap: int = InventoryManager.max_capacity
	status_items.text = "%s/%s" % [NumFormat.short(total), NumFormat.short(cap)]
	capacity_bar.max_value = max(1, cap)
	capacity_bar.value = clamp(total, 0, cap)


func _on_item_changed(_i: ItemData, _q: int) -> void:
	_update_capacity()
	_refresh_deliver_button()


func _on_rep_changed(amount: int) -> void:
	status_rep.text = "★ %s" % NumFormat.short(amount)


func _on_order_generated(o: OrderData) -> void:
	if o == null or o.requested_item == null:
		order_label.text = "Order: —"
		deliver_button.disabled = true
		return
	order_label.text = "%dx %s" % [o.requested_quantity, o.requested_item.display_name]
	_refresh_deliver_button()


func _on_order_completed(_o: OrderData) -> void:
	if OrderManager.get_active_count() == 0:
		order_label.text = "✓"
		deliver_button.disabled = true


func _on_deliver_pressed() -> void:
	deliver_button.disabled = true
	OrderManager.try_complete_current()


func _on_section(section_id: StringName, title: String) -> void:
	if _current_section == section_id and content_panel.visible:
		_close_content()
		return
	_current_section = section_id
	content_title.text = title
	_populate_section(section_id)
	_open_content()


func _open_content() -> void:
	if UIManager.has_method("animate_open"):
		UIManager.animate_open(content_panel)
	else:
		content_panel.visible = true
	AudioManager.play_soft(560.0, 0.18, -22.0)


func _close_content() -> void:
	_current_section = &""
	if UIManager.has_method("animate_close"):
		UIManager.animate_close(content_panel)
	else:
		content_panel.visible = false
	AudioManager.play_soft(420.0, 0.14, -24.0)


func _populate_section(section_id: StringName) -> void:
	for c in content_body.get_children():
		c.queue_free()
	match section_id:
		&"inventory":
			_populate_inventory()
		&"orders":
			_populate_orders()
		&"achievements":
			_populate_achievements()
		&"stats":
			_populate_stats()
		&"album":
			_populate_album()
		&"wardrobe":
			_populate_wardrobe()


func _populate_album() -> void:
	var skins: Array = []
	for path in CustomerAI.NPC_POOL + CustomerAI.VIP_POOL:
		skins.append(StringName(path.get_file().get_basename()))
	_add_line("Descubiertos: %d/%d" % [AlbumManager.discovered_total(), skins.size()])
	for skin in skins:
		if AlbumManager.is_discovered(skin):
			var pretty: String = String(skin).trim_prefix("npc_").replace("_", " ").capitalize()
			_add_line("✓ %s ×%d" % [pretty, AlbumManager.get_count(skin)])


func _populate_wardrobe() -> void:
	# Botón por outfit: cambia el look de la protagonista desde el escritorio.
	for oid in WardrobeManager.OUTFITS:
		if not WardrobeManager.is_available(oid):
			continue
		var btn := Button.new()
		var current: bool = WardrobeManager.current_outfit == oid
		btn.text = ("✔ " if current else "") + WardrobeManager.OUTFITS[oid]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override(&"font_size", 13)
		btn.pressed.connect(func():
			WardrobeManager.set_outfit(oid)
			_populate_section(&"wardrobe"))
		content_body.add_child(btn)


func _populate_inventory() -> void:
	var total: int = InventoryManager.get_total_count()
	if total == 0:
		_add_line("(vacío)")
		return
	var top: Array = []
	for id in InventoryManager.items.keys():
		var qty: int = InventoryManager.items[id]
		if qty <= 0: continue
		var item: ItemData = InventoryManager.item_lookup.get(id)
		var name_str: String = item.display_name if item != null else String(id)
		top.append({"name": name_str, "qty": qty})
	top.sort_custom(func(a, b): return a.qty > b.qty)
	for i in min(top.size(), 18):
		_add_line("%s ×%d" % [top[i].name, top[i].qty])


func _populate_orders() -> void:
	var active: Array = OrderManager.get_active_orders()
	if active.is_empty():
		_add_line("(sin pedidos activos)")
		return
	for entry in active:
		var o: OrderData = entry.data
		if o == null: continue
		var have: int = InventoryManager.get_item_count(o.requested_item)
		_add_line("%dx %s (%d/%d)" % [o.requested_quantity, o.requested_item.display_name, have, o.requested_quantity])


func _populate_achievements() -> void:
	var unlocked: Array = StatsManager.get_unlocked_achievements()
	_add_line("Desbloqueados: %d/%d" % [unlocked.size(), StatsManager.ACHIEVEMENTS.size()])
	for ach in StatsManager.ACHIEVEMENTS:
		var done: bool = ach.id in unlocked
		var icon: String = "✓" if done else "·"
		_add_line("%s %s" % [icon, ach.label])


func _populate_stats() -> void:
	for stat_id in StatsManager.stats.keys():
		_add_line("%s: %s" % [stat_id, NumFormat.short(StatsManager.stats[stat_id])])


func _add_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_body.add_child(l)
