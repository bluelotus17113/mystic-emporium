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


## Tres tarjetas fijas, una por plaza de la bolsa de contratos. Se construyen una
## sola vez y `_refresh_all` les cambia el contenido: los candidatos rotan cada día
## pero los nodos son siempre los mismos, que es lo que evita el tirón de recrear
## texturas al abrir el panel.
func _build_tiles_once() -> void:
	for i in 3:
		var tile: Dictionary = _build_tile(WORKER_INFO[0], i)
		grid.add_child(tile.btn)
		_tiles.append(tile)


## Vuelca la bolsa de hoy en las tres tarjetas: sprite, nombre, rasgo, favorito y
## precio. Una plaza ya contratada queda vacía hasta la renovación de mañana.
func _refresh_all() -> void:
	var bolsa: Array = Contratos.candidatos_crudos()
	for i in _tiles.size():
		var tile: Dictionary = _tiles[i]
		var c: Dictionary = bolsa[i] if i < bolsa.size() else {}
		if c.is_empty():
			tile.btn.disabled = true
			tile.name_lbl.text = "—"
			tile.desc_lbl.text = "Contratado.\nVuelve mañana."
			tile.cost_lbl.text = ""
			tile.icon.texture = null
			tile.worker_type = -1
			continue
		var tipo: int = int(c["type"])
		var info: Dictionary = _info_de(tipo)
		var precio: int = int(c["price"])
		var hay_plaza: bool = Contratos.puede_contratar(tipo)
		var puede_pagar: bool = InventoryManager.arcane_coins >= precio
		tile.worker_type = tipo
		tile.icon.texture = _icono_de(info)
		tile.name_lbl.text = "%s · %s" % [String(c["name"]), String(info.name)]
		tile.name_lbl.add_theme_color_override(&"font_color", Color(info.color).lightened(0.35))
		# La ficha: el rasgo y el recurso favorito son LA decisión del contrato.
		# Sin ellos delante esto vuelve a ser comprar a ciegas, que es lo que había.
		var sig: String = VidaSocial.sigla_de(c.get("ejes", {}))
		tile.desc_lbl.text = "%s\n%s\n%s" % [String(c["trait_label"]), sig,
			_fav_texto(int(c["favorite"]))]
		if not hay_plaza:
			# El candidato se ve igual pero bloqueado y CON el motivo: esconderlo
			# dejaría al jugador sin entender por qué unos días hay tres y otros dos.
			tile.btn.disabled = true
			tile.cost_lbl.text = "Sin plaza (máx. %d)" % Contratos.MAX_POR_TIPO
			tile.cost_lbl.modulate = Color(1, 0.55, 0.55, 1)
			continue
		tile.btn.disabled = not puede_pagar
		tile.cost_lbl.text = "%d ⚜" % precio
		tile.cost_lbl.modulate = Color(1, 0.95, 0.55, 1) if puede_pagar else Color(1, 0.55, 0.55, 1)


func _info_de(tipo: int) -> Dictionary:
	for w in WORKER_INFO:
		if w.type == tipo:
			return w
	return WORKER_INFO[0]


## Primer fotograma de la hoja de animación, para que la ficha enseñe EXACTAMENTE
## el sprite que se va a ver en el juego.
func _icono_de(info: Dictionary) -> Texture2D:
	if not ResourceLoader.exists(info.icon):
		return null
	var tex: Texture2D = load(info.icon)
	if tex != null and tex.get_width() > 64:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, 64, 64)
		return at
	return tex


func _fav_texto(fav: int) -> String:
	if fav < 0:
		return "Sin especialidad"
	return "Prefiere %s" % WorkerBase._resource_type_label(fav)


func _build_tile(w: Dictionary, idx: int) -> Dictionary:
	var price: int = 0
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.tooltip_text = w.desc
	btn.disabled = InventoryManager.arcane_coins < price
	btn.pressed.connect(ShopManager.try_contratar.bind(idx))

	# El color del ayudante ya no rellena la tarjeta entera: es una franja a la
	# izquierda y el color del nombre. Como fondo eran cinco bloques pastel muy
	# saturados sobre una interfaz oscura —lo más ruidoso de la pantalla— y la
	# descripción en blanco encima del verde apenas se leía.
	var color: Color = w.color
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = UIPalette.fondo(UIPalette.SURFACE, 0.92)
	sb_normal.border_color = Color(color.r, color.g, color.b, 0.8)
	sb_normal.border_width_left = 5
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
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
	sb_hover.bg_color = UIPalette.fondo(UIPalette.SURFACE_HI, 0.98)
	sb_hover.border_color = UIPalette.GOLD
	sb_hover.shadow_color = Color(color.r, color.g, color.b, 0.45)
	sb_hover.shadow_size = 8
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = UIPalette.fondo(UIPalette.SURFACE_LO, 1.0)
	var sb_disabled := sb_normal.duplicate() as StyleBoxFlat
	sb_disabled.bg_color = UIPalette.fondo(UIPalette.SURFACE_LO, 0.5)
	sb_disabled.border_color = Color(color.r, color.g, color.b, 0.3)
	sb_disabled.shadow_size = 1
	btn.add_theme_stylebox_override(&"normal", sb_normal)
	btn.add_theme_stylebox_override(&"hover", sb_hover)
	btn.add_theme_stylebox_override(&"pressed", sb_pressed)
	btn.add_theme_stylebox_override(&"disabled", sb_disabled)
	btn.add_theme_color_override(&"font_color", UIPalette.TEXT)
	btn.add_theme_color_override(&"font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override(&"font_disabled_color", UIPalette.TEXT_OFF)

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
	# El nombre lleva el color del ayudante: es lo que lo identifica ahora que el
	# fondo de la tarjeta es el mismo para los cinco. Aclarado para que verdes y
	# morados medios se lean sobre oscuro.
	name_lbl.add_theme_color_override(&"font_color", color.lightened(0.35))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = w.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override(&"font_size", 11)
	desc_lbl.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
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
	return {"btn": btn, "cost_lbl": cost_lbl, "worker_type": w.type,
		"name_lbl": name_lbl, "desc_lbl": desc_lbl, "icon": icon_rect}


func _card_hover(btn: Button, entering: bool) -> void:
	if not is_instance_valid(btn) or btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06) if entering else Vector2.ONE, 0.16)
