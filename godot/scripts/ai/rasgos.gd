class_name Rasgos
## Funciones puras que modulan constantes según el rasgo del ayudante.
## worker_base.gd las llama sin conocer los detalles de cada modulación.


## Un curioso no tiene recurso favorito: todos los tipos pesan igual.
## base es FAVORITE_BIAS (0.45), que reduce la distancia² ~33 % del favorito.
## Devolver 1.0 anula el sesgo: gana el nodo más cercano siempre.
static func sesgo_favorito(wtrait: int, base: float) -> float:
	if wtrait == WorkerBase.Trait.CURIOSO:
		return 1.0
	return base


## Umbral de energía al que el ayudante deja de descansar y vuelve al trabajo.
## base es REST_RECOVER_TO (0.55). Un diligente vuelve un 45 % antes (0.30),
## así descansa ~1.3 s en sitio cálido en vez de ~2.4 s: se nota a simple vista.
static func recuperar_hasta(wtrait: int, base: float) -> float:
	if wtrait == WorkerBase.Trait.DILIGENTE:
		return base * 0.55
	return base


## Multiplicador del radio de merodeo. base = 1.0 (el _wander_mult por defecto).
## Enérgico ×1.5: se aleja más buscando tarea, no se queda pegado a casa.
## Curioso ×1.6: mantiene el valor que ya tenía en worker_base:259.
static func radio_merodeo(wtrait: int, base: float) -> float:
	if wtrait == WorkerBase.Trait.ENERGICO:
		return base * 1.5
	if wtrait == WorkerBase.Trait.CURIOSO:
		return base * 1.6
	return base


## ¿Le toca siesta al dormilón? True = parar a mitad de jornada (💤), no en casa,
## recuperar unos segundos y seguir. Solo de día, con energía baja pero no agotada.
##   - energía < 0.25: ~mitad del ciclo de trabajo (desde 0.55 post-descanso),
##     así la siesta cae una vez por ciclo y no oscila
##   - energía > 0.05: no compite con el descanso forzoso de energía 0
## La llama _maybe_sleep / _update_energy tras comprobar !_resting && !_sleeping.
static func quiere_siesta(wtrait: int, energia: float, es_de_dia: bool) -> bool:
	if wtrait != WorkerBase.Trait.DORMILON:
		return false
	return es_de_dia and energia < 0.25 and energia > 0.05
