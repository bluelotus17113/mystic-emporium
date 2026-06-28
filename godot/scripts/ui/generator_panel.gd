extends PanelContainer

const PANEL_NAME: StringName = &"generator"

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var level_label: Label = $Margin/VBox/Stats/LevelLabel
@onready var cooldown_label: Label = $Margin/VBox/Stats/CooldownLabel
@onready var yield_label: Label = $Margin/VBox/Stats/YieldLabel
@onready var upgrade_button: Button = $Margin/VBox/UpgradeRow/UpgradeButton
@onready var upgrade_cost_label: Label = $Margin/VBox/UpgradeRow/CostLabel

var active_generator = null
var _upgrade_handler: Callable = Callable()


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)


func on_generator_clicked(gen) -> void:
	active_generator = gen
	if not gen.upgraded.is_connected(_on_upgraded):
		gen.upgraded.connect(_on_upgraded)
	UIManager.open(PANEL_NAME)
	_rebuild()


func _rebuild() -> void:
	if active_generator == null:
		return
	title_label.text = "Generador"
	if active_generator.item_data != null:
		title_label.text += " · " + String(active_generator.item_data.display_name)
	level_label.text = "Nivel: %d / %d" % [active_generator.current_level, ResourceGenerator.MAX_LEVEL]
	var cd: float = active_generator.get_effective_cooldown()
	cooldown_label.text = "⏱ Cooldown: %.1fs" % cd
	yield_label.text = "📦 Yield: %d por cosecha" % active_generator.yield_per_node
	# Próximo upgrade: muestra el delta exacto que recibirá el jugador.
	if active_generator.current_level < ResourceGenerator.MAX_LEVEL:
		var next_cd: float = cd * ResourceGenerator.UPGRADE_COOLDOWN_REDUCTION
		var bonus_yield: bool = (active_generator.current_level + 1) == 3 or (active_generator.current_level + 1) == 5
		var preview: String = "→ %.1fs" % next_cd
		if bonus_yield:
			preview += "  +1 yield"
		upgrade_cost_label.text = "%d ⚜  %s" % [active_generator.upgrade_cost, preview]
		upgrade_button.text = "⬆ Mejorar a nivel %d" % (active_generator.current_level + 1)
		upgrade_button.disabled = false
	else:
		upgrade_cost_label.text = "MAX"
		upgrade_button.text = "Nivel máximo"
		upgrade_button.disabled = true
	if _upgrade_handler.is_valid() and upgrade_button.pressed.is_connected(_upgrade_handler):
		upgrade_button.pressed.disconnect(_upgrade_handler)
	_upgrade_handler = Callable(active_generator, "try_upgrade")
	upgrade_button.pressed.connect(_upgrade_handler)


func _on_upgraded(_level: int) -> void:
	if visible:
		_rebuild()
