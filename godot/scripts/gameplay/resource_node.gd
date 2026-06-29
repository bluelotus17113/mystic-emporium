class_name ResourceNode
extends Node2D

@export var item_data: ItemData
@export var resource_type: GameEnums.ResourceType = GameEnums.ResourceType.HERB
@export var yield_quantity: int = 1
@export var respawn_after_collect: bool = false
@export var respawn_time: float = 0.0

var _is_collected: bool = false
var _generator_owner: Node = null
## Worker que reservó este nodo. Otros workers lo ignoran y wander en su lugar.
var _reserved_by: Node = null

signal collected(node: ResourceNode)


func _ready() -> void:
	add_to_group("resource_nodes")
	# Diferir el registro: el generator hace add_child y SOLO DESPUÉS setea
	# global_position. Si registramos en _ready, los workers ven el nodo en
	# la pos del parent (0,0 raíz) y caminan fuera del mapa un frame antes
	# de que el reposicionamiento ocurra.
	call_deferred("_deferred_register")


func _deferred_register() -> void:
	if is_inside_tree():
		ResourceManager.register_node(self)


func _exit_tree() -> void:
	ResourceManager.unregister_node(self)


func is_available() -> bool:
	# IMPORTANTE: no chequear `visible`. La zona-camera oculta nodos para render
	# (estás mirando otra zona) pero gameplay sigue corriendo. Si filtráramos por
	# visible, los workers en una zona no recogerían recursos en otra cuando el
	# jugador se mueve. El gating real por desbloqueo lo hace resource_generator
	# vía set_process(false) cuando la zona no alcanzó el nivel necesario.
	return not _is_collected


func collect() -> bool:
	if _is_collected:
		return false
	_is_collected = true
	hide()
	set_process(false)
	# Add to central inventory
	if item_data != null:
		InventoryManager.add_item(item_data, yield_quantity)
		StatsManager.bump("items_collected_total", yield_quantity)
		print("[Collect] +%d %s" % [yield_quantity, item_data.display_name])
	VFXManager.play(VFXManager.FX.COLLECT, global_position)
	collected.emit(self)
	# Notify owner generator (so it can start its cooldown)
	if _generator_owner != null and _generator_owner.has_method("on_node_collected"):
		_generator_owner.on_node_collected(self)
	if respawn_after_collect and _generator_owner == null:
		await get_tree().create_timer(respawn_time).timeout
		_respawn()
	return true


func _respawn() -> void:
	_is_collected = false
	_reserved_by = null
	show()
	set_process(true)


func respawn() -> void:
	_respawn()


func set_generator_owner(owner_node: Node) -> void:
	_generator_owner = owner_node


func reserve(by: Node) -> bool:
	# Solo reserva si no está reservado por otro vivo.
	if _reserved_by != null and is_instance_valid(_reserved_by) and _reserved_by != by:
		return false
	_reserved_by = by
	return true


func release(by: Node) -> void:
	if _reserved_by == by:
		_reserved_by = null


func is_reserved_for_other(by: Node) -> bool:
	return _reserved_by != null and is_instance_valid(_reserved_by) and _reserved_by != by


func _respawn_reset_reservation() -> void:
	_reserved_by = null
