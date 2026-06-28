extends Node
## Notificaciones centralizadas.
## Filosofía actual: TODAS las notifs van a un log persistente (visible en el
## panel de Pedidos → sección Diario). SOLO las críticas (Kind.ALERT) se emiten
## como toast pop-up. Esto evita el congelamiento por cascadas de logros + orders
## + quests que disparaban 5 panels + audios + tweens en el mismo frame.

signal notification_posted(text: String, kind: int)  ## SOLO para ALERT (toast crítico)
signal log_appended(entry: Dictionary)               ## SIEMPRE: panel Diario escucha esto

enum Kind { INFO, SUCCESS, WARNING, ALERT, REWARD }

const COOLDOWN_SECONDS: float = 2.5
const EMIT_INTERVAL: float = 1.0   ## espacio entre toasts críticos (siguen rate-limitados)
const MAX_QUEUE_SIZE: int = 8      ## queue de ALERTS pendientes para toast
const LOG_LIMIT: int = 80          ## entradas del log persistente (panel Diario)

var _recent: Dictionary = {}  # text -> timestamp
var _queue: Array = []        # solo entries Kind.ALERT
var _log: Array = []          # todo el feed cronológico (recientes al frente)
var _last_emit_t: float = 0.0


func post(text: String, kind: int = Kind.INFO) -> void:
	if text.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = _recent.get(text, -1e9)
	if now - last < COOLDOWN_SECONDS:
		return
	_recent[text] = now
	var entry := {"text": text, "kind": kind, "ts": now}
	# 1) Log persistente: SIEMPRE acumula (con cap).
	_log.push_front(entry)
	while _log.size() > LOG_LIMIT:
		_log.pop_back()
	log_appended.emit(entry)
	# 2) Toast: solo si es crítico (ALERT). El resto se queda en el log.
	if kind == Kind.ALERT:
		_queue.append(entry)
		while _queue.size() > MAX_QUEUE_SIZE:
			_queue.pop_front()


func get_log() -> Array:
	return _log.duplicate()


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _queue.is_empty() and now - _last_emit_t >= EMIT_INTERVAL:
		var item: Dictionary = _queue.pop_front()
		notification_posted.emit(item.text, item.kind)
		_last_emit_t = now
	# Limpiar entradas viejas del _recent para no acumular memoria.
	if _recent.size() > 64:
		var to_delete: Array = []
		for k in _recent:
			if now - _recent[k] > COOLDOWN_SECONDS * 4:
				to_delete.append(k)
		for k in to_delete:
			_recent.erase(k)


func _ready() -> void:
	# Defer connections so all AutoLoads finish booting first.
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	OrderManager.order_generated.connect(_on_order_generated)
	OrderManager.order_completed.connect(_on_order_completed)
	ResearchManager.research_completed.connect(_on_research_completed)
	BuildManager.buildable_unlocked.connect(_on_buildable_unlocked)
	InventoryManager.inventory_full.connect(_on_inventory_full)
	ShopManager.worker_purchased.connect(_on_worker_purchased)


func _on_order_generated(order: OrderData) -> void:
	if order == null or order.requested_item == null:
		return
	post("Nuevo pedido: %d × %s" % [order.requested_quantity, order.requested_item.display_name], Kind.INFO)


func _on_order_completed(order: OrderData) -> void:
	if order == null:
		return
	post("+%d ⚜  Pedido entregado" % order.coin_reward, Kind.REWARD)


func _on_research_completed(r: ResearchData) -> void:
	if r != null:
		post("Investigación completada: %s" % r.display_name, Kind.SUCCESS)


func _on_buildable_unlocked(b: BuildableData) -> void:
	if b != null:
		post("Desbloqueado: %s" % b.display_name, Kind.SUCCESS)


func _on_inventory_full(item: ItemData) -> void:
	var name_str: String = item.display_name if item != null else "—"
	post("Inventario lleno (%s)" % name_str, Kind.WARNING)


func _on_worker_purchased(_t: int, _i) -> void:
	post("Nuevo ayudante contratado", Kind.SUCCESS)
