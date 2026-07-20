extends PanelContainer
## Árbol de investigación: cards posicionadas por tier (eje X) + nivel vertical,
## con líneas dibujadas entre prereq → research.

const PANEL_NAME: StringName = &"research"
const CARD_W: int = 240
const CARD_H: int = 170
const COL_GAP: int = 50
const ROW_GAP: int = 16
const ROW_HEIGHT: int = CARD_H + ROW_GAP
const COL_WIDTH: int = CARD_W + COL_GAP
const LEFT_PAD: int = 24
const TOP_PAD: int = 16

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var tree_view: Control = $Margin/VBox/Scroll/TreeView
@onready var status_label: Label = $Margin/VBox/StatusLabel

var active_station = null
var _card_refs: Dictionary = {}  # research.id → {card, pos}
var _connections_node: Node2D = null  # custom-draw node


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	_add_background()
	close_button.pressed.connect(UIManager.close_active)
	ResearchManager.station_clicked.connect(_on_station_clicked)
	ResearchManager.research_started.connect(_on_research_started)
	ResearchManager.research_completed.connect(_on_research_completed)
	# Custom draw node para las líneas de conexión.
	_connections_node = Node2D.new()
	_connections_node.draw.connect(_draw_connections)
	tree_view.add_child(_connections_node)
	_connections_node.z_index = -1
	_setup_legend()


## Fondo decorativo de biblioteca arcana (PixelLab) detrás de las cards, atenuado
## para que el árbol siga legible.
func _add_background() -> void:
	var tex: Texture2D = load("res://art/sprites/ui/research_bg.png")
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.name = "LibraryBackground"
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.modulate = Color(1, 1, 1, 0.8)
	add_child(bg)
	move_child(bg, 0)  # detrás de todo el contenido


func _setup_legend() -> void:
	var legend: Node = get_node_or_null("Margin/VBox/Legend")
	if legend == null or legend.get_child_count() < 4:
		return
	var specs: Array = [
		["🟢 Completada", Color(0.5, 1, 0.6)],
		["🟡 Disponible", Color(1, 0.9, 0.45)],
		["🟣 En curso", Color(1, 0.7, 1)],
		["🔒 Bloqueada", Color(0.72, 0.66, 0.86)],
	]
	for i in 4:
		var lbl: Label = legend.get_child(i) as Label
		if lbl != null:
			lbl.text = specs[i][0]
			lbl.modulate = specs[i][1]
			lbl.add_theme_font_size_override(&"font_size", 12)


func _on_station_clicked(station) -> void:
	active_station = station
	UIManager.open(PANEL_NAME)
	_rebuild()


func _rebuild() -> void:
	if active_station == null:
		return
	for child in tree_view.get_children():
		if child != _connections_node:
			child.queue_free()
	_card_refs.clear()

	# Catálogo completo del tipo de estación (incluye completados, locked y available).
	var all_for_station: Array = _gather_all_for_station()
	# Asignamos columna por tier, fila por orden alfabético dentro del tier.
	var by_tier: Dictionary = {}
	for r in all_for_station:
		var tier_arr: Array = by_tier.get(r.tier, [])
		tier_arr.append(r)
		by_tier[r.tier] = tier_arr
	for tier in by_tier.keys():
		by_tier[tier].sort_custom(func(a, b): return a.display_name < b.display_name)

	for tier in by_tier.keys():
		var col_x: int = LEFT_PAD + (tier - 1) * COL_WIDTH
		var arr: Array = by_tier[tier]
		for i in arr.size():
			var r: ResearchData = arr[i]
			var pos: Vector2 = Vector2(col_x, TOP_PAD + i * ROW_HEIGHT)
			var card: Control = _build_card(r)
			card.position = pos
			tree_view.add_child(card)
			_card_refs[r.id] = {"card": card, "pos": pos}

	# Ajustar tamaño del contenedor para que el scroll funcione.
	var max_tier: int = 1
	var max_per_tier: int = 1
	for tier in by_tier.keys():
		max_tier = max(max_tier, tier)
		max_per_tier = max(max_per_tier, by_tier[tier].size())
	tree_view.custom_minimum_size = Vector2(
		LEFT_PAD * 2 + max_tier * COL_WIDTH,
		TOP_PAD * 2 + max_per_tier * ROW_HEIGHT
	)
	_connections_node.queue_redraw()


