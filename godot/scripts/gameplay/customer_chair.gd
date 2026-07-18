class_name CustomerChair
extends Node2D
## Silla de espera. Añade 1 al cupo de pedidos activos. Muestra el sprite de
## silla según su dirección (rotación del build) y expone `facing` para que el
## cliente se siente mirando hacia donde apunta la silla.

const TEX: Dictionary = {
	&"down":  "res://art/sprites/environment/customer_chair_down.png",
	&"up":    "res://art/sprites/environment/customer_chair_up.png",
	&"left":  "res://art/sprites/environment/customer_chair_left.png",
	&"right": "res://art/sprites/environment/customer_chair_right.png",
}
const DEG_TO_FACING: Dictionary = {0: &"down", 90: &"left", 180: &"up", 270: &"right"}

var occupied: bool = false
var facing: StringName = &""
@onready var _spr: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("customer_chairs")
	_apply_facing()


func _process(_delta: float) -> void:
	# El build-rotate cambia rotation_degrees; el sprite se mantiene recto y
	# cambiamos la textura direccional en su lugar.
	_apply_facing()


func _apply_facing() -> void:
	if _spr == null:
		return
	_spr.rotation = -rotation  # sprite siempre vertical pese a la rotación del nodo
	var deg: int = int(round(rotation_degrees / 90.0)) * 90
	deg = ((deg % 360) + 360) % 360
	var f: StringName = DEG_TO_FACING.get(deg, &"down")
	if f != facing:
		facing = f
		var path: String = TEX.get(f, TEX[&"down"])
		if ResourceLoader.exists(path):
			_spr.texture = load(path)


func reserve() -> void:
	occupied = true


func release() -> void:
	occupied = false
