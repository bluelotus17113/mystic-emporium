extends Node
## Álbum de clientes: registra qué skins de NPC han sido atendidas (pedido
## completado) y cuántas veces. Los no descubiertos se muestran como silueta.

signal album_updated(skin: StringName)

## skin base_name ("npc_aldeano") -> nº de pedidos completados a ese cliente
var served: Dictionary = {}


func record(skin: StringName) -> void:
	if skin == &"":
		return
	served[skin] = int(served.get(skin, 0)) + 1
	album_updated.emit(skin)


func is_discovered(skin: StringName) -> bool:
	return served.has(skin)


func get_count(skin: StringName) -> int:
	return int(served.get(skin, 0))


func discovered_total() -> int:
	return served.size()


func get_save_state() -> Dictionary:
	var out: Dictionary = {}
	for k in served:
		out[String(k)] = served[k]
	return {"served": out}


func load_save_state(state: Dictionary) -> void:
	served.clear()
	var s: Dictionary = state.get("served", {})
	for k in s:
		served[StringName(k)] = int(s[k])
