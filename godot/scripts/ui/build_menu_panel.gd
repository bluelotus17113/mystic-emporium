extends PanelContainer

const PANEL_NAME: StringName = &"build"

## Caché id → textura extraída de la escena (una sola instanciación por buildable).
static var _icon_cache: Dictionary = {}


## Devuelve la textura del sprite principal de la escena del buildable, de modo
## que el icono del menú sea EXACTAMENTE lo que se coloca. Cachea el resultado.
static func _icon_from_scene(b) -> Texture2D:
	if b == null or b.scene == null:
		return null
	if _icon_cache.has(b.id):
		return _icon_cache[b.id]
	var tex: Texture2D = null
	var inst: Node = b.scene.instantiate()
	if inst != null:
		tex = _find_sprite_tex(inst)
		inst.free()
	_icon_cache[b.id] = tex
	return tex


static func _find_sprite_tex(n: Node) -> Texture2D:
	if n is Sprite2D and (n as Sprite2D).texture != null:
		return (n as Sprite2D).texture
	if n is AnimatedSprite2D:
		var sf: SpriteFrames = (n as AnimatedSprite2D).sprite_frames
		if sf != null:
			var anim: StringName = (n as AnimatedSprite2D).animation
			if not sf.has_animation(anim):
				var names := sf.get_animation_names()
				if names.size() > 0:
					anim = names[0]
			if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
				return sf.get_frame_texture(anim, 0)
	for c in n.get_children():
		var t: Texture2D = _find_sprite_tex(c)
		if t != null:
			return t
	return null

