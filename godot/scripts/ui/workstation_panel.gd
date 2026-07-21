extends PanelContainer

const PANEL_NAME: StringName = &"workstation"

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var level_label: Label = $Margin/VBox/Header/LevelLabel
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var upgrade_button: Button = $Margin/VBox/Header/UpgradeButton
@onready var craft_box: VBoxContainer = $Margin/VBox/CraftProgressBox
@onready var craft_label: Label = $Margin/VBox/CraftProgressBox/CraftLabel
@onready var craft_bar: ProgressBar = $Margin/VBox/CraftProgressBox/CraftBar
@onready var recipe_list: VBoxContainer = $Margin/VBox/Scroll/RecipeList
@onready var status_label: Label = $Margin/VBox/StatusLabel

var active_station: Workstation = null
var _upgrade_pressed_handler: Callable = Callable()
var _auto_button: Button = null
var _auto_pressed_handler: Callable = Callable()

# ponytail: en companion mode el panel se posiciona junto a MenuColumn (igual que
# los tiles), no sobre DeliverPanel. Guardamos el layout normal para restaurar al salir.
var _saved_anchors: Vector4 = Vector4.ZERO
var _saved_offsets: Vector4 = Vector4.ZERO
var _saved_min_size: Vector2 = Vector2.ZERO
var _layout_saved: bool = false


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	WorkstationManager.workstation_clicked.connect(_on_workstation_clicked)
	WindowController.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(WindowController.is_compact())
	_build_auto_button()


func _build_auto_button() -> void:
	_auto_button = Button.new()
	_auto_button.custom_minimum_size = Vector2(120, 32)
	_auto_button.add_theme_font_size_override(&"font_size", 12)
	_auto_button.toggle_mode = true
	_auto_button.text = "🤖 Auto: ON"
	var header: HBoxContainer = $"Margin/VBox/Header"
	header.add_child(_auto_button)
	# Reordenamos para que quede entre UpgradeButton y CloseButton.
	var close_idx: int = close_button.get_index()
	header.move_child(_auto_button, close_idx)


func _save_layout() -> void:
	if _layout_saved:
		return
	_saved_anchors = Vector4(anchor_left, anchor_top, anchor_right, anchor_bottom)
	_saved_offsets = Vector4(offset_left, offset_top, offset_right, offset_bottom)
	_saved_min_size = custom_minimum_size
	_layout_saved = true


func _on_mode_changed(is_compact: bool) -> void:
	_save_layout()
	if is_compact:
		# Anclar al lado derecho de MenuColumn (320px) con altura completa.
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 1.0
		offset_left = 330.0
		offset_top = 6.0
		offset_right = 900.0
		offset_bottom = -6.0
		custom_minimum_size = Vector2(560, 0)
	else:
		anchor_left = _saved_anchors.x
		anchor_top = _saved_anchors.y
		anchor_right = _saved_anchors.z
		anchor_bottom = _saved_anchors.w
		offset_left = _saved_offsets.x
		offset_top = _saved_offsets.y
		offset_right = _saved_offsets.z
		offset_bottom = _saved_offsets.w
		custom_minimum_size = _saved_min_size


func _on_workstation_clicked(station: Workstation) -> void:
	active_station = station
	_rebuild()
	# Si el panel ya está abierto (cambiando de una estación a otra), refrescamos
	# en el sitio: nada de cerrar/reabrir con animación (evita el parpadeo).
	if not UIManager.is_open(PANEL_NAME):
		UIManager.open(PANEL_NAME)
	# Listen to this station's craft progress so we can refresh status
	if not station.craft_started.is_connected(_on_craft_started):
		station.craft_started.connect(_on_craft_started)
		station.craft_progress.connect(_on_craft_progress)
		station.craft_completed.connect(_on_craft_completed)
		station.queue_changed.connect(_on_queue_changed)
		station.upgraded.connect(_on_upgraded)
	_refresh_craft_progress()


func _refresh_craft_progress() -> void:
	# Si la estación activa está crafteando, mostrar barra con su estado actual.
	if active_station != null and active_station._is_crafting and active_station._current_recipe != null:
		var total: float = active_station._current_recipe.crafting_time * active_station.crafting_time_multiplier
		var pct: float = clamp(active_station._craft_timer / max(0.001, total), 0.0, 1.0)
		craft_label.text = "⚗ Crafteando %s… %d%%%s" % [active_station._current_recipe.display_name, int(pct * 100), _queue_suffix()]
		craft_bar.value = pct
		craft_box.show()
	else:
		craft_box.hide()


## Sufijo con la cola pendiente para las etiquetas de progreso.
func _queue_suffix() -> String:
	if active_station == null:
		return ""
	var q: int = active_station.get_queue_size()
	return "  (+%d en cola)" % q if q > 0 else ""


func _on_queue_changed(_size: int) -> void:
	if not visible:
		return
	_refresh_craft_progress()
	_populate_recipes()


func _on_craft_progress(recipe: RecipeData, percent: float) -> void:
	if not visible or active_station == null:
		return
	craft_box.show()
	craft_bar.value = percent
	craft_label.text = "⚗ Crafteando %s… %d%%%s" % [recipe.display_name, int(percent * 100), _queue_suffix()]


