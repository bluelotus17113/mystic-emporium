extends PanelContainer
## Grimorio Arcano: libro abierto con 2 páginas, navegación, símbolos místicos.
## Estilo manuscrito iluminado: drop cap, ornamentos, marcos internos por receta.

const PANEL_NAME: StringName = &"recipe_book"
const RECIPES_PER_PAGE: int = 4

# Símbolos arcanos por tipo de estación
const STATION_SYMBOL: Dictionary = {
	GameEnums.StationType.NONE:              "✧",
	GameEnums.StationType.CAULDRON:          "♨",
	GameEnums.StationType.MYSTIC_FORGE:      "⚒",
	GameEnums.StationType.ENCHANTING_TABLE:  "✶",
	GameEnums.StationType.SCRIBE_DESK:       "✒",
	GameEnums.StationType.SUMMONING_CIRCLE:  "⛧",
	GameEnums.StationType.ARCANE_LIBRARY:    "📜",
	GameEnums.StationType.ASTRO_OBSERVATORY: "☽",
	GameEnums.StationType.STORAGE:           "⊞",
	GameEnums.StationType.COUNTER:           "⚖",
}
const STATION_NAME: Dictionary = {
	GameEnums.StationType.CAULDRON:          "Caldero",
	GameEnums.StationType.MYSTIC_FORGE:      "Forja",
	GameEnums.StationType.ENCHANTING_TABLE:  "Encantamiento",
	GameEnums.StationType.SCRIBE_DESK:       "Escriba",
	GameEnums.StationType.SUMMONING_CIRCLE:  "Invocación",
	GameEnums.StationType.ARCANE_LIBRARY:    "Biblioteca",
	GameEnums.StationType.ASTRO_OBSERVATORY: "Observatorio",
	GameEnums.StationType.STORAGE:           "Almacén",
	GameEnums.StationType.COUNTER:           "Mostrador",
}

@onready var close_button: Button = $Margin/VBox/TitleRow/CloseButton
@onready var progress_label: Label = $Margin/VBox/ProgressRow/ProgressLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressRow/ProgressBar
@onready var progress_percent: Label = $Margin/VBox/ProgressRow/ProgressPercent
@onready var filter_all: Button = $Margin/VBox/Filters/FilterAll
@onready var filter_unlocked: Button = $Margin/VBox/Filters/FilterUnlocked
@onready var filter_locked: Button = $Margin/VBox/Filters/FilterLocked
@onready var search_box: LineEdit = $Margin/VBox/Filters/SearchBox
@onready var left_vbox: VBoxContainer = $Margin/VBox/BookBody/LeftPage/LeftVBox
@onready var right_vbox: VBoxContainer = $Margin/VBox/BookBody/RightPage/RightVBox
@onready var prev_button: Button = $Margin/VBox/Footer/PrevButton
@onready var next_button: Button = $Margin/VBox/Footer/NextButton
@onready var page_label: Label = $Margin/VBox/Footer/PageLabel
@onready var bookmark: PanelContainer = $Bookmark

enum FilterMode { ALL, UNLOCKED, LOCKED }
var _filter_mode: FilterMode = FilterMode.ALL
var _search: String = ""
var _page: int = 0
var _filtered: Array[RecipeData] = []
var _was_visible: bool = false


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	filter_all.pressed.connect(_set_filter.bind(FilterMode.ALL))
	filter_unlocked.pressed.connect(_set_filter.bind(FilterMode.UNLOCKED))
	filter_locked.pressed.connect(_set_filter.bind(FilterMode.LOCKED))
	search_box.text_changed.connect(_on_search_changed)
	prev_button.pressed.connect(_prev_page)
	next_button.pressed.connect(_next_page)
	RecipeManager.recipe_unlocked.connect(_on_recipe_unlocked)
	visibility_changed.connect(_on_visibility_changed)
	visible = false
	_refilter()


func _on_visibility_changed() -> void:
	# Animación de apertura: pop-in con escala y fade
	if visible and not _was_visible:
		_animate_open()
	_was_visible = visible


func _animate_open() -> void:
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.35)
	t.tween_property(self, "scale", Vector2.ONE, 0.40)
	# Wiggle del bookmark
	if bookmark != null:
		bookmark.rotation = -0.18
		var bt := create_tween()
		bt.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		bt.tween_property(bookmark, "rotation", 0.0, 0.8)


func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_PAGEUP:
				_prev_page()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_PAGEDOWN:
				_next_page()
				get_viewport().set_input_as_handled()