func _gather_all_for_station() -> Array:
	# La Biblioteca muestra el árbol completo; las otras stations muestran su rama.
	var is_library: bool = active_station.station_type == GameEnums.StationType.ARCANE_LIBRARY
	var out: Array = []
	for r in ResearchManager._all_research:
		if r == null:
			continue
		if not is_library and r.required_station_type != active_station.station_type:
			continue
		# Filtramos research huérfana (consistente con get_available_for_station).
		if r.recipe_to_unlock == null and r.buildable_to_unlock == null:
			continue
		out.append(r)
	return out


func _build_card(r: ResearchData) -> Control:
	var state: StringName = _state_of(r)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.tooltip_text = "%s\n\nCosto: %d ⚜ · %ds" % [r.description, r.coin_cost, int(r.research_time)]
	card.add_theme_stylebox_override(&"panel", _card_style(state))
	if state == &"locked" or state == &"tier_locked":
		card.modulate = Color(1, 1, 1, 0.82)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	card.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 3)
	margin.add_child(v)

	# Cabecera: chip de estado + nombre + tier.
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override(&"separation", 6)
	v.add_child(hdr)
	var chip := Label.new()
	chip.text = _state_icon(state)
	chip.add_theme_font_size_override(&"font_size", 16)
	hdr.add_child(chip)
	var name_l := Label.new()
	name_l.text = r.display_name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true  # que un nombre largo no ensanche la card
	name_l.add_theme_font_size_override(&"font_size", 14)
	hdr.add_child(name_l)
	var tier_label := Label.new()
	tier_label.text = "T%d" % r.tier
	tier_label.add_theme_font_size_override(&"font_size", 11)
	tier_label.modulate = Color(0.95, 0.78, 0.35, 1)
	hdr.add_child(tier_label)

	# 🔓 Desbloquea: icono + nombre de lo que abre este nodo (el "flujo").
	var unlock: Dictionary = _unlock_info(r)
	if not unlock.is_empty():
		var ub := HBoxContainer.new()
		ub.add_theme_constant_override(&"separation", 5)
		v.add_child(ub)
		if unlock.get("icon") != null:
			ub.add_child(_icon_rect(unlock.icon))
		var ul := Label.new()
		var extra: int = r.extra_recipes_to_unlock.size()
		ul.text = "🔓 %s%s" % [String(unlock.name), (" +%d" % extra) if extra > 0 else ""]
		ul.add_theme_font_size_override(&"font_size", 12)
		ul.modulate = Color(0.75, 0.95, 1.0, 1)
		ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ul.clip_text = true  # no ensanchar la card con nombres largos
		ub.add_child(ul)

	var meta := Label.new()
	meta.text = "%d ⚜    ⏱ %ds" % [r.coin_cost, int(r.research_time)]
	meta.add_theme_font_size_override(&"font_size", 11)
	meta.modulate = Color(0.85, 0.85, 0.95, 1)
	v.add_child(meta)

	# Items requeridos: una línea por item con check ✓/✗ y conteo have/need.
	var reqs: Array = ResearchManager.get_required_items_for(r)
	for req in reqs:
		var rl := Label.new()
		var item_name: String = req.item.display_name if req.item != null else String(req.get("id", "?"))
		rl.text = "  %s %d/%d %s" % ["✓" if req.ok else "✗", req.have, req.qty, item_name]
		rl.add_theme_font_size_override(&"font_size", 10)
		rl.clip_text = true
		rl.modulate = Color(0.62, 1.0, 0.65, 1) if req.ok else Color(1.0, 0.75, 0.75, 1)
		v.add_child(rl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# Botón de acción / estado.
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override(&"font_size", 12)
	btn.custom_minimum_size = Vector2(0, 28)
	v.add_child(btn)
	match state:
		&"completed":
			btn.text = "✓ Completada"
			btn.disabled = true
		&"active":
			btn.text = "⌛ %d%%" % int(ResearchManager.get_active_progress_percent() * 100)
			btn.disabled = true
		&"available":
			btn.text = "⚡ Investigar"
			var has_active: bool = ResearchManager.get_active() != null
			btn.disabled = has_active or not ResearchManager.can_afford(r)
			btn.pressed.connect(_on_start_pressed.bind(r))
		&"tier_locked":
			btn.text = "🔒 Tier T%d requerido" % (r.tier - 1)
			btn.disabled = true
		_:
			btn.text = "🔒 Falta prerrequisito"
			btn.disabled = true
	return card


func _state_icon(state: StringName) -> String:
	match state:
		&"completed": return "🟢"
		&"active": return "🟣"
		&"available": return "🟡"
		_: return "🔒"


func _card_style(state: StringName) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.20, 0.97)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	match state:
		&"completed":
			sb.border_color = Color(0.45, 0.9, 0.55)
			sb.bg_color = Color(0.13, 0.20, 0.15, 0.97)
		&"active":
			sb.border_color = Color(1, 0.6, 1)
			sb.bg_color = Color(0.20, 0.13, 0.22, 0.97)
		&"available":
			sb.border_color = Color(1, 0.85, 0.4)
			sb.set_border_width_all(3)
			sb.bg_color = Color(0.20, 0.17, 0.12, 0.97)
		&"tier_locked":
			sb.border_color = Color(0.5, 0.45, 0.62)
		_:
			sb.border_color = Color(0.4, 0.37, 0.5)
	return sb


