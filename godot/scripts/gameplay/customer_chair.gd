class_name CustomerChair
extends Node2D
## Silla de espera. Cada una añade 1 al cupo de pedidos activos del OrderManager.
## El cliente camina a esta silla (en vez del counter) si hay una libre al spawn.

var occupied: bool = false


func _ready() -> void:
	add_to_group("customer_chairs")


func reserve() -> void:
	occupied = true


func release() -> void:
	occupied = false
