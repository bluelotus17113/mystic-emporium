extends CanvasLayer
## Persistent on-screen HUD. Shows coins, inventory totals, current order, calendar
## and offers buttons to all main panels + companion mode.

@onready var coins_label: Label = $Root/BottomLeftInfo/InfoMargin/InfoVBox/CoinsRow/CoinsLabel
@onready var inventory_label: Label = $Root/BottomLeftInfo/InfoMargin/InfoVBox/InvRow/InventoryLabel
@onready var rep_label: Label = $Root/BottomLeftInfo/InfoMargin/InfoVBox/RepRow/RepLabel
@onready var auto_bar: HBoxContainer = $Root/TopBar/AutoBar
@onready var order_label: Label = $Root/TopBar/OrderLabel
@onready var deliver_button: Button = $Root/TopBar/DeliverButton

@onready var clock_label: Label = $Root/ClockBox/ClockLabel
@onready var daily_quest_label: Label = $Root/ClockBox/DailyQuestLabel
@onready var daily_quest_progress: ProgressBar = $Root/ClockBox/DailyQuestProgress
@onready var prev_zone_button: Button = $Root/ClockBox/ZoneSwitcher/PrevZoneButton
@onready var next_zone_button: Button = $Root/ClockBox/ZoneSwitcher/NextZoneButton
@onready var zone_label: Label = $Root/ClockBox/ZoneSwitcher/ZoneLabel
@onready var expand_natural_button: Button = $Root/ClockBox/ExpandNaturalButton

@onready var inventory_button: Button = $Root/ActionBar/InventoryButton
@onready var build_button: Button = $Root/ActionBar/BuildButton
@onready var shop_button: Button = $Root/ActionBar/ShopButton
@onready var orders_button: Button = $Root/ActionBar/OrdersButton
@onready var recipe_book_button: Button = $Root/ActionBar/RecipeBookButton
@onready var settings_button: Button = $Root/ActionBar/SettingsButton
@onready var demolish_button: Button = $Root/ActionBar/DemolishButton
@onready var stats_button: Button = $Root/ActionBar/StatsButton
@onready var achievements_button: Button = $Root/ActionBar/AchievementsButton
@onready var companion_button: Button = $Root/ActionBar/CompanionButton

@onready var research_label: Label = $Root/ResearchBox/ResearchMargin/ResearchVBox/ResearchLabel
@onready var research_progress: ProgressBar = $Root/ResearchBox/ResearchMargin/ResearchVBox/ResearchProgress

const SEASON_NAMES: Array[String] = ["Primavera", "Verano", "Otoño", "Invierno"]


func _ready() -> void:
	InventoryManager.coins_changed.connect(_on_coins_changed)
	InventoryManager.item_changed.connect(_on_item_changed)
	InventoryManager.reputation_changed.connect(_on_reputation_changed)
	OrderManager.order_generated.connect(_on_order_generated)
	OrderManager.order_completed.connect(_on_order_completed)
	OrderManager.queue_changed.connect(_refresh_all)

	deliver_button.pressed.connect(_on_deliver_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	build_button.pressed.connect(_on_build_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	orders_button.pressed.connect(func(): UIManager.toggle(&"orders"))
	recipe_book_button.pressed.connect(func(): UIManager.toggle(&"recipe_book"))
	settings_button.pressed.connect(func(): UIManager.toggle(&"settings"))
	stats_button.pressed.connect(func(): UIManager.toggle(&"stats"))
	achievements_button.pressed.connect(func(): UIManager.toggle(&"achievements"))
	demolish_button.pressed.connect(_on_demolish_pressed)
	companion_button.pressed.connect(WindowController.toggle_compact_mode)

	BuildManager.demolish_mode_changed.connect(_on_demolish_mode_changed)
	ResearchManager.research_started.connect(_on_research_started)
	ResearchManager.research_progress.connect(_on_research_progress)
	ResearchManager.research_completed.connect(_on_research_completed)
	IdleAutomationManager.automation_toggled.connect(_on_auto_toggled)
	_wire_zone_switcher()
	_setup_action_button_hover()
	_build_auto_chips()
	_refresh_all()


func _setup_action_button_hover() -> void:
	# ponytail: scale-up sutil en hover/press → "vida" a la barra sin tocar StyleBox.
	for btn in [inventory_button, build_button, shop_button, orders_button,
				settings_button, demolish_button, stats_button,
				achievements_button, companion_button]:
		if btn == null:
			continue
		btn.pivot_offset = btn.size * 0.5
		btn.mouse_entered.connect(_on_action_btn_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_action_btn_hover.bind(btn, false))
		btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)


func _on_action_btn_hover(btn: Button, entering: bool) -> void:
	if not is_instance_valid(btn):
		return
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.08, 1.08) if entering else Vector2.ONE, 0.18)


