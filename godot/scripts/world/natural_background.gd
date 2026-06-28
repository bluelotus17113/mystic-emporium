extends Sprite2D
## Background del Patio Natural (4500×500). Anclado en NATURAL_LEFT_X y recortado vía region_rect.

func _ready() -> void:
	centered = false
	region_enabled = true
	ZoneExpansionManager.natural_level_changed.connect(_apply)
	_apply(ZoneExpansionManager.natural_level)


func _apply(level: int) -> void:
	var size: Vector2 = ZoneExpansionManager.get_size_for(level)
	position = Vector2(ZoneExpansionManager.NATURAL_LEFT_X, -size.y * 0.5)
	region_rect = Rect2(0, 0, min(size.x, 4500), min(size.y, 500))
