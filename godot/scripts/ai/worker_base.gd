class_name WorkerBase
extends CharacterBody2D
## Base FSM for all helpers (Duende, Golem, Apprentice).

@export var move_speed: float = 80.0
@export var arrival_distance: float = 6.0
@export var worker_type: GameEnums.WorkerType = GameEnums.WorkerType.DUENDE
@export var preferred_resource_type: GameEnums.ResourceType = GameEnums.ResourceType.HERB
## Si se llena, el worker busca el nodo más cercano de CUALQUIERA de estos tipos.
## Cuando está vacío, se usa preferred_resource_type singular (compat Duende/Gólem).
@export var preferred_resource_types: Array[int] = []

## Identidad y progresión: cada ayudante tiene nombre propio y sube de nivel
## recolectando (cada nivel lo hace un poco más rápido).
const NAMES: Dictionary = {
	GameEnums.WorkerType.DUENDE: ["Fizwick", "Pip", "Bramble", "Tato", "Nix", "Coco", "Gwen", "Moss"],
	GameEnums.WorkerType.GOLEM: ["Roco", "Canto", "Basalto", "Terrón", "Guijarro", "Sílex"],
	GameEnums.WorkerType.APPRENTICE: ["Lumi", "Sage", "Vera", "Orin", "Mira", "Nube"],
	GameEnums.WorkerType.LENADOR: ["Roble", "Serrín", "Hacha", "Nudo"],
	GameEnums.WorkerType.ESPIRITU: ["Bruma", "Eco", "Vela", "Alba"],
}
const NAMES_FALLBACK: Array = ["Alma", "Trébol", "Fauno", "Espina"]
const XP_PER_LEVEL: int = 5
const MAX_LEVEL: int = 6
const SPEED_PER_LEVEL: float = 0.06  ## +6% velocidad por nivel
const MOOD_MIN: float = 7.0
const MOOD_MAX: float = 15.0

## Personalidad: cada ayudante nace con un rasgo que matiza su comportamiento.
enum Trait { DILIGENTE, DORMILON, ENERGICO, CURIOSO }
const TRAIT_NAMES: Dictionary = {
	Trait.DILIGENTE: "📚 Diligente",
	Trait.DORMILON: "😴 Dormilón",
	Trait.ENERGICO: "⚡ Enérgico",
	Trait.CURIOSO: "🔍 Curioso",
}
## Energía 0..1: baja al trabajar, sube al descansar. A 0 obliga un descanso.
const ENERGY_DRAIN: float = 0.05
const ENERGY_REGEN: float = 0.09
const REST_RECOVER_TO: float = 0.55

var worker_name: String = ""
var level: int = 1
var xp: int = 0
var wtrait: int = Trait.DILIGENTE
var _favorite_type: int = -1  ## especialización: recurso preferido de entre sus tipos
var _favorite_manual: bool = false  ## true si la eligió el jugador, false si salió al azar
## Cuánto pesa el favorito al elegir destino. Se multiplica por la distancia AL
## CUADRADO, así que 0.45 equivale a tratarlo como si estuviese un ~33% más cerca:
## se nota la especialidad, pero un nodo a los pies gana a un favorito lejano.
const FAVORITE_BIAS: float = 0.45
var energy: float = 1.0
var _resting: bool = false
var _rest_target: Node2D = null
var _rest_house: Node2D = null
var _inside: bool = false
var _sleeping: bool = false   ## durmiendo de noche (no despierta hasta el día)
var _sleep_scan: float = 0.0
var _wander_mult: float = 1.0
var _drain_mult: float = 1.0
var _base_move_speed: float = 0.0
var _mood: Label = null
var _mood_accum: float = 0.0
var _dust_accum: float = 0.0
var _greet_cd: float = 0.0
var _greet_scan: float = 0.0
var _breath_cd: float = 0.0
var _chat_pause: float = 0.0  ## se paran un momento a "charlar" al cruzarse
const GREET_RADIUS: float = 28.0
const GREET_COOLDOWN: float = 12.0
const GREET_EMOTES: Array = ["👋", "♪", "😀", "🤝"]
const CHAT_EMOTES: Array = ["😄", "💬", "♪", "🤝", "✨", "😆", "👍"]