func _wire_zone_switcher() -> void:
	# ponytail: la cámara puede estar o no en la escena (compact mode / menu). Si no existe,
	# ocultamos el switcher para no fallar silenciosamente.
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	if cam == null:
		# fallback: buscar Camera2D con el script.
		for c in get_tree().get_nodes_in_group("world_container"):
			cam = c.get_parent().get_node_or_null("Camera2D")
			if cam != null: break
	if cam == null:
		prev_zone_button.get_parent().hide()
		return
	prev_zone_button.pressed.connect(cam.prev_zone)
	next_zone_button.pressed.connect(cam.next_zone)
	cam.zone_changed.connect(_on_zone_changed)
	expand_natural_button.pressed.connect(func(): ZoneExpansionManager.expand_natural())
	ZoneExpansionManager.natural_level_changed.connect(func(_l): _refresh_expand_button())
	InventoryManager.coins_changed.connect(func(_c): _refresh_expand_button())
	_on_zone_changed(cam.get_current_zone().name)


func _on_zone_changed(zone_name: StringName) -> void:
	match zone_name:
		&"natural": zone_label.text = "🌳 Natural (1)"
		&"taller": zone_label.text = "🔨 Taller (2)"
		&"recepcion": zone_label.text = "🏛 Recepción (3)"
		_: zone_label.text = String(zone_name)
	expand_natural_button.visible = (zone_name == &"natural")
	_refresh_expand_button()


func _refresh_expand_button() -> void:
	if not expand_natural_button.visible:
		return
	if ZoneExpansionManager.is_max_level():
		expand_natural_button.text = "🌳 Patio máximo"
		expand_natural_button.disabled = true
	else:
		var cost: int = ZoneExpansionManager.get_next_cost()
		var next_label: String = ZoneExpansionManager.NATURAL_LEVELS[ZoneExpansionManager.natural_level + 1].label
		expand_natural_button.text = "🌳 → %s (%s ⚜)" % [next_label, NumFormat.short(cost)]
		expand_natural_button.disabled = not ZoneExpansionManager.can_expand()


const _AUTO_CHIPS: Array = [
	{"key": &"craft",       "label": "🔨 Craft"},
	{"key": &"orders",      "label": "📦 Entregas"},
	{"key": &"research",    "label": "📚 Research"},
	{"key": &"upgrade",     "label": "⬆ Upgrade"},
	{"key": &"buy_workers", "label": "🛒 Workers"},
]

var _chip_buttons: Dictionary = {}  # key (StringName) -> Button


func _build_auto_chips() -> void:
	for c in _AUTO_CHIPS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = c.label
		btn.custom_minimum_size = Vector2(0, 24)
		btn.add_theme_font_size_override(&"font_size", 11)
		btn.button_pressed = IdleAutomationManager.get_auto(c.key)
		btn.toggled.connect(_on_chip_toggled.bind(c.key))
		_apply_chip_style(btn)
		auto_bar.add_child(btn)
		_chip_buttons[c.key] = btn


func _apply_chip_style(btn: Button) -> void:
	# Cartel colgante de madera: ON = iluminado dorado, OFF = madera apagada.
	var tex: Texture2D = load("res://art/sprites/ui/theme/sign_wood.png")
	btn.add_theme_color_override(&"font_color", Color(0.22, 0.15, 0.09, 1))
	btn.add_theme_color_override(&"font_pressed_color", Color(0.20, 0.12, 0.05, 1))
	btn.add_theme_color_override(&"font_hover_color", Color(0.20, 0.12, 0.05, 1))
	btn.add_theme_color_override(&"font_outline_color", Color(0.98, 0.95, 0.86, 1))
	btn.add_theme_constant_override(&"outline_size", 3)
	btn.add_theme_font_size_override(&"font_size", 12)
	btn.custom_minimum_size = Vector2(0, 34)
	var mk := func(mod: Color) -> StyleBoxTexture:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(12)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 4
		sb.modulate_color = mod
		return sb
	btn.add_theme_stylebox_override(&"normal", mk.call(Color(0.86, 0.74, 0.56, 1)))
	btn.add_theme_stylebox_override(&"hover", mk.call(Color(0.82, 0.72, 0.58, 1)))
	btn.add_theme_stylebox_override(&"pressed", mk.call(Color(1.0, 0.85, 0.45, 1)))
	btn.add_theme_stylebox_override(&"hover_pressed", mk.call(Color(1.0, 0.9, 0.55, 1)))

func _on_chip_toggled(on: bool, key: StringName) -> void:
	IdleAutomationManager.set_auto(key, on)


func _on_auto_toggled(key: StringName, on: bool) -> void:
	# Sincroniza el estado visual si algo más cambió el toggle (load save, otro panel).
	var btn: Button = _chip_buttons.get(key)
	if btn != null and btn.button_pressed != on:
		btn.set_pressed_no_signal(on)


var _hud_refresh_accum: float = 0.0


