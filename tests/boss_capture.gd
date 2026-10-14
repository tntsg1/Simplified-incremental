extends SceneTree
# Boss screenshots for every scale: dev jump to the boss fight, capture after escorts deploy.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var stage: int = int(OS.get_cmdline_user_args()[0])
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = stage
	sim.automation = true
	sim.owned[stage] = true
	sim.levels.turrets = 30
	sim.start_boss()
	game.field.reset_growth()
	sim.skill_clock = 1.0
	var marks: Array = [[2.0, "w"], [1.0, "f"]]
	for m in marks:
		var until: int = Time.get_ticks_msec() + int(float(m[0]) * 1000)
		while Time.get_ticks_msec() < until:
			sim.manual_held = true
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("build/shots/skill_%d_%s.png" % [stage, m[1]])
	var esc: int = 0
	for e in sim.enemies:
		if e.has("escort") and not bool(e.dead): esc += 1
	print("BOSS stage=", stage, " escorts=", esc, " remaining=", sim.boss_remaining, " penalty=", sim.boss_penalty)
	quit()