# ponytail: mapeo id → sprite. Los .tres no traen icon set, así que infiero por id.
const ICON_BY_ID: Dictionary = {
	&"build_caldero": "res://art/sprites/environment/cauldron.png",
	&"build_forja": "res://art/sprites/environment/forge.png",
	&"build_biblioteca": "res://art/sprites/environment/bookshelf.png",
	&"build_cofre": "res://art/sprites/environment/chest.png",
	&"build_escritorio_escriba": "res://art/sprites/environment/desk.png",
	&"build_mesa_encantamiento": "res://art/sprites/environment/spellbook.png",
	&"build_generador_cristal": "res://art/sprites/environment/crystal_node.png",
	&"build_generador_hierbas": "res://art/sprites/environment/herb_node.png",
	&"build_generador_hierro": "res://art/sprites/environment/iron_node.png",
	&"build_arboleda": "res://art/sprites/environment/wood_node.png",
	&"deco_painting": "res://art/sprites/environment/decoration_painting.png",
	&"deco_rug": "res://art/sprites/environment/decoration_rug.png",
	&"deco_potion_jar": "res://art/sprites/environment/decoration_potion_jar.png",
	&"deco_shelf": "res://art/sprites/environment/decoration_shelf.png",
	&"deco_candle": "res://art/sprites/environment/decoration_candle.png",
	&"deco_plant": "res://art/sprites/environment/decoration_plant.png",
	&"deco_tapestry": "res://art/sprites/environment/decoration_tapestry.png",
	&"deco_clock": "res://art/sprites/environment/decoration_clock.png",
	&"deco_mirror": "res://art/sprites/environment/decoration_mirror.png",
	&"deco_rune_circle": "res://art/sprites/environment/decoration_rune_circle.png",
	&"deco_floor_tile": "res://art/sprites/environment/decoration_floor_tile.png",
	&"deco_crystal_ball": "res://art/sprites/environment/decoration_crystal_ball.png",
	&"deco_skull": "res://art/sprites/environment/decoration_skull.png",
	&"deco_spellbook_open": "res://art/sprites/environment/decoration_spellbook_open.png",
	&"deco_mushroom": "res://art/sprites/environment/decoration_mushroom.png",
	&"deco_torch": "res://art/sprites/environment/decoration_torch.png",
	&"deco_window": "res://art/sprites/environment/decoration_window.png",
	&"deco_skull_trophy": "res://art/sprites/environment/decoration_skull_trophy.png",
	&"deco_marble_tile": "res://art/sprites/environment/decoration_marble_tile.png",
	&"deco_summon_glyph": "res://art/sprites/environment/decoration_summon_glyph.png",
	&"deco_throw_rug": "res://art/sprites/environment/decoration_throw_rug.png",
	&"deco_hourglass": "res://art/sprites/environment/decoration_hourglass.png",
	&"deco_tome_stack": "res://art/sprites/environment/decoration_tome_stack.png",
	&"deco_inkwell": "res://art/sprites/environment/decoration_inkwell.png",
	&"deco_bonsai": "res://art/sprites/environment/decoration_bonsai.png",
	&"deco_lantern": "res://art/sprites/environment/decoration_lantern.png",
	&"deco_flower_pot": "res://art/sprites/environment/decoration_flower_pot.png",
	&"deco_pennant": "res://art/sprites/environment/decoration_pennant.png",
	&"deco_dreamcatcher": "res://art/sprites/environment/decoration_dreamcatcher.png",
	&"deco_zodiac_wheel": "res://art/sprites/environment/decoration_zodiac_wheel.png",
	&"deco_potion_rack": "res://art/sprites/environment/decoration_potion_rack.png",
	&"deco_quest_board": "res://art/sprites/environment/decoration_quest_board.png",
	&"deco_arch_window": "res://art/sprites/environment/decoration_arch_window.png",
	&"deco_starstone_tile": "res://art/sprites/environment/decoration_starstone_tile.png",
	&"deco_compass_rose": "res://art/sprites/environment/decoration_compass_rose.png",
	&"deco_red_carpet": "res://art/sprites/environment/decoration_red_carpet.png",
	&"deco_mosaic_tile": "res://art/sprites/environment/decoration_mosaic_tile.png",
	&"deco_chalk_circle": "res://art/sprites/environment/decoration_chalk_circle.png",
	&"deco_water_pool": "res://art/sprites/environment/decoration_water_pool.png",
	&"deco_telescope": "res://art/sprites/environment/decoration_telescope.png",
	&"deco_globe": "res://art/sprites/environment/decoration_globe.png",
	&"deco_chess_set": "res://art/sprites/environment/decoration_chess_set.png",
	&"deco_crystal_cluster": "res://art/sprites/environment/decoration_crystal_cluster.png",
	&"deco_quill_stand": "res://art/sprites/environment/decoration_quill_stand.png",
	&"deco_jewelry_box": "res://art/sprites/environment/decoration_jewelry_box.png",
	&"deco_fountain": "res://art/sprites/environment/decoration_fountain.png",
	&"deco_log_stump": "res://art/sprites/environment/decoration_log_stump.png",
	&"deco_garden_gnome": "res://art/sprites/environment/decoration_garden_gnome.png",
	&"deco_birdhouse": "res://art/sprites/environment/decoration_birdhouse.png",
	&"deco_pumpkin": "res://art/sprites/environment/decoration_pumpkin.png",
	&"deco_butterfly_jar": "res://art/sprites/environment/decoration_butterfly_jar.png",
	&"deco_round_table": "res://art/sprites/environment/decoration_round_table.png",
	&"deco_wood_table": "res://art/sprites/environment/decoration_wood_table.png",
	&"deco_marble_pedestal": "res://art/sprites/environment/decoration_marble_pedestal.png",
	&"deco_workbench": "res://art/sprites/environment/decoration_workbench.png",
	&"deco_altar": "res://art/sprites/environment/decoration_altar.png",
	&"deco_nightstand": "res://art/sprites/environment/decoration_nightstand.png",
	&"deco_cuckoo_clock": "res://art/sprites/environment/decoration_cuckoo_clock.png",
	&"deco_antlers": "res://art/sprites/environment/decoration_antlers.png",
	&"deco_map_scroll": "res://art/sprites/environment/decoration_map_scroll.png",
	&"deco_crossed_swords": "res://art/sprites/environment/decoration_crossed_swords.png",
	&"deco_wall_lamp": "res://art/sprites/environment/decoration_wall_lamp.png",
	&"deco_petals": "res://art/sprites/environment/decoration_petals.png",
	&"deco_checker_tile": "res://art/sprites/environment/decoration_checker_tile.png",
	&"deco_straw_bed": "res://art/sprites/environment/decoration_straw_bed.png",
	&"deco_meteor_crater": "res://art/sprites/environment/decoration_meteor_crater.png",
	&"deco_arrow_marker": "res://art/sprites/environment/decoration_arrow_marker.png",
	&"deco_teapot": "res://art/sprites/environment/decoration_teapot.png",
	&"deco_fruit_bowl": "res://art/sprites/environment/decoration_fruit_bowl.png",
	&"deco_witch_hat": "res://art/sprites/environment/decoration_witch_hat.png",
	&"deco_mortar_pestle": "res://art/sprites/environment/decoration_mortar_pestle.png",
	&"deco_pocket_watch": "res://art/sprites/environment/decoration_pocket_watch.png",
	&"deco_soul_bowl": "res://art/sprites/environment/decoration_soul_bowl.png",
	&"deco_tarot_pile": "res://art/sprites/environment/decoration_tarot_pile.png",
	&"deco_letter_seal": "res://art/sprites/environment/decoration_letter_seal.png",
	&"deco_fallen_log": "res://art/sprites/environment/decoration_fallen_log.png",
	&"deco_brazier": "res://art/sprites/environment/decoration_brazier.png",
	&"deco_wishing_well": "res://art/sprites/environment/decoration_wishing_well.png",
	&"deco_stone_cairn": "res://art/sprites/environment/decoration_stone_cairn.png",
	&"deco_cozy_armchair": "res://art/sprites/environment/decoration_cozy_armchair.png",
	&"deco_treasure_chest": "res://art/sprites/environment/decoration_treasure_chest.png",
	&"deco_shop_sign": "res://art/sprites/environment/decoration_shop_sign.png",
	&"deco_price_board": "res://art/sprites/environment/decoration_price_board.png",
	&"deco_business_license": "res://art/sprites/environment/decoration_business_license.png",
	&"deco_chalkboard": "res://art/sprites/environment/decoration_chalkboard.png",
	&"deco_clock_round": "res://art/sprites/environment/decoration_clock_round.png",
	&"deco_welcome_mat": "res://art/sprites/environment/decoration_welcome_mat.png",
	&"deco_queue_rope": "res://art/sprites/environment/decoration_queue_rope.png",
	&"deco_floor_lamp": "res://art/sprites/environment/decoration_floor_lamp.png",
	&"deco_reception_desk": "res://art/sprites/environment/decoration_reception_desk.png",
	&"deco_cash_register": "res://art/sprites/environment/decoration_cash_register.png",
	&"deco_display_case": "res://art/sprites/environment/decoration_display_case.png",
	&"deco_business_card_holder": "res://art/sprites/environment/decoration_business_card_holder.png",
	&"deco_guest_book": "res://art/sprites/environment/decoration_guest_book.png",
	&"deco_bell_service": "res://art/sprites/environment/decoration_bell_service.png",
	&"deco_palm_plant": "res://art/sprites/environment/decoration_palm_plant.png",
	&"deco_flower_vase": "res://art/sprites/environment/decoration_flower_vase.png",
	&"deco_garden_arch": "res://art/sprites/environment/decoration_garden_arch.png",
	&"deco_scarecrow": "res://art/sprites/environment/decoration_scarecrow.png",
	&"deco_signpost": "res://art/sprites/environment/decoration_signpost.png",
	&"deco_birdfeeder": "res://art/sprites/environment/decoration_birdfeeder.png",
	&"deco_stone_path": "res://art/sprites/environment/decoration_stone_path.png",
	&"deco_garden_patch": "res://art/sprites/environment/decoration_garden_patch.png",
	&"deco_haybale": "res://art/sprites/environment/decoration_haybale.png",
	&"deco_garden_pond": "res://art/sprites/environment/decoration_garden_pond.png",
	&"deco_garden_bench": "res://art/sprites/environment/decoration_garden_bench.png",
	&"deco_bird_bath": "res://art/sprites/environment/decoration_bird_bath.png",
	&"deco_apple_tree": "res://art/sprites/environment/decoration_apple_tree.png",
	&"deco_picnic_set": "res://art/sprites/environment/decoration_picnic_set.png",
	&"deco_torch_stake": "res://art/sprites/environment/decoration_torch_stake.png",
	&"deco_lavender_bush": "res://art/sprites/environment/decoration_lavender_bush.png",
	&"deco_compost_bin": "res://art/sprites/environment/decoration_compost_bin.png",
	&"deco_wheelbarrow": "res://art/sprites/environment/decoration_wheelbarrow.png",
	&"deco_framed_photo": "res://art/sprites/environment/decoration_framed_photo.png",
	&"deco_wall_shelf_books": "res://art/sprites/environment/decoration_wall_shelf_books.png",
	&"deco_coat_rack": "res://art/sprites/environment/decoration_coat_rack.png",
	&"deco_headboard": "res://art/sprites/environment/decoration_headboard.png",
	&"deco_window_curtain": "res://art/sprites/environment/decoration_window_curtain.png",
	&"deco_wall_clock_pendulum": "res://art/sprites/environment/decoration_wall_clock_pendulum.png",
	&"deco_bed_single": "res://art/sprites/environment/decoration_bed_single.png",
	&"deco_bed_canopy": "res://art/sprites/environment/decoration_bed_canopy.png",
	&"deco_hammock": "res://art/sprites/environment/decoration_hammock.png",
	&"deco_dresser": "res://art/sprites/environment/decoration_dresser.png",
	&"deco_wardrobe": "res://art/sprites/environment/decoration_wardrobe.png",
	&"deco_vanity_mirror": "res://art/sprites/environment/decoration_vanity_mirror.png",
	&"deco_dining_table": "res://art/sprites/environment/decoration_dining_table.png",
	&"deco_dining_chair": "res://art/sprites/environment/decoration_dining_chair.png",
	&"deco_fireplace": "res://art/sprites/environment/decoration_fireplace.png",
	&"deco_kitchen_stove": "res://art/sprites/environment/decoration_kitchen_stove.png",
	&"deco_pillow_pile": "res://art/sprites/environment/decoration_pillow_pile.png",
	&"deco_blanket_chest": "res://art/sprites/environment/decoration_blanket_chest.png",
}

