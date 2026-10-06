extends SceneTree
# Real window, vsync on, normal play: records frame intervals, sim steps per
# frame and save cost to find stutter (uneven steps, periodic spikes).
var game: Control
var deltas: Array[float] = []
var steps: Array[int] = []
var last_elapsed: float = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.path = "user://skyguard_pacing_check.json"
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	var stage: int = int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 2
	sim.stage = stage
	sim.wave = 7
	sim.automation = true
	for i in range(stage + 1):
		sim.owned[i] = true
	sim.levels.damage = 10 + stage * 20
	sim.levels.reload = 10 + stage * 15
	sim.levels.turrets = 10 + stage * 10
	sim.start_wave()
	if OS.get_cmdline_user_args().size() > 1:
		game.game_speed = int(OS.get_cmdline_user_args()[1])
		game.refresh_speed_button()
	var save_ms: float = 0
	var t0: int = Time.get_ticks_usec()
	game.save_game()
	save_ms = (Time.get_ticks_usec() - t0) / 1000.0
	last_elapsed = sim.elapsed
	var previous: int = Time.get_ticks_usec()
	for frame in range(1200):
		await process_frame
		var now: int = Time.get_ticks_usec()
		deltas.append((now - previous) / 1000.0)
		previous = now
		steps.append(int(round((sim.elapsed - last_elapsed) * 60)))
		last_elapsed = sim.elapsed
	var histogram: Dictionary = {}
	for s in steps:
		histogram[s] = int(histogram.get(s, 0)) + 1
	var sorted: Array[float] = deltas.duplicate()
	sorted.sort()
	var spikes: int = 0
	for d in deltas:
		if d > 25.0:
			spikes += 1
	print("PACING refresh_hz=", DisplayServer.screen_get_refresh_rate(), " frames=", deltas.size(), " median_ms=", snappedf(sorted[sorted.size() / 2], .01), " p99_ms=", snappedf(sorted[int(sorted.size() * .99)], .01), " max_ms=", snappedf(sorted.back(), .01), " frames_over_25ms=", spikes)
	await RenderingServer.frame_post_draw
	if OS.get_cmdline_user_args().size() > 2:
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[2])
	print("PACING sim_steps_per_frame=", histogram, " enemies=", sim.enemies.size(), " save_ms=", snappedf(save_ms, .01))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path + ".bak"))
	quit()
