class_name Workstation
extends Node2D

signal craft_started(recipe: RecipeData)
signal craft_progress(recipe: RecipeData, percent: float)
signal craft_completed(recipe: RecipeData)
signal upgraded(new_level: int)

@export var station_type: GameEnums.StationType = GameEnums.StationType.CAULDRON
@export var available_recipes: Array[RecipeData] = []

@export_group("Upgrades")
@export var crafting_time_multiplier: float = 1.0
@export var current_level: int = 1
@export var upgrade_cost: int = 100
const UPGRADE_TIME_REDUCTION: float = 0.85
const UPGRADE_COST_MULTIPLIER: float = 1.75
const MAX_LEVEL: int = 5

var _current_recipe: RecipeData = null
var _is_crafting: bool = false
var _craft_timer: float = 0.0
## Override por-estación del auto-craft. Cuando IdleAutomationManager itera
## stations, se salta las que tengan esto en false. El toggle global de
## auto_craft sigue funcionando; este es un filtro fino encima.
var auto_craft_enabled: bool = true

signal auto_craft_changed(enabled: bool)

# Idle "respiración" del sprite — más sutil cuando idle, más intenso al craftear.
var _bob_time: float = 0.0
var _sprite: Node2D = null
var _sprite_base_y: float = 0.0
var _sprite_base_scale: Vector2 = Vector2.ONE


var _hover_label: Label = null


func _ready() -> void:
	add_to_group("workstations")
	WorkstationManager.register(self)
	# Colisión de pies: los personajes no atraviesan la estación. El mostrador
	# queda libre para que los clientes lleguen sin chocar.
	if station_type != GameEnums.StationType.COUNTER:
		SolidBase.attach(self, Vector2(44, 16), Vector2(0, 6))
	var area: Area2D = get_node_or_null("Area2D") as Area2D
	if area != null:
		area.input_event.connect(_on_area_input_event)
		area.mouse_entered.connect(_on_hover_enter)
		area.mouse_exited.connect(_on_hover_exit)
	_sprite = get_node_or_null("AnimatedSprite2D")
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D")
	if _sprite != null:
		_sprite_base_y = _sprite.position.y
		_sprite_base_scale = _sprite.scale
		_bob_time = randf() * TAU  # offset así no se sincronizan todas
	_build_hover_label()
	_setup_positional_loop()


## Sonido ambiental posicional: el caldero burbujea y la forja cruje
## solo cuando la cámara está cerca (atenuación 2D).
func _setup_positional_loop() -> void:
	var loop_key: StringName
	match station_type:
		GameEnums.StationType.CAULDRON:
			loop_key = &"ambient_cauldron"
		GameEnums.StationType.MYSTIC_FORGE:
			loop_key = &"ambient_fire"
		_:
			return
	var stream: AudioStream = AudioManager.get_loop_stream(loop_key)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = -16.0
	p.max_distance = 520.0
	p.attenuation = 1.4
	add_child(p)
	p.play()


func _build_hover_label() -> void:
	_hover_label = Label.new()
	_hover_label.position = Vector2(-70, -80)
	_hover_label.custom_minimum_size = Vector2(140, 0)
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.add_theme_font_size_override(&"font_size", 11)
	_hover_label.add_theme_color_override(&"font_color", Color(1, 0.95, 0.7, 1))
	_hover_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_hover_label.add_theme_constant_override(&"outline_size", 4)
	_hover_label.visible = false
	_hover_label.z_index = 100
	add_child(_hover_label)


func _on_hover_enter() -> void:
	if _hover_label != null:
		_hover_label.visible = true
		_refresh_hover_text()


func _on_hover_exit() -> void:
	if _hover_label != null:
		_hover_label.visible = false


func _refresh_hover_text() -> void:
	if _hover_label == null or not _hover_label.visible:
		return
	var lines: Array[String] = []
	lines.append("%s · Nv %d" % [_station_display_name(), current_level])
	if _is_crafting and _current_recipe != null:
		var total: float = _current_recipe.crafting_time * crafting_time_multiplier
		var remaining: float = max(0.0, total - _craft_timer)
		lines.append("⚗ %s" % _current_recipe.display_name)
		lines.append("⏱ %.1fs" % remaining)
	elif _has_craftable_recipe():
		lines.append("✓ Receta disponible")
	else:
		lines.append("— sin recetas")
	if current_level < MAX_LEVEL:
		lines.append("⬆ %d⚜" % upgrade_cost)
	_hover_label.text = "\n".join(lines)


func _station_display_name() -> String:
	match station_type:
		GameEnums.StationType.CAULDRON: return "⚗ Caldero"
		GameEnums.StationType.MYSTIC_FORGE: return "🔨 Forja"
		GameEnums.StationType.ENCHANTING_TABLE: return "✨ Encantamiento"
		GameEnums.StationType.SCRIBE_DESK: return "📜 Escritorio"
		GameEnums.StationType.SUMMONING_CIRCLE: return "🔮 Invocación"
		GameEnums.StationType.ARCANE_LIBRARY: return "📚 Biblioteca"
		GameEnums.StationType.ASTRO_OBSERVATORY: return "🔭 Observatorio"
		_: return "Estación"


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# En modo obra (colocar/mover/rotar/demoler) la estación es un objeto más:
	# no abrir su panel; el clic lo gestiona BuildManager.
	if BuildManager.is_active() or BuildManager.is_move_active() 			or BuildManager.is_rotate_active() or BuildManager.is_demolish_active():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		WorkstationManager.workstation_clicked.emit(self)


func _exit_tree() -> void:
	WorkstationManager.unregister(self)


