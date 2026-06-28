extends PanelContainer

const PANEL_NAME: StringName = &"settings"

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var music_slider: HSlider = $Margin/VBox/MusicRow/MusicSlider
@onready var music_value: Label = $Margin/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Margin/VBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $Margin/VBox/SFXRow/SFXValue
@onready var save_button: Button = $Margin/VBox/Buttons/SaveButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var auto_craft_check: CheckBox = $Margin/VBox/AutoCraftCheck
@onready var auto_research_check: CheckBox = $Margin/VBox/AutoResearchCheck
@onready var auto_upgrade_check: CheckBox = $Margin/VBox/AutoUpgradeCheck
@onready var auto_buy_workers_check: CheckBox = $Margin/VBox/AutoBuyWorkersCheck
@onready var prestige_info: Label = $Margin/VBox/PrestigeInfo
@onready var prestige_button: Button = $Margin/VBox/PrestigeButton


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	save_button.pressed.connect(_on_save_pressed)
	prestige_button.pressed.connect(_on_prestige_pressed)
	visibility_changed.connect(_sync_volume_sliders)
	PrestigeManager.stars_changed.connect(func(_n): _refresh_prestige())
	PrestigeManager.prestige_done.connect(func(_g, _t): _refresh_prestige())
	InventoryManager.reputation_changed.connect(func(_r): _refresh_prestige())
	_init_idle_toggles()
	_refresh_prestige()
	_sync_volume_sliders()


func _sync_volume_sliders() -> void:
	# Re-leer del AudioManager cada vez que abrimos — refleja el valor cargado del save.
	music_slider.set_value_no_signal(_db_to_linear(AudioManager.music_master_volume_db))
	sfx_slider.set_value_no_signal(_db_to_linear(AudioManager.sfx_master_volume_db))
	music_value.text = "%d%%" % int(music_slider.value * 100)
	sfx_value.text = "%d%%" % int(sfx_slider.value * 100)


func _refresh_prestige() -> void:
	var bonus_pct: int = int((PrestigeManager.get_coin_multiplier() - 1.0) * 100)
	prestige_info.text = "Estrellas: %d · Bonus coins: +%d%% · Prestigios: %d" % [
		PrestigeManager.stars, bonus_pct, PrestigeManager.prestige_count
	]
	if PrestigeManager.can_prestige():
		var gain: int = PrestigeManager.preview_stars_gain()
		prestige_button.text = "Prestigiar (+%d ★)" % gain
		prestige_button.disabled = false
	else:
		prestige_button.text = "Prestigiar (necesitas %d rep)" % PrestigeManager.PRESTIGE_MIN_REPUTATION
		prestige_button.disabled = true


func _on_prestige_pressed() -> void:
	if not PrestigeManager.can_prestige():
		return
	# ponytail: ConfirmationDialog inline. Sin scene file extra.
	var gain: int = PrestigeManager.preview_stars_gain()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirmar Prestigio"
	dialog.dialog_text = (
		"Vas a resetear:\n" +
		"  • Coins, items, inventario\n" +
		"  • Edificios construidos\n" +
		"  • Recetas y research desbloqueados\n" +
		"  • Patio Natural vuelve a Pequeño\n\n" +
		"Vas a ganar:\n" +
		"  • +%d Estrellas permanentes ✨\n" +
		"  • Total: %d ★ (bonus +%d%% coins)\n\n" +
		"¿Continuar?"
	) % [gain, PrestigeManager.stars + gain, int((PrestigeManager.stars + gain) * 5.0)]
	dialog.ok_button_text = "Prestigiar"
	dialog.cancel_button_text = "Cancelar"
	add_child(dialog)
	dialog.confirmed.connect(_do_prestige_confirmed.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _do_prestige_confirmed(dialog: Window) -> void:
	if PrestigeManager.do_prestige():
		status_label.text = "✨ Prestigio realizado."
	dialog.queue_free()


func _init_idle_toggles() -> void:
	auto_craft_check.button_pressed = IdleAutomationManager.get_auto(&"craft")
	auto_research_check.button_pressed = IdleAutomationManager.get_auto(&"research")
	auto_upgrade_check.button_pressed = IdleAutomationManager.get_auto(&"upgrade")
	auto_buy_workers_check.button_pressed = IdleAutomationManager.get_auto(&"buy_workers")
	auto_craft_check.toggled.connect(func(on): IdleAutomationManager.set_auto(&"craft", on))
	auto_research_check.toggled.connect(func(on): IdleAutomationManager.set_auto(&"research", on))
	auto_upgrade_check.toggled.connect(func(on): IdleAutomationManager.set_auto(&"upgrade", on))
	auto_buy_workers_check.toggled.connect(func(on): IdleAutomationManager.set_auto(&"buy_workers", on))


func _on_music_changed(value: float) -> void:
	music_value.text = "%d%%" % int(value * 100)
	AudioManager.set_music_volume_db(_linear_to_db(value))


func _on_sfx_changed(value: float) -> void:
	sfx_value.text = "%d%%" % int(value * 100)
	AudioManager.set_sfx_volume_db(_linear_to_db(value))
	AudioManager.play_beep(660.0, 0.05, -12.0)


func _on_save_pressed() -> void:
	SaveManager.save_game()
	status_label.text = "Partida guardada ✓"


func _linear_to_db(linear: float) -> float:
	if linear <= 0.001:
		return -60.0
	return 20.0 * log(linear) / log(10.0)


func _db_to_linear(db: float) -> float:
	return pow(10.0, db / 20.0)
