extends Node
## Diagnóstico: ¿se cruzan los ayudantes lo bastante para que la vida social exista?
##
## Antes de meter personalidades MBTI, afinidades y conflictos hay que responder una
## pregunta que nadie ha medido: **cuántas veces se encuentran dos ayudantes
## concretos**. Hoy hacen falta 5 encuentros con el mismo compañero para que el saludo
## cambie (`vida_social.gd`, UMBRAL_AMIGO), con 12 s de enfriamiento entre saludos.
##
## Si el par medio se cruza una vez por hora, nadie será amigo nunca y todo lo social
## que construyamos encima será decorado invisible. Si se cruzan cada dos minutos, el
## umbral se queda corto y todos serán amigos enseguida, que también lo vacía.
##
## Bandera: `--diagencuentros`. Está en SaveManager.BANDERAS_DIAGNOSTICO, así que el
## arranque es de SOLO LECTURA: en este repo hay precedente de un diagnóstico que
## sobrescribió una partida de 341 construcciones.
##
##     godot --headless -- --diagencuentros=180
##
## El número es cuántos segundos simular (por defecto 120).

const INTERVALO: float = 0.5   ## cada cuánto se toma una muestra de proximidad

var _segundos: float = 120.0
var _t: float = 0.0
var _muestreo: float = 0.0
## par ordenado "a|b" -> veces que han estado dentro del radio de saludo
var _cruces: Dictionary = {}
var _por_worker: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--diagencuentros="):
			_segundos = float(a.split("=")[1])
	print("[DiagEnc] midiendo %d s de partida…" % _segundos)


func _process(delta: float) -> void:
	_t += delta
	_muestreo -= delta
	if _muestreo <= 0.0:
		_muestreo = INTERVALO
		_muestrear()
	if _t >= _segundos:
		_informe()
		get_tree().quit()


## Cuenta qué parejas están ahora mismo dentro del radio en el que se saludarían.
## No cuenta saludos reales —esos los limita el enfriamiento de 12 s— sino
## OPORTUNIDADES: si dos nunca coinciden en el radio, el enfriamiento da igual.
func _muestrear() -> void:
	var ws: Array = []
	for w in get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(w) and (w as Node2D).visible:
			ws.append(w)
	for i in ws.size():
		for j in range(i + 1, ws.size()):
			var a: Node2D = ws[i]
			var b: Node2D = ws[j]
			if a.global_position.distance_to(b.global_position) >= VidaSocial.GREET_RADIUS:
				continue
			var na: String = String(a.get("worker_name"))
			var nb: String = String(b.get("worker_name"))
			var clave: String = "%s|%s" % ([na, nb] if na < nb else [nb, na])
			_cruces[clave] = _cruces.get(clave, 0) + 1
			_por_worker[na] = _por_worker.get(na, 0) + 1
			_por_worker[nb] = _por_worker.get(nb, 0) + 1


func _informe() -> void:
	var n: int = get_tree().get_nodes_in_group("workers").size()
	var pares_posibles: int = n * (n - 1) / 2
	print("\n===== ENCUENTROS EN %d s =====" % _segundos)
	print("ayudantes vivos: %d   pares posibles: %d" % [n, pares_posibles])
	print("pares que llegaron a coincidir: %d de %d" % [_cruces.size(), pares_posibles])
	if _cruces.is_empty():
		print("NINGÚN par coincidió. La vida social es invisible con esta configuración.")
		return
	var vals: Array = _cruces.values()
	vals.sort()
	var total: int = 0
	for v in vals:
		total += v
	print("muestras de proximidad por par: mín %d · mediana %d · máx %d · media %.1f" % [
		vals[0], vals[vals.size() / 2], vals[-1], float(total) / vals.size()])
	# Lo que de verdad importa: a este ritmo, ¿cuánto tarda un par en llegar a 5
	# saludos? Cada saludo necesita coincidir Y que haya pasado el enfriamiento.
	var por_seg: float = float(vals[vals.size() / 2]) * INTERVALO / _segundos
	if por_seg > 0.0:
		var seg_por_saludo: float = maxf(VidaSocial.GREET_COOLDOWN, 1.0 / por_seg)
		print("par MEDIANO: coincide el %.1f%% del tiempo → ~%.0f s por saludo" % [
			por_seg * 100.0, seg_por_saludo])
		print("→ llegar a UMBRAL_AMIGO(%d) le costaría ~%.0f min de juego" % [
			VidaSocial.UMBRAL_AMIGO, seg_por_saludo * VidaSocial.UMBRAL_AMIGO / 60.0])
	print("\ntop 5 parejas:")
	var claves: Array = _cruces.keys()
	claves.sort_custom(func(x, y): return _cruces[x] > _cruces[y])
	for k in claves.slice(0, 5):
		print("  %-28s %d muestras" % [k, _cruces[k]])
	print("=====================================\n")
