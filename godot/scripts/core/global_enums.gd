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
	ABYSSAL_SALT,       # Salina Abisal → sal_abisal
	UMBRAL_ROOT,        # Arboleda Umbría → raiz_umbria
	STAR_ASH,           # Brasero Estelar → ceniza_estelar
	OBSIDIAN_CORE,      # Vena de Obsidiana → nucleo_obsidiana
	SPECTRE_DUST,       # Cripta Espectral → polvo_espectro
	ANCIENT_SAP,        # Tocón Ancestral → savia_ancestral
	CELESTIAL_SHARD,    # Cráter Celeste → fragmento_celestial
	MAGMA_HEART,        # Caldera Magmática → corazon_magmatico
	ETERNAL_FROST,      # Manantial Helado → escarcha_eterna
	CRYSTAL_BOLT,       # Pararrayos Arcano → rayo_cristalizado
}

enum WorkerType { DUENDE, GOLEM, APPRENTICE, PROTAGONIST, CUSTOMER, LENADOR, ESPIRITU }

enum WorkerState { IDLE, FETCHING, WORKING, DELIVERING, MOVING, WAITING, LEAVING, ARRIVING }

enum ItemCategory { PRIMARY, PROCESSED, FINAL, CURRENCY }

## Qué ayudante recolecta cada recurso. Fuente de verdad compartida: mantener en
## sync con las asignaciones de scripts/ai/worker_*.gd (preferred_resource_type(s)).
const RESOURCE_TO_WORKER: Dictionary = {
	ResourceType.HERB: WorkerType.DUENDE,
	ResourceType.CRYSTAL: WorkerType.GOLEM,
	ResourceType.IRON_ORE: WorkerType.GOLEM,
	ResourceType.ARCANE_WOOD: WorkerType.LENADOR,
	ResourceType.SPIRIT_ESSENCE: WorkerType.ESPIRITU,
	ResourceType.ARCANE_WATER: WorkerType.ESPIRITU,
	ResourceType.MOON_DUST: WorkerType.ESPIRITU,
	ResourceType.AMETHYST_FRAGMENT: WorkerType.ESPIRITU,
	ResourceType.IRON_INGOT: WorkerType.ESPIRITU,
	# Recolectables de endgame. Repartidos a propósito entre tres oficios: si
	# todos cayesen en el Espíritu, el tramo T4-T5 se jugaría con un solo ayudante.
	ResourceType.ABYSSAL_SALT: WorkerType.GOLEM,
	ResourceType.UMBRAL_ROOT: WorkerType.LENADOR,
	ResourceType.STAR_ASH: WorkerType.ESPIRITU,
	ResourceType.OBSIDIAN_CORE: WorkerType.GOLEM,
	ResourceType.SPECTRE_DUST: WorkerType.ESPIRITU,
	ResourceType.ANCIENT_SAP: WorkerType.LENADOR,
	ResourceType.CELESTIAL_SHARD: WorkerType.ESPIRITU,
	ResourceType.MAGMA_HEART: WorkerType.GOLEM,
	ResourceType.ETERNAL_FROST: WorkerType.ESPIRITU,
	ResourceType.CRYSTAL_BOLT: WorkerType.GOLEM,
}

const WORKER_LABEL: Dictionary = {
	WorkerType.DUENDE: "🧝 Duende",
	WorkerType.GOLEM: "🗿 Gólem",
	WorkerType.APPRENTICE: "🧙 Aprendiz",
	WorkerType.LENADOR: "🪓 Leñador",
	WorkerType.ESPIRITU: "👻 Espíritu",
}


## Tipo de ayudante que recolecta este recurso (-1 si ninguno).
func worker_for_resource(resource_type: int) -> int:
	return RESOURCE_TO_WORKER.get(resource_type, -1)


func worker_label(worker_type: int) -> String:
	return WORKER_LABEL.get(worker_type, "Ayudante")
