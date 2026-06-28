extends PanelContainer

const PANEL_NAME: StringName = &"inventory"

@onready var coins_label: Label = $Margin/VBox/Header/CoinsLabel
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var search_input: LineEdit = $Margin/VBox/SearchInput
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var empty_hint: Label = $Margin/VBox/Footer/EmptyHint
@onready var sell_all_button: Button = $Margin/VBox/Footer/SellAllButton

var _filter: String = ""


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	sell_all_button.pressed.connect(_on_sell_all)
	search_input.text_changed.connect(_on_search_changed)
	InventoryManager.item_changed.connect(_on_item_changed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_toggle_inventory"):
		UIManager.toggle(PANEL_NAME)


func _on_item_changed(_item: ItemData, _qty: int) -> void:
	if visible:
		_rebuild()


func _on_coins_changed(amount: int) -> void:
	coins_label.text = "💰 %d" % amount
	if visible:
		_update_sell_button_state()


func _on_search_changed(text: String) -> void:
	_filter = text.strip_edges().to_lower()
	_rebuild()


func _on_sell_all() -> void:
	var gained: int = InventoryManager.sell_all()
	if gained > 0:
		NotificationManager.post("+%d ⚜  por inventario vendido" % gained, NotificationManager.Kind.REWARD)


func _on_sell_one(item: ItemData) -> void:
	InventoryManager.sell_item(item, 1)


func _on_sell_stack(item: ItemData) -> void:
	InventoryManager.sell_item(item, InventoryManager.get_item_count(item))


func _rebuild() -> void:
	coins_label.text = "💰 %d" % InventoryManager.arcane_coins
	for child in list.get_children():
		child.queue_free()
	if InventoryManager.items.is_empty():
		var l := Label.new()
		l.text = "(inventario vacío)"
		l.modulate = Color(0.7, 0.7, 0.75, 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(l)
		empty_hint.text = ""
		sell_all_button.disabled = true
		return
	var visible_rows: int = 0
	for item_id in InventoryManager.items.keys():
		var item: ItemData = InventoryManager.item_lookup.get(item_id)
		var qty: int = InventoryManager.items[item_id]
		if qty <= 0:
			continue
		var name_str: String = item.display_name if item != null else str(item_id)
		if _filter != "" and not name_str.to_lower().contains(_filter):
			continue
		list.add_child(_build_row(item, name_str, qty))
		visible_rows += 1
	if visible_rows == 0:
		var l := Label.new()
		l.text = "(sin coincidencias para \"%s\")" % _filter
		l.modulate = Color(0.7, 0.7, 0.75, 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(l)
	empty_hint.text = "%d ítems · %d slots" % [
		InventoryManager.get_total_count(),
		InventoryManager.max_capacity
	]
	_update_sell_button_state()


func _update_sell_button_state() -> void:
	sell_all_button.disabled = InventoryManager.items.is_empty()


func _build_row(item: ItemData, name_str: String, qty: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	# Icono del item (24×24, pixel-perfect)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item != null and item.icon != null:
		icon_rect.texture = item.icon
	row.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = "%s ×%d" % [name_str, qty]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override(&"font_size", 13)
	row.add_child(name_lbl)

	if item != null and item.base_value > 0:
		var price_lbl := Label.new()
		price_lbl.text = "%d⚜" % item.base_value
		price_lbl.add_theme_font_size_override(&"font_size", 11)
		price_lbl.modulate = Color(1, 0.92, 0.55, 0.85)
		row.add_child(price_lbl)

		var sell_one := Button.new()
		sell_one.text = "×1"
		sell_one.tooltip_text = "Vender 1 (+%d⚜)" % item.base_value
		sell_one.add_theme_font_size_override(&"font_size", 11)
		sell_one.pressed.connect(_on_sell_one.bind(item))
		row.add_child(sell_one)

		var sell_stack := Button.new()
		sell_stack.text = "Todo"
		sell_stack.tooltip_text = "Vender ×%d (+%d⚜)" % [qty, item.base_value * qty]
		sell_stack.add_theme_font_size_override(&"font_size", 11)
		sell_stack.pressed.connect(_on_sell_stack.bind(item))
		row.add_child(sell_stack)
	return row