func _process(delta: float) -> void:
	_apply_idle_bob(delta)
	if _hover_label != null and _hover_label.visible:
		_refresh_hover_text()
	if not _is_crafting or _current_recipe == null:
		return
	_craft_timer += delta
	var total: float = _current_recipe.crafting_time * crafting_time_multiplier
	craft_progress.emit(_current_recipe, clamp(_craft_timer / total, 0.0, 1.0))
	if _craft_timer >= total:
		_finish_craft()


func _apply_idle_bob(delta: float) -> void:
	if _sprite == null:
		return
	_bob_time += delta
	# Idle: amplitude pequeño y frecuencia lenta (respiración)
	# Crafteando: amplitude mayor y frecuencia más rápida (esfuerzo)
	var amp: float = 2.5 if _is_crafting else 1.0
	var freq: float = 4.0 if _is_crafting else 1.6
	_sprite.position.y = _sprite_base_y + sin(_bob_time * freq) * amp
	# Halo dorado pulsante cuando idle Y hay receta crafteable: invita a usarla.
	if not _is_crafting and _has_craftable_recipe():
		var pulse: float = 0.5 + 0.5 * sin(_bob_time * 3.0)
		_sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.35, 1.20, 0.75), pulse * 0.55)
	elif _sprite.modulate != Color.WHITE:
		_sprite.modulate = Color.WHITE


func _has_craftable_recipe() -> bool:
	for r in get_filtered_recipes():
		if r != null and InventoryManager.has_items(r.get_ingredient_pairs()):
			return true
	return false


func get_filtered_recipes() -> Array[RecipeData]:
	# Combina recetas pre-asignadas (Inspector) y desbloqueadas globalmente
	# por el RecipeManager, sin duplicados.
	var result: Array[RecipeData] = []
	for r in available_recipes:
		if r != null and r.required_station_type == station_type:
			result.append(r)
	for r in RecipeManager.get_unlocked_for_station(station_type):
		if r not in result:
			result.append(r)
	return result


func is_ready_to_work() -> bool:
	return not _is_crafting


func start_craft(recipe: RecipeData) -> bool:
	if recipe == null or _is_crafting:
		return false
	if recipe.required_station_type != station_type:
		return false
	var pairs: Array = recipe.get_ingredient_pairs()
	if not InventoryManager.consume_items(pairs):
		return false
	_current_recipe = recipe
	_is_crafting = true
	_craft_timer = 0.0
	craft_started.emit(recipe)
	return true


func _finish_craft() -> void:
	if _current_recipe != null and _current_recipe.output_item != null:
		InventoryManager.add_item(_current_recipe.output_item, _current_recipe.output_quantity)
		StatsManager.bump("items_crafted_total", _current_recipe.output_quantity)
	var finished: RecipeData = _current_recipe
	_current_recipe = null
	_is_crafting = false
	_craft_timer = 0.0
	VFXManager.play(VFXManager.FX.CRAFT_DONE, global_position)
	if station_type == GameEnums.StationType.MYSTIC_FORGE:
		AudioManager.play_named(&"forge")
	else:
		AudioManager.play_named(&"bubble")
	_play_finish_pop()
	craft_completed.emit(finished)


func _play_finish_pop() -> void:
	# Squash & stretch sutil al completar — el caldero "salta" con satisfacción.
	if _sprite == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", _sprite_base_scale * 1.18, 0.12)
	tw.tween_property(_sprite, "scale", _sprite_base_scale, 0.20)


func get_state_dict() -> Dictionary:
	# Serializa el estado mutable de la station. La identidad (qué station es)
	# la resuelve WorkstationManager por grid_pos, no por esta dict.
	var recipe_id: String = ""
	if _is_crafting and _current_recipe != null:
		recipe_id = String(_current_recipe.id)
	return {
		"level": current_level,
		"time_mult": crafting_time_multiplier,
		"upgrade_cost": upgrade_cost,
		"crafting": _is_crafting,
		"recipe_id": recipe_id,
		"craft_timer": _craft_timer,
		"auto_craft": auto_craft_enabled,
	}


func apply_state_dict(d: Dictionary) -> void:
	current_level = int(d.get("level", 1))
	crafting_time_multiplier = float(d.get("time_mult", 1.0))
	upgrade_cost = int(d.get("upgrade_cost", upgrade_cost))
	auto_craft_enabled = bool(d.get("auto_craft", true))
	if bool(d.get("crafting", false)):
		var rid: String = d.get("recipe_id", "")
		if rid != "":
			var recipe: RecipeData = RecipeManager.find_recipe_by_id(StringName(rid))
			if recipe != null:
				_current_recipe = recipe
				_is_crafting = true
				_craft_timer = float(d.get("craft_timer", 0.0))
				craft_started.emit(recipe)


func set_auto_craft(enabled: bool) -> void:
	if auto_craft_enabled == enabled:
		return
	auto_craft_enabled = enabled
	auto_craft_changed.emit(enabled)


func try_upgrade() -> bool:
	if current_level >= MAX_LEVEL:
		return false
	if not InventoryManager.spend_coins(upgrade_cost):
		return false
	current_level += 1
	crafting_time_multiplier *= UPGRADE_TIME_REDUCTION
	upgrade_cost = int(upgrade_cost * UPGRADE_COST_MULTIPLIER)
	VFXManager.play(VFXManager.FX.UPGRADE, global_position)
	AudioManager.play_beep(1240.0, 0.15, -10.0)
	StatsManager.bump("upgrades_done", 1)
	upgraded.emit(current_level)
	return true