var state: GameEnums.WorkerState = GameEnums.WorkerState.IDLE
var target: Node2D = null
var _action_timer: float = 0.0
var _anim_phase: float = 0.0
var _facing_x: float = 1.0
var _facing: StringName = &"down"
var _anim_sprite: AnimatedSprite2D = null  ## opcional, solo workers que tienen AnimatedSprite2D
## Wander: cuando no hay recursos disponibles (o están reservados por otros),
## el worker pasea hacia un punto random cerca de su home para no congelarse.
var _home_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
const WANDER_RADIUS: float = 120.0
const WANDER_REPICK_MIN: float = 1.5
const WANDER_REPICK_MAX: float = 3.5
const WANDER_SPEED_FACTOR: float = 0.55  ## wander es más lento que ir a recolectar
const TARGET_SEARCH_INTERVAL: float = 0.3  ## no escanear recursos cada frame; cada 0.3s basta
var _target_search_cd: float = 0.0
var _step_accum: float = 0.0
var _stuck_time: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
# Evasión de obstáculos: al chocar, seguimos la tangente de la pared un instante
# para rodear en vez de quedarnos pegados caminando recto.
var _avoid_dir: Vector2 = Vector2.ZERO
var _avoid_time: float = 0.0
const AVOID_COMMIT: float = 0.55  ## segundos que mantiene el rodeo antes de recalcular
# --- combate de asedio ---
const WORKER_MAX_HP: float = 70.0
const COMBAT_AGGRO: float = 220.0   ## distancia a la que un worker engancha a un ogro
const MELEE_RANGE: float = 38.0
const MELEE_DAMAGE: float = 10.0
const MELEE_INTERVAL: float = 0.8
const DOWN_RECOVER_TIME: float = 16.0  ## seg. derribado en la base antes de reincorporarse
const DOWN_RECOVER_HP: float = 0.6     ## fracción de vida al volver a la lucha
var _combat_hb: HealthBar = null
var _downed: bool = false
var _downed_timer: float = 0.0
var _melee_cd: float = 0.0

signal state_changed(new_state: GameEnums.WorkerState)


func _ready() -> void:
	add_to_group("workers")
	CharShadow.attach(self)
	_setup_click_area()
	_base_move_speed = move_speed
	if worker_name == "":
		worker_name = _random_name()
	_apply_trait()
	# Especialización: si maneja varios tipos, nace con un favorito propio.
	if not preferred_resource_types.is_empty():
		_favorite_type = preferred_resource_types[randi() % preferred_resource_types.size()]
	_mood = _make_mood_bubble()
	_mood_accum = randf_range(MOOD_MIN, MOOD_MAX)
	_anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	# Combate de asedio: vida + recuperación al terminar.
	_combat_hb = HealthBar.new()
	add_child(_combat_hb)
	_combat_hb.setup(WORKER_MAX_HP, -52.0, false)
	_combat_hb.died.connect(_enter_downed)
	SiegeManager.siege_ended.connect(_on_siege_ended)
	# call_deferred porque al spawnear, global_position aún no está finalizado.
	call_deferred("_capture_home")


## Recibe daño de un ogro. Al caer, queda "derribado" (huye, no muere).
func hit(amount: float) -> void:
	if _downed or _combat_hb == null:
		return
	_combat_hb.take_damage(amount)
	modulate = Color(1.6, 1.2, 1.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)


func is_downed() -> bool:
	return _downed


func _enter_downed() -> void:
	if _downed:
		return
	_downed = true
	_downed_timer = DOWN_RECOVER_TIME
	NotificationManager.post("%s fue derribado y se repliega a la base." % worker_name, NotificationManager.Kind.INFO)


## Se reincorpora tras recuperarse en la base: vuelve con parte de la vida y
## regresa a defender/trabajar (no se queda plantado).
func _recover_from_downed() -> void:
	if not _downed:
		return
	_downed = false
	_downed_timer = 0.0
	if _combat_hb != null:
		_combat_hb.heal(_combat_hb.max_hp * DOWN_RECOVER_HP)
	_puff_mood("💪")
	_release_target()
	_change_state(GameEnums.WorkerState.IDLE)


func _on_siege_ended(_won: bool) -> void:
	# Reset completo: cura, deja de estar derribado y vuelve a la rutina normal
	# de inmediato (antes se quedaban plantados en la base sin volver a trabajar).
	_downed = false
	_downed_timer = 0.0
	if _combat_hb != null:
		_combat_hb.heal(_combat_hb.max_hp)
	_release_target()
	_change_state(GameEnums.WorkerState.IDLE)


## Combate durante el asedio. Devuelve true si tomó el control este frame (para
## saltar la FSM normal). Derribado → huye a la base; si hay un ogro cerca, lo
## ataca cuerpo a cuerpo; si no, deja seguir con el trabajo normal.
func _siege_combat(delta: float) -> bool:
	if _downed:
		var safe: Vector2 = SiegeManager.base_position
		if global_position.distance_to(safe) > 34.0:
			_drive_to(safe, move_speed * 1.2, delta)  # se repliega esquivando obstáculos
		else:
			# A salvo en la base: se recupera y al cabo de un rato vuelve a la lucha.
			velocity = Vector2.ZERO
			_downed_timer -= delta
			if _downed_timer <= 0.0:
				_recover_from_downed()
		return true
	var ogre: Node2D = _nearest_ogre(COMBAT_AGGRO)
	if ogre == null:
		return false
	var d: Vector2 = ogre.global_position - global_position
	if d.length() <= MELEE_RANGE:
		velocity = Vector2.ZERO
		_melee_cd -= delta
		if _melee_cd <= 0.0:
			_melee_cd = MELEE_INTERVAL
			if ogre.has_method("hit"):
				ogre.hit(MELEE_DAMAGE)
			_face_toward(ogre.global_position)
	else:
		_drive_to(ogre.global_position, move_speed, delta)  # se acerca rodeando obstáculos
	return true


