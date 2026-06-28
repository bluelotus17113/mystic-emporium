extends Node
## Static-style helper. Genera nombres temáticos para cada tipo de ayudante.

const DUENDE_NAMES: Array[String] = [
	"Pim", "Bramo", "Wisko", "Tarli", "Glip", "Tundi", "Nirko", "Fimsa", "Korkin", "Zelpu",
	"Misli", "Bonku", "Lurka", "Spindle", "Wickle", "Tippet", "Floxy", "Brindle", "Roko", "Tindo"
]
const GOLEM_NAMES: Array[String] = [
	"Granito", "Onix", "Marmol", "Cuarcita", "Andesita", "Cobalto", "Hematita", "Pirita",
	"Basalto", "Diorita", "Obsidiana", "Adoquín", "Pumice", "Travertino"
]
const APPRENTICE_NAMES: Array[String] = [
	"Calix", "Linnea", "Mirio", "Velora", "Tessa", "Orin", "Iliana", "Sefar",
	"Briand", "Noctra", "Vesper", "Aelin", "Cira", "Telios", "Yara"
]

static func random_for_type(worker_type: int) -> String:
	match worker_type:
		GameEnums.WorkerType.DUENDE:
			return DUENDE_NAMES.pick_random()
		GameEnums.WorkerType.GOLEM:
			return GOLEM_NAMES.pick_random()
		GameEnums.WorkerType.APPRENTICE:
			return APPRENTICE_NAMES.pick_random()
		_:
			return "Anónimo"
