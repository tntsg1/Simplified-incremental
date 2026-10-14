extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.saved = {}
	game.start_game()
	game.audio.set_enabled(false)
	await create_timer(.6).timeout
	var c = game.sim
	for stage in [3, 4, 5]:
		c.clear_battle()
		c.stage = stage
		c.mode = "wave"
		c.wave = 3
		c.spawn_left = 100
		c.spawn_clock = 1000000.0
		c.money = 1e18
		c.elapsed = 15.0
		c.levels.turrets = 4
		c.levels.damage = 12
		c.bodies[stage] = 1 << 2
		game.field.banner = {}
		game.field.banner_wave = "%d-%d" % [stage, c.wave]
		game.field.hover = Vector2(-1000, -1000)
		game.field.body_hover = -1
		game._process(1.0 / 60.0)
		game.field.clock = 15.0
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/maps_%s_%d.png" % [OS.get_environment("SKYGUARD_MAP_CAPTURE"), stage])
		var f = FileAccess.open("res://proofs/map_seed_%d.json" % stage, FileAccess.WRITE)
		f.store_string(JSON.stringify(c.snapshot()))
		f.close()
	game.audio.free()
	quit()
