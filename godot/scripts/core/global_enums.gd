extends Node

enum ZoneType { NONE, NATURE, WORKSHOP, RECEPTION }

enum StationType {
	NONE,
	CAULDRON,
	MYSTIC_FORGE,
	ENCHANTING_TABLE,
	SCRIBE_DESK,
	SUMMONING_CIRCLE,
	ARCANE_LIBRARY,
	ASTRO_OBSERVATORY,
	STORAGE,
	COUNTER
}

enum ResourceType {
	NONE,
	HERB,
	CRYSTAL,
	IRON_ORE,
	ARCANE_WOOD,
	SPIRIT_ESSENCE,
	ARCANE_WATER,       # Pozo Arcano → agua_arcana
	MOON_DUST,          # Altar Lunar → polvo_lunar
	AMETHYST_FRAGMENT,  # Geoda Amatista → fragmento_amatista
	IRON_INGOT,         # Veta Fundida → lingote_hierro
}

enum WorkerType { DUENDE, GOLEM, APPRENTICE, PROTAGONIST, CUSTOMER }

enum WorkerState { IDLE, FETCHING, WORKING, DELIVERING, MOVING, WAITING, LEAVING, ARRIVING }

enum ItemCategory { PRIMARY, PROCESSED, FINAL, CURRENCY }
