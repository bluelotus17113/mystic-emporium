extends CanvasLayer
## Panel cozy del tutorial. Aparece arriba-centro con título, mensaje y pista del paso.

@onready var panel: PanelContainer = $Panel
@onready var step_label: Label = $Panel/Margin/VBox/Header/StepLabel
@onready var skip_button: Button = $Panel/Margin/VBox/Header/SkipButton
@onready var progress: ProgressBar = $Panel/Margin/VBox/Progress
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel
@onready var start_button: Button = $Panel/Margin/VBox/ButtonRow/StartButton

var _base_hint: String = ""


func _ready() -> void:
	TutorialManager.step_started.connect(_on_step_started)
	TutorialManager.step_progress.connect(_on_step_progress)
	TutorialManager.tutorial_finished.connect(_on_finished)
	skip_button.pressed.connect(TutorialManager.skip)
	start_button.pressed.connect(TutorialManager.advance_welcome)
	progress.max_value = TutorialManager.TOTAL_STEPS
	if not TutorialManager.active:
		hide()


func _on_step_started(step: int, title: String, message: String, hint: String) -> void:
	step_label.text = "Paso %d de %d" % [step + 1, TutorialManager.TOTAL_STEPS]
	progress.value = step + 1
	title_label.text = title
	message_label.text = message
	_base_hint = hint
	hint_label.text = "→ " + hint
	start_button.visible = (step == TutorialManager.Step.WELCOME)
	panel.show()
	show()
	_bounce_in()


## Progreso en vivo del paso actual: el hint pasa a "→ pista  (2/3)".
func _on_step_progress(current: int, target: int) -> void:
	hint_label.text = "→ %s  (%d/%d)" % [_base_hint, current, target]


func _bounce_in() -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)


func _on_finished() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(hide)