func _set_filter(mode: int) -> void:
	_filter_mode = mode
	filter_all.button_pressed = mode == FilterMode.ALL
	filter_unlocked.button_pressed = mode == FilterMode.UNLOCKED
	filter_locked.button_pressed = mode == FilterMode.LOCKED
	_page = 0
	_refilter()


func _on_search_changed(text: String) -> void:
	_search = text.to_lower()
	_page = 0
	_refilter()


func _on_recipe_unlocked(_r: RecipeData) -> void:
	if visible:
		AudioManager.play_named(&"achievement_unlock")
		_refilter()


func _refilter() -> void:
	_filtered.clear()
	var all: Array[RecipeData] = RecipeManager.get_all_recipes()
	var unlocked_total: int = 0
	for r in all:
		if r == null: continue
		var is_unlocked: bool = RecipeManager.is_unlocked(r)
		if is_unlocked: unlocked_total += 1
		if _filter_mode == FilterMode.UNLOCKED and not is_unlocked: continue
		if _filter_mode == FilterMode.LOCKED and is_unlocked: continue
		if _search != "" and not r.display_name.to_lower().contains(_search): continue
		_filtered.append(r)
	# Progreso global
	var total: int = all.size()
	progress_label.text = "📜 %d / %d" % [unlocked_total, total]
	progress_bar.value = (float(unlocked_total) / total * 100.0) if total > 0 else 0.0
	progress_percent.text = "%d %%" % int(progress_bar.value)
	_rebuild()


func _total_pages() -> int:
	if _filtered.is_empty(): return 1
	return int(ceil(float(_filtered.size()) / RECIPES_PER_PAGE))


func _prev_page() -> void:
	if _page > 0:
		_page -= 1
		AudioManager.play_named(&"ui_close")
		_rebuild()


func _next_page() -> void:
	if _page < _total_pages() - 1:
		_page += 1
		AudioManager.play_named(&"ui_open")
		_rebuild()


func _rebuild() -> void:
	for child in left_vbox.get_children(): child.queue_free()
	for child in right_vbox.get_children(): child.queue_free()

	if _filtered.is_empty():
		left_vbox.add_child(_build_empty_page("✧ Sin recetas ✧"))
	else:
		var start: int = _page * RECIPES_PER_PAGE
		for i in range(2):
			var idx: int = start + i
			if idx < _filtered.size():
				left_vbox.add_child(_build_entry(_filtered[idx]))
			else:
				left_vbox.add_child(_build_blank_slot())
		for i in range(2):
			var idx: int = start + 2 + i
			if idx < _filtered.size():
				right_vbox.add_child(_build_entry(_filtered[idx]))
			else:
				right_vbox.add_child(_build_blank_slot())

	var total: int = _total_pages()
	page_label.text = "✦ Página %d  /  %d ✦" % [_page + 1, total]
	prev_button.disabled = _page == 0
	next_button.disabled = _page >= total - 1


