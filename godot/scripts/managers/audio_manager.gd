extends Node

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var _music_player: AudioStreamPlayer       # canal A (track activo)
var _music_player_b: AudioStreamPlayer     # canal B (crossfade)
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

var _sfx_cache: Dictionary = {}  # name -> AudioStream

@export var sfx_master_volume_db: float = 0.0
@export var music_master_volume_db: float = -10.0

# Tracks por phase del día (claves alineadas con CalendarManager.Phase)
const MUSIC_TRACKS: Dictionary = {
	&"dawn":  "res://audio/music/ambient_dawn.wav",
	&"day":   "res://audio/music/ambient_cozy.wav",
	&"dusk":  "res://audio/music/ambient_dusk.wav",
	&"night": "res://audio/music/ambient_night.wav",
	# Tracks expandidos (cozy market y rítmicos para taller / festival / lullaby companion)
	&"market":      "res://audio/music/cozy_market.wav",
	&"twilight":    "res://audio/music/twilight_dreams.wav",
	&"lullaby":     "res://audio/music/lullaby_emporium.wav",
	&"working":     "res://audio/music/working_rhythm.wav",
	&"festival":    "res://audio/music/festival.wav",
	&"meditation":  "res://audio/music/night_meditation.wav",
}
const MUSIC_CROSSFADE_SECONDS: float = 4.0
var _current_music_key: StringName = &""
var _current_zone: StringName = &"taller"  ## zona activa (para música por ambiente)
var _music_streams_cache: Dictionary = {}
var _music_crossfade_tween: Tween = null
const SFX_PATHS: Dictionary = {
	&"footstep": "res://audio/sfx/footstep.wav",
	&"doorbell": "res://audio/sfx/doorbell.wav",
	&"coin": "res://audio/sfx/coin_pickup.wav",
	&"bubble": "res://audio/sfx/craft_bubble.wav",
	&"forge": "res://audio/sfx/forge_clang.wav",
	&"order_complete": "res://audio/sfx/order_complete.wav",
	&"menu_select": "res://audio/sfx/menu_select.wav",
	&"ui_click": "res://audio/sfx/ui_click.wav",
	&"ui_hover": "res://audio/sfx/ui_hover.wav",
	&"ui_open": "res://audio/sfx/ui_open.wav",
	&"ui_close": "res://audio/sfx/ui_close.wav",
	&"build_place": "res://audio/sfx/build_place.wav",
	&"build_error": "res://audio/sfx/build_error.wav",
	&"achievement_unlock": "res://audio/sfx/achievement_unlock.wav",
	&"level_up": "res://audio/sfx/level_up.wav",
	&"research_complete": "res://audio/sfx/research_complete.wav",
	&"notification": "res://audio/sfx/notification.wav",
	&"customer_bell": "res://audio/sfx/customer_bell.wav",
	# Ambient loops (para usar con loop_mode forward, no como one-shot)
	&"ambient_birds": "res://audio/sfx/ambient_birds.wav",
	&"ambient_wind": "res://audio/sfx/ambient_wind.wav",
	&"ambient_water": "res://audio/sfx/ambient_water.wav",
	&"ambient_fire": "res://audio/sfx/ambient_fire.wav",
	&"ambient_cauldron": "res://audio/sfx/ambient_cauldron.wav",
}

# ---- ambiente por zona (crossfade al cambiar con Q/E) ----
const ZONE_AMBIENCE: Dictionary = {
	&"taller":    {&"ambient_fire": -20.0},
	&"natural":   {&"ambient_birds": -14.0, &"ambient_wind": -22.0},
	&"recepcion": {&"ambient_wind": -30.0},
}
const AMBIENT_FADE_SECONDS: float = 1.6
const AMBIENT_SILENT_DB: float = -60.0
var _ambient_players: Dictionary = {}   # sfx_name -> AudioStreamPlayer
var _ambient_tweens: Dictionary = {}    # sfx_name -> Tween

# ---- ducking: jingles que bajan la música momentáneamente ----
const DUCK_SFX: Array[StringName] = [&"achievement_unlock", &"order_complete",
	&"level_up", &"research_complete"]
const DUCK_DB: float = -8.0
var _duck_tween: Tween = null


func _ready() -> void:
	_ensure_buses()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = music_master_volume_db
	add_child(_music_player)
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	_music_player_b.volume_db = -80.0
	add_child(_music_player_b)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		p.volume_db = sfx_master_volume_db
		add_child(p)
		_sfx_pool.append(p)
	# Solo en el juego principal arrancamos música/cargamos cache.
	if not _is_standalone_app():
		_load_sfx_cache()
		_load_music_cache()
		_start_ambient_music()
		# Conectarse al cambio de phase del CalendarManager
		CalendarManager.phase_changed.connect(_on_phase_changed)


func _is_standalone_app() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return "--pomodoro" in args or "--todo" in args


func _load_sfx_cache() -> void:
	for key in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_sfx_cache[key] = load(path)


func _load_music_cache() -> void:
	for key in MUSIC_TRACKS:
		var path: String = MUSIC_TRACKS[key]
		if not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_end = 0
		_music_streams_cache[key] = stream


