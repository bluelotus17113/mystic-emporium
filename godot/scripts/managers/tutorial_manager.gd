extends Node
## Tutorial guiado con pasos. Cada paso espera un evento (señal) para avanzar.
## tutorial_done se persiste en el save; no vuelve a aparecer una vez completado o saltado.

signal step_started(step_index: int, title: String, message: String, hint: String)
signal step_progress(current: int, target: int)  ## avance dentro de un paso de conteo
signal tutorial_finished

enum Step {
	WELCOME,         # mostrar bienvenida; usuario pulsa "Empezar"
	COLLECT_HERBS,   # esperar a tener 3+ Hierba Lunar
	CRAFT_POWDER,    # esperar a tener 1+ Polvo Lunar
	DELIVER,         # esperar a completar 1 pedido
	BUILD,           # esperar a colocar un edificio
	RESEARCH,        # esperar a iniciar una investigación
	DONE
}

const TOTAL_STEPS: int = Step.DONE  # 6
const STEP_DATA: Array = [
	# title, message, hint
	["✨ Bienvenida/o al Emporio Místico", "Eres La Maga del Emporio. Tu objetivo: atender clientes, automatizar producción y prosperar.", "Pulsa Empezar cuando estés lista/o."],
	["🌿 Recolecta hierbas", "Los Duendes recogen Hierbas Lunares en las parcelas del Patio Natural.", "Espera a tener 3 hierbas."],
	["⚗ Craftea en el Caldero", "Haz clic en el Caldero del Taller para crear Polvo Lunar con tus hierbas.", "Crea 1 Polvo Lunar."],
	["📦 Atiende un cliente", "Cuando llegue un cliente al mostrador con un pedido que puedas cumplir, pulsa Entregar.", "Entrega 1 pedido."],
	["🔨 Construye algo nuevo", "Abre el menú Construir (B) y coloca una decoración o un edificio.", "Coloca 1 ítem."],
	["📜 Investiga", "Haz clic en la Biblioteca Arcana e inicia una investigación para desbloquear recetas.", "Inicia 1 investigación."],
]

var current_step: int = -1
var active: bool = false
var tutorial_done: bool = false
var _hierba_item: ItemData = null
var _polvo_item: ItemData = null


func start() -> void:
	if tutorial_done:
		return
	active = true
	current_step = Step.WELCOME
	_emit_current()


func skip() -> void:
	active = false
	current_step = Step.DONE
	tutorial_done = true
	tutorial_finished.emit()


func get_save_state() -> Dictionary:
	return {"tutorial_done": tutorial_done}


func load_save_state(data: Dictionary) -> void:
	tutorial_done = bool(data.get("tutorial_done", false))


func _ready() -> void:
	InventoryManager.item_changed.connect(_on_item_changed)
	OrderManager.order_completed.connect(_on_order_completed)
	BuildManager.placement_completed.connect(_on_placement_completed)
	ResearchManager.research_started.connect(_on_research_started)
	call_deferred("_auto_start")


func _auto_start() -> void:
	if tutorial_done or SaveManager.has_save():
		return
	start()


func _on_item_changed(item: ItemData, qty: int) -> void:
	if not active or item == null:
		return
	if item.id == &"hierba_lunar":
		_hierba_item = item
	elif item.id == &"polvo_lunar":
		_polvo_item = item
	if current_step == Step.COLLECT_HERBS and item.id == &"hierba_lunar":
		step_progress.emit(mini(qty, 3), 3)
		if qty >= 3:
			_advance()
	elif current_step == Step.CRAFT_POWDER and item.id == &"polvo_lunar":
		step_progress.emit(mini(qty, 1), 1)
		if qty >= 1:
			_advance()


func _on_order_completed(_o: OrderData) -> void:
	if active and current_step == Step.DELIVER:
		_advance()


func _on_placement_completed(_b: BuildableData, _pos: Vector2) -> void:
	if active and current_step == Step.BUILD:
		_advance()


func _on_research_started(_r: ResearchData) -> void:
	if active and current_step == Step.RESEARCH:
		_advance()


func advance_welcome() -> void:
	if active and current_step == Step.WELCOME:
		_advance()


func _advance() -> void:
	current_step += 1
	if current_step >= Step.DONE:
		active = false
		tutorial_done = true
		tutorial_finished.emit()
		return
	_emit_current()


func _emit_current() -> void:
	var data: Array = STEP_DATA[current_step]
	step_started.emit(current_step, data[0], data[1], data[2])