func _nearest_ogre(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = radius
	for e in get_tree().get_nodes_in_group("siege_enemies"):
		var n: Node2D = e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var dist: float = global_position.distance_to(n.global_position)
		if dist < best_d:
			best_d = dist
			best = n
	return best


func _random_name() -> String:
	var pool: Array = NAMES.get(worker_type, NAMES_FALLBACK)
	if pool.is_empty():
		pool = NAMES_FALLBACK
	return pool[randi() % pool.size()]


## Sortea rasgo y ajusta parámetros base según personalidad.
func _apply_trait() -> void:
	wtrait = randi() % TRAIT_NAMES.size()
	var speed_mult: float = 1.12 if wtrait == Trait.ENERGICO else (0.95 if wtrait == Trait.DORMILON else 1.0)
	_base_move_speed *= speed_mult
	move_speed = _base_move_speed
	_apply_trait_behavior()


## Multiplicadores de personalidad NO-velocidad (cansancio/deambular). Idempotente,
## para poder reaplicarlos al restaurar el rasgo desde el save.
func _apply_trait_behavior() -> void:
	_drain_mult = 1.0
	_wander_mult = 1.0
	match wtrait:
		Trait.ENERGICO:
			_drain_mult = 0.65   # se cansa menos
		Trait.DORMILON:
			_drain_mult = 1.35   # se cansa antes
		Trait.CURIOSO:
			_wander_mult = 1.6   # explora más al deambular
		_:
			pass


## --- Persistencia: identidad y progresión del ayudante ---
func get_save_dict() -> Dictionary:
	return {
		"name": worker_name,
		"level": level,
		"xp": xp,
		"trait": wtrait,
		"energy": energy,
		"favorite": _favorite_type,
		"favorite_manual": _favorite_manual,
	}


func apply_save_dict(d: Dictionary) -> void:
	if d.has("name"):
		set_worker_name(String(d["name"]))
	level = clampi(int(d.get("level", level)), 1, MAX_LEVEL)
	xp = int(d.get("xp", xp))
	energy = clampf(float(d.get("energy", energy)), 0.0, 1.0)
	_favorite_type = int(d.get("favorite", _favorite_type))
	_favorite_manual = bool(d.get("favorite_manual", false))
	if d.has("trait"):
		wtrait = int(d["trait"])
		_apply_trait_behavior()
	# Reaplica la velocidad según el nivel restaurado (cada nivel: +6%).
	move_speed = _base_move_speed * (1.0 + SPEED_PER_LEVEL * float(level - 1))


func set_worker_name(new_name: String) -> void:
	var t: String = new_name.strip_edges()
	if t != "":
		worker_name = t.left(16)


func _make_mood_bubble() -> Label:
	var l := Label.new()
	l.z_index = 20
	l.position = Vector2(6, -46)
	l.modulate.a = 0.0
	l.add_theme_font_size_override(&"font_size", 15)
	add_child(l)
	return l


## Sube XP al recolectar; cada nivel reduce el cooldown (más velocidad).
func gain_xp(amount: int = 1) -> void:
	if level >= MAX_LEVEL:
		return
	if wtrait == Trait.DILIGENTE:
		amount *= 2  # los diligentes aprenden el doble de rápido
	xp += amount
	while xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		move_speed = _base_move_speed * (1.0 + SPEED_PER_LEVEL * float(level - 1))
		_puff_mood("⭐")
		VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	if level >= MAX_LEVEL:
		xp = 0


func _maybe_mood(delta: float) -> void:
	_mood_accum -= delta
	if _mood_accum > 0.0:
		return
	_mood_accum = randf_range(MOOD_MIN, MOOD_MAX)
	var pool: Array
	match state:
		GameEnums.WorkerState.FETCHING:
			pool = ["🎵", "✨", "👀"]
		GameEnums.WorkerState.WORKING:
			pool = ["💪", "⚙", "🔨"]
		_:
			pool = ["🍃", "😌", "💭", "♪"]
	_puff_mood(pool[randi() % pool.size()])


## Vaho blanco al respirar en invierno.
func _maybe_breath(delta: float) -> void:
	if CalendarManager.current_season != CalendarManager.Season.WINTER:
		return
	_breath_cd -= delta
	if _breath_cd > 0.0:
		return
	_breath_cd = randf_range(3.5, 6.5)
	BreathPuff.spawn(self, Vector2(_facing_x * 5.0, -32.0))


## Al cruzarse con otro worker caminando, se paran un momento a charlar:
## ambos se plantan e intercambian un par de burbujas (con cooldown anti-spam).
func _maybe_greet(delta: float) -> void:
	_greet_cd -= delta
	_greet_scan -= delta
	if _greet_cd > 0.0 or _greet_scan > 0.0:
		return
	_greet_scan = 0.4
	if velocity.length_squared() < 4.0:
		return
	for w in get_tree().get_nodes_in_group("workers"):
		if w == self or not is_instance_valid(w) or not (w as Node2D).visible:
			continue
		if global_position.distance_to((w as Node2D).global_position) < GREET_RADIUS:
			_start_chat(w)
			return


## Inicia una charla: yo saludo y "provoco" que el otro responda.
func _start_chat(other: Node) -> void:
	_greet_cd = GREET_COOLDOWN
	_chat_pause = randf_range(0.8, 1.2)
	_face_toward((other as Node2D).global_position)
	_puff_mood(GREET_EMOTES[randi() % GREET_EMOTES.size()])
	_chat_followup(randf_range(0.5, 0.8))
	if other.has_method("_receive_chat"):
		other._receive_chat(global_position)


## Respuesta cuando otro worker nos aborda: nos paramos y contestamos.
func _receive_chat(from_pos: Vector2) -> void:
	if _chat_pause > 0.0:
		return
	_greet_cd = GREET_COOLDOWN
	_chat_pause = randf_range(0.8, 1.2)
	_face_toward(from_pos)
	_chat_followup(randf_range(0.25, 0.5))


## Suelta otra burbuja tras un pequeño retardo (el "ida y vuelta" de la charla).
func _chat_followup(delay: float) -> void:
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_puff_mood(CHAT_EMOTES[randi() % CHAT_EMOTES.size()]))


