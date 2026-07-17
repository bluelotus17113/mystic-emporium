extends PanelContainer
## Armario de la protagonista: elige outfit (hojas completas). El actual se
## marca con borde dorado; los no generados aún aparecen deshabilitados.

const PANEL_NAME: StringName = &"wardrobe"
const COLS: int = 6

@onready var _close: Button = $Margin/VBox/Header/CloseButton
@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	_close.pressed.connect(UIManager.close_active)
	_grid.columns = COLS
	visibility_changed.connect(func():
		if visible:
			_rebuild())
	WardrobeManager.outfit_changed.connect(func(_o):
		if visible:
			_rebuild())


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for oid in WardrobeManager.OUTFITS:
		_grid.add_child(_build_card(oid))


func _build_card(oid: StringName) -> Control:
	var available: bool = WardrobeManager.is_available(oid)
	var current: bool = WardrobeManager.current_outfit == oid
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 130)
	btn.disabled = not available
	btn.tooltip_text = WardrobeManager.OUTFITS[oid] if available else "Aún no disponible"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.91, 0.76, 1) if available else Color(0.82, 0.78, 0.68, 1)
	sb.border_color = Color(0.95, 0.78, 0.35, 1) if current else Color(0.60, 0.42, 0.24, 1)
	sb.set_border_width_all(4 if current else 2)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override(&"normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(1.0, 0.97, 0.86, 1)
	btn.add_theme_stylebox_override(&"hover", sbh)
	btn.add_theme_stylebox_override(&"pressed", sb)
	btn.add_theme_stylebox_override(&"disabled", sb)
	btn.pressed.connect(func(): WardrobeManager.set_outfit(oid))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vb)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if available:
		var at := AtlasTexture.new()
		at.atlas = load(WardrobeManager.sheet_path(oid))
		at.region = Rect2(0, 0, 64, 64)
		icon.texture = at
	vb.add_child(icon)

	var lbl := Label.new()
	lbl.text = WardrobeManager.OUTFITS[oid] if available else "???"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override(&"font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
	if current:
		var mark := Label.new()
		mark.text = "✔ puesto"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override(&"font_size", 10)
		mark.modulate = Color(0.55, 0.40, 0.08, 1)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(mark)
	return btn
