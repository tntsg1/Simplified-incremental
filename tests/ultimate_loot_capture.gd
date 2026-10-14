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
	var c = game.sim
	c.spawn_left = 100
	c.spawn_clock = 1000000.0
	for i in range(12):
		c.spawn_enemy(20)
		var e: Dictionary = c.enemies.back()
		e.pos = Vector2(300 + (i % 4) * 130, 180 + (i / 4) * 70)
		e.start = e.pos
		e.end = e.pos
	c.ult_charge = 1.0
	var seed_file := FileAccess.open("res://proofs/ultimate_loot_seed.json", FileAccess.WRITE)
	seed_file.store_string(JSON.stringify(c.snapshot()))
	seed_file.close()
	c.fire_ultimate(Vector2(500, 300))
	var captured: Dictionary = {}
	var max_coins: int = 0
	for tick in range(420):
		game._process(1.0 / 60.0)
		max_coins = maxi(max_coins, game.field.coins.size())
		await process_frame
		await RenderingServer.frame_post_draw
		var phase: String = ""
		if not c.reward_batches.is_empty():
			var age: float = c.reward_batches[0].age
			if age > .6 and age < .9:
				phase = "hold"
			elif age > 1.1 and age < 1.2:
				phase = "burst"
			elif age > 1.45 and age < 1.6:
				phase = "pull"
		elif c.money > 0:
			phase = "paid"
		if phase != "" and not captured.has(phase):
			root.get_texture().get_image().save_png("res://proofs/ultimate_loot_%s.png" % phase)
			captured[phase] = true
			print("LOOT_VISUAL phase=", phase, " money=", c.money, " coins=", game.field.coins.size())
		if captured.size() == 4:
			break
	print("LOOT_VISUAL captures=", captured.size(), " peak_coins=", max_coins, " money=", c.money, " kills=", c.kills)
	game.audio.free()
	await create_timer(.3).timeout
	quit(0 if captured.size() == 4 and c.money == 2400 and max_coins == 48 else 1)
