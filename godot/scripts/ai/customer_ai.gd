class_name CustomerAI
extends CharacterBody2D

signal arrived_at_counter(customer: CustomerAI)
signal left(customer: CustomerAI)
signal expired(customer: CustomerAI)

@export var move_speed: float = 60.0
@export var arrival_distance: float = 6.0
@export var patience_seconds: float = 240.0  ## tiempo máximo esperando (4 min base; ×0.75-1.3 por personalidad → rango 3-5 min)

# ponytail: personalidades inline. Si crece a >6 variantes movemos a Resource.
# Cada una: {emoji, patience_mult, speed_mult, coin_mult, rep_mult, color, greetings}
const PERSONALITIES: Array = [
	{"id": &"normal",    "emoji": "",   "patience_mult": 1.0, "speed_mult": 1.0, "coin_mult": 1.0, "rep_mult": 1.0, "color": Color.WHITE,                "weight": 50,
		"greetings": ["Buenas, ¿tienes lo mío?", "Hola, vengo por el pedido.", "¿Está listo?"]},
	{"id": &"impatient", "emoji": "⏰", "patience_mult": 0.75, "speed_mult": 1.5, "coin_mult": 1.0, "rep_mult": 1.0, "color": Color(1, 0.7, 0.7, 1),       "weight": 20,
		"greetings": ["¡Rápido, no tengo todo el día!", "Llego tarde, dame eso ya.", "Apúrate por favor."]},
	{"id": &"generous",  "emoji": "💰", "patience_mult": 1.0, "speed_mult": 1.0, "coin_mult": 1.6, "rep_mult": 1.0, "color": Color(1, 0.95, 0.55, 1),     "weight": 15,
		"greetings": ["Pagaré bien, sin prisa.", "Tu negocio es excelente.", "Toma tu tiempo, te lo compensaré."]},
	{"id": &"picky",     "emoji": "🧐", "patience_mult": 1.3, "speed_mult": 0.85, "coin_mult": 1.0, "rep_mult": 2.0, "color": Color(0.75, 0.85, 1, 1),    "weight": 15,
		"greetings": ["Espero la calidad de siempre.", "Quiero solo lo mejor.", "Más vale que esté impecable."]},
]
const GREETING_DURATION: float = 2.8

# Pool de skins para clientes (sprites estáticos del catálogo).
# VIP_POOL se usa cuando OrderData.reward_tier >= 2 (clientes premium).
const NPC_POOL: Array[String] = [
	"res://art/sprites/characters/npc_aldeano.png",
	"res://art/sprites/characters/npc_aventurero_novato.png",
	"res://art/sprites/characters/npc_aventurero_veterano.png",
	"res://art/sprites/characters/npc_comerciante.png",
	"res://art/sprites/characters/npc_anciano_sabio.png",
	"res://art/sprites/characters/npc_nino_curioso.png",
	"res://art/sprites/characters/npc_cocinero.png",
	"res://art/sprites/characters/npc_doctor.png",
	"res://art/sprites/characters/npc_caballero.png",
	"res://art/sprites/characters/npc_mago_iniciado.png",
	"res://art/sprites/characters/npc_druida.png",
	"res://art/sprites/characters/npc_bardo.png",
	"res://art/sprites/characters/npc_sacerdote.png",
	"res://art/sprites/characters/npc_ladron.png",
	"res://art/sprites/characters/npc_pirata.png",
	"res://art/sprites/characters/npc_elfo_bosque.png",
	"res://art/sprites/characters/npc_elfo_oscuro.png",
	"res://art/sprites/characters/npc_enano_forjador.png",
	"res://art/sprites/characters/npc_orco_mercenario.png",
	"res://art/sprites/characters/npc_halfling.png",
	"res://art/sprites/characters/npc_hada_visitante.png",
	"res://art/sprites/characters/npc_vampiro.png",
	"res://art/sprites/characters/npc_hombre_lobo.png",
	"res://art/sprites/characters/npc_fantasma.png",
	"res://art/sprites/characters/npc_angel.png",
	"res://art/sprites/characters/npc_esqueleto.png",
	"res://art/sprites/characters/npc_genio.png",
	"res://art/sprites/characters/npc_bandido.png",
	"res://art/sprites/characters/npc_periodista.png",
	"res://art/sprites/characters/npc_misterioso.png",
]
const VIP_POOL: Array[String] = [
	"res://art/sprites/characters/npc_paladin.png",
	"res://art/sprites/characters/npc_archimago.png",
	"res://art/sprites/characters/npc_caballero_negro.png",
	"res://art/sprites/characters/npc_brujo_oscuro.png",
	"res://art/sprites/characters/npc_demonio_menor.png",
	"res://art/sprites/characters/npc_princesa.png",
	"res://art/sprites/characters/npc_principe.png",
	"res://art/sprites/characters/npc_rey.png",
	"res://art/sprites/characters/npc_reina.png",
	"res://art/sprites/characters/npc_emperador.png",
	"res://art/sprites/characters/npc_inspector.png",
	"res://art/sprites/characters/npc_inspector_calidad.png",
	"res://art/sprites/characters/npc_critico_gastronomico.png",
	"res://art/sprites/characters/npc_celebrities.png",
]

