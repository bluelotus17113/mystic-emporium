extends PanelContainer

const PANEL_NAME: StringName = &"orders"

const PERSONALITY_EMOJI: Dictionary = {
	"normal": "🙂",
	"impatient": "⏰",
	"generous": "💰",
	"picky": "🧐",
}

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var stats_bar: HBoxContainer = $Margin/VBox/StatsBox/StatsBar
@onready var active_box: VBoxContainer = $Margin/VBox/ActiveBox/ActiveBoxVBox
@onready var current_box: VBoxContainer = $Margin/VBox/ActiveBox/ActiveBoxVBox/CurrentBox
@onready var current_label: Label = $Margin/VBox/ActiveBox/ActiveBoxVBox/CurrentBox/CurrentLabel
@onready var current_progress: Label = $Margin/VBox/ActiveBox/ActiveBoxVBox/CurrentBox/ProgressLabel
@onready var deliver_button: Button = $Margin/VBox/ActiveBox/ActiveBoxVBox/CurrentBox/DeliverButton
@onready var history_list: VBoxContainer = $Margin/VBox/HistoryBox/Scroll/History
@onready var diario_list: VBoxContainer = $Margin/VBox/DiarioBox/DiarioScroll/DiarioList

const KIND_ICON: Dictionary = {
	0: "•",   # INFO
	1: "✓",   # SUCCESS
	2: "⚠",   # WARNING
	3: "✖",   # ALERT
	4: "⚜",   # REWARD
}
const KIND_COLOR: Dictionary = {
	0: Color(0.78, 0.82, 0.92, 1),
	1: Color(0.55, 0.95, 0.55, 1),
	2: Color(1.0, 0.78, 0.30, 1),
	3: Color(1.0, 0.45, 0.45, 1),
	4: Color(1.0, 0.85, 0.30, 1),
}

var _current_icon: TextureRect = null


func _ensure_current_icon() -> void:
	if _current_icon != null and is_instance_valid(_current_icon):
		return
	_current_icon = TextureRect.new()
	_current_icon.custom_minimum_size = Vector2(40, 40)
	_current_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_current_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_current_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	current_box.add_child(_current_icon)
	current_box.move_child(_current_icon, 0)


func _update_current_icon(tex: Texture2D) -> void:
	_ensure_current_icon()
	_current_icon.texture = tex
	_current_icon.visible = tex != null


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	deliver_button.pressed.connect(OrderManager.try_complete_current)
	OrderManager.order_generated.connect(_on_order_generated)
	OrderManager.order_completed.connect(_on_order_completed)
	OrderManager.order_expired.connect(_on_order_expired)
	OrderManager.queue_changed.connect(_on_queue_changed)
	NotificationManager.log_appended.connect(_on_log_appended)
	InventoryManager.item_changed.connect(_on_item_changed)
	_rebuild()


func _on_log_appended(_entry: Dictionary) -> void:
	if visible:
		_rebuild_diario()


func _on_order_generated(_o: OrderData) -> void:
	if visible:
		_rebuild()


func _on_order_completed(_o: OrderData) -> void:
	if visible:
		_rebuild()


func _on_order_expired(_o: OrderData) -> void:
	if visible:
		_rebuild()


func _on_queue_changed() -> void:
	if visible:
		_rebuild()


func _on_item_changed(_item: ItemData, _qty: int) -> void:
	if visible:
		_refresh_progress()


func _rebuild() -> void:
	_rebuild_stats()
	_rebuild_active()
	_rebuild_history()
	_rebuild_diario()


func _rebuild_diario() -> void:
	for child in diario_list.get_children():
		child.queue_free()
	var log_entries: Array = NotificationManager.get_log()
	if log_entries.is_empty():
		var empty := Label.new()
		empty.text = "(sin actividad reciente)"
		empty.modulate = Color(0.7, 0.7, 0.7, 1)
		diario_list.add_child(empty)
		return
	for entry in log_entries:
		diario_list.add_child(_build_diario_row(entry))


func _build_diario_row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var kind: int = int(e.get("kind", 0))
	var icon := Label.new()
	icon.text = KIND_ICON.get(kind, "•")
	icon.add_theme_font_size_override(&"font_size", 13)
	icon.add_theme_color_override(&"font_color", KIND_COLOR.get(kind, Color.WHITE))
	icon.custom_minimum_size = Vector2(18, 0)
	row.add_child(icon)
	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = String(e.get("text", ""))
	text.add_theme_font_size_override(&"font_size", 12)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text)
	return row


# ---------- Stats globales (chips) ----------

func _rebuild_stats() -> void:
	for c in stats_bar.get_children():
		c.queue_free()
	var hist: Array = OrderManager.get_history()
	var delivered_count: int = 0
	var lost_count: int = 0
	var coins_earned: int = 0
	var vip_count: int = 0
	for e in hist:
		if bool(e.get("delivered", false)):
			delivered_count += 1
			coins_earned += int(e.get("coin", 0))
			if int(e.get("tier", 1)) >= 4:
				vip_count += 1
		else:
			lost_count += 1
	var total: int = delivered_count + lost_count
	var rate: int = int(round(100.0 * delivered_count / max(1, total))) if total > 0 else 0
	stats_bar.add_child(_build_stat_chip("✓", "%d" % delivered_count, "Entregados", Color(0.55, 0.95, 0.55)))
	stats_bar.add_child(_build_stat_chip("✗", "%d" % lost_count, "Perdidos", Color(1.0, 0.55, 0.45)))
	stats_bar.add_child(_build_stat_chip("📊", "%d%%" % rate, "Tasa éxito", Color(0.75, 0.85, 1.0)))
	stats_bar.add_child(_build_stat_chip("⚜", "%d" % coins_earned, "Coins ganadas", Color(1.0, 0.92, 0.55)))
	stats_bar.add_child(_build_stat_chip("👑", "%d" % vip_count, "VIPs", Color(1.0, 0.75, 0.95)))


