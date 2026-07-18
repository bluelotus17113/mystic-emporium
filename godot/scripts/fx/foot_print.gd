class_name FootPrint
extends RefCounted
## Huella temporal que dejan los personajes al cruzar nieve o desierto. Se
## desvanece sola. Estático: FootPrint.maybe(personaje) — comprueba el bioma.

const TEX: String = "res://art/sprites/fx/footprint.png"
static var _tex: Texture2D = null
static var _map: Node = null


static func maybe(host: Node2D) -> void:
	if host == null or not host.is_inside_tree():
		return
	if _map == null or not is_instance_valid(_map):
		_map = host.get_tree().get_first_node_in_group("biome_map")
	if _map == null or not _map.has_method("biome_at_world"):
		return
	var b: String = _map.biome_at_world(host.global_position)
	if b != "snow" and b != "desert":
		return
	if _tex == null:
		_tex = load(TEX)
	var parent: Node = host.get_parent()
	if parent == null:
		return
	var s := Sprite2D.new()
	s.texture = _tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(2, 2)
	s.z_index = -3
	s.rotation = host.velocity.angle() + PI * 0.5 if "velocity" in host else 0.0
	s.modulate = Color(0.25, 0.28, 0.38, 0.5) if b == "snow" else Color(0.42, 0.3, 0.16, 0.5)
	parent.add_child(s)
	s.global_position = host.global_position + Vector2(0, -2)
	var tw := s.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(s, "modulate:a", 0.0, 2.2)
	tw.tween_callback(s.queue_free)