func _process(_delta: float) -> void:
	# ponytail: el reloj y la quest cambian a 1Hz; reformatear 60x/seg es desperdicio.
	_hud_refresh_accum += _delta
	if _hud_refresh_accum < 0.25:
		return
	_hud_refresh_accum = 0.0
	clock_label.text = "Día %d · %s · %s · %s" % [
		CalendarManager.current_day,
		CalendarManager.get_clock_string(),
		CalendarManager.get_phase_name(),
		SEASON_NAMES[CalendarManager.current_season] if CalendarManager.current_season < SEASON_NAMES.size() else "—"
	]
	daily_quest_label.text = "📋 " + DailyQuestManager.get_progress_text()
	var q: Dictionary = DailyQuestManager.current_quest
	if q.is_empty():
		daily_quest_progress.value = 1.0
		daily_quest_progress.modulate = Color(0.6, 1, 0.7, 0.7)
	else:
		var target: float = max(1, q.get("target", 1))
		daily_quest_progress.value = clamp(DailyQuestManager.current_progress / target, 0.0, 1.0)
		daily_quest_progress.modulate = Color(1, 0.92, 0.5, 0.9)


func _on_demolish_pressed() -> void:
	if BuildManager.is_demolish_active():
		BuildManager.exit_demolish_mode()
	else:
		BuildManager.enter_demolish_mode()


func _on_demolish_mode_changed(active: bool) -> void:
	demolish_button.text = "Cancelar" if active else "Demoler"
	demolish_button.modulate = Color(1, 0.5, 0.5, 1) if active else Color.WHITE


func _on_reputation_changed(amount: int) -> void:
	rep_label.text = "%s" % NumFormat.short(amount)


func _on_shop_pressed() -> void:
	UIManager.toggle(&"shop")


func _refresh_all() -> void:
	_on_coins_changed(InventoryManager.arcane_coins)
	inventory_label.text = "%s/%s" % [
		NumFormat.short(InventoryManager.get_total_count()),
		NumFormat.short(InventoryManager.max_capacity)
	]
	var order: OrderData = OrderManager.get_current_order()
	if order == null:
		order_label.text = "Order: —"
		deliver_button.disabled = true
	else:
		_on_order_generated(order)


func _on_coins_changed(amount: int) -> void:
	coins_label.text = "%s" % NumFormat.short(amount)
	_refresh_deliver_button()


func _on_item_changed(_item: ItemData, _qty: int) -> void:
	inventory_label.text = "%s/%s" % [
		NumFormat.short(InventoryManager.get_total_count()),
		NumFormat.short(InventoryManager.max_capacity)
	]
	_refresh_deliver_button()


func _on_order_generated(order: OrderData) -> void:
	if order == null or order.requested_item == null:
		order_label.text = "Order: —"
		deliver_button.disabled = true
		return
	var stars: String = "★".repeat(order.tier)
	order_label.text = "[%s] %d × %s (%s ⚜)" % [stars, order.requested_quantity, order.requested_item.display_name, NumFormat.short(order.coin_reward)]
	# Color por tier
	match order.tier:
		1: order_label.modulate = Color.WHITE
		2: order_label.modulate = Color(0.75, 0.95, 0.6, 1)
		3: order_label.modulate = Color(0.6, 0.85, 1, 1)
		4: order_label.modulate = Color(0.95, 0.7, 1, 1)
		5: order_label.modulate = Color(1, 0.85, 0.4, 1)
	_refresh_deliver_button()


func _on_order_completed(_order: OrderData) -> void:
	# queue_changed → _refresh_all mostrará la próxima orden activa.
	# Aquí solo damos feedback visual breve si no quedan más.
	if OrderManager.get_active_count() == 0:
		order_label.text = "Order: ✓ entregada"
		deliver_button.disabled = true


func _refresh_deliver_button() -> void:
	var order: OrderData = OrderManager.get_current_order()
	if order == null or order.requested_item == null:
		deliver_button.disabled = true
		return
	deliver_button.disabled = InventoryManager.get_item_count(order.requested_item) < order.requested_quantity


func _on_deliver_pressed() -> void:
	deliver_button.disabled = true  # evita doble click — _refresh_deliver_button lo reactiva si toca
	OrderManager.try_complete_current()


func _on_inventory_pressed() -> void:
	UIManager.toggle(&"inventory")


func _on_build_pressed() -> void:
	UIManager.toggle(&"build")


func _on_research_started(r: ResearchData) -> void:
	research_label.text = "Investigación: %s" % r.display_name
	research_progress.value = 0.0


func _on_research_progress(r: ResearchData, percent: float) -> void:
	research_label.text = "Investigación: %s (%d%%)" % [r.display_name, int(percent * 100)]
	research_progress.value = percent * 100.0


func _on_research_completed(_r: ResearchData) -> void:
	research_label.text = "Investigación: ✓ completada"
	research_progress.value = 100.0