const DECO_CATEGORIES: Array = [
	{"id": &"",       "label": "Todas"},
	{"id": &"wall",   "label": "🖼 Pared"},
	{"id": &"floor",  "label": "🟪 Suelo"},
	{"id": &"table",  "label": "🕯 Mesa"},
	{"id": &"nature", "label": "🍄 Natural"},
]

const ZONE_COLOR: Dictionary = {
	GameEnums.ZoneType.NATURE: Color(0.42, 0.72, 0.45),
	GameEnums.ZoneType.WORKSHOP: Color(0.60, 0.45, 0.30),
	GameEnums.ZoneType.RECEPTION: Color(0.65, 0.40, 0.85),
}

const TILE_SIZE: Vector2 = Vector2(145, 122)
const GRID_COLUMNS: int = 6

@onready var func_grid: GridContainer = $"Margin/VBox/Tabs/🔨 Funcional/Grid"
@onready var deco_grid: GridContainer = $"Margin/VBox/Tabs/✨ Decoración/DecoScroll/Grid"
@onready var deco_filters: HBoxContainer = $"Margin/VBox/Tabs/✨ Decoración/Filters"
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var tabs: TabContainer = $"Margin/VBox/Tabs"

var _deco_filter: StringName = &""
var _filter_buttons: Dictionary = {}  # category_id -> Button