func _start_ambient_music() -> void:
	var key: StringName = _resolve_music_key()
	var stream: AudioStream = _music_streams_cache.get(key)
	if stream == null:
		# Fallback: cualquier track disponible
		for k in _music_streams_cache:
			stream = _music_streams_cache[k]; key = k
			break
	if stream == null:
		return
	_current_music_key = key
	_music_player.stream = stream
	_music_player.volume_db = music_master_volume_db
	_music_player.play()


func _phase_to_key(phase: int) -> StringName:
	match phase:
		CalendarManager.Phase.DAWN: return &"dawn"
		CalendarManager.Phase.DAY: return &"day"
		CalendarManager.Phase.DUSK: return &"dusk"
		CalendarManager.Phase.NIGHT: return &"night"
	return &"day"


## Música según ambiente: de día cambia por zona (taller rítmico, recepción de
## mercado, patio cozy); al amanecer/atardecer/noche mandan las pistas de fase
## (la noche del patio usa meditación). Reutiliza los tracks ya existentes.
func _resolve_music_key() -> StringName:
	var phase: int = CalendarManager.current_phase
	if phase == CalendarManager.Phase.NIGHT:
		return &"meditation" if _current_zone == &"natural" else &"night"
	if phase == CalendarManager.Phase.DAWN:
		return &"dawn"
	if phase == CalendarManager.Phase.DUSK:
		return &"dusk"
	match _current_zone:  # DAY
		&"taller": return &"working"
		&"recepcion": return &"market"
		&"natural": return &"day"
	return &"day"


func _on_phase_changed(_phase: int) -> void:
	_crossfade_to_track(_resolve_music_key())


func _crossfade_to_track(key: StringName) -> void:
	if key == _current_music_key:
		return
	var stream: AudioStream = _music_streams_cache.get(key)
	if stream == null:
		return
	# Cancela tween anterior si quedó
	if _music_crossfade_tween != null and _music_crossfade_tween.is_valid():
		_music_crossfade_tween.kill()
	# El canal B arranca con el nuevo track desde silencio
	_music_player_b.stream = stream
	_music_player_b.volume_db = -80.0
	_music_player_b.play()
	# Crossfade: A→silencio, B→volumen master
	_music_crossfade_tween = create_tween().set_parallel(true)
	_music_crossfade_tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_CROSSFADE_SECONDS)
	_music_crossfade_tween.tween_property(_music_player_b, "volume_db", music_master_volume_db, MUSIC_CROSSFADE_SECONDS)
	# Al terminar, swap punteros: B se vuelve A
	_music_crossfade_tween.chain().tween_callback(func(): _swap_music_players(key))


func _swap_music_players(new_key: StringName) -> void:
	_music_player.stop()
	# Intercambia referencias
	var tmp: AudioStreamPlayer = _music_player
	_music_player = _music_player_b
	_music_player_b = tmp
	_current_music_key = new_key


## Reproduce un SFX precargado por nombre. Ver SFX_PATHS para los disponibles.
func play_named(sfx_name: StringName, pitch_variation: float = 0.06) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name)
	if stream != null:
		play_sfx(stream, pitch_variation)
		if sfx_name in DUCK_SFX:
			_duck_music()


## Devuelve el stream en versión loop (para posicionales/ambientes).
func get_loop_stream(sfx_name: StringName) -> AudioStream:
	var stream: AudioStream = _sfx_cache.get(sfx_name)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2   # 16-bit mono → samples
	return stream


## Ambiente según la zona activa de la cámara (fuego en taller, aves en patio).
func on_zone_changed(zone_name: StringName) -> void:
	# Música por ambiente: cruza a la pista de la nueva zona (según la hora).
	_current_zone = zone_name
	_crossfade_to_track(_resolve_music_key())
	var want: Dictionary = ZONE_AMBIENCE.get(zone_name, {})
	for key in _ambient_players:
		if not want.has(key):
			_fade_ambient(key, AMBIENT_SILENT_DB)
	for key in want:
		var p: AudioStreamPlayer = _ambient_players.get(key)
		if p == null:
			var stream: AudioStream = get_loop_stream(key)
			if stream == null:
				continue
			p = AudioStreamPlayer.new()
			p.bus = SFX_BUS
			p.stream = stream
			p.volume_db = AMBIENT_SILENT_DB
			add_child(p)
			_ambient_players[key] = p
		if not p.playing:
			p.play()
		_fade_ambient(key, float(want[key]))


func _fade_ambient(key: StringName, target_db: float) -> void:
	var p: AudioStreamPlayer = _ambient_players.get(key)
	if p == null:
		return
	var old: Tween = _ambient_tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, AMBIENT_FADE_SECONDS)
	_ambient_tweens[key] = tw


func _duck_music() -> void:
	# No pelear con el crossfade de música
	if _music_crossfade_tween != null and _music_crossfade_tween.is_running():
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music_player, "volume_db",
		music_master_volume_db + DUCK_DB, 0.12)
	_duck_tween.tween_interval(0.6)
	_duck_tween.tween_property(_music_player, "volume_db",
		music_master_volume_db, 1.4)


