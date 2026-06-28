extends Node
## Dispara eventos periódicos que modifican el gameplay temporalmente.
## Cada evento tiene una probabilidad de aparecer y una duración.

signal event_started(event_id: StringName, label: String)
signal event_ended(event_id: StringName)

enum EventID {
	NONE,
	FESTIVAL_LUNAR,       # +50% coins durante 90s
	ECLIPSE_ARCANO,       # generadores -40% cooldown durante 60s
	INSPECCION_GREMIO,    # +rep por cada pedido completado en 60s
	ASALTO_BANDIDOS,      # Roba coins si no defiendes (auto-resuelve a favor del jugador por ahora)
	TORMENTA_ARCANA,      # Crafteo x2 velocidad durante 75s
}

const EVENT_DEFINITIONS: Dictionary = {
	EventID.FESTIVAL_LUNAR: {
		"id": &"festival_lunar",
		"label": "Festival Lunar",
		"description": "+50% coins por pedido durante 90s.",
		"duration": 90.0,
	},
	EventID.ECLIPSE_ARCANO: {
		"id": &"eclipse_arcano",
		"label": "Eclipse Arcano",
		"description": "Generadores producen 40% más rápido durante 60s.",
		"duration": 60.0,
	},
	EventID.INSPECCION_GREMIO: {
		"id": &"inspeccion_gremio",
		"label": "Inspección del Gremio",
		"description": "+3 reputación extra por pedido en 60s.",
		"duration": 60.0,
	},
	EventID.ASALTO_BANDIDOS: {
		"id": &"asalto_bandidos",
		"label": "¡Asalto de Bandidos!",
		"description": "Tus duendes defienden la tienda. Resultado en 15s.",
		"duration": 15.0,
	},
	EventID.TORMENTA_ARCANA: {
		"id": &"tormenta_arcana",
		"label": "Tormenta Arcana",
		"description": "Crafteo 2× más rápido durante 75s.",
		"duration": 75.0,
	},
}

@export var auto_run: bool = true
## Tiempo mínimo entre evento y el siguiente intento.
@export var event_interval_seconds: float = 90.0
## Probabilidad por intento de que arranque un evento (0-1).
@export var trigger_chance: float = 0.6

var _interval_timer: float = 0.0
var _active_event_id: int = EventID.NONE
var _active_remaining: float = 0.0


func _process(delta: float) -> void:
	if not auto_run:
		return
	if _active_event_id != EventID.NONE:
		_active_remaining -= delta
		if _active_remaining <= 0.0:
			_end_event()
		return
	_interval_timer += delta
	if _interval_timer >= event_interval_seconds:
		_interval_timer = 0.0
		if randf() < trigger_chance:
			_trigger_random_event()


func _trigger_random_event() -> void:
	var keys: Array = EVENT_DEFINITIONS.keys()
	var pick: int = keys.pick_random()
	_start_event(pick)


func _start_event(event_id: int) -> void:
	if not EVENT_DEFINITIONS.has(event_id):
		return
	var def: Dictionary = EVENT_DEFINITIONS[event_id]
	_active_event_id = event_id
	_active_remaining = def.duration
	_apply_event_modifiers(event_id, true)
	NotificationManager.post(def.label + " — " + def.description, NotificationManager.Kind.INFO)
	event_started.emit(def.id, def.label)
	print("[Event] Started: %s (%ds)" % [def.label, int(def.duration)])


func _end_event() -> void:
	if _active_event_id == EventID.NONE:
		return
	var def: Dictionary = EVENT_DEFINITIONS[_active_event_id]
	_apply_event_modifiers(_active_event_id, false)
	NotificationManager.post("Evento terminado: %s" % def.label, NotificationManager.Kind.INFO)
	event_ended.emit(def.id)
	print("[Event] Ended: %s" % def.label)
	_active_event_id = EventID.NONE
	_active_remaining = 0.0