func _build_stat_chip(icon: String, value: String, label: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := Label.new()
	top.text = "%s %s" % [icon, value]
	top.add_theme_font_size_override(&"font_size", 18)
	top.add_theme_color_override(&"font_color", color)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top)
	var sub := Label.new()
	sub.text = label
	sub.add_theme_font_size_override(&"font_size", 10)
	sub.modulate = Color(0.75, 0.75, 0.82, 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	return box


# ---------- Pedidos activos ----------

func _rebuild_active() -> void:
	# Quitamos hijos extra (clones de active rows) pero conservamos el CurrentBox base.
	for c in active_box.get_children():
		if c != current_box:
			c.queue_free()
	var active_list: Array = OrderManager.get_active_orders()
	var order: OrderData = OrderManager.get_current_order()
	if order == null or order.requested_item == null:
		current_label.text = "(no hay pedido activo)"
		current_progress.text = ""
		deliver_button.disabled = true
		_update_current_icon(null)
	else:
		current_label.text = "%s × %s  →  +%d⚜  +%d★" % [
			order.display_name, order.requested_item.display_name, order.coin_reward, order.reputation_reward
		]
		_update_current_icon(order.requested_item.icon)
		_refresh_progress()
	# Mostrar el resto de orders activas como mini filas debajo.
	var shown_main: bool = false
	for a in active_list:
		if a == null or a.data == null or a.data == order and not shown_main:
			shown_main = true
			continue
		active_box.add_child(_build_active_row(a))


func _build_active_row(active_order) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if active_order.data.requested_item != null:
		icon.texture = active_order.data.requested_item.icon
	row.add_child(icon)
	var tier: int = int(active_order.data.tier)
	if tier >= 2:
		var crown := Label.new()
		crown.text = "👑" if tier >= 4 else "★"
		crown.add_theme_font_size_override(&"font_size", 14)
		row.add_child(crown)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "%d × %s" % [active_order.data.requested_quantity, active_order.data.requested_item.display_name]
	info.add_theme_font_size_override(&"font_size", 13)
	info.clip_text = true
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(info)
	# Stock
	var have: int = InventoryManager.get_item_count(active_order.data.requested_item)
	var stock := Label.new()
	stock.text = "%d/%d" % [have, active_order.data.requested_quantity]
	stock.add_theme_font_size_override(&"font_size", 12)
	stock.modulate = Color(0.6, 0.95, 0.6, 1) if have >= active_order.data.requested_quantity else Color(0.9, 0.9, 0.6, 1)
	row.add_child(stock)
	# Reward
	var reward := Label.new()
	reward.text = "+%d⚜" % active_order.data.coin_reward
	reward.add_theme_font_size_override(&"font_size", 12)
	reward.modulate = Color(1.0, 0.92, 0.55, 1)
	row.add_child(reward)
	return row


# ---------- Historial ----------

func _rebuild_history() -> void:
	for child in history_list.get_children():
		child.queue_free()
	var hist: Array = OrderManager.get_history()
	if hist.is_empty():
		var empty := Label.new()
		empty.text = "(sin historial)"
		empty.modulate = Color(0.7, 0.7, 0.7, 1)
		history_list.add_child(empty)
		return
	for entry in hist:
		history_list.add_child(_build_history_row(entry))


func _build_history_row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var delivered: bool = bool(e.get("delivered", false))
	var status := Label.new()
	status.text = "✓" if delivered else "✗"
	status.add_theme_font_size_override(&"font_size", 16)
	status.modulate = Color(0.55, 0.95, 0.55, 1) if delivered else Color(1.0, 0.55, 0.45, 1)
	status.custom_minimum_size = Vector2(18, 0)
	row.add_child(status)
	var pers_id: String = e.get("personality", "normal")
	var pers_label := Label.new()
	pers_label.text = PERSONALITY_EMOJI.get(pers_id, "🙂")
	pers_label.add_theme_font_size_override(&"font_size", 14)
	pers_label.custom_minimum_size = Vector2(20, 0)
	row.add_child(pers_label)
	var tier: int = int(e.get("tier", 1))
	if tier >= 2:
		var crown := Label.new()
		crown.text = "👑" if tier >= 4 else "★"
		crown.add_theme_font_size_override(&"font_size", 13)
		row.add_child(crown)
	var main := Label.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.text = "%s × %d" % [e.get("item_name", "?"), int(e.get("qty", 1))]
	main.add_theme_font_size_override(&"font_size", 13)
	main.clip_text = true
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not delivered:
		main.modulate = Color(0.78, 0.78, 0.78, 0.85)
	row.add_child(main)
	var reward := Label.new()
	if delivered:
		reward.text = "+%d⚜ +%d★" % [int(e.get("coin", 0)), int(e.get("rep", 0))]
		reward.modulate = Color(1.0, 0.92, 0.55, 1)
	else:
		reward.text = "perdido"
		reward.modulate = Color(0.9, 0.45, 0.45, 1)
	reward.add_theme_font_size_override(&"font_size", 12)
	row.add_child(reward)
	return row


func _refresh_progress() -> void:
	var order: OrderData = OrderManager.get_current_order()
	if order == null or order.requested_item == null:
		return
	var have: int = InventoryManager.get_item_count(order.requested_item)
	current_progress.text = "Stock: %d / %d" % [have, order.requested_quantity]
	deliver_button.disabled = have < order.requested_quantity
