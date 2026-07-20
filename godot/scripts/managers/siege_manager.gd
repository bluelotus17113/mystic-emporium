extends Node
## Orquesta el minijuego de Asedio (opt-in): una oleada de ogros entra por la
## izquierda del Patio Natural y avanza hacia el cultivo (la base). El jugador lo
## defiende con torretas (y luego workers/protagonista). Ganar da recompensa;
## perder, una penalización leve. No es persistente: empieza y termina.

signal siege_started
signal siege_ended(won: bool)
signal base_hp_changed(hp: float, max_hp: float)

enum State { IDLE, ACTIVE }

signal wave_changed(wave: int, total: int)
signal prep_tick(seconds_left: int)

const PREP_SECONDS: float = 8.0  ## aviso previo para colocar defensas de última hora
const BASE_MAX_HP: float = 260.0
const WAVE_SIZE: int = 6
const TOTAL_WAVES: int = 3
const BREAK_SECONDS: float = 6.0
## Cuánto a la izquierda (fuera de la pradera usable) aparecen los ogros, para
## verlos venir desde lejos con un trayecto largo. Limitado al borde del mapa.
const APPROACH_MARGIN: float = 1200.0

var state: int = State.IDLE
var base_position: Vector2 = Vector2.ZERO
var _to_spawn: int = 0
var _spawn_cd: float = 0.0
var _alive: int = 0
var _wave: int = 0
var _prep_cd: float = 0.0
var _in_break: bool = false
var _break_cd: float = 0.0
var _wave_hp: float = 60.0
var _wave_dmg: float = 8.0
var _wave_reward: int = 12
var _diff: float = 1.0        ## multiplicador de dificultad (rep + nivel natural)
var _total_waves: int = TOTAL_WAVES
var _base_hp_max: float = BASE_MAX_HP
var _base_node: Node2D = null
var _base_bar: HealthBar = null


## Escala la dificultad con la progresión: reputación y nivel del Patio Natural.
func _compute_difficulty() -> void:
	var rep_tier: float = float(InventoryManager.reputation) / 20.0
	var lvl: int = ZoneExpansionManager.natural_level
	_diff = 1.0 + rep_tier * 0.15 + float(lvl) * 0.10
	_total_waves = clampi(TOTAL_WAVES + int((rep_tier + float(lvl)) / 3.0), TOTAL_WAVES, 6)
	_base_hp_max = BASE_MAX_HP * (1.0 + float(lvl) * 0.10)


func get_difficulty() -> float:
	return _diff


func current_wave() -> int:
	return _wave


func total_waves() -> int:
	return _total_waves


## Ogros que faltan por aparecer + los que siguen vivos.
func enemies_left() -> int:
	return _to_spawn + _alive


func is_active() -> bool:
	return state == State.ACTIVE


func can_start() -> bool:
	return state == State.IDLE and _natural_rect().size != Vector2.ZERO


func request_start() -> bool:
	if state == State.ACTIVE:
		NotificationManager.post("Ya hay un asedio en curso.", NotificationManager.Kind.INFO)
		return false
	if not can_start():
		NotificationManager.post("No se puede iniciar el asedio ahora.", NotificationManager.Kind.INFO)
		return false
	_start()
	return true


func _start() -> void:
	_compute_difficulty()
	var rect: Rect2 = _natural_rect()
	base_position = Vector2(rect.end.x - 90.0, rect.get_center().y)
	_wave = 0
	_alive = 0
	_in_break = false
	_prep_cd = PREP_SECONDS
	state = State.ACTIVE
	_spawn_base()
	siege_started.emit()
	base_hp_changed.emit(_base_hp_max, _base_hp_max)
	AudioManager.play_named(&"siege_horn")
	NotificationManager.post("🏰 ¡ASEDIO! Prepara tus defensas… los ogros se acercan.", NotificationManager.Kind.ALERT)


