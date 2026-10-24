extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.start_game()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for stage in [0, 3, 5, 7, 9]:
		game.sim.start_new(4262026)
		game.sim.stage = stage
		game.sim.wave = 10
		game.sim.start_wave()
		game.sim.automation = true
		game.sim.health = 1000000
		game.sim.spawn_left = 1
		game.sim.spawn_clock = 10000.0
		game.sim.topup_clock = 10000.0
		for s in range(stage + 1): game.sim.owned[s] = true
		game.sim.levels.damage = 8 + stage * 23
		game.sim.levels.reload = 7 + stage * 12
		game.sim.levels.turrets = 6 + stage * 8
		for i in range(120):
			game.sim.spawn_enemy(100000)
			game.sim.enemies.back().age = 3.0
		game.field.profile.clear()
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame in range(180):
			await process_frame
			var now: int = Time.get_ticks_usec()
			if frame >= 30: samples.append((now - previous) / 1000.0)
			previous = now
		var parts: Dictionary = {}
		for key in game.field.profile:
			parts[key] = snappedf(float(game.field.profile[key]) / 180000.0, .001)
		samples.sort()
		print("OPT_AUDIT stage=", stage, " median_ms=",samples[75]," p95_ms=",samples[142]," sections_ms=",parts)
	game.queue_free()
	await process_frame
	quit()