var order: OrderData
var counter_point: Node2D
var exit_point: Node2D
var state: GameEnums.WorkerState = GameEnums.WorkerState.ARRIVING
var counter_offset: Vector2 = Vector2.ZERO

var _patience_remaining: float = 0.0
var _has_expired: bool = false

var personality: Dictionary = PERSONALITIES[0]  ## se asigna en setup()

@onready var label: Label = $Label if has_node("Label") else null
var _patience_bar: ProgressBar


func setup(p_order: OrderData, p_counter: Node2D, p_exit: Node2D) -> void:
	order = p_order
	counter_point = p_counter
	exit_point = p_exit
	state = GameEnums.WorkerState.ARRIVING
	_assign_personality()
	_patience_remaining = patience_seconds * personality.patience_mult
	move_speed *= personality.speed_mult
	modulate = personality.color
	_apply_random_skin()
	_update_label()


func _apply_random_skin() -> void:
	# Elige sprite del pool según tier del pedido (VIP si tier >= 2).
	var tier: int = 1
	if order != null and "tier" in order:
		tier = order.tier
	var pool: Array[String] = VIP_POOL if tier >= 2 else NPC_POOL
	if pool.is_empty():
		return
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if sprite_node == null:
		return
	var path: String = pool[randi() % pool.size()]
	var tex: Texture2D = load(path)
	if tex == null:
		return
	sprite_node.texture = tex
	# Los sprites del catálogo son 32×48; ajustar pivot/offset al pie.
	sprite_node.scale = Vector2(2, 2)
	sprite_node.offset = Vector2(0, -24)


func _assign_personality() -> void:
	var total: int = 0
	for p in PERSONALITIES:
		total += p.weight
	var roll: int = randi() % total
	var acc: int = 0
	for p in PERSONALITIES:
		acc += p.weight
		if roll < acc:
			personality = p
			return


func get_coin_mult() -> float:
	return personality.coin_mult


func get_rep_mult() -> float:
	return personality.rep_mult


func _ready() -> void:
	add_to_group("customers")
	_update_label()
	_create_patience_bar()


func _create_patience_bar() -> void:
	_patience_bar = ProgressBar.new()
	_patience_bar.custom_minimum_size = Vector2(50, 4)
	_patience_bar.show_percentage = false
	_patience_bar.max_value = 100.0
	_patience_bar.value = 100.0
	_patience_bar.position = Vector2(-25, -52)
	_patience_bar.visible = false
	add_child(_patience_bar)


func _process(delta: float) -> void:
	if state == GameEnums.WorkerState.WAITING and not _has_expired:
		_patience_remaining -= delta
		if _patience_bar != null:
			_patience_bar.value = (_patience_remaining / patience_seconds) * 100.0
		if _patience_remaining <= 0.0:
			_has_expired = true
			expired.emit(self)
			NotificationManager.post("Cliente impaciente se fue: %s" % (order.display_name if order else "—"), NotificationManager.Kind.ALERT)
			leave()


func _physics_process(_delta: float) -> void:
	match state:
		GameEnums.WorkerState.ARRIVING:
			if counter_point == null:
				return
			var target_pos: Vector2 = counter_point.global_position + counter_offset
			_move_toward(target_pos)
			if global_position.distance_to(target_pos) <= arrival_distance:
				state = GameEnums.WorkerState.WAITING
				velocity = Vector2.ZERO
				if _patience_bar != null:
					_patience_bar.visible = true
				_show_greeting()
				arrived_at_counter.emit(self)
		GameEnums.WorkerState.WAITING:
			velocity = Vector2.ZERO
		GameEnums.WorkerState.LEAVING:
			if exit_point == null:
				queue_free()
				return
			if _patience_bar != null:
				_patience_bar.visible = false
			_move_toward(exit_point.global_position)
			if global_position.distance_to(exit_point.global_position) <= arrival_distance:
				left.emit(self)
				queue_free()


func _move_toward(target_pos: Vector2) -> void:
	var dir: Vector2 = (target_pos - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()


func leave() -> void:
	state = GameEnums.WorkerState.LEAVING


func _update_label() -> void:
	if label == null or order == null or order.requested_item == null:
		return
	var prefix: String = ""
	if personality.emoji != "":
		prefix = "%s " % personality.emoji
	label.text = "%s%d × %s" % [prefix, order.requested_quantity, order.requested_item.display_name]


func _show_greeting() -> void:
	# ponytail: Label temporal sobre la cabeza. Sin scene file ni tween manager.
	var lines: Array = personality.get("greetings", [])
	if lines.is_empty():
		return
	var bubble := Label.new()
	bubble.text = lines.pick_random()
	bubble.position = Vector2(-60, -72)
	bubble.size = Vector2(120, 24)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	bubble.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	bubble.add_theme_constant_override(&"outline_size", 4)
	bubble.modulate = Color(1, 1, 1, 0)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.2)
	tw.tween_interval(GREETING_DURATION - 0.4)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.2)
	tw.tween_callback(bubble.queue_free)
