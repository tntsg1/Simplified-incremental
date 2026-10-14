extends SceneTree
var failures := 0
func check(value: bool, why: String) -> void:
	if not value:
		failures += 1
		push_error(why)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.start_game()
	game.set_process(false)
	game.audio.set_enabled(false)
	await create_timer(.6).timeout
	var c = game.sim
	c.levels.turrets = 48
	c.levels.damage = 110
	c.levels.reload = 20
	c.levels.crit = 18
	c.levels.pierce = 4
	c.levels.targets = 2
	for stage in range(5):
		c.clear_battle()
		c.stage = stage
		c.wave = 10
		c.mode = "transition"
		c.mode_time = 0.0
		c.elapsed = 40.0
		for i in range(6):
			c.owned[i] = i <= stage
			c.bodies[i] = 63 if i <= stage else 0
		game.cine_mode = "transition"
		game.field.hover = Vector2(-999,-999)
		game.field.clock = 40.0
		game.field.banner = {}
		game.field.ensure_turret_visuals()
		var seed_file := FileAccess.open("res://proofs/handoff_seed_%d.json" % stage,FileAccess.WRITE)
		seed_file.store_string(JSON.stringify(c.snapshot()))
		seed_file.close()
		for second in [0.0,3.5,5.5,6.9]:
			c.mode_time = second
			game.field.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://proofs/handoff_%d_%s.png" % [stage,str(second).replace(".","-")])
		var snapshot: String = JSON.stringify(c.snapshot())
		var outgoing := Transform2D.IDENTITY
		for i in range(stage+1):
			var pose: Dictionary = game.field.transition_weapon_pose(i,outgoing,1.0)
			check(pose.point.distance_to(c.weapon_origin_at(i,stage+1)) < .001,"Weapon must arrive at actual next-stage firing origin")
			check(is_equal_approx(pose.scale,.7),"Legacy weapon size must match handoff")
		check(snapshot == JSON.stringify(c.snapshot()),"Presentation projection must not mutate campaign")
		var next_positions: Array[Vector2] = []
		for j in range(c.turret_count()):
			next_positions.append(c.turret_position_at(j,stage+1))
		c.stage += 1
		c.mode = "wave"
		for j in range(c.turret_count()):
			check(next_positions[j].distance_to(c.turret_position(j)) < .001,"Preview and active turret anchors must be identical")
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/handoff_%d_active.png" % stage)
		game.audio.prepare_stage(stage+1)
		check(game.audio.streams.has(game.audio.TRACKS[stage+1]),"Next music resource must be prepared before handoff")
	print("HANDOFF_CHECK failures=",failures)
	game.audio.free()
	quit(failures)
