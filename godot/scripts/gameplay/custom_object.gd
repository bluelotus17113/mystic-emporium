extends Node2D
## Objeto creado por el jugador (Abracadabra). Genérico: al colocarse lee su
## textura y tipo (solid/floor) desde CustomObjectManager por custom_id.
## BuildManager setea custom_id ANTES de add_child, así _ready ya lo tiene.

@export var custom_id: StringName = &""


func _ready() -> void:
	y_sort_enabled = true
	var data: Dictionary = CustomObjectManager.get_object(custom_id)
	if data.is_empty():
		return
	var tex: Texture2D = CustomObjectManager.get_texture(custom_id)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	add_child(spr)
	# Tipo sólido → colisión de pies; alfombra (floor) → se puede atravesar.
	if String(data.get("type", "solid")) == "solid":
		SolidBase.attach(self, Vector2(24.0, 12.0), Vector2(0, 6))
	else:
		# Alfombras/suelos siempre por debajo de personajes y objetos (no y-sort).
		z_index = -5
