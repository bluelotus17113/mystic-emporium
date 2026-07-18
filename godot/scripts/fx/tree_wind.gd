class_name TreeWind
extends Sprite2D
## Árbol que mece su copa con el viento: aplica un 'skew' sutil que inclina la
## parte alta del sprite mientras la base (el origen) queda fija en el suelo.
## El desfase por posición hace que la ráfaga recorra el patio como una onda.

var phase: float = 0.0
var amp: float = 0.05  ## radianes de inclinación (~3°): sutil, no caricaturesco
var speed: float = 1.1


func _process(_delta: float) -> void:
	skew = Wind.sway(phase, speed) * amp