## TextureRect de 22×22 con tamaño FIJO (EXPAND_IGNORE_SIZE), recortando el
## primer frame cuadrado si el icono resulta ser un spritesheet horizontal (si no,
## el TextureRect tomaría el tamaño natural de la tira y ensancharía la card).
func _icon_rect(tex: Texture2D) -> TextureRect:
	var ico := TextureRect.new()
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	if w > int(h * 1.5):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, h, h)
		ico.texture = at
	else:
		ico.texture = tex
	ico.custom_minimum_size = Vector2(22, 22)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ico


func _unlock_info(r: ResearchData) -> Dictionary:
	if r.recipe_to_unlock != null and r.recipe_to_unlock.output_item != null:
		var it: ItemData = r.recipe_to_unlock.output_item
		return {"name": it.display_name, "icon": it.icon}
	if r.buildable_to_unlock != null:
		return {"name": r.buildable_to_unlock.display_name, "icon": r.buildable_to_unlock.icon}
	return {}


func _state_of(r: ResearchData) -> StringName:
	if ResearchManager.is_completed(r):
		return &"completed"
	if ResearchManager.get_active() == r:
		return &"active"
	if not ResearchManager.explicit_prereqs_met(r):
		return &"locked"
	if not ResearchManager.is_tier_gate_met(r):
		return &"tier_locked"
	return &"available"


func _draw_connections() -> void:
	# Para cada research con prereqs, dibujamos línea desde el centro derecho del prereq
	# al centro izquierdo de la card.
	for r_id in _card_refs.keys():
		var data: Dictionary = _card_refs[r_id]
		var r: ResearchData = _find_by_id(r_id)
		if r == null:
			continue
		for prereq in r.prerequisites:
			if prereq == null:
				continue
			var pdata: Dictionary = _card_refs.get(prereq.id, {})
			if pdata.is_empty():
				continue
			var from: Vector2 = pdata.pos + Vector2(CARD_W, CARD_H * 0.5)
			var to: Vector2 = data.pos + Vector2(0, CARD_H * 0.5)
			var done: bool = ResearchManager.is_completed(prereq)
			var color: Color = Color(1.0, 0.82, 0.35, 0.95) if done else Color(0.55, 0.45, 0.75, 0.5)
			_draw_curve(from, to, color, done)


## Curva bezier suave prereq→research con flecha en el destino (y glow si el
## prerrequisito ya está completado: resalta la ruta desbloqueada).
func _draw_curve(a: Vector2, b: Vector2, col: Color, glow: bool) -> void:
	var dx: float = maxf(40.0, (b.x - a.x) * 0.5)
	var c1: Vector2 = a + Vector2(dx, 0)
	var c2: Vector2 = b - Vector2(dx, 0)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 18
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(a.bezier_interpolate(c1, c2, b, t))
	if glow:
		_connections_node.draw_polyline(pts, Color(col.r, col.g, col.b, 0.22), 8.0, true)
	_connections_node.draw_polyline(pts, col, 3.0, true)
	# Flecha en el destino (apunta hacia la card, +x).
	var tip: Vector2 = b + Vector2(1, 0)
	var back: Vector2 = tip - Vector2(10, 0)
	var arrow: PackedVector2Array = [tip, back + Vector2(0, -5), back + Vector2(0, 5)]
	_connections_node.draw_colored_polygon(arrow, col)


func _find_by_id(id: StringName) -> ResearchData:
	for r in ResearchManager._all_research:
		if r != null and r.id == id:
			return r
	return null


func _on_start_pressed(r: ResearchData) -> void:
	if ResearchManager.start_research(r):
		status_label.text = "%s en curso." % r.display_name
		_rebuild()
	else:
		status_label.text = "No se puede iniciar (revisa coins o prerrequisitos)."


func _on_research_started(_r: ResearchData) -> void:
	if visible:
		_rebuild()


func _on_research_completed(r: ResearchData) -> void:
	if visible:
		status_label.text = "Completada: %s ✓" % r.display_name
		_rebuild()