func _face_toward(pos: Vector2) -> void:
	var d: Vector2 = pos - global_position
	if absf(d.x) > absf(d.y):
		_facing = &"side"
		_facing_x = signf(d.x)
	else:
		_facing = &"down" if d.y > 0.0 else &"up"


func _puff_mood(txt: String) -> void:
	if _mood == null:
		return
	_mood.text = txt
	var base_y: float = -46.0
	_mood.position.y = base_y
	_mood.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_mood, "modulate:a", 0.95, 0.25)
	tw.parallel().tween_property(_mood, "position:y", base_y - 12.0, 1.4)
	tw.tween_property(_mood, "modulate:a", 0.0, 0.45)


## Clic izquierdo sobre el worker → menú contextual (Seguir con la cámara).
func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	cs.shape = circ
	cs.position = Vector2(0, -18)
	area.add_child(cs)
	add_child(area)
	area.input_event.connect(_on_body_clicked)


func _on_body_clicked(_vp: Node, event: InputEvent, _idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# En modo obra el clic lo gestiona BuildManager; no abrir menú.
	if BuildManager.is_active() or BuildManager.is_move_active() \
			or BuildManager.is_rotate_active() or BuildManager.is_demolish_active() \
			or BuildManager.is_copy_active():
		return
	var menu: Node = get_tree().get_first_node_in_group("entity_menu")
	if menu != null and menu.has_method("open_for"):
		var acciones: Array = [{
			"rename": true,
			"text": "✏ Renombrar",
			"get": Callable(self, "_get_name"),
			"set": Callable(self, "set_worker_name"),
		}]
		if preferred_resource_types.size() > 1:
			acciones.append({
				"cycle": true,
				"label": "Especialidad",
				"get": Callable(self, "especialidad_texto"),
				"next": Callable(self, "ciclar_especialidad"),
			})
		acciones.append_array(_acciones_de_oficio())
		menu.open_for(self, _worker_title(), acciones,
				Callable(self, "_stats_data"), _portrait_texture())
		get_viewport().set_input_as_handled()


## Órdenes propias de cada oficio, para su menú. Vacío en el trabajador genérico;
## el Leñador añade la de talar.
func _acciones_de_oficio() -> Array:
	return []


## Frame actual del sprite como mini-retrato para el menú (o null).
func _portrait_texture() -> Texture2D:
	if _anim_sprite != null and _anim_sprite.sprite_frames != null:
		var a: StringName = _anim_sprite.animation
		if _anim_sprite.sprite_frames.has_animation(a):
			return _anim_sprite.sprite_frames.get_frame_texture(a, _anim_sprite.frame)
	return null


## Stats para el menú contextual: barra de energía/cansancio, XP, rasgo,
## especialidad y actividad actual. Se refresca solo mientras el menú está abierto.
func _stats_data() -> Array:
	var out: Array = []
	var e: float = clampf(energy, 0.0, 1.0)
	var ecol: Color = Color(0.45, 0.85, 0.4)
	if e <= 0.25:
		ecol = Color(0.9, 0.4, 0.4)
	elif e <= 0.5:
		ecol = Color(0.9, 0.8, 0.35)
	out.append({"label": "Energía", "ratio": e, "color": ecol, "value_text": "%d%%" % int(round(e * 100.0))})
	if level < MAX_LEVEL:
		out.append({
			"label": "XP (Nv %d)" % level,
			"ratio": float(xp) / float(XP_PER_LEVEL),
			"color": Color(0.55, 0.7, 1.0),
			"value_text": "%d/%d" % [xp, XP_PER_LEVEL],
		})
	else:
		out.append({"label": "Nivel", "text": "MÁX (%d)" % level})
	out.append({"label": "Rasgo", "text": String(TRAIT_NAMES.get(wtrait, "—"))})
	if preferred_resource_types.size() > 1:
		out.append({"label": "Especialidad", "text": especialidad_texto()})
	out.append({"label": "Ahora", "text": _state_label()})
	return out


func _resource_type_label(t: int) -> String:
	match t:
		GameEnums.ResourceType.HERB: return "🌿 Hierbas"
		GameEnums.ResourceType.CRYSTAL: return "🔮 Cristal"
		GameEnums.ResourceType.IRON_ORE: return "⛏ Mena de hierro"
		GameEnums.ResourceType.ARCANE_WOOD: return "🪵 Madera arcana"
		GameEnums.ResourceType.SPIRIT_ESSENCE: return "👻 Esencia"
		GameEnums.ResourceType.ARCANE_WATER: return "💧 Agua arcana"
		GameEnums.ResourceType.MOON_DUST: return "🌙 Polvo lunar"
		GameEnums.ResourceType.AMETHYST_FRAGMENT: return "💎 Amatista"
		GameEnums.ResourceType.IRON_INGOT: return "🔩 Lingote"
		# Los diez de endgame. Si se añade un ResourceType hay que añadirlo aquí
		# también: sin etiqueta, el selector de especialidad y la ficha del
		# ayudante muestran "—" y el jugador no sabe en qué se ha especializado.
		GameEnums.ResourceType.ABYSSAL_SALT: return "🧂 Sal abisal"
		GameEnums.ResourceType.UMBRAL_ROOT: return "🌑 Raíz umbría"
		GameEnums.ResourceType.STAR_ASH: return "✨ Ceniza estelar"
		GameEnums.ResourceType.OBSIDIAN_CORE: return "🌋 Obsidiana"
		GameEnums.ResourceType.SPECTRE_DUST: return "💀 Polvo de espectro"
		GameEnums.ResourceType.ANCIENT_SAP: return "🍯 Savia ancestral"
		GameEnums.ResourceType.CELESTIAL_SHARD: return "☄ Fragmento celestial"
		GameEnums.ResourceType.MAGMA_HEART: return "🔥 Corazón magmático"
		GameEnums.ResourceType.ETERNAL_FROST: return "❄ Escarcha eterna"
		GameEnums.ResourceType.CRYSTAL_BOLT: return "⚡ Rayo cristalizado"
		_: return "—"


func especialidad_texto() -> String:
	if _favorite_manual:
		return _resource_type_label(_favorite_type)
	return "🎲 Aleatorio"


func ciclar_especialidad() -> void:
	if preferred_resource_types.is_empty():
		return
	if not _favorite_manual:
		# Aleatorio → primer tipo
		_favorite_type = preferred_resource_types[0]
		_favorite_manual = true
	else:
		var idx: int = preferred_resource_types.find(_favorite_type)
		if idx < 0 or idx >= preferred_resource_types.size() - 1:
			# Último tipo (o no encontrado) → vuelve a Aleatorio
			_favorite_type = preferred_resource_types[randi() % preferred_resource_types.size()]
			_favorite_manual = false
		else:
			# Siguiente tipo en la lista
			_favorite_type = preferred_resource_types[idx + 1]
			_favorite_manual = true


func _state_label() -> String:
	if _sleeping:
		return "😴 Durmiendo"
	if _resting:
		return "☕ Descansando"
	match state:
		GameEnums.WorkerState.IDLE: return "😌 Ocioso"
		GameEnums.WorkerState.FETCHING: return "🏃 Buscando"
		GameEnums.WorkerState.WORKING: return "🔨 Trabajando"
		GameEnums.WorkerState.DELIVERING: return "📦 Entregando"
		GameEnums.WorkerState.MOVING: return "🚶 Moviéndose"
		_: return "…"


func _get_name() -> String:
	return worker_name


func _worker_title() -> String:
	var role: String
	match worker_type:
		GameEnums.WorkerType.DUENDE: role = "🧝 Duende"
		GameEnums.WorkerType.GOLEM: role = "🗿 Gólem"
		GameEnums.WorkerType.APPRENTICE: role = "🧙 Aprendiz"
		GameEnums.WorkerType.LENADOR: role = "🪓 Leñador"
		GameEnums.WorkerType.ESPIRITU: role = "👻 Espíritu"
		_: role = "Ayudante"
	return "%s %s · Nv %d · %s" % [role, worker_name, level, TRAIT_NAMES.get(wtrait, "")]


func _capture_home() -> void:
	# Una partida guardada ANTES de que el wander tuviera límites puede traer al
	# worker ya fuera de la sala. Si su casa cae fuera de toda zona, el recorte
	# de `_pick_wander_target` no tendría contra qué recortar y se quedaría
	# paseando por encima del muro para siempre. Se le devuelve a la zona más
	# cercana, que es de donde nunca debio salir.
	_home_position = global_position
	if GridManager.get_zone_rect_at(_home_position).size == Vector2.ZERO:
		var destino: Rect2 = _zona_mas_cercana(_home_position)
		if destino.size != Vector2.ZERO:
			_home_position = _recortar(_home_position, destino, WANDER_MARGEN)
			global_position = _home_position
	_wander_target = _home_position


static func _zona_mas_cercana(p: Vector2) -> Rect2:
	var mejor := Rect2()
	var mejor_d: float = INF
	for z in [GameEnums.ZoneType.NATURE, GameEnums.ZoneType.WORKSHOP, GameEnums.ZoneType.RECEPTION]:
		var r: Rect2 = GridManager.get_zone_rect(z)
		if r.size == Vector2.ZERO:
			continue
		var d: float = p.distance_to(_recortar(p, r, 0.0))
		if d < mejor_d:
			mejor_d = d
			mejor = r
	return mejor


func _physics_process(delta: float) -> void:
	# --- Sistema de prioridades del ayudante (de mayor a menor) ---
	# 1) ASEDIO — defender (o replegarse si está derribado) manda sobre todo lo
	#    demás. Corta incluso una charla en curso: no se quedan parados ante un ogro.
	if SiegeManager.is_active() and _siege_combat(delta):
		_update_anim(delta)
		return
	# 2) SOCIAL — al cruzarse con otro worker se paran un momento a charlar (solo
	#    en tiempos de paz, ya cubierto por el punto 1).
	if _chat_pause > 0.0:
		_chat_pause -= delta
		velocity = Vector2.ZERO
		_update_anim(delta)
		return
	# 3) DESCANSO / TRABAJO — FSM normal. El cansancio fuerza el descanso desde
	#    _update_energy (pone _resting) y _on_idle prioriza descansar antes que
	#    recolectar. Orden efectivo: cansado → descansar; libre → recolectar.
	match state:
		GameEnums.WorkerState.IDLE:
			_on_idle(delta)
		GameEnums.WorkerState.FETCHING:
			_move_to(target, delta)
			# Anti-atasco: encajado contra una colisión cerca del objetivo → llegó.
			if global_position.distance_to(_last_pos) < 1.2 * delta * 60.0 * 0.02 + 0.8:
				_stuck_time += delta
			else:
				_stuck_time = 0.0
			_last_pos = global_position
			if _stuck_time > 1.0 and target != null and is_instance_valid(target):
				_stuck_time = 0.0
				if global_position.distance_to(target.global_position) < 60.0:
					_on_arrived_at_target()
				else:
					_release_target()
					_change_state(GameEnums.WorkerState.IDLE)
			if target == null or not is_instance_valid(target):
				_release_target()
				_change_state(GameEnums.WorkerState.IDLE)
			elif target is ResourceNode and not target.is_available():
				# Otro worker o el sistema colectó este recurso mientras viajábamos:
				# soltar y volver a IDLE. Solo aplica a ResourceNode; workstations
				# manejan su propio ciclo de busy/idle internamente.
				_release_target()
				_change_state(GameEnums.WorkerState.IDLE)
			elif _has_arrived(target):
				_on_arrived_at_target()
		GameEnums.WorkerState.WORKING:
			_action_timer -= delta
			if _action_timer <= 0.0:
				_change_state(GameEnums.WorkerState.IDLE)
		_:
			pass
	_update_anim(delta)
	_maybe_mood(delta)
	_maybe_greet(delta)
	_maybe_breath(delta)
	_maybe_sleep(delta)
	_update_energy(delta)
	# pasos suaves + polvo (solo si el worker está en la zona visible)
	if visible and velocity.length_squared() > 4.0:
		_step_accum -= delta
		if _step_accum <= 0.0:
			_step_accum = 0.42
			AudioManager.play_positional(&"footstep", global_position, 0.3)
			FootDust.spawn(self)
			FootPrint.maybe(self)
	else:
		_step_accum = 0.2


func _update_anim(delta: float) -> void:
	var is_moving: bool = velocity.length_squared() > 4.0
	# Workers con hoja direccional (idle/walk × down/up/side): eligen animación
	# por el eje dominante del movimiento, flip_h para izquierda.
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(&"walk_down"):
		_update_anim_directional(is_moving)
		return
	if is_moving:
		_anim_phase += delta * 14.0
		if abs(velocity.x) > 1.0:
			_facing_x = sign(velocity.x)
		var sx: float = _facing_x * (1.0 + sin(_anim_phase * 2.0) * 0.06)
		var sy: float = 1.0 - sin(_anim_phase * 2.0) * 0.06
		scale = Vector2(sx, sy)
		rotation = sin(_anim_phase) * 0.06
	else:
		_anim_phase += delta * 2.0
		scale = Vector2(_facing_x, 1.0)
		rotation = lerp(rotation, 0.0, 0.2)
	# ponytail: si el worker tiene AnimatedSprite2D con anim "idle"/"walk_south", switch entre ellas.
	# Workers viejos (Golem/Apprentice con Sprite2D estático) ignoran este bloque.
	if _anim_sprite != null and _anim_sprite.sprite_frames != null:
		var want: StringName = &"walk_south" if is_moving else &"idle"
		if _anim_sprite.sprite_frames.has_animation(want) and _anim_sprite.animation != want:
			_anim_sprite.play(want)


func _update_anim_directional(is_moving: bool) -> void:
	# El flip se hace en el sprite (flip_h), no en la escala del cuerpo.
	scale = Vector2.ONE
	rotation = 0.0
	if is_moving:
		if absf(velocity.x) > absf(velocity.y):
			_facing = &"side"
			_facing_x = signf(velocity.x)
		else:
			_facing = &"down" if velocity.y > 0.0 else &"up"
	_anim_sprite.flip_h = _facing == &"side" and _facing_x < 0.0
	var prefix: StringName = &"walk_" if is_moving else &"idle_"
	var want: StringName = prefix + _facing
	if _anim_sprite.animation != want:
		_anim_sprite.play(want)


## Energía: baja al moverse/trabajar, sube al estar quieto. A 0 fuerza descanso
## (se planta hasta recuperar REST_RECOVER_TO). Los rasgos ajustan el ritmo.
func _update_energy(delta: float) -> void:
	var active: bool = velocity.length_squared() > 4.0
	if _resting:
		# ¿Ya está descansando EN su sitio (dentro de casa o junto al punto cálido)?
		# Mientras aún viaja hacia el descanso la energía sube lento; si la dejáramos
		# cancelar el reposo a mitad de camino, volvería a currar, se cansaría y
		# quedaría oscilando entre "ir a descansar" y "ir a trabajar". Nos comprometemos:
		# solo se cancela el descanso una vez que ha llegado a su sitio de reposo.
		var settled: bool = _inside or _rest_target == null or not is_instance_valid(_rest_target) \
				or global_position.distance_to(_rest_target.global_position) < 24.0
		# Dentro de casa recupera muy rápido; en sitio cálido rápido; de camino lento.
		var rate: float = 3.5 if _inside else (2.5 if settled else 0.7)
		energy = minf(1.0, energy + ENERGY_REGEN * rate * delta)
		if settled and energy >= REST_RECOVER_TO and not _sleeping:
			if _inside:
				_exit_house()
			_resting = false
			_rest_target = null
			_rest_house = null
	elif active:
		energy = maxf(0.0, energy - ENERGY_DRAIN * _drain_mult * EmporiumUpgradeManager.vigor_multiplier() * delta)
		if energy <= 0.0:
			_resting = true
			# Preferimos una casa con hueco; si no, un sitio cálido.
			_rest_house = _find_worker_house()
			_rest_target = _rest_house if _rest_house != null else _find_warm_spot()
			_release_target()
			_change_state(GameEnums.WorkerState.IDLE)
			_puff_mood("💤")
	else:
		energy = minf(1.0, energy + ENERGY_REGEN * delta)


## Rutina: de noche los duendes vuelven a casa a dormir; despiertan de día.
func _maybe_sleep(delta: float) -> void:
	_sleep_scan -= delta
	if _sleep_scan > 0.0:
		return
	_sleep_scan = 1.0
	var night: bool = CalendarManager.get_darkness() > 0.55
	if night:
		if not _sleeping and not _resting:
			var h: Node2D = _find_worker_house()
			if h != null:
				_sleeping = true
				_resting = true
				_rest_house = h
				_rest_target = h
				_release_target()
				_change_state(GameEnums.WorkerState.IDLE)
				_puff_mood("😴")
	elif _sleeping:
		# Amaneció: despertar.
		_sleeping = false
		if _inside:
			_exit_house()
		_resting = false
		_rest_house = null


## Casa de duendes con hueco libre más cercana, para descansar dentro.
func _find_worker_house() -> Node2D:
	var best: Node2D = null
	var best_d: float = 520.0
	for h in get_tree().get_nodes_in_group("worker_house"):
		var n: Node2D = h as Node2D
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		if not n.has_method("has_room") or not n.has_room():
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _enter_house() -> void:
	if _rest_house == null or not is_instance_valid(_rest_house):
		_rest_house = null
		return
	if not _rest_house.has_room():
		_rest_house = null  # se llenó mientras llegaba → a un sitio cálido
		return
	_rest_house.enter(self)
	_inside = true
	velocity = Vector2.ZERO
	visible = false


func _exit_house() -> void:
	if _rest_house != null and is_instance_valid(_rest_house):
		_rest_house.leave(self)
		global_position = _rest_house.door_point()
	_inside = false
	visible = true


func _move_to_point(pos: Vector2, delta: float) -> void:
	_drive_to(pos, move_speed, delta)


## Se dirige a `pos` esquivando obstáculos: si choca de frente, sigue la tangente
## de la pared hacia el lado que lo acerca al objetivo (con compromiso temporal
## para rodear sin oscilar). Es una evasión ligera, sin navmesh.
func _drive_to(pos: Vector2, speed: float, delta: float) -> void:
	var desired: Vector2 = (pos - global_position).normalized()
	var move_dir: Vector2 = desired
	if _avoid_time > 0.0:
		_avoid_time -= delta
		# Sigue la tangente pero sesgada hacia el objetivo (así "sale" del rodeo).
		move_dir = (_avoid_dir * 0.85 + desired * 0.35).normalized()
	velocity = move_dir * speed
	move_and_slide()
	var col := get_last_slide_collision()
	if col != null:
		var n: Vector2 = col.get_normal()
		# ¿El obstáculo está delante (bloquea el avance hacia el objetivo)?
		if desired.dot(-n) > 0.2:
			var t1 := Vector2(-n.y, n.x)
			var t2 := -t1
			# Tangente de la pared que más nos acerca al objetivo → rodear por ahí.
			_avoid_dir = t1 if t1.dot(desired) > t2.dot(desired) else t2
			_avoid_time = AVOID_COMMIT
	elif _avoid_time <= 0.0:
		_avoid_dir = Vector2.ZERO


## Sitio cálido (farol/vela/chimenea) más cercano y visible, para descansar.
func _find_warm_spot() -> Node2D:
	var best: Node2D = null
	var best_d: float = 420.0
	for w in get_tree().get_nodes_in_group("warm_spot"):
		var n: Node2D = w as Node2D
		if n == null or not is_instance_valid(n) or not n.visible:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _on_idle(delta: float) -> void:
	# Descansando: camina a un sitio cálido si lo hay y aún no llegó; si no, se
	# planta a recuperar energía.
	if _resting:
		if _inside:
			if not is_instance_valid(_rest_house):  # demolieron la casa: salir
				_inside = false
				visible = true
				_rest_house = null
			velocity = Vector2.ZERO
			return
		# Prioridad: entrar en una casa por la puerta.
		if _rest_house != null and is_instance_valid(_rest_house):
			var door: Vector2 = _rest_house.door_point()
			if global_position.distance_to(door) > 18.0:
				_move_to_point(door, delta)
			else:
				_enter_house()
			return
		# Si no, descansar en un sitio cálido.
		if _rest_target != null and is_instance_valid(_rest_target) \
				and global_position.distance_to(_rest_target.global_position) > 22.0:
			_move_to(_rest_target, delta)
		else:
			velocity = Vector2.ZERO
		return
	# Si el inventario está lleno, no recolectar más (evita spam y trabajo en vacío).
	if InventoryManager.get_total_count() >= InventoryManager.max_capacity:
		_wander(delta)
		return
	# Escanear todos los nodos de recurso cada frame por worker es caro; basta
	# con hacerlo cada TARGET_SEARCH_INTERVAL. Entre búsquedas, wander.
	_target_search_cd -= delta
	if _target_search_cd <= 0.0:
		_target_search_cd = TARGET_SEARCH_INTERVAL
		var candidate = _find_best_target()
		if candidate != null and candidate.has_method("reserve") and candidate.reserve(self):
			target = candidate
			_change_state(GameEnums.WorkerState.FETCHING)
			return
	# No hay recursos libres (o todos reservados por otros workers): wander como ocioso.
	_wander(delta)


func _find_best_target():
	# Si hay lista de tipos, picamos el más cercano de TODOS los tipos. Sin lista
	# (compat workers viejos), usamos el tipo singular.
	if preferred_resource_types.is_empty():
		return ResourceManager.get_closest_available_node(global_position, preferred_resource_type, self)
	# Especialización individual: el favorito PESA, pero no manda.
	#
	# Antes se cogía el favorito siempre que hubiese un nodo suyo libre, y solo se
	# miraba el resto si no lo había. Con listas de dos tipos daba igual; al subir el
	# Espíritu a nueve tipos y el Gólem a seis dejó de dar igual: como las parcelas
	# regeneran, el favorito casi nunca falta, así que un ayudante se quedaba pegado a
	# un único recurso y no volvía a tocar los otros ocho en toda la partida.
	var best = null
	var best_score: float = INF
	for t in preferred_resource_types:
		var cand = ResourceManager.get_closest_available_node(global_position, t, self)
		if cand == null:
			continue
		var d: float = cand.global_position.distance_squared_to(global_position)
		if t == _favorite_type:
			d *= FAVORITE_BIAS
		if d < best_score:
			best_score = d
			best = cand
	return best


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) <= arrival_distance:
		_pick_wander_target()
	if global_position.distance_to(_wander_target) < 1.0:
		velocity = Vector2.ZERO
		return
	_drive_to(_wander_target, move_speed * WANDER_SPEED_FACTOR, delta)


