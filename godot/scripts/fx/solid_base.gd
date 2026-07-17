class_name SolidBase
## Colisión "de pies": StaticBody2D con un rect pequeño en la base del objeto.
## Los personajes chocan con la base (no con todo el sprite), así pueden pasar
## por detrás visualmente pero no atravesarlo.


static func attach(node: Node2D, size: Vector2, offset: Vector2 = Vector2.ZERO) -> StaticBody2D:
	if node == null or node.get_node_or_null("SolidBase") != null:
		return null
	var body := StaticBody2D.new()
	body.name = "SolidBase"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	body.add_child(shape)
	node.add_child(body)
	return body


static func set_enabled(node: Node2D, enabled: bool) -> void:
	var body: StaticBody2D = node.get_node_or_null("SolidBase") as StaticBody2D
	if body != null:
		body.collision_layer = 1 if enabled else 0
