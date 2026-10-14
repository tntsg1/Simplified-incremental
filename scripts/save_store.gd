extends RefCounted

const PATH: String = "user://skyguard_save_v1.json"
var legacy_path: String = PATH
var profile_root := "user://steam"
var path: String = PATH
var enabled: bool = true

var task_id: int = -1

func save_game(sim: RefCounted, settings: Dictionary) -> bool:
	if not enabled or sim.mode == "title":
		return false
	finish_pending()
	return write(build(sim, settings))

# Autosave: the snapshot is taken here (cheap); JSON encoding and disk writes
# run on a worker thread so a crowded battlefield never hitches the frame.
func save_game_async(sim: RefCounted, settings: Dictionary) -> void:
	if not enabled or sim.mode == "title":
		return
	if OS.has_feature("web"):
		write(build(sim, settings))
		return
	if task_id >= 0 and not WorkerThreadPool.is_task_completed(task_id):
		return
	finish_pending()
	task_id = WorkerThreadPool.add_task(write.bind(build(sim, settings)))

func finish_pending() -> void:
	if task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1

func build(sim: RefCounted, settings: Dictionary) -> Dictionary:
	var payload: Dictionary = sim.snapshot()
	payload["settings"] = settings.duplicate()
	return payload

func write(payload: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_game() -> Dictionary:
	finish_pending()
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

# Per-account Auto-Cloud path. Never replace a cloud-downloaded save with legacy data.
func select_steam_profile(steam_id: String) -> bool:
	if not enabled or path != legacy_path: return true
	if not steam_id.is_valid_int() or steam_id.length() != 17: return false
	var folder := profile_root+"/"+steam_id
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	var target := folder+"/skyguard_save_v1.json"
	var marker := profile_root+"/legacy_owner.txt"
	var owner := FileAccess.get_file_as_string(marker) if FileAccess.file_exists(marker) else ""
	if owner == "":
		var file := FileAccess.open(marker,FileAccess.WRITE)
		if file == null: return false
		file.store_string(steam_id)
		file.close()
		owner = steam_id
	if owner == steam_id and not FileAccess.file_exists(target) and not FileAccess.file_exists(target+".bak"):
		var legacy := read_game()
		if not legacy.is_empty():
			path = target
			if not write(legacy): path = legacy_path; return false
			var old_achievements := "user://skyguard_achievements_v1.json"
			var new_achievements := folder+"/skyguard_achievements_v1.json"
			if legacy_path == PATH and FileAccess.file_exists(old_achievements) and not FileAccess.file_exists(new_achievements): DirAccess.copy_absolute(old_achievements,new_achievements)
	path = target
	return true
