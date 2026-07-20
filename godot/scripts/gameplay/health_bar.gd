class_name HealthBar
extends Node2D
## Componente de vida reutilizable (ogros, torretas, base…): guarda HP, recibe
## daño y dibuja una barra flotante encima. Se muestra al recibir daño (o siempre
## si always_visible). Emite `died` al llegar a 0.

signal died
signal damaged(amount: float)

const BAR_W: float = 34.0
const BAR_H: float = 5.0

var max_hp: float = 100.0
var hp: float = 100.0
var bar_y: float = -46.0
var always_visible: bool = false
var _show_t: float = 0.0


func setup(mhp: float, y_off: float = -46.0, always: bool = false) -> void:
	max_hp = maxf(1.0, mhp)
	hp = max_hp
	bar_y = y_off
	always_visible = always
	z_index = 60
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_show_t = 2.5
	damaged.emit(amount)
	queue_redraw()
	if hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func is_alive() -> bool:
	return hp > 0.0


func _process(delta: float) -> void:
	if _show_t > 0.0:
		_show_t -= delta
		if _show_t <= 0.0:
			queue_redraw()


func _draw() -> void:
	var visible_now: bool = always_visible or _show_t > 0.0
	if not visible_now or hp >= max_hp and not always_visible:
		return
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var x: float = -BAR_W * 0.5
	draw_rect(Rect2(x - 1.0, bar_y - 1.0, BAR_W + 2.0, BAR_H + 2.0), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(x, bar_y, BAR_W, BAR_H), Color(0.22, 0.06, 0.06, 0.9))
	var col: Color
	if ratio > 0.5:
		col = Color(0.45, 0.9, 0.45)
	elif ratio > 0.25:
		col = Color(0.95, 0.8, 0.3)
	else:
		col = Color(0.95, 0.35, 0.3)
	draw_rect(Rect2(x, bar_y, BAR_W * ratio, BAR_H), col)
