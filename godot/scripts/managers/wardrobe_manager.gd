extends Node
## Vestuario de la protagonista: outfit actual + catálogo. Cada outfit es una
## hoja completa protagonist_outfit_<id>.png (mismo layout que protagonist_anim).

signal outfit_changed(outfit_id: StringName)

## id -> nombre visible. "default" usa la hoja original protagonist_anim.png.
const OUTFITS: Dictionary = {
	&"default": "Bruja clásica",
	&"primavera": "Primavera floral",
	&"verano": "Verano ligero",
	&"otono": "Otoño acogedor",
	&"invierno": "Invierno abrigado",
	&"alquimista": "Alquimista",
	&"maga_oscura": "Maga oscura",
	&"celeste": "Maga celeste",
	&"pijama": "Pijama",
	&"jardinera": "Jardinera",
	&"gala": "Gala elegante",
}

var current_outfit: StringName = &"default"


func sheet_path(outfit_id: StringName) -> String:
	if outfit_id == &"default":
		return "res://art/sprites/characters/protagonist_anim.png"
	return "res://art/sprites/characters/protagonist_outfit_%s.png" % outfit_id


func is_available(outfit_id: StringName) -> bool:
	return ResourceLoader.exists(sheet_path(outfit_id))


func set_outfit(outfit_id: StringName) -> void:
	if not OUTFITS.has(outfit_id) or not is_available(outfit_id):
		return
	current_outfit = outfit_id
	outfit_changed.emit(outfit_id)


func get_save_state() -> Dictionary:
	return {"outfit": String(current_outfit)}


func load_save_state(state: Dictionary) -> void:
	var o: StringName = StringName(state.get("outfit", "default"))
	if OUTFITS.has(o) and is_available(o):
		current_outfit = o
		outfit_changed.emit(o)
