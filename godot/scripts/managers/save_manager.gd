extends Node
## Sistema de guardado con 3 slots. Compatibilidad con saves antiguas
## (un único savegame.json en la raíz de user://).

const SLOT_COUNT: int = 3
const SAVE_VERSION: int = 2
const LEGACY_PATH: String = "user://savegame.json"

signal game_saved(slot: int)
signal game_loaded(slot: int)

var current_slot: int = 0

## Set por main_menu antes de change_scene. game_bootstrap lo consume al final
## de _ready() para garantizar que BuildManager/WorkstationManager.load_save_state
## reinstancien sobre la escena correcta (main_game), no sobre main_menu.
var pending_load_slot: int = -1


const AUTOSAVE_INTERVAL: float = 120.0  ## autosave cada 2 min + al cambiar de día
var _autosave_accum: float = 0.0
var _world_ready: bool = false  ## no autosavear en el menú principal


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_migrate_legacy()
	# Autosave al terminar cada día del juego (solo con partida activa).
	CalendarManager.day_changed.connect(func(_d, _s):
		if _world_ready:
			save_game())


func mark_world_ready(ready: bool = true) -> void:
	_world_ready = ready
	_autosave_accum = 0.0


func _process(delta: float) -> void:
	if not _world_ready:
		return
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


func _slot_tmp_path(slot: int) -> String:
	return "user://save_slot_%d.json.tmp" % slot


func _slot_bak_path(slot: int) -> String:
	return "user://save_slot_%d.json.bak" % slot


func _migrate_legacy() -> void:
	if FileAccess.file_exists(LEGACY_PATH) and not FileAccess.file_exists(_slot_path(0)):
		var f := FileAccess.open(LEGACY_PATH, FileAccess.READ)
		if f == null:
			return
		var raw: String = f.get_as_text()
		f.close()
		var out := FileAccess.open(_slot_path(0), FileAccess.WRITE)
		if out == null:
			return
		out.store_string(raw)
		out.close()
		print("[Save] Migrated legacy save to slot 0.")


func select_slot(slot: int) -> void:
	current_slot = clamp(slot, 0, SLOT_COUNT - 1)


func save_game(slot: int = -1) -> void:
	if slot < 0:
		slot = current_slot
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"inventory": InventoryManager.get_save_state(),
		"upgrades": EmporiumUpgradeManager.get_save_state(),
		"siege": SiegeManager.get_save_state(),
		"stats": StatsManager.get_save_state(),
		"calendar": CalendarManager.get_save_state(),
		"recipes": RecipeManager.get_save_state(),
		"research": ResearchManager.get_save_state(),
		"build": BuildManager.get_save_state(),
		"idle": IdleAutomationManager.get_save_state(),
		"prestige": PrestigeManager.get_save_state(),
		"daily_quest": DailyQuestManager.get_save_state(),
		"album": AlbumManager.get_save_state(),
		"wardrobe": WardrobeManager.get_save_state(),
		"zones": ZoneExpansionManager.get_save_state(),
		"tutorial": TutorialManager.get_save_state(),
		"audio": AudioManager.get_save_state(),
		"ending": EndingManager.get_save_state(),
		"workstations": WorkstationManager.get_save_state(),
		"orders": OrderManager.get_save_state(),
		"event": EventManager.get_save_state(),
		"shop": ShopManager.get_save_state(),
	}
	var path: String = _slot_path(slot)
	var tmp_path: String = _slot_tmp_path(slot)
	var bak_path: String = _slot_bak_path(slot)
	# 1) Escribir a .tmp. Si esto falla, el slot real queda intacto.
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[Save] Could not open tmp: %s" % tmp_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# 2) Rotar el slot anterior a .bak (descarta .bak previo si existe).
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("[Save] Could not open user:// dir")
		return
	if dir.file_exists(path.get_file()):
		if dir.file_exists(bak_path.get_file()):
			dir.remove(bak_path.get_file())
		dir.rename(path.get_file(), bak_path.get_file())
	# 3) Promover .tmp → slot real.
	dir.rename(tmp_path.get_file(), path.get_file())
	current_slot = slot
	print("[Save] Saved slot %d → %s" % [slot, path])
	game_saved.emit(slot)