## Margen para que el sprite no quede medio metido en el muro: el worker se para
## por su base, pero mide ~48 px de alto y el borde de la zona es el suelo.
const WANDER_MARGEN: float = 12.0


func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var radius: float = randf_range(WANDER_RADIUS * 0.3, WANDER_RADIUS) * _wander_mult
	_wander_target = _home_position + Vector2(cos(angle), sin(angle)) * radius
	# Sin esto el destino podía caer FUERA de la sala y el worker se iba andando
	# por encima de la pared: no hay colisionadores en el mundo, así que nada lo
	# frenaba. Se recorta contra la zona donde vive, no contra la actual, para
	# que uno que ande cruzando de patio no se quede clavado en el umbral.
	var rect: Rect2 = GridManager.get_zone_rect_at(_home_position)
	if rect.size != Vector2.ZERO:
		_wander_target = _recortar(_wander_target, rect, WANDER_MARGEN)
	_wander_timer = randf_range(WANDER_REPICK_MIN, WANDER_REPICK_MAX)


static func _recortar(p: Vector2, r: Rect2, margen: float) -> Vector2:
	var m: float = minf(margen, minf(r.size.x, r.size.y) * 0.5 - 1.0)
	return Vector2(
		clampf(p.x, r.position.x + m, r.end.x - m),
		clampf(p.y, r.position.y + m, r.end.y - m))


func _release_target() -> void:
	if target != null and is_instance_valid(target) and target.has_method("release"):
		target.release(self)
	target = null


func _on_arrived_at_target() -> void:
	if target is ResourceNode:
		(target as ResourceNode).collect()
		target = null
		gain_xp(1)
		_change_state(GameEnums.WorkerState.IDLE)


func _move_to(t: Node2D, delta: float) -> void:
	if t == null or not is_instance_valid(t):
		velocity = Vector2.ZERO
		return
	_drive_to(t.global_position, move_speed, delta)


func _has_arrived(t: Node2D) -> bool:
	if t == null:
		return false
	return global_position.distance_to(t.global_position) <= arrival_distance


func _change_state(new_state: GameEnums.WorkerState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)