func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func play_sfx(stream: AudioStream, pitch_variation: float = 0.0, extra_db: float = 0.0) -> void:
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			p.volume_db = sfx_master_volume_db + extra_db
			p.play()
			return
	# Fallback: reuse the first one
	_sfx_pool[0].stream = stream
	_sfx_pool[0].volume_db = sfx_master_volume_db + extra_db
	_sfx_pool[0].play()


## Reproduce un SFX atenuado por la cámara: fuerte solo si hay zoom cercano y el
## emisor está cerca del centro de la vista; se apaga con la cámara alejada o el
## emisor fuera de foco. Para sonidos "de proximidad" como los pasos.
const _AUDIBLE_ZOOM_MIN: float = 1.05   ## por debajo de esto, prácticamente en silencio
const _FULL_ZOOM: float = 1.9           ## desde aquí, sin penalización por zoom
const _NEAR_PX: float = 130.0           ## radio (en px de pantalla) de volumen pleno
const _FAR_PX: float = 560.0            ## más allá, silencio
const _MIN_GAIN: float = 0.03           ## por debajo, ni se reproduce
const _MAX_ATTEN_DB: float = -26.0      ## atenuación máxima audible

func play_positional(sfx_name: StringName, world_pos: Vector2, pitch_variation: float = 0.06) -> void:
	var stream: AudioStream = _sfx_cache.get(sfx_name)
	if stream == null:
		return
	var cam: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam == null:
		play_sfx(stream, pitch_variation)
		return
	var zoom_level: float = cam.zoom.x
	var zoom_factor: float = smoothstep(_AUDIBLE_ZOOM_MIN, _FULL_ZOOM, zoom_level)
	if zoom_factor <= 0.0:
		return
	var screen_dist: float = cam.get_screen_center_position().distance_to(world_pos) * zoom_level
	var proximity: float = 1.0 - smoothstep(_NEAR_PX, _FAR_PX, screen_dist)
	var gain: float = zoom_factor * proximity
	if gain <= _MIN_GAIN:
		return
	play_sfx(stream, pitch_variation, maxf(_MAX_ATTEN_DB, linear_to_db(gain)))


func set_music_volume_db(db: float) -> void:
	music_master_volume_db = db
	# Aplicar solo al canal activo (el otro está en -80 o haciendo crossfade)
	if _music_player != null and _music_player.playing:
		_music_player.volume_db = db


func set_sfx_volume_db(db: float) -> void:
	sfx_master_volume_db = db
	for p in _sfx_pool:
		p.volume_db = db


func get_save_state() -> Dictionary:
	return {
		"music_db": music_master_volume_db,
		"sfx_db": sfx_master_volume_db,
	}


func load_save_state(data: Dictionary) -> void:
	if data.has("music_db"):
		set_music_volume_db(float(data["music_db"]))
	if data.has("sfx_db"):
		set_sfx_volume_db(float(data["sfx_db"]))


## Tono suave tipo "click cozy": senoidal con attack rápido + decay largo, volumen bajo.
## Para abrir/cerrar menús sin que sea molesto.
func play_soft(frequency: float = 520.0, duration: float = 0.18, volume_db: float = -22.0) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_beep_t < BEEP_MIN_GAP:
		return
	_last_beep_t = now
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = max(duration + 0.05, 0.25)
	var player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_pool[0]
	player.volume_db = volume_db
	player.stream = stream
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback == null:
		return
	var sample_count: int = int(stream.mix_rate * duration)
	var phase: float = 0.0
	var step: float = TAU * frequency / stream.mix_rate
	var attack: int = int(sample_count * 0.08)
	for i in sample_count:
		var t: float = float(i) / sample_count
		var env: float
		if i < attack:
			env = float(i) / attack
		else:
			# decay exponencial suave
			env = pow(1.0 - t, 1.4)
		var sample: float = sin(phase) * env * 0.25
		playback.push_frame(Vector2(sample, sample))
		phase += step


## Reproduce un beep sintético sin assets externos.
const BEEP_MIN_GAP: float = 0.12  ## min seg entre beeps; dropea exceso para no bloquear main thread
var _last_beep_t: float = 0.0


func play_beep(frequency: float = 660.0, duration: float = 0.08, volume_db: float = -12.0) -> void:
	# ponytail: cada beep genera N samples en loop SINCRÓNICO. Con 5+ logros en un frame
	# el main thread se bloquea 20k+ iteraciones → freeze visible. Throttling resuelve.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_beep_t < BEEP_MIN_GAP:
		return
	_last_beep_t = now
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = max(duration + 0.05, 0.2)
	var player: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_pool[0]
	var prev_db: float = player.volume_db
	player.volume_db = volume_db
	player.stream = stream
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback == null:
		return
	var sample_count: int = int(stream.mix_rate * duration)
	var phase: float = 0.0
	var step: float = TAU * frequency / stream.mix_rate
	for i in sample_count:
		var t: float = float(i) / sample_count
		var env: float = 1.0 - t
		var sample: float = sin(phase) * env * 0.4
		playback.push_frame(Vector2(sample, sample))
		phase += step
	player.volume_db = prev_db