# Cache de tiles construidos (solo cost_lbl + btn + buildable) para hacer refresh
# de precios/disabled sin rebuild completo. Se resetea en cada _rebuild().
var _active_tiles: Array = []  # [{btn, cost_lbl, buildable}]

const ZONE_BY_NAME: Dictionary = {
	&"natural": GameEnums.ZoneType.NATURE,
	&"taller": GameEnums.ZoneType.WORKSHOP,
	&"recepcion": GameEnums.ZoneType.RECEPTION,
}


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	BuildManager.buildable_unlocked.connect(_on_buildable_unlocked)
	BuildManager.build_mode_entered.connect(_on_build_mode_entered)
	BuildManager.placement_completed.connect(_on_placement_completed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	visibility_changed.connect(_on_visibility_changed)
	for g in [func_grid, deco_grid]:
		g.columns = GRID_COLUMNS
		g.add_theme_constant_override(&"h_separation", 10)
		g.add_theme_constant_override(&"v_separation", 10)
	_build_deco_filters()
	_build_hotkey_hint()
	# Reaccionar al cambio de zona para que el panel se refresque mientras está abierto.
	var cam := get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_signal("zone_changed"):
		cam.zone_changed.connect(_on_zone_changed)


func _build_hotkey_hint() -> void:
	var hint := Label.new()
	hint.text = "⌨ B abrir/cerrar · Click izq colocar · Click der / Esc cancelar · R rotar · Tab cambiar pestaña"
	hint.add_theme_font_size_override(&"font_size", 10)
	hint.modulate = Color(0.7, 0.72, 0.8, 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vbox: VBoxContainer = $"Margin/VBox"
	vbox.add_child(hint)
	vbox.move_child(hint, 1)  # debajo del Header


func _on_zone_changed(_zone_name: StringName) -> void:
	if visible:
		_rebuild()


func _get_active_zone() -> GameEnums.ZoneType:
	var cam := get_tree().get_first_node_in_group("zone_camera")
	if cam != null and cam.has_method("get_current_zone"):
		var z = cam.get_current_zone()
		if z is Dictionary:
			return ZONE_BY_NAME.get(z.get("name", &""), GameEnums.ZoneType.NONE)
	return GameEnums.ZoneType.NONE


func _build_deco_filters() -> void:
	for c in deco_filters.get_children():
		c.queue_free()
	_filter_buttons.clear()
	for cat in DECO_CATEGORIES:
		var btn := Button.new()
		btn.text = cat.label
		btn.toggle_mode = true
		btn.button_pressed = (cat.id == _deco_filter)
		btn.add_theme_font_size_override(&"font_size", 12)
		btn.pressed.connect(_on_filter_pressed.bind(cat.id))
		deco_filters.add_child(btn)
		_filter_buttons[cat.id] = btn


func _on_filter_pressed(cat_id: StringName) -> void:
	_deco_filter = cat_id
	for k in _filter_buttons:
		_filter_buttons[k].button_pressed = (k == cat_id)
	_rebuild()


func _on_visibility_changed() -> void:
	if visible:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_toggle_build"):
		UIManager.toggle(PANEL_NAME)
		return
	# Tab alterna pestañas mientras el panel está abierto (Funcional ↔ Decoración).
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if tabs != null and tabs.get_tab_count() > 0:
			tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count()
			get_viewport().set_input_as_handled()


func _on_buildable_unlocked(_b: BuildableData) -> void:
	if visible:
		_rebuild()


func _on_coins_changed(_amount: int) -> void:
	# Coin changes son alta frecuencia (cada compra, cada tick de automation).
	# Solo refrescamos precio/disabled sin destruir tiles → sin hitch.
	if visible:
		_refresh_prices()


func _on_build_mode_entered(_b: BuildableData) -> void:
	UIManager.close_active()


func _on_placement_completed(b: BuildableData, _pos: Vector2) -> void:
	status_label.text = "Construido: %s" % b.display_name


func _rebuild() -> void:
	for g in [func_grid, deco_grid]:
		for child in g.get_children():
			child.queue_free()
	_active_tiles.clear()
	var unlocked: Array[BuildableData] = BuildManager.get_unlocked_buildables()
	var active_zone: GameEnums.ZoneType = _get_active_zone()
	var has_func: bool = false
	var has_deco: bool = false
	for b in unlocked:
		# Filtrado por zona: si el buildable tiene allowed_zone específica y no coincide
		# con la zona activa de la cámara, lo ocultamos. NONE = universal (siempre visible).
		if active_zone != GameEnums.ZoneType.NONE and b.allowed_zone != GameEnums.ZoneType.NONE and b.allowed_zone != active_zone:
			continue
		var tile: Dictionary = _build_tile(b)
		if b.is_decorative:
			if _deco_filter != &"" and b.decoration_category != _deco_filter:
				tile.btn.queue_free()
				continue
			deco_grid.add_child(tile.btn)
			has_deco = true
		else:
			func_grid.add_child(tile.btn)
			has_func = true
		_active_tiles.append(tile)
	if not has_func:
		var l := Label.new()
		l.text = "(sin edificios para esta zona)"
		l.modulate = Color(0.7, 0.7, 0.7, 1)
		func_grid.add_child(l)
	if not has_deco:
		var l := Label.new()
		l.text = "(sin decoraciones en esta categoría)" if _deco_filter != &"" else "(sin decoraciones para esta zona)"
		l.modulate = Color(0.7, 0.7, 0.7, 1)
		deco_grid.add_child(l)



func _build_tile(b: BuildableData) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.tooltip_text = b.description if b.description != "" else b.display_name
	btn.disabled = InventoryManager.arcane_coins < b.cost
	btn.pressed.connect(_on_tile_pressed.bind(b))

	# Tarjeta pergamino: crema con marco de madera y franja izquierda del color
	# de zona (identifica dónde se puede colocar sin teñir toda la card).
	var color: Color = ZONE_COLOR.get(b.allowed_zone, Color(0.5, 0.5, 0.5))
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.96, 0.91, 0.76, 1)
	sb_normal.border_color = Color(0.60, 0.42, 0.24, 1)
	sb_normal.border_width_left = 5
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 3
	sb_normal.set_corner_radius_all(6)
	sb_normal.content_margin_left = 6
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_right = 6
	sb_normal.content_margin_bottom = 6
	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(1.0, 0.97, 0.86, 1)
	sb_hover.border_color = Color(0.95, 0.78, 0.35, 1)
	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.88, 0.80, 0.62, 1)
	var sb_disabled := sb_normal.duplicate()
	sb_disabled.bg_color = Color(0.80, 0.76, 0.66, 1)
	sb_disabled.border_color = Color(0.62, 0.56, 0.46, 1)
	btn.add_theme_stylebox_override(&"normal", sb_normal)
	btn.add_theme_stylebox_override(&"hover", sb_hover)
	btn.add_theme_stylebox_override(&"pressed", sb_pressed)
	btn.add_theme_stylebox_override(&"disabled", sb_disabled)
	btn.add_theme_color_override(&"font_color", Color(0.24, 0.16, 0.11, 1))
	btn.add_theme_color_override(&"font_hover_color", Color(0.20, 0.12, 0.05, 1))
	btn.add_theme_color_override(&"font_disabled_color", Color(0.45, 0.40, 0.33, 1))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override(&"separation", 2)
	btn.add_child(vb)

	# Icono pixel art
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fuente única de verdad: el icono sale del sprite de la ESCENA que se coloca,
	# así menú y objeto colocado SIEMPRE coinciden (no hay dos refs que sincronizar).
	var tex: Texture2D = _icon_from_scene(b)
	if tex == null and b.icon != null:
		tex = b.icon
	if tex != null:
		icon_rect.texture = tex
	vb.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = b.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override(&"font_size", 12)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%s ⚜" % NumFormat.short(b.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override(&"font_size", 13)
	if InventoryManager.arcane_coins < b.cost:
		cost_lbl.modulate = Color(0.78, 0.22, 0.16, 1)
	else:
		cost_lbl.modulate = Color(0.55, 0.40, 0.08, 1)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_lbl)

	var zone_lbl := Label.new()
	zone_lbl.text = _zone_name(b.allowed_zone)
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.add_theme_font_size_override(&"font_size", 10)
	zone_lbl.modulate = color.darkened(0.25)
	zone_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(zone_lbl)
	btn.mouse_entered.connect(_tile_hover.bind(btn, true))
	btn.mouse_exited.connect(_tile_hover.bind(btn, false))
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	return {"btn": btn, "cost_lbl": cost_lbl, "buildable": b}


## Actualiza precio y disabled state de los tiles ya construidos sin destruir nada.
## Se llama en respuesta a coins_changed (alta frecuencia) para evitar hitch de rebuild.
func _refresh_prices() -> void:
	for tile in _active_tiles:
		if not is_instance_valid(tile.btn):
			continue
		var affordable: bool = InventoryManager.arcane_coins >= tile.buildable.cost
		tile.btn.disabled = not affordable
		tile.cost_lbl.modulate = Color(1, 0.95, 0.55, 1) if affordable else Color(1, 0.55, 0.55, 1)


func _tile_hover(btn: Button, entering: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06) if entering else Vector2.ONE, 0.16)


func _on_tile_pressed(b: BuildableData) -> void:
	BuildManager.enter_build_mode(b)


func _zone_name(z: GameEnums.ZoneType) -> String:
	match z:
		GameEnums.ZoneType.NATURE: return "🌳 Natural"
		GameEnums.ZoneType.WORKSHOP: return "🔨 Taller"
		GameEnums.ZoneType.RECEPTION: return "🏛 Recepción"
		_: return "—"
