@tool
extends EditorScript
## Run con File > Run en Godot editor para identificar .tres que no carga al tipo correcto

const DIRS := {
	"res://data/items/":      "ItemData",
	"res://data/recipes/":    "RecipeData",
	"res://data/orders/":     "OrderData",
	"res://data/research/":   "ResearchData",
	"res://data/buildables/": "BuildableData",
}

func _run() -> void:
	for path in DIRS:
		var expected: String = DIRS[path]
		var dir := DirAccess.open(path)
		if dir == null:
			print("CANNOT OPEN: ", path)
			continue
		dir.list_dir_begin()
		var fn: String = dir.get_next()
		var bad: Array = []
		var total: int = 0
		while fn != "":
			if not dir.current_is_dir() and fn.ends_with(".tres"):
				total += 1
				var res: Resource = load(path + fn)
				if res == null:
					bad.append("%s → null" % fn)
				else:
					var script = res.get_script()
					var cls_name: String = ""
					if script != null:
						cls_name = script.get_global_name()
					if cls_name != expected:
						bad.append("%s → %s (expected %s)" % [fn, cls_name, expected])
			fn = dir.get_next()
		dir.list_dir_end()
		print("== %s (expected %s, total %d) ==" % [path, expected, total])
		if bad.is_empty():
			print("  ✓ all OK")
		else:
			for b in bad:
				print("  ✗ ", b)