## Prepara la siguiente oleada: más grande y más dura que la anterior.
func _next_wave() -> void:
	_wave += 1
	_to_spawn = WAVE_SIZE + (_wave - 1) * 2 + int((_diff - 1.0) * 4.0)
	_spawn_cd = 0.6
	_wave_hp = (50.0 + float(_wave - 1) * 22.0) * _diff
	_wave_dmg = (7.0 + float(_wave - 1) * 2.0) * _diff
	_wave_reward = int(float(10 + _wave * 4) * _diff)
	wave_changed.emit(_wave, _total_waves)
	AudioManager.play_named(&"wave_alarm")
	NotificationManager.post("🌊 Oleada %d/%d — ¡%d ogros!" % [_wave, _total_waves, _to_spawn], NotificationManager.Kind.ALERT)


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	if _prep_cd > 0.0:
		_prep_cd -= delta
		prep_tick.emit(int(ceil(_prep_cd)))
		if _prep_cd <= 0.0:
			_next_wave()
		return
	if _in_break:
		_break_cd -= delta
		if _break_cd <= 0.0:
			_in_break = false
			_next_wave()
		return
	if _to_spawn > 0:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = randf_range(0.9, 2.1)
			_spawn_ogre()
	elif _alive <= 0:
		# Oleada despejada: ¿siguiente o victoria?
		if _wave >= _total_waves:
			_end(true)
		else:
			_in_break = true
			_break_cd = BREAK_SECONDS
			NotificationManager.post("✔ Oleada repelida. Prepárate para la siguiente…", NotificationManager.Kind.INFO)


func _spawn_ogre() -> void:
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		return
	var rect: Rect2 = _natural_rect()
	# Aparecen lejos, a la izquierda (hacia el borde del mapa), y se ven venir.
	var map: Rect2 = ZoneExpansionManager.map_rect()
	var spawn_x: float = maxf(map.position.x + 30.0, rect.position.x - APPROACH_MARGIN) - randf_range(0.0, 160.0)
	var e := SiegeEnemy.new()
	e.add_to_group("natural_visual")
	world.add_child(e)
	e.global_position = Vector2(
		spawn_x,
		randf_range(rect.position.y + 40.0, rect.end.y - 40.0))
	e.setup(base_position, _wave_hp, randf_range(26.0, 36.0), _wave_dmg, _wave_reward)
	e.visible = _in_natural()
	_alive += 1
	_to_spawn -= 1


func damage_base(amount: float) -> void:
	if state != State.ACTIVE or _base_bar == null:
		return
	_base_bar.take_damage(amount)
	base_hp_changed.emit(_base_bar.hp, _base_bar.max_hp)


func on_enemy_died(_e: Node) -> void:
	_alive = maxi(0, _alive - 1)


func _spawn_base() -> void:
	var world: Node = get_tree().get_first_node_in_group("world_container")
	if world == null:
		return
	_base_node = Node2D.new()
	_base_node.add_to_group("natural_visual")
	_base_node.z_index = 1
	world.add_child(_base_node)
	_base_node.global_position = base_position
	_base_node.visible = _in_natural()
	var lbl := Label.new()
	lbl.text = "🌱"
	lbl.add_theme_font_size_override(&"font_size", 30)
	lbl.position = Vector2(-16, -60)
	_base_node.add_child(lbl)
	_base_bar = HealthBar.new()
	_base_node.add_child(_base_bar)
	_base_bar.setup(_base_hp_max, -66.0, true)
	_base_bar.died.connect(func(): _end(false))


func _end(won: bool) -> void:
	if state != State.ACTIVE:
		return
	state = State.IDLE
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		if is_instance_valid(e):
			e.queue_free()
	if _base_node != null and is_instance_valid(_base_node):
		_base_node.queue_free()
	_base_node = null
	_base_bar = null
	if won:
		var reward: int = int(float(200 + _total_waves * 60) * _diff)
		InventoryManager.add_coins(reward)
		InventoryManager.add_reputation(8)
		NotificationManager.post("🏆 ¡Asedio repelido! +%d ⚜ y +8 reputación." % reward, NotificationManager.Kind.INFO)
		AudioManager.play_named(&"siege_victory")
		_maybe_unlock_trophy()
	else:
		var loss: int = mini(InventoryManager.arcane_coins, 80)
		InventoryManager.spend_coins(loss)
		NotificationManager.post("💥 Los ogros arrasaron el cultivo… -%d ⚜." % loss, NotificationManager.Kind.ALERT)
		AudioManager.play_named(&"siege_defeat")
	siege_ended.emit(won)


## Recompensa especial: la primera victoria desbloquea el Trofeo de Asedio.
func _maybe_unlock_trophy() -> void:
	var bd: BuildableData = BuildManager._find_buildable_by_id(&"build_siege_trophy")
	if bd == null:
		return
	if bd in BuildManager.get_unlocked_buildables():
		return
	BuildManager.unlock_buildable(bd)
	NotificationManager.post("🏆 ¡Nuevo! Desbloqueaste el Trofeo de Asedio. Constrúyelo donde quieras.", NotificationManager.Kind.INFO)


func _natural_rect() -> Rect2:
	return GridManager.get_zone_rect(GameEnums.ZoneType.NATURE)


func _in_natural() -> bool:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	return cam != null and cam.has_method("get_current_zone") and cam.get_current_zone().name == &"natural"
