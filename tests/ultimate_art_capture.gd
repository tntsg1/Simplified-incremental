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
	game.game_speed = 1
	game.start_game()
	game.ult_overlay.set_process(false)
	game.audio.set_enabled(false)
	for stage in [2, 3, 4, 5]:
		var c = game.sim
		c.start_new()
		c.stage = stage
		for i in range(6):
			c.owned[i] = true
		c.start_wave()
		c.spawn_left = 300
		c.spawn_clock = 1000000.0
		for i in range(24):
			c.spawn_enemy(10)
			var e: Dictionary = c.enemies.back()
			e.pos = Vector2(200 + (i % 6) * 120, 145 + (i / 6) * 102)
			e.start = e.pos
			e.end = c.defense_position()
			e.lifetime = 30.0
		c.ult_charge = 1.0
		var file := FileAccess.open("res://proofs/ultimate_art_seed_%d.json" % stage, FileAccess.WRITE)
		file.store_string(JSON.stringify(c.snapshot()))
		file.close()
		c.fire_ultimate(Vector2(500, 325))
		var captured: Dictionary = {}
		for tick in range(360):
			game._process(1.0 / 60)
			game.ult_overlay._process(1.0 / 60)
			game.field.hover = Vector2(-1000, -1000)
			await process_frame
			if c.ult.is_empty():
				break
			var u: float = c.ult.age
			for phase in [1.0, 2.35, 3.25]:
				if u >= phase and not captured.has(phase):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://proofs/ultimate_art_%d_%.2f.png" % [stage, phase])
					captured[phase] = true
		print("ULT_ART_CAPTURE stage=", stage, " frames=", captured.size(), " remnants=", game.field.ultimate_art.remnants.size())
	game.audio.free()
	quit()
