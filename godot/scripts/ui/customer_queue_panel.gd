extends PanelContainer
## Panel lateral derecho que muestra cada cliente activo con su pedido y un
## botón individual de "Entregar". Da control fino: el jugador decide a quién
## entregar primero (útil cuando hay un VIP esperando junto a varios comunes).

const PERSONALITY_EMOJI: Dictionary = {
	&"normal": "🙂",
	&"impatient": "⏰",
	&"generous": "💰",
	&"picky": "🧐",
}

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List


func _ready() -> void:
	OrderManager.queue_changed.connect(_rebuild)
	OrderManager.order_generated.connect(func(_o): _rebuild())
	OrderManager.order_completed.connect(func(_o): _rebuild())
	OrderManager.order_expired.connect(func(_o): _rebuild())
	InventoryManager.item_changed.connect(func(_i, _q): _rebuild())
	_rebuild()


func _rebuild() -> void:
	if list == null:
		return
	for c in list.get_children():
		c.queue_free()
	var active: Array = OrderManager.get_active_orders()
	# Ocultar el panel si no hay pedidos (no estorba la vista).
	visible = not active.is_empty()
	if active.is_empty():
		return
	# Ordenar por tier desc (VIPs arriba) y luego por orden de llegada.
	active.sort_custom(func(a, b):
		var ta: int = a.data.tier if a != null and a.data != null else 0
		var tb: int = b.data.tier if b != null and b.data != null else 0
		return ta > tb)
	for i in active.size():
		var entry = active[i]
		if entry == null or entry.data == null:
			continue
		list.add_child(_build_row(entry))


func _build_row(entry) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.18, 0.92)
	sb.border_color = _tier_color(entry.data.tier)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override(&"panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	card.add_child(v)
	# Top row: icono cliente + tier crown + personality
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 4)
	v.add_child(top)
	var pers_id: StringName = StringName("normal")
	if entry.customer != null and is_instance_valid(entry.customer) and "personality" in entry.customer:
		pers_id = StringName(entry.customer.personality.id)
	var pers_label := Label.new()
	pers_label.text = PERSONALITY_EMOJI.get(pers_id, "🙂")
	pers_label.add_theme_font_size_override(&"font_size", 18)
	top.add_child(pers_label)
	var tier: int = int(entry.data.tier)
	if tier >= 2:
		var crown := Label.new()
		crown.text = "👑" if tier >= 4 else "★".repeat(tier - 1)
		crown.add_theme_font_size_override(&"font_size", 13)
		crown.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
		top.add_child(crown)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = String(entry.data.display_name)
	name_label.add_theme_font_size_override(&"font_size", 12)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	# Mid row: icono item + nombre × qty + stock
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 6)
	v.add_child(mid)
	var item_icon := TextureRect.new()
	item_icon.custom_minimum_size = Vector2(28, 28)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if entry.data.requested_item != null:
		item_icon.texture = entry.data.requested_item.icon
	mid.add_child(item_icon)
	var item_info := Label.new()
	item_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_info.text = "%d × %s" % [entry.data.requested_quantity, entry.data.requested_item.display_name]
	item_info.add_theme_font_size_override(&"font_size", 12)
	item_info.clip_text = true
	item_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(item_info)
	# Bottom row: reward + stock + botón entregar
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override(&"separation", 6)
	v.add_child(bot)
	var have: int = InventoryManager.get_item_count(entry.data.requested_item)
	var has_stock: bool = have >= entry.data.requested_quantity
	var stock := Label.new()
	stock.text = "%d/%d" % [have, entry.data.requested_quantity]
	stock.add_theme_font_size_override(&"font_size", 11)
	stock.modulate = Color(0.6, 0.95, 0.6) if has_stock else Color(0.95, 0.85, 0.55)
	bot.add_child(stock)
	var reward := Label.new()
	reward.text = "+%d⚜" % entry.data.coin_reward
	reward.add_theme_font_size_override(&"font_size", 11)
	reward.modulate = Color(1.0, 0.9, 0.45)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(reward)
	var btn := Button.new()
	btn.text = "✓"
	btn.custom_minimum_size = Vector2(34, 26)
	btn.disabled = not has_stock or entry.completed
	btn.add_theme_font_size_override(&"font_size", 13)
	btn.pressed.connect(_on_deliver_pressed.bind(entry))
	bot.add_child(btn)
	return card


func _on_deliver_pressed(entry) -> void:
	# Buscamos el índice actual de este entry en el manager y entregamos ahí.
	var active: Array = OrderManager.get_active_orders()
	var idx: int = active.find(entry)
	if idx >= 0:
		OrderManager.try_complete_at(idx)


func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.55, 0.65, 0.85, 0.85)
		2: return Color(0.55, 0.85, 0.65, 0.9)
		3: return Color(0.85, 0.75, 0.55, 0.95)
		4: return Color(0.95, 0.55, 0.85, 1.0)
		5: return Color(1.0, 0.45, 0.45, 1.0)
		_: return Color(0.55, 0.65, 0.85, 0.85)
