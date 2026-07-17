extends PanelContainer
## 🪄 Abracadabra — editor de píxeles 32×32 para crear objetos construibles.
## Herramientas: lápiz, borrador, relleno, cuentagotas. Tipo sólido (colisión)
## o alfombra (se atraviesa). Crear cuesta 50 monedas.

const PANEL_NAME: StringName = &"abracadabra"
const PX: int = 32
const CELL: int = 15  ## px de pantalla por píxel del arte

const PALETTE: Array = [
	"21181b", "ffffff", "c8c8d8", "8a8a9c", "4a4a5a",
	"6b4726", "9a6b3c", "c89b5c", "e0cc98", "f5ecc8",
	"df5235", "e8804a", "ffb570", "8b2f3a", "c0392b",
	"63ab3e", "8fc84f", "c8d45d", "3b7d4f", "2a5a3a",
	"4fa4b8", "92e8c0", "5a8fd0", "2f4b8e", "a56bd8",
	"7a3fb0", "ffd196", "e8b04a", "f0a0c0", "ff7fb0",
]

var _img: Image
var _tex: ImageTexture
var _canvas: Control
var _tool: StringName = &"pencil"
var _color: Color = Color("df5235")
var _type: String = "solid"
var _painting: bool = false

var _name_edit: LineEdit
var _create_btn: Button
var _solid_btn: Button
var _floor_btn: Button
var _tool_btns: Dictionary = {}
var _swatch_sel: ColorRect


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	custom_minimum_size = Vector2(1100, 720)
	_build_ui()
	InventoryManager.coins_changed.connect(func(_c): _refresh_create())
	visibility_changed.connect(func():
		if visible:
			move_to_front()
			_refresh_create())


func _new_image() -> void:
	_img = Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	if _canvas:
		_canvas.queue_redraw()


# ---------------------------------------------------------------- UI ---
func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 20)
	margin.add_theme_constant_override(&"margin_top", 16)
	margin.add_theme_constant_override(&"margin_right", 20)
	margin.add_theme_constant_override(&"margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 10)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🪄 Abracadabra — crea tu objeto"
	title.add_theme_font_size_override(&"font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(UIManager.close_active)
	header.add_child(close)
	root.add_child(header)
	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Canvas
	_new_image()
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(PX * CELL, PX * CELL)
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)

	# Panel derecho
	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 10)
	side.custom_minimum_size = Vector2(340, 0)
	body.add_child(side)

	# Herramientas
	var tools_lbl := Label.new(); tools_lbl.text = "Herramienta"; side.add_child(tools_lbl)
	var tools := HBoxContainer.new()
	for spec in [["pencil", "✏️ Lápiz"], ["eraser", "🩹 Borrar"], ["fill", "🪣 Relleno"], ["pick", "🎯 Pipeta"]]:
		var b := Button.new()
		b.text = spec[1]
		b.toggle_mode = true
		b.button_pressed = (spec[0] == "pencil")
		b.pressed.connect(_select_tool.bind(StringName(spec[0])))
		tools.add_child(b)
		_tool_btns[StringName(spec[0])] = b
	side.add_child(tools)

	# Paleta
	var pal_lbl := Label.new(); pal_lbl.text = "Colores"; side.add_child(pal_lbl)
	var pal := GridContainer.new()
	pal.columns = 10
	pal.add_theme_constant_override(&"h_separation", 3)
	pal.add_theme_constant_override(&"v_separation", 3)
	for hexc in PALETTE:
		var sw := ColorRect.new()
		sw.color = Color(hexc)
		sw.custom_minimum_size = Vector2(28, 28)
		sw.mouse_filter = Control.MOUSE_FILTER_STOP
		sw.gui_input.connect(_on_swatch_input.bind(Color(hexc), sw))
		pal.add_child(sw)
	side.add_child(pal)
	_swatch_sel = ColorRect.new()
	_swatch_sel.color = _color
	_swatch_sel.custom_minimum_size = Vector2(0, 22)
	side.add_child(_swatch_sel)

	side.add_child(HSeparator.new())

	# Nombre
	var name_lbl := Label.new(); name_lbl.text = "Nombre"; side.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Mi objeto mágico"
	_name_edit.max_length = 24
	side.add_child(_name_edit)

	# Tipo
	var type_lbl := Label.new(); type_lbl.text = "Tipo"; side.add_child(type_lbl)
	var types := HBoxContainer.new()
	_solid_btn = Button.new(); _solid_btn.text = "🧱 Sólido"; _solid_btn.toggle_mode = true; _solid_btn.button_pressed = true
	_solid_btn.tooltip_text = "Bloquea el paso (mesas, muebles)"
	_solid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floor_btn = Button.new(); _floor_btn.text = "🟪 Alfombra"; _floor_btn.toggle_mode = true
	_floor_btn.tooltip_text = "Se puede pisar/atravesar (suelo)"
	_floor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_solid_btn.pressed.connect(func(): _set_type("solid"))
	_floor_btn.pressed.connect(func(): _set_type("floor"))
	types.add_child(_solid_btn); types.add_child(_floor_btn)
	side.add_child(types)

	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; side.add_child(spacer)

	# Acciones
	var clear_btn := Button.new()
	clear_btn.text = "🗑 Limpiar lienzo"
	clear_btn.pressed.connect(func(): _new_image())
	side.add_child(clear_btn)
	_create_btn = Button.new()
	_create_btn.add_theme_font_size_override(&"font_size", 18)
	_create_btn.custom_minimum_size = Vector2(0, 52)
	_create_btn.pressed.connect(_on_create)
	side.add_child(_create_btn)
	_refresh_create()