func _rebuild() -> void:
	if active_station == null:
		return
	_apply_theme(active_station.station_type)
	title_label.text = _station_type_name(active_station.station_type)
	level_label.text = "Nv %d" % active_station.current_level
	# rewire upgrade button
	if _upgrade_pressed_handler.is_valid() and upgrade_button.pressed.is_connected(_upgrade_pressed_handler):
		upgrade_button.pressed.disconnect(_upgrade_pressed_handler)
	_upgrade_pressed_handler = Callable(active_station, "try_upgrade")
	upgrade_button.pressed.connect(_upgrade_pressed_handler)
	var maxed: bool = active_station.current_level >= Workstation.MAX_LEVEL
	upgrade_button.disabled = maxed
	upgrade_button.text = "MAX" if maxed else "⬆ %d⚜" % active_station.upgrade_cost
	# Auto-craft toggle: refresca texto + reconecta handler con la station activa.
	if _auto_pressed_handler.is_valid() and _auto_button.pressed.is_connected(_auto_pressed_handler):
		_auto_button.pressed.disconnect(_auto_pressed_handler)
	_auto_pressed_handler = Callable(self, "_on_auto_toggled")
	_auto_button.pressed.connect(_auto_pressed_handler)
	_auto_button.set_pressed_no_signal(active_station.auto_craft_enabled)
	_auto_button.text = "🤖 Auto: ON" if active_station.auto_craft_enabled else "⏸ Auto: OFF"
	_auto_button.modulate = Color(0.85, 1, 0.85, 1) if active_station.auto_craft_enabled else Color(1, 0.85, 0.85, 1)
	status_label.text = ""
	# Recetas de ESTA estación: sin esto la lista se quedaba con las de la estación
	# anterior hasta el siguiente evento de crafteo (el "flash" del menú viejo).
	_populate_recipes()


func _on_auto_toggled() -> void:
	if active_station == null:
		return
	active_station.set_auto_craft(_auto_button.button_pressed)
	_auto_button.text = "🤖 Auto: ON" if active_station.auto_craft_enabled else "⏸ Auto: OFF"
	_auto_button.modulate = Color(0.85, 1, 0.85, 1) if active_station.auto_craft_enabled else Color(1, 0.85, 0.85, 1)
	_populate_recipes()


func _populate_recipes() -> void:
	# remove_child inmediato (no solo queue_free) para que las filas viejas no se
	# vean un frame junto a las nuevas al cambiar de estación.
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	var recipes: Array[RecipeData] = active_station.get_filtered_recipes()
	if recipes.is_empty():
		var empty := Label.new()
		empty.text = "(sin recetas disponibles)"
		empty.modulate = Color(0.7, 0.7, 0.7, 1)
		recipe_list.add_child(empty)
		return
	for recipe in recipes:
		recipe_list.add_child(_build_recipe_row(recipe))


func _build_recipe_row(recipe: RecipeData) -> Control:
	# Card compacta: una sola fila, alto 48px. Si una receta no cabe en la lista
	# visible, mejor scroll de pocas que cards gigantes que obligan scroll siempre.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 48)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.tooltip_text = RecipeHints.tooltip_for(recipe)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 6)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_right", 6)
	margin.add_theme_constant_override(&"margin_bottom", 4)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	margin.add_child(row)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if recipe.output_item != null and recipe.output_item.icon != null:
		icon_rect.texture = recipe.output_item.icon
	row.add_child(icon_rect)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "★".repeat(recipe.tier) + " " + recipe.display_name
	name_label.add_theme_font_size_override(&"font_size", 14)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)

	var ingredients_label := Label.new()
	ingredients_label.text = _ingredients_to_str(recipe)
	ingredients_label.add_theme_font_size_override(&"font_size", 11)
	ingredients_label.modulate = Color(0.85, 0.85, 0.95, 1)
	ingredients_label.clip_text = true
	ingredients_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(ingredients_label)

	var craft_button := Button.new()
	craft_button.text = "🔨"
	craft_button.custom_minimum_size = Vector2(56, 40)
	craft_button.add_theme_font_size_override(&"font_size", 18)
	craft_button.disabled = not _can_afford(recipe)
	craft_button.pressed.connect(_on_craft_pressed.bind(recipe))
	row.add_child(craft_button)
	return card


func _ingredients_to_str(recipe: RecipeData) -> String:
	var parts: Array[String] = []
	for pair in recipe.get_ingredient_pairs():
		var item: ItemData = pair.item
		if item == null:
			continue
		var have: int = InventoryManager.get_item_count(item)
		parts.append("%s %d/%d" % [item.display_name, have, pair.qty])
	return " · ".join(parts)


func _can_afford(recipe: RecipeData) -> bool:
	return InventoryManager.has_items(recipe.get_ingredient_pairs())