func _apply_event_modifiers(event_id: int, on: bool) -> void:
	match event_id:
		EventID.FESTIVAL_LUNAR:
			# Aplica un multiplicador global a coin_reward cuando complete pedido.
			# Lo hacemos via señal interna: el HUD/OrderManager pueden consultar is_event_active.
			pass
		EventID.ECLIPSE_ARCANO:
			var mult: float = 0.6 if on else 1.0
			for gen in get_tree().get_nodes_in_group("generators"):
				if gen != null and "cooldown_multiplier" in gen:
					gen.set("_event_cooldown_factor", mult)
					# Reconstruimos cooldown efectivo manualmente
					gen.cooldown_multiplier = (gen.cooldown_multiplier) * (mult if on else 1.0 / 0.6)
		EventID.TORMENTA_ARCANA:
			var mult2: float = 0.5 if on else 1.0
			for ws in get_tree().get_nodes_in_group("workstations"):
				if ws != null and "crafting_time_multiplier" in ws:
					ws.crafting_time_multiplier = ws.crafting_time_multiplier * (mult2 if on else 1.0 / 0.5)
		EventID.ASALTO_BANDIDOS:
			if on:
				# Resolvemos automáticamente: 70% éxito si tienes >= 2 ayudantes
				var workers: int = get_tree().get_nodes_in_group("workers").size()
				var success: bool = workers >= 2 and randf() < 0.7
				if success:
					InventoryManager.add_reputation(2)
					NotificationManager.post("¡Bandidos repelidos! +2 reputación.", NotificationManager.Kind.SUCCESS)
				else:
					var lost: int = mini(40, InventoryManager.arcane_coins)
					InventoryManager.spend_coins(lost)
					NotificationManager.post("Bandidos robaron %d coins." % lost, NotificationManager.Kind.ALERT)
		EventID.INSPECCION_GREMIO:
			# Bonus de reputación se aplica desde OrderManager via consulta
			pass


func get_active_event_id() -> StringName:
	if _active_event_id == EventID.NONE:
		return &""
	return EVENT_DEFINITIONS[_active_event_id].id


func get_active_event_label() -> String:
	if _active_event_id == EventID.NONE:
		return ""
	return EVENT_DEFINITIONS[_active_event_id].label


func get_active_remaining() -> float:
	return _active_remaining


func has_active_modifier(id: StringName) -> bool:
	return get_active_event_id() == id


func get_coin_multiplier() -> float:
	return 1.5 if has_active_modifier(&"festival_lunar") else 1.0


func get_rep_bonus() -> int:
	return 3 if has_active_modifier(&"inspeccion_gremio") else 0


## Trigger manual para testing/cheat.
func debug_trigger(event_id: int) -> void:
	_start_event(event_id)


func get_save_state() -> Dictionary:
	return {
		"active_id": _active_event_id,
		"remaining": _active_remaining,
		"interval_timer": _interval_timer,
	}


func load_save_state(data: Dictionary) -> void:
	# Importante: NO re-ejecutamos _apply_event_modifiers(true). Los multipliers
	# (crafting_time_multiplier de stations, cooldown_multiplier de gens) ya están
	# en el save bajo Workstation.apply_state_dict / BuildManager. Re-aplicarlos
	# acá produciría doble-stack. Cuando el evento expire naturalmente, _end_event
	# llama _apply_event_modifiers(false) que los desaplica al estado base.
	_active_event_id = int(data.get("active_id", EventID.NONE))
	_active_remaining = float(data.get("remaining", 0.0))
	_interval_timer = float(data.get("interval_timer", 0.0))
	if _active_event_id != EventID.NONE and EVENT_DEFINITIONS.has(_active_event_id):
		# Re-emitimos event_started para que el HUD/notificaciones reflejen el estado.
		var def: Dictionary = EVENT_DEFINITIONS[_active_event_id]
		event_started.emit(def.id, def.label)
