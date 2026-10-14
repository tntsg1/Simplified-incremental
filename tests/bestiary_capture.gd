extends SceneTree
# Renders every chapter's enemy archetypes and bosses one at a time, live, and
# saves a close-up of each for the bestiary page.
# Usage: -- <out_dir>     (writes <stage>_<arch>.png, <stage>_boss.png, bestiary.json)
var game: Control

func _initialize() -> void:
	call_deferred("run")

func wait_real(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		game.sim.health = 100.0
		# Keep the pointer, its aim ring and the core glow out of the portraits - by hiding them
		# inside the game. Never move the real OS pointer (the developer is using it).
		game.field.hover = Vector2(-9999, -9999)
		if game.get("pointer_frame") != null:
			game.pointer_frame.visible = false
		game.field.glow.visible = false
		game.field.intro_t = 0.0
		await process_frame

func grab(center: Vector2, half: float, path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var screen: Vector2 = game.field.get_global_transform_with_canvas() * center
	var scale: float = game.field.get_global_transform_with_canvas().get_scale().x
	var side: int = int(half * 2.0 * scale)
	var rect := Rect2i(int(screen.x) - side / 2, int(screen.y) - side / 2, side, side).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(rect).save_png(path)

func quiet_field() -> void:
	# Nothing fires: the subject stays whole and alone.
	var sim = game.sim
	for i in range(sim.STAGE_COUNT):
		sim.owned[i] = false
		sim.bodies[i] = 0
	sim.levels.turrets = 0
	sim.automation = false
	sim.clear_battle()
	sim.spawn_left = 0
	sim.grace = 9999.0

func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/frames")
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.close_modal()
	game.field.bare = true
	game.ui.hide()
	var sim = game.sim
	var index: Array = []
	# Far from the core and its defence ring, clear of the HUD.
	var center := Vector2(200, 190)
	for st in range(sim.STAGE_COUNT):
		sim.stage = st
		sim.wave = 3
		sim.start_wave()
		game.field.reset_growth()
		quiet_field()
		var roster: Dictionary = sim.ROSTER[st]
		for arch in sim.ARCHES:
			if not roster.has(arch):
				continue
			quiet_field()
			sim.serial = 1
			sim.spawn_enemy(6 if arch == "swarm" else 1)
			var e: Dictionary = sim.enemies.back()
			e.merge({"arch": arch, "art": "%d_%s" % [st, arch], "mat": str(roster[arch][1]), "title": str(roster[arch][0]), "elite": false,
				"start": center + Vector2(-.6, -.3), "end": center + Vector2(.6, .3), "pos": center, "age": 0.0, "lifetime": 1000.0,
				"kind": "ship" if str(roster[arch][1]) == "metal" else "rock"}, true)
			# Same body size as a mid-sized group in play, without the "x6" count on specials.
			e.radius = 12.0 + minf(22.0, log(6.0) * 3.0) + {"dart": -2.0, "armored": 5.0, "mother": 9.0}.get(arch, 0.0)
			e.hp = float(e.unit_hp)
			if arch == "shielded":
				e.shield = 100.0
				e.shield_max = 100.0
			else:
				e.erase("shield")
			if arch == "dart":
				e.swerve = 1.0
			if arch == "mother":
				e.launch_t = 2.6
				e.launched = 0
			await wait_real(1.4)
			# Frame the body itself (darts keep a little of their speed streak).
			var half: float = float(e.radius) * float(game.field.ARCH_SIZE.get(arch, 1.0)) * (1.8 if arch != "dart" else 2.6) + 8.0
			var file: String = "%d_%s.png" % [st, arch]
			await grab(center, half, out + "/" + file)
			# A short burst of frames for the animated portrait (assembled by tools/bestiary_page.py).
			for frame in range(16):
				await wait_real(.07)
				await grab(center, half, out + "/frames/%d_%s_%02d.png" % [st, arch, frame])
			index.append({"stage": st, "arch": arch, "title": str(roster[arch][0]), "mat": str(roster[arch][1]), "file": file,
				"new": arch == sim.NEW_ARCH[st]})
			print("BESTIARY ", file)
		# The chapter boss, once it has settled in.
		quiet_field()
		sim.wave = 10
		sim.start_boss()
		await wait_real(4.0)
		var boss: Dictionary = sim.boss_actor()
		if not boss.is_empty():
			var file: String = "%d_boss.png" % st
			await grab(Vector2(boss.pos), float(boss.radius) * 2.4 + 20.0, out + "/" + file)
			index.append({"stage": st, "arch": "boss", "title": str(sim.stage_data().boss_title), "mat": str(boss.kind), "file": file, "new": false})
			print("BESTIARY ", file)
		sim.mode = "wave"
		quiet_field()
	var f := FileAccess.open(out + "/bestiary.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, " "))
	f.close()
	print("BESTIARY_DONE ", index.size())
	quit()
