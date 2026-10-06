extends SceneTree
# Frame times around a wave ending and the next wave starting (stutter hunt).
var game: Control

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.path = "user://skyguard_hitch_check.json"
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = 2
	sim.wave = 6
	sim.automation = true
	sim.owned[1] = true
	sim.owned[2] = true
	sim.levels.damage = 40
	sim.levels.reload = 40
	sim.levels.turrets = 30
	sim.start_wave()
	var waited: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < waited:
		await process_frame
	var worst: float = 0
	var spikes: Array[String] = []
	var last: int = Time.get_ticks_usec()
	game.dev_skip_wave()
	for frame in range(330):
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		if ms > 20.0:
			spikes.append("%d:%s:%.1fms" % [frame, sim.mode, ms])
	print("HITCH worst_ms=", snappedf(worst, .01), " spikes=", spikes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path + ".bak"))
	quit()