func _build_empty_page(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", Color(0.55, 0.40, 0.20, 0.85))
	l.add_theme_font_size_override(&"font_size", 16)
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l


func _build_blank_slot() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return v


func _build_entry(recipe: RecipeData) -> Control:
	var is_unlocked: bool = RecipeManager.is_unlocked(recipe)

	# Marco contenedor con StyleBox
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_unlocked:
		card.tooltip_text = RecipeHints.tooltip_for(recipe)
	var sb := StyleBoxFlat.new()
	if is_unlocked:
		sb.bg_color = Color(0.97, 0.91, 0.74, 0.55)
		sb.border_color = Color(0.72, 0.50, 0.20, 0.55)
	else:
		sb.bg_color = Color(0.30, 0.22, 0.16, 0.40)
		sb.border_color = Color(0.55, 0.40, 0.20, 0.40)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override(&"panel", sb)

	var container := VBoxContainer.new()
	container.add_theme_constant_override(&"separation", 4)
	card.add_child(container)

	# === Ornamento superior ===
	var top_orn := Label.new()
	top_orn.text = "✦ ◆ ✦"
	top_orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_orn.add_theme_color_override(&"font_color",
		Color(0.65, 0.38, 0.10, 0.85) if is_unlocked else Color(0.55, 0.32, 0.10, 0.40))
	top_orn.add_theme_font_size_override(&"font_size", 12)
	container.add_child(top_orn)

	# === Header: icono + drop cap + título ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	container.add_child(header)

	var output_icon := TextureRect.new()
	output_icon.custom_minimum_size = Vector2(56, 56)
	output_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	output_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if recipe.output_item != null and recipe.output_item.icon != null:
		output_icon.texture = recipe.output_item.icon
	if not is_unlocked:
		output_icon.modulate = Color(0.35, 0.30, 0.25, 0.55)
	header.add_child(output_icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override(&"separation", 0)
	header.add_child(title_box)

	# Drop cap + título en línea horizontal
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 4)
	title_box.add_child(title_row)

	var stars: String = "★".repeat(recipe.tier)
	var name_str: String = recipe.display_name if is_unlocked else "???"
	# Drop cap = primera letra del nombre, grande
	if is_unlocked and name_str.length() > 0:
		var drop_cap := Label.new()
		drop_cap.text = name_str.substr(0, 1)
		drop_cap.add_theme_font_size_override(&"font_size", 26)
		drop_cap.add_theme_color_override(&"font_color", Color(0.55, 0.18, 0.10, 1))
		drop_cap.add_theme_color_override(&"font_outline_color", Color(0.95, 0.74, 0.30, 0.9))
		drop_cap.add_theme_constant_override(&"outline_size", 3)
		title_row.add_child(drop_cap)

	var name_lbl := Label.new()
	if is_unlocked:
		name_lbl.text = "%s %s" % [stars, name_str.substr(1)]
	else:
		name_lbl.text = "%s  ???" % stars
	name_lbl.add_theme_font_size_override(&"font_size", 17)
	name_lbl.add_theme_color_override(&"font_color",
		Color(0.20, 0.10, 0.04, 1) if is_unlocked else Color(0.55, 0.40, 0.20, 0.85))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_row.add_child(name_lbl)

	# Subtítulo con símbolo arcano + estación + tiempo
	var subtitle := Label.new()
	var sym: String = STATION_SYMBOL.get(recipe.required_station_type, "✧")
	var sname: String = STATION_NAME.get(recipe.required_station_type, "—")
	subtitle.text = "  %s  %s  ·  ⏱ %.0fs" % [sym, sname, recipe.crafting_time]
	subtitle.add_theme_font_size_override(&"font_size", 11)
	subtitle.add_theme_color_override(&"font_color",
		Color(0.50, 0.32, 0.15, 1) if is_unlocked else Color(0.55, 0.42, 0.25, 0.75))
	title_box.add_child(subtitle)

	# Estado a la derecha
	var state_label := Label.new()
	state_label.add_theme_font_size_override(&"font_size", 11)
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_unlocked:
		state_label.text = "✓ Conocida"
		state_label.add_theme_color_override(&"font_color", Color(0.15, 0.40, 0.10, 1))
	else:
		state_label.text = "🔒 Oculta"
		state_label.add_theme_color_override(&"font_color", Color(0.65, 0.45, 0.15, 1))
	header.add_child(state_label)

	# === Sección componentes ===
	var ing_header := Label.new()
	ing_header.text = "✥  Componentes  ✥"
	ing_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ing_header.add_theme_font_size_override(&"font_size", 11)
	ing_header.add_theme_color_override(&"font_color",
		Color(0.45, 0.25, 0.10, 0.85) if is_unlocked else Color(0.55, 0.42, 0.20, 0.55))
	container.add_child(ing_header)

	var ing_box := HBoxContainer.new()
	ing_box.add_theme_constant_override(&"separation", 12)
	ing_box.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(ing_box)

	if not is_unlocked:
		var hidden := Label.new()
		hidden.text = "Investiga más para revelar esta receta..."
		hidden.add_theme_font_size_override(&"font_size", 11)
		hidden.add_theme_color_override(&"font_color", Color(0.55, 0.42, 0.20, 0.85))
		ing_box.add_child(hidden)
	else:
		var pairs: Array = recipe.get_ingredient_pairs()
		for pair in pairs:
			ing_box.add_child(_build_ingredient(pair.item, pair.qty))

	# === Ornamento inferior ===
	var bottom_orn := Label.new()
	bottom_orn.text = "═══✦═══"
	bottom_orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_orn.add_theme_color_override(&"font_color",
		Color(0.65, 0.38, 0.10, 0.7) if is_unlocked else Color(0.55, 0.32, 0.10, 0.30))
	bottom_orn.add_theme_font_size_override(&"font_size", 10)
	container.add_child(bottom_orn)

	return card


func _build_ingredient(item: ItemData, qty: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item != null and item.icon != null:
		icon_rect.texture = item.icon
	box.add_child(icon_rect)

	var qty_lbl := Label.new()
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.text = "× %d" % qty
	qty_lbl.add_theme_font_size_override(&"font_size", 11)
	qty_lbl.add_theme_color_override(&"font_color", Color(0.20, 0.10, 0.04, 1))
	box.add_child(qty_lbl)

	if item != null:
		icon_rect.tooltip_text = "%s  (tier %d)" % [item.display_name, item.tier]

	return box
