extends PanelContainer

const PANEL_NAME: StringName = &"achievements"

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var summary_label: Label = $Margin/VBox/Header/Title
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid


var _card_refs: Array = []  ## [(panel, title, progress, progress_label), ...] mismo orden que ACHIEVEMENTS
var _refresh_accum: float = 0.0


var _needs_rebuild: bool = false

func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	# ponytail: solo reconstruimos cuando el panel se abre. Si se desbloquea un logro
	# con el panel oculto, marcamos _needs_rebuild y se aplica al abrir.
	StatsManager.achievement_unlocked.connect(func(_id, _l): _needs_rebuild = true)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild()


func _on_visibility_changed() -> void:
	if visible and _needs_rebuild:
		_needs_rebuild = false
		_rebuild()


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_accum += _delta
	if _refresh_accum < 0.5:
		return
	_refresh_accum = 0.0
	_refresh_cards_in_place()


func _refresh_cards_in_place() -> void:
	# Actualiza progress + counter de cada card sin destruir nodos.
	for i in min(_card_refs.size(), StatsManager.ACHIEVEMENTS.size()):
		var ach: Dictionary = StatsManager.ACHIEVEMENTS[i]
		var ref: Dictionary = _card_refs[i]
		var current: int = StatsManager.get_stat(ach.stat)
		var threshold: int = int(ach.threshold)
		ref.progress.value = min(current, threshold)
		ref.progress_label.text = "%d / %d" % [min(current, threshold), threshold]


func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	_card_refs.clear()
	var total: int = StatsManager.ACHIEVEMENTS.size()
	var unlocked: int = StatsManager.get_unlocked_achievements().size()
	summary_label.text = "🏆 Logros · %d / %d" % [unlocked, total]
	for ach in StatsManager.ACHIEVEMENTS:
		grid.add_child(_make_card(ach))


func _make_card(ach: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 76)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	card.add_child(v)

	var is_unlocked: bool = StatsManager.is_achievement_unlocked(ach.id)
	var title := Label.new()
	title.text = ("✅ " if is_unlocked else "🔒 ") + ach.label
	title.add_theme_font_size_override(&"font_size", 12)
	title.modulate = Color(1, 0.92, 0.55, 1) if is_unlocked else Color(0.7, 0.7, 0.8, 1)
	v.add_child(title)

	var current: int = StatsManager.get_stat(ach.stat)
	var threshold: int = int(ach.threshold)
	var progress := ProgressBar.new()
	progress.max_value = threshold
	progress.value = min(current, threshold)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 8)
	v.add_child(progress)

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(info_row)

	var progress_label := Label.new()
	progress_label.text = "%d / %d" % [min(current, threshold), threshold]
	progress_label.add_theme_font_size_override(&"font_size", 10)
	progress_label.modulate = Color(0.85, 0.85, 0.95, 1)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(progress_label)

	var reward_label := Label.new()
	var coins: int = ach.get("coins", 0)
	var stars: int = ach.get("stars", 0)
	var bits: PackedStringArray = []
	if coins > 0: bits.append("%d⚜" % coins)
	if stars > 0: bits.append("%d★" % stars)
	reward_label.text = " · ".join(bits) if not bits.is_empty() else ""
	reward_label.add_theme_font_size_override(&"font_size", 10)
	reward_label.modulate = Color(1, 0.85, 0.4, 1) if is_unlocked else Color(0.7, 0.6, 0.4, 1)
	info_row.add_child(reward_label)

	_card_refs.append({
		"card": card, "title": title, "progress": progress, "progress_label": progress_label
	})
	return card
