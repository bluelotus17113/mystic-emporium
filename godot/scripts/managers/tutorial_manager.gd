extends Node
## Tutorial guiado build-first: el jugador empieza con una tienda casi vacía y
## el tutorial le hace COLOCAR sus primeros objetos (caldero, parcela) para
## enseñar el modo construcción, y luego recolectar → craftear → vender.
## Cada paso espera un evento (señal) para avanzar. tutorial_done se persiste;
## no vuelve a aparecer una vez completado o saltado.

signal step_started(step_index: int, title: String, message: String, hint: String)
signal step_progress(current: int, target: int)  ## avance dentro de un paso de conteo
signal tutorial_finished

## Estipendio inicial para poder pagar los primeros edificios del tutorial
## (caldero 80 + parcela 30 = 110). Solo se otorga en partida nueva.
const START_STIPEND: int = 100
const CAULDRON_ID: StringName = &"build_caldero"
const PARCEL_ID: StringName = &"build_generador_hierbas"

enum Step {
	WELCOME,         # bienvenida; usuario pulsa "Empezar"
	BUILD_CAULDRON,  # colocar el Caldero (enseña el modo construcción)
	BUILD_PARCEL,    # colocar una Parcela de Hierbas en el Patio Natural
	COLLECT_HERBS,   # esperar a tener 3+ Hierba Lunar (las recoge el Duende)
	CRAFT_POWDER,    # esperar a tener 1+ Polvo Lunar
	DELIVER,         # esperar a completar 1 pedido
	DONE
}

const TOTAL_STEPS: int = Step.DONE  # 6
const STEP_DATA: Array = [
	# title, message, hint
	["✨ Bienvenida/o al Emporio Místico", "Eres La Maga del Emporio. Tu tienda está casi vacía: vas a construirla tú misma/o, atender clientes y prosperar.", "Pulsa Empezar cuando estés lista/o."],
	["🔨 Construye tu Caldero", "Abre el menú Construir (B), elige el Caldero Alquímico y colócalo en la marca del Taller.", "Coloca 1 Caldero."],
	["🌿 Planta una Parcela de Hierbas", "Cruza al Patio Natural por el portal, abre Construir (B) y coloca la Parcela de Hierbas en la marca.", "Coloca 1 Parcela."],
	["🧺 Recolecta hierbas", "Tu Duende recogerá Hierbas Lunares de la parcela. Espera a tener suficientes.", "Consigue 3 Hierbas."],
	["⚗ Craftea en el Caldero", "Vuelve al Taller y haz clic en el Caldero para crear Polvo Lunar con tus hierbas.", "Crea 1 Polvo Lunar."],
	["📦 Atiende un cliente", "Cuando llegue un cliente al mostrador con un pedido que puedas cumplir, pulsa Entregar.", "Entrega 1 pedido."],
]

var current_step: int = -1
var active: bool = false
var tutorial_done: bool = false


func start() -> void:
	if tutorial_done:
		return
	# Estipendio para costear los primeros edificios (solo partida nueva).
	InventoryManager.add_coins(START_STIPEND)
	# Silenciar clientes hasta el paso de atender: nada de pedidos al azar
	# (ni imposibles) mientras el jugador aprende a construir/recolectar/craftear.
	OrderManager.auto_generate = false
	active = true
	current_step = Step.WELCOME
	_emit_current()


func skip() -> void:
	OrderManager.auto_generate = true  # reanudar clientes normales
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
	call_deferred("_auto_start")


func _auto_start() -> void:
	if tutorial_done or SaveManager.has_save():
		return
	start()


func _on_item_changed(item: ItemData, qty: int) -> void:
	if not active or item == null:
		return
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


func _on_placement_completed(b: BuildableData, _pos: Vector2) -> void:
	if not active or b == null:
		return
	if current_step == Step.BUILD_CAULDRON and b.id == CAULDRON_ID:
		_advance()
	elif current_step == Step.BUILD_PARCEL and b.id == PARCEL_ID:
		_advance()


func advance_welcome() -> void:
	if active and current_step == Step.WELCOME:
		_advance()


## Re-emite el paso actual. Lo usa el overlay al entrar en escena por si el
## tutorial ya arrancó (call_deferred) antes de que conectara la señal.
func emit_current_step() -> void:
	if active and current_step >= 0 and current_step < Step.DONE:
		_emit_current()


func _advance() -> void:
	current_step += 1
	if current_step >= Step.DONE:
		active = false
		tutorial_done = true
		OrderManager.auto_generate = true  # reanudar clientes normales al terminar
		tutorial_finished.emit()
		return
	# Al llegar al paso de atender: ahora sí llega UN cliente, y pide justo lo
	# que acabas de craftear (Polvo Lunar). "Oh, llegó un cliente, atendámoslo."
	if current_step == Step.DELIVER:
		OrderManager.generate_tutorial_order(&"polvo_lunar")
	_emit_current()


func _emit_current() -> void:
	var data: Array = STEP_DATA[current_step]
	step_started.emit(current_step, data[0], data[1], data[2])
