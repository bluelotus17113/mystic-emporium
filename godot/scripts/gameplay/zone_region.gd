@tool
class_name ZoneRegion
extends Node2D
## Pinta visualmente una zona (rect coloreado) y la registra en el GridManager
## en _ready para que la lógica de construcción la respete.

@export var zone_type: GameEnums.ZoneType = GameEnums.ZoneType.NATURE
@export var size: Vector2 = Vector2(480, 240):
	set(value):
		size = value
		_refresh_visual()
@export var fill_color: Color = Color(0.25, 0.55, 0.25, 0.18):
	set(value):
		fill_color = value
		_refresh_visual()
@export var border_color: Color = Color(0.3, 0.7, 0.3, 0.6):
	set(value):
		border_color = value
		_refresh_visual()
@export var label_text: String = "Natural":
	set(value):
		label_text = value
		if is_inside_tree() and _label != null:
			_label.text = label_text

var _fill: Polygon2D
var _border_top: Polygon2D
var _border_bottom: Polygon2D
var _border_left: Polygon2D
var _border_right: Polygon2D
var _label: Label


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	GridManager.register_zone_rect(zone_type, Rect2(global_position - size * 0.5, size))
	# ponytail: solo Natural se redimensiona dinámicamente; las otras quedan fijas.
	if zone_type == GameEnums.ZoneType.NATURE:
		ZoneExpansionManager.natural_level_changed.connect(_on_natural_level_changed)
		_apply_natural_level(ZoneExpansionManager.natural_level)


func _on_natural_level_changed(new_level: int) -> void:
	_apply_natural_level(new_level)


func _apply_natural_level(level: int) -> void:
	size = ZoneExpansionManager.get_size_for(level)
	position = ZoneExpansionManager.get_center_for(level)
	GridManager.register_zone_rect(zone_type, Rect2(global_position - size * 0.5, size))


func _build_visual() -> void:
	if _fill != null:
		return
	_fill = Polygon2D.new()
	_fill.color = fill_color
	add_child(_fill)
	_border_top = Polygon2D.new()
	_border_top.color = border_color
	add_child(_border_top)
	_border_bottom = Polygon2D.new()
	_border_bottom.color = border_color
	add_child(_border_bottom)
	_border_left = Polygon2D.new()
	_border_left.color = border_color
	add_child(_border_left)
	_border_right = Polygon2D.new()
	_border_right.color = border_color
	add_child(_border_right)
	_label = Label.new()
	_label.modulate = border_color
	_label.text = label_text
	add_child(_label)
	_refresh_visual()


func _refresh_visual() -> void:
	if _fill == null:
		return
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	_fill.color = fill_color
	_fill.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	const T: float = 2.0
	_border_top.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + T), Vector2(-hw, -hh + T)
	])
	_border_bottom.polygon = PackedVector2Array([
		Vector2(-hw, hh - T), Vector2(hw, hh - T), Vector2(hw, hh), Vector2(-hw, hh)
	])
	_border_left.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(-hw + T, -hh), Vector2(-hw + T, hh), Vector2(-hw, hh)
	])
	_border_right.polygon = PackedVector2Array([
		Vector2(hw - T, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(hw - T, hh)
	])
	_border_top.color = border_color
	_border_bottom.color = border_color
	_border_left.color = border_color
	_border_right.color = border_color
	_label.position = Vector2(-hw + 6, -hh + 4)
	_label.modulate = border_color