func _draw_canvas() -> void:
	# fondo tipo tablero + el arte + rejilla
	var checker_a := Color(0.86, 0.82, 0.72)
	var checker_b := Color(0.80, 0.76, 0.66)
	for y in PX:
		for x in PX:
			var c: Color = checker_a if (x + y) % 2 == 0 else checker_b
			_canvas.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), c)
	_canvas.draw_texture_rect(_tex, Rect2(0, 0, PX * CELL, PX * CELL), false)
	var grid := Color(0, 0, 0, 0.12)
	for i in range(PX + 1):
		_canvas.draw_line(Vector2(i * CELL, 0), Vector2(i * CELL, PX * CELL), grid, 1.0)
		_canvas.draw_line(Vector2(0, i * CELL), Vector2(PX * CELL, i * CELL), grid, 1.0)
	_canvas.draw_rect(Rect2(0, 0, PX * CELL, PX * CELL), Color(0.13, 0.09, 0.06), false, 2.0)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
			if event.pressed:
				_paint_at(event.position)
	elif event is InputEventMouseMotion and _painting:
		_paint_at(event.position)


func _paint_at(pos: Vector2) -> void:
	var px: int = int(pos.x / CELL)
	var py: int = int(pos.y / CELL)
	if px < 0 or px >= PX or py < 0 or py >= PX:
		return
	match _tool:
		&"pencil":
			_img.set_pixel(px, py, _color)
		&"eraser":
			_img.set_pixel(px, py, Color(0, 0, 0, 0))
		&"pick":
			var c: Color = _img.get_pixel(px, py)
			if c.a > 0.0:
				_set_color(c)
			return
		&"fill":
			_flood_fill(px, py, _color)
	_tex.update(_img)
	_canvas.queue_redraw()


func _flood_fill(sx: int, sy: int, to: Color) -> void:
	var from: Color = _img.get_pixel(sx, sy)
	if from.is_equal_approx(to):
		return
	var stack: Array = [Vector2i(sx, sy)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= PX or p.y < 0 or p.y >= PX:
			continue
		if not _img.get_pixel(p.x, p.y).is_equal_approx(from):
			continue
		_img.set_pixel(p.x, p.y, to)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))


func _on_swatch_input(event: InputEvent, c: Color, _sw: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_color(c)
		if _tool == &"eraser" or _tool == &"pick":
			_select_tool(&"pencil")


func _set_color(c: Color) -> void:
	_color = c
	if _swatch_sel:
		_swatch_sel.color = c


func _select_tool(t: StringName) -> void:
	_tool = t
	for k in _tool_btns:
		(_tool_btns[k] as Button).set_pressed_no_signal(k == t)


func _set_type(t: String) -> void:
	_type = t
	_solid_btn.set_pressed_no_signal(t == "solid")
	_floor_btn.set_pressed_no_signal(t == "floor")


func _refresh_create() -> void:
	if _create_btn == null:
		return
	var afford: bool = CustomObjectManager.can_afford()
	_create_btn.disabled = not afford
	_create_btn.text = "✨ Crear objeto (%d ⚜)" % CustomObjectManager.CREATE_COST


func _on_create() -> void:
	# Rechazar lienzo vacío.
	var used := _img.get_used_rect()
	if used.size == Vector2i.ZERO:
		NotificationManager.post("El lienzo está vacío — dibuja algo primero.", NotificationManager.Kind.ALERT)
		return
	var id: StringName = CustomObjectManager.create(_name_edit.text, _type, _img.duplicate())
	if id == &"":
		NotificationManager.post("No tienes suficientes monedas.", NotificationManager.Kind.ALERT)
		return
	AudioManager.play_named(&"order_complete")
	NotificationManager.post("✨ '%s' creado. ¡Búscalo en Construcción → Mías!" % _name_edit.text, NotificationManager.Kind.INFO)
	UIManager.close_active()
	_new_image()
	_name_edit.text = ""
	# Abrir el catálogo en la pestaña de creaciones.
	UIManager.open(&"build")