func _read_and_parse(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


func load_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_slot
	var path: String = _slot_path(slot)
	var parsed = _read_and_parse(path)
	if parsed == null:
		# Slot ausente o corrupto. Probar .bak (escritura anterior).
		var bak: String = _slot_bak_path(slot)
		parsed = _read_and_parse(bak)
		if parsed == null:
			if FileAccess.file_exists(path):
				push_error("[Save] Corrupt slot %d and no usable .bak" % slot)
			else:
				print("[Save] No save in slot %d" % slot)
			return false
		push_warning("[Save] Slot %d corrupt — recovered from .bak" % slot)
	if parsed.has("inventory"):
		InventoryManager.load_save_state(parsed.inventory)
	if parsed.has("upgrades"):
		EmporiumUpgradeManager.load_save_state(parsed.upgrades)
	if parsed.has("siege"):
		SiegeManager.load_save_state(parsed.siege)
	if parsed.has("stats"):
		StatsManager.load_save_state(parsed.stats)
	if parsed.has("calendar"):
		CalendarManager.load_save_state(parsed.calendar)
	if parsed.has("recipes"):
		RecipeManager.load_save_state(parsed.recipes)
	# ponytail: research va antes que build para que los unlocks reapliquen primero
	# por si algún building se desbloqueó vía investigación completada.
	if parsed.has("research"):
		ResearchManager.load_save_state(parsed.research)
	if parsed.has("build"):
		BuildManager.load_save_state(parsed.build)
	if parsed.has("prestige"):
		PrestigeManager.load_save_state(parsed.prestige)
	if parsed.has("daily_quest"):
		DailyQuestManager.load_save_state(parsed.daily_quest)
	if parsed.has("album"):
		AlbumManager.load_save_state(parsed.album)
	if parsed.has("wardrobe"):
		WardrobeManager.load_save_state(parsed.wardrobe)
	if parsed.has("zones"):
		ZoneExpansionManager.load_save_state(parsed.zones)
	if parsed.has("idle"):
		IdleAutomationManager.load_save_state(parsed.idle)
	if parsed.has("tutorial"):
		TutorialManager.load_save_state(parsed.tutorial)
	if parsed.has("audio"):
		AudioManager.load_save_state(parsed.audio)
	if parsed.has("ending"):
		EndingManager.load_save_state(parsed.ending)
	# WorkstationManager debe ir DESPUÉS de BuildManager: éste reinstancia las
	# stations en su grid_pos original y aquí les reaplicamos level + craft activo.
	if parsed.has("workstations"):
		WorkstationManager.load_save_state(parsed.workstations)
	# Orders va al final: requiere que OrderManager.customer_scene/spawn_point ya
	# estén cableados (los setea game_bootstrap antes de invocar load_game).
	if parsed.has("orders"):
		OrderManager.load_save_state(parsed.orders)
	if parsed.has("event"):
		EventManager.load_save_state(parsed.event)
	# Shop al final: requiere ShopManager.spawn_container/worker_scenes ya cableados.
	if parsed.has("shop"):
		ShopManager.load_save_state(parsed.shop)
	current_slot = slot
	print("[Save] Loaded slot %d" % slot)
	game_loaded.emit(slot)
	return true


func has_save(slot: int = -1) -> bool:
	if slot < 0:
		slot = current_slot
	return FileAccess.file_exists(_slot_path(slot))


func has_any_save() -> bool:
	for i in SLOT_COUNT:
		if FileAccess.file_exists(_slot_path(i)):
			return true
	return false


func get_slot_metadata(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_slot_path(slot)):
		return {"exists": false}
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {"exists": false}
	var raw: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": false, "corrupt": true}
	var inv: Dictionary = parsed.get("inventory", {})
	var cal: Dictionary = parsed.get("calendar", {})
	var stats: Dictionary = parsed.get("stats", {}).get("stats", {})
	var ts: int = int(parsed.get("timestamp", 0))
	return {
		"exists": true,
		"day": cal.get("current_day", 1),
		"coins": inv.get("arcane_coins", 0),
		"reputation": inv.get("reputation", 0),
		"playtime": stats.get("playtime_seconds", 0),
		"timestamp": ts,
	}


func delete_save(slot: int = -1) -> void:
	if slot < 0:
		slot = current_slot
	# Borrar slot + .bak para que un load posterior no auto-recupere desde backup.
	for p in [_slot_path(slot), _slot_bak_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("[Save] Slot %d deleted." % slot)
