extends PanelContainer

const PANEL_NAME: StringName = &"shop"

const TILE_SIZE: Vector2 = Vector2(150, 200)
const GRID_COLUMNS: int = 3

const WORKER_INFO: Array = [
	{
		"type": GameEnums.WorkerType.DUENDE,
		"name": "Duende",
		"desc": "Especialista en hierbas. Rápido y barato.",
		"icon": "res://art/sprites/characters/duende_anim.png",
		"color": Color(0.42, 0.72, 0.45),
	},
	{
		"type": GameEnums.WorkerType.GOLEM,
		"name": "Gólem",
		"desc": "Recolecta cristales y minerales. Lento pero resistente.",
		"icon": "res://art/sprites/characters/golem_anim.png",
		"color": Color(0.55, 0.55, 0.65),
	},
	{
		"type": GameEnums.WorkerType.APPRENTICE,
		"name": "Aprendiz",
		"desc": "Trabaja en investigaciones en la Biblioteca.",
		"icon": "res://art/sprites/characters/apprentice_anim.png",
		"color": Color(0.65, 0.40, 0.85),
	},
	{
		"type": GameEnums.WorkerType.LENADOR,
		"name": "Leñador",
		"desc": "Recolecta madera arcana y mena de hierro.",
		"icon": "res://art/sprites/characters/lenador_anim.png",
		"color": Color(0.45, 0.55, 0.30),
	},
	{
		"type": GameEnums.WorkerType.ESPIRITU,
		"name": "Espíritu",
		"desc": "Recoge agua, polvo lunar, amatista, esencia y lingotes.",
		"icon": "res://art/sprites/characters/espiritu_anim.png",
		"color": Color(0.55, 0.40, 0.75),
	},
]

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var status_label: Label = $Margin/VBox/StatusLabel

# Cache de tiles construidas 1 sola vez. Refresh solo actualiza precio + disabled.
# Antes: _rebuild() destruía todo con queue_free en cada visible=true → hitch de 20-50ms
# por descarga+re-upload de texturas al VRAM. Ahora los tiles quedan vivos siempre.
var _tiles: Array = []  # [{btn, cost_lbl, worker_type}]


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	ShopManager.worker_purchased.connect(_on_purchased)
	ShopManager.purchase_failed.connect(_on_failed)
	InventoryManager.coins_changed.connect(_on_coins_changed)
	visibility_changed.connect(_on_visibility_changed)
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	_build_tiles_once()
	_refresh_all()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_all()


func _on_coins_changed(_amount: int) -> void:
	if visible:
		_refresh_all()


func _on_purchased(_worker_type: int, _instance) -> void:
	if visible:
		_refresh_all()


func _on_failed(reason: String) -> void:
	status_label.text = reason


## Construye todos los tiles una única vez. Se llama en _ready().
func _build_tiles_once() -> void:
	for w in WORKER_INFO:
		var tile: Dictionary = _build_tile(w)
		grid.add_child(tile.btn)
		_tiles.append(tile)


## Actualiza valores dinámicos (precio, disabled, color de precio) sin recrear nodos.
func _refresh_all() -> void:
	for tile in _tiles:
		var price: int = ShopManager.get_price(tile.worker_type)
		var affordable: bool = InventoryManager.arcane_coins >= price
		tile.btn.disabled = not affordable
		tile.cost_lbl.text = "%d ⚜" % price
		tile.cost_lbl.modulate = Color(1, 0.95, 0.55, 1) if affordable else Color(1, 0.55, 0.55, 1)


func _build_tile(w: Dictionary) -> Dictionary:
	var price: int = ShopManager.get_price(w.type)
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.tooltip_text = w.desc
	btn.disabled = InventoryManager.arcane_coins < price
	btn.pressed.connect(ShopManager.try_buy.bind(w.type))

	var color: Color = w.color
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = color
	sb_normal.border_color = color.lightened(0.3)
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 2
	sb_normal.corner_radius_top_left = 14
	sb_normal.corner_radius_top_right = 14
	sb_normal.corner_radius_bottom_right = 14
	sb_normal.corner_radius_bottom_left = 14
	sb_normal.content_margin_left = 8
	sb_normal.content_margin_top = 8
	sb_normal.content_margin_right = 8
	sb_normal.content_margin_bottom = 8
	sb_normal.shadow_color = Color(0, 0, 0, 0.35)
	sb_normal.shadow_size = 4
	sb_normal.shadow_offset = Vector2(0, 2)
	sb_normal.anti_aliasing = true
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = color.lightened(0.18)
	sb_hover.border_color = Color(1, 0.95, 0.55, 1)
	sb_hover.border_width_bottom = 3
	sb_hover.shadow_color = color.lightened(0.5)
	sb_hover.shadow_color.a = 0.45
	sb_hover.shadow_size = 6
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = color.darkened(0.18)
	var sb_disabled := sb_normal.duplicate() as StyleBoxFlat
	sb_disabled.bg_color = color.darkened(0.40)
	sb_disabled.border_color = color.darkened(0.55)
	sb_disabled.shadow_size = 1
	btn.add_theme_stylebox_override(&"normal", sb_normal)
	btn.add_theme_stylebox_override(&"hover", sb_hover)
	btn.add_theme_stylebox_override(&"pressed", sb_pressed)
	btn.add_theme_stylebox_override(&"disabled", sb_disabled)
	btn.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override(&"font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override(&"font_disabled_color", Color(0.85, 0.85, 0.85, 1))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override(&"separation", 4)
	btn.add_child(vb)

	# Sprite del ayudante (pixel art)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(w.icon):
		var tex: Texture2D = load(w.icon)
		# Las hojas de animación son grids 64px: usar el primer frame (idle_down)
		# como icono para que la tarjeta muestre EXACTAMENTE el sprite del juego.
		if tex != null and tex.get_width() > 64:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, 0, 64, 64)
			icon_rect.texture = at
		else:
			icon_rect.texture = tex
	vb.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.text = w.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override(&"font_size", 14)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = w.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override(&"font_size", 10)
	desc_lbl.modulate = Color(1, 1, 1, 0.85)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%d ⚜" % price
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override(&"font_size", 14)
	if InventoryManager.arcane_coins < price:
		cost_lbl.modulate = Color(1, 0.55, 0.55, 1)
	else:
		cost_lbl.modulate = Color(1, 0.95, 0.55, 1)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_lbl)

	btn.mouse_entered.connect(_card_hover.bind(btn, true))
	btn.mouse_exited.connect(_card_hover.bind(btn, false))
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	return {"btn": btn, "cost_lbl": cost_lbl, "worker_type": w.type}


func _card_hover(btn: Button, entering: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06) if entering else Vector2.ONE, 0.16)
