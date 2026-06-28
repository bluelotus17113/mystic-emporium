extends PanelContainer
## Árbol de investigación: cards posicionadas por tier (eje X) + nivel vertical,
## con líneas dibujadas entre prereq → research.

const PANEL_NAME: StringName = &"research"
const CARD_W: int = 220
const CARD_H: int = 110
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
	close_button.pressed.connect(UIManager.close_active)
	ResearchManager.station_clicked.connect(_on_station_clicked)
	ResearchManager.research_started.connect(_on_research_started)
	ResearchManager.research_completed.connect(_on_research_completed)
	# Custom draw node para las líneas de conexión.
	_connections_node = Node2D.new()
	_connections_node.draw.connect(_draw_connections)
	tree_view.add_child(_connections_node)
	_connections_node.z_index = -1


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
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.tooltip_text = "%s\n\nCosto: %d ⚜ · %ds\n%s" % [r.description, r.coin_cost, int(r.research_time), r.display_name]

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_top", 6)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_bottom", 6)
	card.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	margin.add_child(v)

	var hdr := HBoxContainer.new()
	v.add_child(hdr)
	var tier_label := Label.new()
	tier_label.text = "T%d" % r.tier
	tier_label.add_theme_font_size_override(&"font_size", 11)
	tier_label.modulate = Color(0.95, 0.78, 0.35, 1)
	tier_label.custom_minimum_size = Vector2(28, 0)
	hdr.add_child(tier_label)
	var name_l := Label.new()
	name_l.text = r.display_name
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override(&"font_size", 13)
	hdr.add_child(name_l)

	var meta := Label.new()
	meta.text = "%d ⚜  ·  %ds" % [r.coin_cost, int(r.research_time)]
	meta.add_theme_font_size_override(&"font_size", 11)
	meta.modulate = Color(0.85, 0.85, 0.95, 1)
	v.add_child(meta)

	var state: StringName = _state_of(r)
	var state_label := Label.new()
	v.add_child(state_label)

	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override(&"font_size", 12)
	btn.custom_minimum_size = Vector2(0, 30)
	v.add_child(btn)

	match state:
		&"completed":
			card.modulate = Color(0.5, 1, 0.6, 1)
			state_label.text = "✓ Completada"
			state_label.modulate = Color(0.5, 1, 0.6, 1)
			btn.text = "Completada"
			btn.disabled = true
		&"active":
			card.modulate = Color(1, 0.7, 1, 1)
			state_label.text = "⌛ %d%%" % int(ResearchManager.get_active_progress_percent() * 100)
			state_label.modulate = Color(1, 0.7, 1, 1)
			btn.text = "En curso"
			btn.disabled = true
		&"available":
			card.modulate = Color(1, 0.95, 0.7, 1)
			state_label.text = "⚡ Lista"
			state_label.modulate = Color(1, 0.92, 0.45, 1)
			btn.text = "Investigar"
			var has_active: bool = ResearchManager.get_active() != null
			btn.disabled = has_active or InventoryManager.arcane_coins < r.coin_cost
			btn.pressed.connect(_on_start_pressed.bind(r))
		_:
			card.modulate = Color(0.65, 0.6, 0.75, 1)
			state_label.text = "🔒 Bloqueada"
			state_label.modulate = Color(0.55, 0.5, 0.65, 1)
			btn.text = "Falta prereq"
			btn.disabled = true
	return card


func _state_of(r: ResearchData) -> StringName:
	if ResearchManager.is_completed(r):
		return &"completed"
	if ResearchManager.get_active() == r:
		return &"active"
	# Prereqs cumplidos?
	for prereq in r.prerequisites:
		if not ResearchManager.is_completed(prereq):
			return &"locked"
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
			var mid_x: float = (from.x + to.x) * 0.5
			# Polyline con codo central — estilo de árbol clásico.
			var pts: PackedVector2Array = [
				from, Vector2(mid_x, from.y), Vector2(mid_x, to.y), to
			]
			var color: Color = Color(0.95, 0.78, 0.35, 0.9) if ResearchManager.is_completed(prereq) else Color(0.5, 0.4, 0.7, 0.6)
			_connections_node.draw_polyline(pts, color, 3.0, false)


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
