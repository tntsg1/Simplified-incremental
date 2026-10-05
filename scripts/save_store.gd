extends RefCounted

const PATH: String = "user://skyguard_save_v1.json"
var path: String = PATH
var enabled: bool = true

func save_game(sim: RefCounted, settings: Dictionary) -> bool:
	if not enabled or sim.mode == "title":
		return false
	var payload: Dictionary = sim.snapshot()
	payload["settings"] = settings.duplicate()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_game() -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parser:=JSON.new()
			if parser.parse(FileAccess.get_file_as_string(candidate))!=OK:
				continue
			var parsed: Variant = parser.data
			if parsed is Dictionary:
				var validator = preload("res://scripts/combat.gd").new()
				if validator.restore(parsed):
					return parsed
	return {}
