extends Node
## Single-panel orchestrator. Scenes register their popup panels here at _ready
## y piden a UIManager open/close, asegurando que solo uno esté visible a la vez.
## También centraliza animaciones cozy (fade + scale) y sonidos suaves de transición.

signal panel_opened(panel_name: StringName)
signal panel_closed(panel_name: StringName)

const ANIM_OPEN_DURATION: float = 0.34
const ANIM_CLOSE_DURATION: float = 0.18
const ANIM_FADE_DURATION: float = 0.22

var _panels: Dictionary = {}  # name -> Control
var _active_panel_name: StringName = &""
var _tweens: Dictionary = {}  # Control -> Tween (para matar el anterior si reabres rápido)


func register_panel(panel_name: StringName, panel: Control) -> void:
	if panel == null:
		return
	_panels[panel_name] = panel
	panel.hide()


func unregister_panel(panel_name: StringName) -> void:
	if _active_panel_name == panel_name:
		_active_panel_name = &""
	_panels.erase(panel_name)


func toggle(panel_name: StringName) -> void:
	if _active_panel_name == panel_name:
		close_active()
		return
	open(panel_name)


func open(panel_name: StringName) -> void:
	if not _panels.has(panel_name):
		push_warning("[UI] Unknown panel: %s" % panel_name)
		return
	close_active()
	var p: Control = _panels[panel_name]
	animate_open(p)
	_active_panel_name = panel_name
	AudioManager.play_named(&"menu_select")
	panel_opened.emit(panel_name)


func close_active() -> void:
	if _active_panel_name == &"":
		return
	var p: Control = _panels.get(_active_panel_name)
	if p != null:
		animate_close(p)
	var was: StringName = _active_panel_name
	_active_panel_name = &""
	AudioManager.play_soft(420.0, 0.14, -24.0)
	panel_closed.emit(was)


func is_open(panel_name: StringName) -> bool:
	return _active_panel_name == panel_name


func get_active_panel_name() -> StringName:
	return _active_panel_name


## ---------- Animaciones cozy reutilizables ----------

func animate_open(target: Control) -> void:
	# Cozy pop-in: fade + scale con overshoot tipo "back" + slight y-offset que se asienta.
	_kill_tween(target)
	target.show()
	target.modulate = Color(1, 1, 1, 0)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2(0.85, 0.85)
	# Capturamos la posición original y arrancamos 8 px más arriba para "caer".
	var orig_pos: Vector2 = target.position
	target.position = orig_pos + Vector2(0, -8)
	var tw := create_tween().set_parallel(true)
	# Scale con BACK out (rebote suave al 100%)
	tw.tween_property(target, "scale", Vector2.ONE, ANIM_OPEN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fade rápido y elegante
	tw.tween_property(target, "modulate:a", 1.0, ANIM_FADE_DURATION) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Drop position al lugar original con easing suave
	tw.tween_property(target, "position", orig_pos, ANIM_OPEN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens[target] = tw


func animate_close(target: Control) -> void:
	_kill_tween(target)
	target.pivot_offset = target.size * 0.5
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(target, "modulate:a", 0.0, ANIM_CLOSE_DURATION)
	tw.tween_property(target, "scale", Vector2(0.92, 0.92), ANIM_CLOSE_DURATION)
	tw.chain().tween_callback(func(): if is_instance_valid(target): target.hide())
	_tweens[target] = tw


func _kill_tween(target: Control) -> void:
	if _tweens.has(target):
		var old: Tween = _tweens[target]
		if old != null and old.is_valid():
			old.kill()
		_tweens.erase(target)
