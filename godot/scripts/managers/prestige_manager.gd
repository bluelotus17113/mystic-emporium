extends Node
## Prestige loop: el jugador resetea su progreso a cambio de Estrellas permanentes.
## Cada Estrella otorga +5% de coins ganados, acumulable sin cap.

signal prestige_done(stars_awarded: int, total_stars: int)
signal stars_changed(new_total: int)

const PRESTIGE_MIN_REPUTATION: int = 100
const REP_TO_STARS_DIVISOR: int = 10
const COIN_BONUS_PER_STAR: float = 0.05

var stars: int = 0:
	set(value):
		var v: int = max(0, value)
		if v == stars: return
		stars = v
		stars_changed.emit(stars)
var prestige_count: int = 0
var lifetime_stars: int = 0


func can_prestige() -> bool:
	return InventoryManager.reputation >= PRESTIGE_MIN_REPUTATION


func preview_stars_gain() -> int:
	return int(InventoryManager.reputation / REP_TO_STARS_DIVISOR)


func get_coin_multiplier() -> float:
	return 1.0 + (stars * COIN_BONUS_PER_STAR)


func do_prestige() -> bool:
	if not can_prestige():
		return false
	var gain: int = preview_stars_gain()
	# ponytail: reset por método explícito en cada manager. Nada de magic broadcasting.
	InventoryManager.reset_for_prestige()
	BuildManager.reset_for_prestige()
	ResearchManager.reset_for_prestige()
	RecipeManager.reset_for_prestige()
	CalendarManager.reset_for_prestige()
	OrderManager.reset_for_prestige()
	StatsManager.reset_for_prestige()
	DailyQuestManager.reset_for_prestige()
	ZoneExpansionManager.reset_for_prestige()
	stars += gain
	lifetime_stars += gain
	prestige_count += 1
	NotificationManager.post("✨ Prestigio %d! +%d Estrellas. Bonus coins: +%d%%" % [
		prestige_count, gain, int((get_coin_multiplier() - 1.0) * 100)
	], NotificationManager.Kind.INFO)
	prestige_done.emit(gain, stars)
	SaveManager.save_game()
	return true


func get_save_state() -> Dictionary:
	return {
		"stars": stars,
		"prestige_count": prestige_count,
		"lifetime_stars": lifetime_stars,
	}


func load_save_state(data: Dictionary) -> void:
	stars = data.get("stars", 0)
	prestige_count = data.get("prestige_count", 0)
	lifetime_stars = data.get("lifetime_stars", 0)
