extends Node2D
## Flecha guía del tutorial: rebota sobre el objetivo del paso actual (caldero,
## mostrador, biblioteca, parcela de hierbas) para que un jugador nuevo sepa a
## dónde mirar. Se instala desde game_bootstrap. Escucha TutorialManager.
## Sin objetivo (bienvenida, construir → tecla B) queda invisible.

const BOB: float = 6.0            ## amplitud del rebote vertical (px)
const BOB_SPEED: float = 3.2
const Y_OFF: float = -52.0        ## altura de la flecha sobre el objetivo
const C_ARROW: Color = Color(0.55, 0.9, 0.98)   ## turquesa arcano
const C_GLOW: Color = Color(0.8, 0.65, 1.0)     ## halo lavanda

var _target: Node2D = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 100
	visible = false
	await get_tree().process_frame
	TutorialManager.step_started.connect(_on_step_started)
	TutorialManager.tutorial_finished.connect(_on_finished)
	if not TutorialManager.active:
		set_process(false)


func _on_step_started(step: int, _title: String, _msg: String, _hint: String) -> void:
	_target = _target_for_step(step)
	visible = _target != null
	set_process(true)


func _on_finished() -> void:
	_target = null
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		visible = false
		return
	_t += delta
	global_position = _target.global_position + Vector2(0.0, Y_OFF + sin(_t * BOB_SPEED) * BOB)
	queue_redraw()


## Nodo del mundo al que apuntar según el paso. null = sin flecha.
func _target_for_step(step: int) -> Node2D:
	match step:
		TutorialManager.Step.COLLECT_HERBS:
			return get_tree().get_first_node_in_group("resource_nodes") as Node2D
		TutorialManager.Step.CRAFT_POWDER:
			var caldrons: Array = WorkstationManager.get_by_type(GameEnums.StationType.CAULDRON)
			return caldrons[0] as Node2D if not caldrons.is_empty() else null
		TutorialManager.Step.DELIVER:
			return get_tree().get_first_node_in_group("customer_counter") as Node2D
		TutorialManager.Step.RESEARCH:
			return get_tree().get_first_node_in_group("research_stations") as Node2D
	return null


func _draw() -> void:
	var pulse: float = 0.75 + 0.25 * sin(_t * BOB_SPEED * 1.3)
	# Halo suave detrás.
	draw_circle(Vector2(0.0, 6.0), 13.0, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, 0.18 * pulse))
	# Flecha apuntando hacia abajo (al objetivo).
	var tip: Vector2 = Vector2(0.0, 12.0)
	var pts: PackedVector2Array = [
		Vector2(-9.0, -2.0), Vector2(9.0, -2.0), tip,
	]
	draw_colored_polygon(pts, Color(C_ARROW.r, C_ARROW.g, C_ARROW.b, 0.95 * pulse))
	# Astil.
	draw_rect(Rect2(-3.5, -14.0, 7.0, 12.0), Color(C_ARROW.r, C_ARROW.g, C_ARROW.b, 0.95 * pulse))
	# Brillo en la punta.
	draw_circle(tip, 2.2, Color(1.0, 1.0, 1.0, 0.7 * pulse))