func _on_craft_pressed(recipe: RecipeData) -> void:
	if active_station == null:
		return
	if not active_station.start_craft(recipe):
		if active_station.get_queue_size() >= Workstation.MAX_QUEUE:
			status_label.text = "Cola llena (%d)." % Workstation.MAX_QUEUE
		else:
			status_label.text = "Faltan ingredientes."
		return
	var qs: int = active_station.get_queue_size()
	if qs > 0:
		status_label.text = "%s en cola (%d) ⏳" % [recipe.display_name, qs]
	else:
		status_label.text = "Crafteando %s…" % recipe.display_name
	# Los ingredientes ya se descontaron: refrescar disponibilidad de recetas.
	_populate_recipes()


func _on_craft_started(recipe: RecipeData) -> void:
	if visible:
		craft_box.show()
		craft_bar.value = 0.0
		craft_label.text = "⚗ Crafteando %s… 0%%" % recipe.display_name
		_populate_recipes()


func _on_craft_completed(recipe: RecipeData) -> void:
	if visible:
		status_label.text = "%s producida ✓" % recipe.display_name
		craft_box.hide()
		_populate_recipes()


func _on_upgraded(_level: int) -> void:
	if visible:
		_rebuild()


func _station_type_name(t: GameEnums.StationType) -> String:
	match t:
		GameEnums.StationType.CAULDRON: return "🧪 Caldero Alquímico"
		GameEnums.StationType.MYSTIC_FORGE: return "⚒ Forja Mística"
		GameEnums.StationType.ENCHANTING_TABLE: return "✶ Mesa de Encantamiento"
		GameEnums.StationType.SCRIBE_DESK: return "✒ Escritorio de Escriba"
		GameEnums.StationType.SUMMONING_CIRCLE: return "⛧ Círculo de Invocación"
		GameEnums.StationType.ARCANE_LIBRARY: return "📚 Biblioteca Arcana"
		GameEnums.StationType.ASTRO_OBSERVATORY: return "☽ Observatorio"
		_: return "Estación"


# Esquema de color por station_type. Cada tema define los tonos que pintamos
# en panel, header, ProgressBar y botón upgrade. Reutiliza el mismo .tscn.
const _THEMES: Dictionary = {
	GameEnums.StationType.CAULDRON: {
		"bg": Color(0.07, 0.04, 0.10, 1.0),         # púrpura profundo
		"border": Color(0.42, 0.78, 0.36, 1.0),     # verde brujeril
		"title": Color(0.78, 1.0, 0.62, 1.0),       # verde fosforescente
		"level": Color(0.65, 1.0, 0.50, 1.0),
		"bar_fill": Color(0.55, 0.95, 0.45, 1.0),   # verde tóxico
		"btn_normal": Color(0.18, 0.36, 0.20, 1.0),
		"btn_hover": Color(0.28, 0.52, 0.30, 1.0),
	},
	GameEnums.StationType.MYSTIC_FORGE: {
		"bg": Color(0.10, 0.04, 0.03, 1.0),         # carbón
		"border": Color(0.88, 0.50, 0.18, 1.0),     # cobre brasa
		"title": Color(1.0, 0.78, 0.42, 1.0),       # oro caliente
		"level": Color(1.0, 0.62, 0.20, 1.0),
		"bar_fill": Color(1.0, 0.45, 0.10, 1.0),    # naranja lava
		"btn_normal": Color(0.45, 0.18, 0.08, 1.0),
		"btn_hover": Color(0.70, 0.30, 0.12, 1.0),
	},
}

const _DEFAULT_THEME: Dictionary = {
	"bg": Color(0.06, 0.05, 0.12, 1.0),
	"border": Color(0.35, 0.28, 0.55, 1.0),
	"title": Color(0.95, 0.92, 1.0, 1.0),
	"level": Color(1.0, 0.92, 0.45, 1.0),
	"bar_fill": Color(0.95, 0.78, 0.35, 1.0),
	"btn_normal": Color(0.20, 0.16, 0.32, 1.0),
	"btn_hover": Color(0.32, 0.26, 0.50, 1.0),
}


func _apply_theme(t: GameEnums.StationType) -> void:
	var th: Dictionary = _THEMES.get(t, _DEFAULT_THEME)
	# Panel raíz: fondo + borde grueso del color temático.
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = th.bg
	panel_sb.border_color = th.border
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(8)
	panel_sb.shadow_color = Color(th.border.r, th.border.g, th.border.b, 0.35)
	panel_sb.shadow_size = 12
	add_theme_stylebox_override(&"panel", panel_sb)

	# Título y nivel
	title_label.add_theme_color_override(&"font_color", th.title)
	level_label.add_theme_color_override(&"font_color", th.level)

	# CraftBar fill
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = th.bar_fill
	bar_fill.set_corner_radius_all(5)
	craft_bar.add_theme_stylebox_override(&"fill", bar_fill)

	# Upgrade button
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = th.btn_normal
	btn_normal.border_color = th.border
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = th.btn_hover
	btn_hover.border_color = th.border
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	upgrade_button.add_theme_stylebox_override(&"normal", btn_normal)
	upgrade_button.add_theme_stylebox_override(&"hover", btn_hover)
	upgrade_button.add_theme_stylebox_override(&"pressed", btn_normal)
