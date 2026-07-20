extends Node
## Orquesta el minijuego de Asedio (opt-in): una oleada de ogros entra por la
## izquierda del Patio Natural y avanza hacia el cultivo (la base). El jugador lo
## defiende con torretas (y luego workers/protagonista). Ganar da recompensa;
## perder, una penalización leve. No es persistente: empieza y termina.

signal siege_started
signal siege_ended(won: bool)
signal base_hp_changed(hp: float, max_hp: float)

enum State { IDLE, ACTIVE }

const BASE_MAX_HP: float = 220.0
const WAVE_SIZE: int = 8
## Cuánto a la izquierda (fuera de la pradera usable) aparecen los ogros, para
## verlos venir desde lejos. Limitado al borde del mapa de biomas.
const APPROACH_MARGIN: float = 780.0

var state: int = State.IDLE
var base_position: Vector2 = Vector2.ZERO
var _to_spawn: int = 0
var _spawn_cd: float = 0.0
var _alive: int = 0
var _base_node: Node2D = null
var _base_bar: HealthBar = null


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
	var rect: Rect2 = _natural_rect()
	base_position = Vector2(rect.end.x - 90.0, rect.get_center().y)
	_to_spawn = WAVE_SIZE
	_alive = 0
	_spawn_cd = 0.6
	state = State.ACTIVE
	_spawn_base()
	siege_started.emit()
	base_hp_changed.emit(BASE_MAX_HP, BASE_MAX_HP)
	NotificationManager.post("🏰 ¡ASEDIO! Los ogros vienen por el cultivo. ¡Defiéndelo!", NotificationManager.Kind.ALERT)


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	if _to_spawn > 0:
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_cd = randf_range(0.9, 2.1)
			_spawn_ogre()
	elif _alive <= 0:
		_end(true)


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
	e.setup(base_position, 60.0, randf_range(40.0, 54.0), 8.0, 12)
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
	_base_bar.setup(BASE_MAX_HP, -66.0, true)
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
		var reward: int = 200 + WAVE_SIZE * 15
		InventoryManager.add_coins(reward)
		InventoryManager.add_reputation(5)
		NotificationManager.post("🏆 ¡Asedio repelido! +%d ⚜ y +5 reputación." % reward, NotificationManager.Kind.INFO)
		AudioManager.play_beep(900.0, 0.18, -8.0)
	else:
		var loss: int = mini(InventoryManager.arcane_coins, 80)
		InventoryManager.spend_coins(loss)
		NotificationManager.post("💥 Los ogros arrasaron el cultivo… -%d ⚜." % loss, NotificationManager.Kind.ALERT)
	siege_ended.emit(won)


func _natural_rect() -> Rect2:
	return GridManager.get_zone_rect(GameEnums.ZoneType.NATURE)


func _in_natural() -> bool:
	var cam: Node = get_tree().get_first_node_in_group("zone_camera")
	return cam != null and cam.has_method("get_current_zone") and cam.get_current_zone().name == &"natural"
