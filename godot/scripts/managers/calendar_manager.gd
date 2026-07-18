extends Node
## Calendario in-game con ciclo día/noche.
## 1 día = DAY_SECONDS reales. Compatible con eventos calendario (festival lunar, etc.).

signal day_changed(day: int, season_id: int)
signal phase_changed(phase: int)  ## NIGHT / DAWN / DAY / DUSK
signal season_changed(season_id: int)

enum Phase { DAWN, DAY, DUSK, NIGHT }
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const DAY_SECONDS: float = 240.0  ## 4 minutos reales = 1 día in-game
const DAYS_PER_SEASON: int = 8
const PHASE_RATIOS: Dictionary = {
	Phase.DAWN: 0.10,   # 0.00 - 0.10
	Phase.DAY: 0.55,    # 0.10 - 0.65
	Phase.DUSK: 0.10,   # 0.65 - 0.75
	Phase.NIGHT: 0.25,  # 0.75 - 1.00
}

var current_day: int = 1
var time_of_day: float = 0.25  ## 0.0-1.0 (mantengo para compat con save state)
var current_phase: int = Phase.DAY
var current_season: int = Season.SPRING

# ponytail: time_of_day se calcula del reloj real del PC, no del delta del juego.
# current_day avanza cuando cambia la fecha del sistema (sin offline-progression).
# Si en algún momento quieres modo "tiempo acelerado", swappea _process por el viejo
# acumulador `time_of_day += delta / DAY_SECONDS`.
var _last_system_date: int = -1  ## día del mes (1-31) visto en el último frame
var _sync_accum: float = 999.0  ## fuerza primer fetch en el frame 1


func _process(_delta: float) -> void:
	# ponytail: Time.get_*_dict_from_system aloca un Dictionary nuevo cada llamada.
	# 60Hz → 120 alocaciones/seg innecesarias. La resolución de un reloj de juego
	# no necesita más que 1Hz, así throttleamos a cada segundo.
	_sync_accum += _delta
	if _sync_accum >= 1.0:
		_sync_accum = 0.0
		var t: Dictionary = Time.get_time_dict_from_system()
		time_of_day = float(t.hour * 60 + t.minute) / 1440.0
		var d: Dictionary = Time.get_date_dict_from_system()
		if _last_system_date == -1:
			_last_system_date = d.day
		elif d.day != _last_system_date:
			_last_system_date = d.day
			_advance_day()
		_check_phase()


func _advance_day() -> void:
	current_day += 1
	var new_season: int = ((current_day - 1) / DAYS_PER_SEASON) % 4
	if new_season != current_season:
		current_season = new_season
		NotificationManager.post("Estación: %s" % _season_name(current_season), NotificationManager.Kind.INFO)
		season_changed.emit(current_season)
	NotificationManager.post("Día %d (%s)" % [current_day, _season_name(current_season)], NotificationManager.Kind.INFO)
	day_changed.emit(current_day, current_season)


func _check_phase() -> void:
	var new_phase: int
	if time_of_day < PHASE_RATIOS[Phase.DAWN]:
		new_phase = Phase.DAWN
	elif time_of_day < PHASE_RATIOS[Phase.DAWN] + PHASE_RATIOS[Phase.DAY]:
		new_phase = Phase.DAY
	elif time_of_day < PHASE_RATIOS[Phase.DAWN] + PHASE_RATIOS[Phase.DAY] + PHASE_RATIOS[Phase.DUSK]:
		new_phase = Phase.DUSK
	else:
		new_phase = Phase.NIGHT
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)


func get_phase_name() -> String:
	match current_phase:
		Phase.DAWN: return "Amanecer"
		Phase.DAY: return "Día"
		Phase.DUSK: return "Atardecer"
		Phase.NIGHT: return "Noche"
		_: return "—"


func _season_name(s: int) -> String:
	match s:
		Season.SPRING: return "Primavera"
		Season.SUMMER: return "Verano"
		Season.AUTUMN: return "Otoño"
		Season.WINTER: return "Invierno"
		_: return "—"


func get_clock_string() -> String:
	# Mapea 0..1 a 00:00..23:59
	var total_minutes: int = int(time_of_day * 1440.0)
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	return "%02d:%02d" % [hours, minutes]


func is_night() -> bool:
	return current_phase == Phase.NIGHT


## Oscuridad 0..1 según la hora real: 0 = mediodía, 1 = noche cerrada.
## Fuente única para faroles, grillos, luciérnagas y ventanas.
func get_darkness() -> float:
	var t: float = time_of_day
	if t < 0.24:
		return 1.0
	elif t < 0.32:
		return 1.0 - (t - 0.24) / 0.08
	elif t < 0.66:
		return 0.0
	elif t < 0.78:
		return (t - 0.66) / 0.12
	return 1.0


func get_ambient_modulate() -> Color:
	# Tinte global aplicable a la cámara/escenario según hora.
	match current_phase:
		Phase.DAWN: return Color(1.0, 0.85, 0.78, 1)
		Phase.DAY: return Color(1.0, 1.0, 1.0, 1)
		Phase.DUSK: return Color(1.0, 0.78, 0.65, 1)
		Phase.NIGHT: return Color(0.55, 0.6, 0.85, 1)
		_: return Color.WHITE


func get_save_state() -> Dictionary:
	return {
		"current_day": current_day,
		"time_of_day": time_of_day,
		"current_season": current_season,
	}


func load_save_state(data: Dictionary) -> void:
	current_day = data.get("current_day", 1)
	time_of_day = data.get("time_of_day", 0.25)
	current_season = data.get("current_season", Season.SPRING)


func reset_for_prestige() -> void:
	current_day = 1
	current_season = Season.SPRING
	# time_of_day se recalcula del PC en el próximo _process; no toco.
