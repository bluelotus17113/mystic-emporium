extends PanelContainer
## Mezclador de sonidos de ambiente. Cada track usa AudioStreamGenerator
## con un buffer corto rellenado periódicamente con ruido/tonos según el tipo.

const PANEL_NAME: StringName = &"ambient"

@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var list: VBoxContainer = $Margin/VBox/List

enum Track { RAIN, WIND, FIRE, WATER }
const TRACK_NAMES: Dictionary = {
	Track.RAIN: "🌧 Lluvia",
	Track.WIND: "🌬 Viento",
	Track.FIRE: "🔥 Fuego",
	Track.WATER: "💧 Agua",
}

var _players: Dictionary = {}       # Track -> AudioStreamPlayer
var _playbacks: Dictionary = {}     # Track -> AudioStreamGeneratorPlayback
var _volumes: Dictionary = {}       # Track -> 0..1
var _phases: Dictionary = {}        # Track -> float


func _ready() -> void:
	UIManager.register_panel(PANEL_NAME, self)
	close_button.pressed.connect(UIManager.close_active)
	for t in TRACK_NAMES.keys():
		_volumes[t] = 0.0
		_phases[t] = 0.0
		_create_player(t)
		list.add_child(_build_row(t))


func _create_player(track: int) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = AudioManager.SFX_BUS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -60.0
	add_child(player)
	player.play()
	_players[track] = player
	_playbacks[track] = player.get_stream_playback()


func _build_row(track: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = TRACK_NAMES[track]
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.0
	slider.value_changed.connect(_on_volume_changed.bind(track))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "0%"
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.name = "Value"
	row.add_child(value_label)
	return row


func _on_volume_changed(value: float, track: int) -> void:
	_volumes[track] = value
	var player: AudioStreamPlayer = _players[track]
	if value < 0.001:
		player.volume_db = -60.0
	else:
		player.volume_db = lerp(-30.0, -6.0, value)
	# update text
	for child in list.get_children():
		var slider: HSlider = child.get_node_or_null("HSlider") as HSlider
		if slider == null:
			# Slider is the second child after the name label
			slider = child.get_child(1)
		var value_label: Label = child.get_child(2) as Label
		if value_label != null and slider == child.get_child(1):
			value_label.text = "%d%%" % int(slider.value * 100)


func _process(_delta: float) -> void:
	for t in TRACK_NAMES.keys():
		if _volumes[t] < 0.001:
			continue
		_fill_buffer(t)


func _fill_buffer(track: int) -> void:
	var playback: AudioStreamGeneratorPlayback = _playbacks[track]
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	if frames <= 0:
		return
	var amp: float = _volumes[track] * 0.5
	var phase: float = _phases[track]
	match track:
		Track.RAIN:
			# White-ish noise with high-frequency sparkle
			for _i in frames:
				var s: float = (randf() - 0.5) * amp
				playback.push_frame(Vector2(s, s))
		Track.WIND:
			# Low-passed noise — running average of a few random samples
			var prev: float = 0.0
			for _i in frames:
				var raw: float = randf() - 0.5
				prev = prev * 0.92 + raw * 0.08
				var s: float = prev * amp * 1.4
				playback.push_frame(Vector2(s, s))
		Track.FIRE:
			# Crackles: noise modulated by another low-pass envelope
			for _i in frames:
				var env: float = clamp(0.6 + (randf() - 0.5) * 0.4, 0.0, 1.0)
				var s: float = (randf() - 0.5) * env * amp * 1.2
				playback.push_frame(Vector2(s, s))
		Track.WATER:
			# Bubbling: low sine + tiny irregular pops
			var freq: float = 90.0
			var step: float = TAU * freq / 22050.0
			for _i in frames:
				phase += step + randf() * 0.001
				var bubble: float = sin(phase) * 0.25
				var pop: float = (randf() - 0.5) * 0.15
				var s: float = (bubble + pop) * amp
				playback.push_frame(Vector2(s, s))
	_phases[track] = phase
