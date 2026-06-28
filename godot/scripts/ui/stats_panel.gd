extends PanelContainer
## Panel con estadísticas globales y logros desbloqueados.

const PANEL_NAME: StringName = &"stats"

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var stats_list: VBoxContainer = $Margin/VBox/Tabs/Stats/StatsList
@onready var ach_list: VBoxContainer = $Margin/VBox/Tabs/Achievements/AchList

const PRETTY_NAMES: Dictionary = {
	"items_collected_total": "Items recolectados",
	"items_crafted_total": "Items crafteados",
	"coins_earned_total": "Coins ganados",
	"coins_spent_total": "Coins gastados",
	"orders_completed": "Pedidos completados",
	"orders_expired": "Pedidos perdidos",
	"buildings_placed": "Edificios construidos",
	"upgrades_done": "Mejoras aplicadas",
	"research_completed": "Investigaciones completadas",
	"workers_hired": "Ayudantes contratados",
	"events_survived": "Eventos sobrevividos",
	"playtime_seconds": "Tiempo jugado",
}


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	visibility_changed.connect(_on_visibility_changed)
	StatsManager.stat_changed.connect(_on_stat_changed)
	StatsManager.achievement_unlocked.connect(_on_ach_unlocked)


func _on_visibility_changed() -> void:
	if visible:
		_rebuild()


func _on_stat_changed(_id: StringName, _val: int) -> void:
	if visible:
		_rebuild_stats()


func _on_ach_unlocked(_id: StringName, _label: String) -> void:
	if visible:
		_rebuild_achievements()


func _rebuild() -> void:
	_rebuild_stats()
	_rebuild_achievements()


func _rebuild_stats() -> void:
	for child in stats_list.get_children():
		child.queue_free()
	for key in StatsManager.stats.keys():
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = PRETTY_NAMES.get(key, key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value_label := Label.new()
		if key == "playtime_seconds":
			value_label.text = _format_duration(StatsManager.get_stat(key))
		else:
			value_label.text = str(StatsManager.get_stat(key))
		value_label.modulate = Color(1, 0.9, 0.5, 1)
		row.add_child(value_label)
		stats_list.add_child(row)


func _rebuild_achievements() -> void:
	for child in ach_list.get_children():
		child.queue_free()
	for ach in StatsManager.ACHIEVEMENTS:
		var unlocked: bool = StatsManager.is_achievement_unlocked(ach.id)
		var row := HBoxContainer.new()
		var icon := Label.new()
		icon.text = "🏆" if unlocked else "·"
		icon.modulate = Color(1, 0.85, 0.3, 1) if unlocked else Color(0.5, 0.5, 0.5, 1)
		row.add_child(icon)
		var label := Label.new()
		label.text = ach.label
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not unlocked:
			label.modulate = Color(0.6, 0.6, 0.6, 1)
		row.add_child(label)
		var progress := Label.new()
		var current: int = StatsManager.get_stat(ach.stat)
		var th: int = ach.threshold
		progress.text = "%d / %d" % [min(current, th), th]
		progress.modulate = Color(0.7, 0.85, 1, 1) if unlocked else Color(0.55, 0.55, 0.55, 1)
		row.add_child(progress)
		ach_list.add_child(row)


func _format_duration(seconds: int) -> String:
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	var s: int = seconds % 60
	return "%dh %02dm %02ds" % [h, m, s]
