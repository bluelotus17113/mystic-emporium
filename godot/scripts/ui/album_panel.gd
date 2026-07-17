extends PanelContainer
## Álbum de Clientes: colección de los 44 NPCs. Atendidos = retrato a color
## + nombre + nº de pedidos; sin descubrir = silueta y "???".

const PANEL_NAME: StringName = &"album"
const COLS: int = 8

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _close: Button = $Margin/VBox/Header/CloseButton
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	_close.pressed.connect(UIManager.close_active)
	_grid.columns = COLS
	visibility_changed.connect(func():
		if visible:
			_rebuild())
	AlbumManager.album_updated.connect(func(_s):
		if visible:
			_rebuild())


func _all_skins() -> Array:
	var out: Array = []
	for path in CustomerAI.NPC_POOL + CustomerAI.VIP_POOL:
		out.append(path.get_file().get_basename())
	return out


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var skins: Array = _all_skins()
	_title.text = "📔 Álbum de Clientes  ·  %d/%d" % [AlbumManager.discovered_total(), skins.size()]
	for skin in skins:
		_grid.add_child(_build_entry(StringName(skin)))


func _build_entry(skin: StringName) -> Control:
	var discovered: bool = AlbumManager.is_discovered(skin)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(96, 108)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.91, 0.76, 1) if discovered else Color(0.82, 0.78, 0.68, 1)
	sb.border_color = Color(0.60, 0.42, 0.24, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override(&"panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = _portrait(skin)
	if not discovered:
		icon.modulate = Color(0.06, 0.05, 0.09, 0.9)  # silueta
	vb.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override(&"font_size", 10)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if discovered:
		name_lbl.text = _pretty(skin)
		card.tooltip_text = "%s — %d pedido(s) atendidos" % [_pretty(skin), AlbumManager.get_count(skin)]
	else:
		name_lbl.text = "???"
		card.tooltip_text = "Cliente sin descubrir: complétale un pedido."
	vb.add_child(name_lbl)

	if discovered:
		var count_lbl := Label.new()
		count_lbl.text = "×%d" % AlbumManager.get_count(skin)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override(&"font_size", 10)
		count_lbl.modulate = Color(0.55, 0.40, 0.08, 1)
		vb.add_child(count_lbl)
	return card


func _portrait(skin: StringName) -> Texture2D:
	var anim_path: String = "res://art/sprites/characters/%s_anim.png" % skin
	if ResourceLoader.exists(anim_path):
		var at := AtlasTexture.new()
		at.atlas = load(anim_path)
		at.region = Rect2(0, 0, 64, 64)
		return at
	var p64: String = "res://art/sprites/characters/%s_64.png" % skin
	if ResourceLoader.exists(p64):
		return load(p64)
	return null


func _pretty(skin: StringName) -> String:
	return String(skin).trim_prefix("npc_").replace("_", " ").capitalize()
