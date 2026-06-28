extends PanelContainer

const PANEL_NAME: StringName = &"pomodoro"
const WORK_SECONDS: float = 25.0 * 60.0
const SHORT_BREAK: float = 5.0 * 60.0
const LONG_BREAK: float = 15.0 * 60.0

enum Phase { IDLE, WORK, SHORT_REST, LONG_REST }

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var phase_label: Label = $Margin/VBox/PhaseLabel
@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var start_button: Button = $Margin/VBox/Buttons/StartButton
@onready var reset_button: Button = $Margin/VBox/Buttons/ResetButton
@onready var cycles_label: Label = $Margin/VBox/CyclesLabel

var phase: int = Phase.IDLE
var remaining: float = WORK_SECONDS
var running: bool = false
var cycles_completed: int = 0


func _ready() -> void:
	var standalone: bool = "--pomodoro" in OS.get_cmdline_user_args()
	if standalone:
		close_button.pressed.connect(func(): get_tree().quit())
		get_tree().get_root().close_requested.connect(func(): get_tree().quit())
	else:
		UIManager.register_panel(PANEL_NAME, self)
		close_button.pressed.connect(UIManager.close_active)
	start_button.pressed.connect(_toggle_start)
	reset_button.pressed.connect(_reset)
	_refresh()


func _process(delta: float) -> void:
	if not running:
		return
	remaining -= delta
	if remaining <= 0.0:
		_complete_phase()
	_refresh()


func _toggle_start() -> void:
	if phase == Phase.IDLE:
		phase = Phase.WORK
		remaining = WORK_SECONDS
	running = not running
	_refresh()


func _reset() -> void:
	running = false
	phase = Phase.IDLE
	remaining = WORK_SECONDS
	cycles_completed = 0
	_refresh()


func _complete_phase() -> void:
	running = false
	AudioManager.play_beep(880.0, 0.18, -8.0)
	if phase == Phase.WORK:
		cycles_completed += 1
		if cycles_completed % 4 == 0:
			phase = Phase.LONG_REST
			remaining = LONG_BREAK
		else:
			phase = Phase.SHORT_REST
			remaining = SHORT_BREAK
	else:
		phase = Phase.WORK
		remaining = WORK_SECONDS
	_refresh()


func _refresh() -> void:
	phase_label.text = _phase_text()
	var minutes: int = int(remaining) / 60
	var seconds: int = int(remaining) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	start_button.text = "Pausar" if running else ("Continuar" if phase != Phase.IDLE else "Iniciar")
	cycles_label.text = "Ciclos completados: %d" % cycles_completed


func _phase_text() -> String:
	match phase:
		Phase.WORK: return "💪 Trabajo"
		Phase.SHORT_REST: return "☕ Descanso corto"
		Phase.LONG_REST: return "🌿 Descanso largo"
		_: return "🍅 Pomodoro"
