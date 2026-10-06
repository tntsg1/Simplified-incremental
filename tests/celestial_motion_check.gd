extends SceneTree
# Fixed-speed flight and independent firing axes, exercised through real signals.
var game: Control
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("MOTION_CHECK ", description, " ", ok)
	if not ok:
		failures += 1

func check_flight(field: Node2D, i: int) -> void:
	var distance: float = 0.0
	var previous: Vector2 = field.round_position(i, 0.0)
	var worst: float = 0.0
	for step in range(1, 101):
		var p: Vector2 = field.round_position(i, step / 100.0)
		var speed: float = p.distance_to(previous) / (field.b_dur[i] / 100.0)
		worst = maxf(worst, absf(speed / game.sim.PROJECTILE_SPEED - 1.0))
		distance += previous.distance_to(p)
		previous = p
	check(worst < .06, "curve speed error <6 percent, actual=" + str(worst))
	check(absf(distance / field.b_dur[i] / game.sim.PROJECTILE_SPEED - 1.0) < .02, "average flight speed fixed")

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/motion_" + label + ".png")

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.audio.set_enabled(false)
	game.set_process(false)
	var sim = game.sim
	var field = game.field
	field.banner.clear()
	sim.levels.turrets = 4
	field.ensure_turret_visuals()
	var origin: Vector2 = sim.turret_position(0)
	field.on_turret_fired(0, origin, origin + Vector2.RIGHT * 300, false)
	check(is_zero_approx(field.turret_aim[0]), "right-facing zero angle is a valid aim")
	field.on_fire(0, sim.weapon_origin(0), sim.weapon_origin(0) + Vector2.DOWN * 300, false)
	check(is_equal_approx(field.aims[0], PI / 2), "main weapon aims down independently")
	for stage in range(6):
		sim.stage = stage
		sim.clear_battle()
		sim.mode = "wave"
		field.banner_wave = "%d-%d" % [stage, sim.wave]
		sim.money = 1e35
		sim.automation = true
		sim.owned.assign([true, stage >= 1, stage >= 2, stage >= 3, stage >= 4, stage >= 5])
		game.update_hud()
		game.money_label.text = "动画验证场景"
		sim.bodies[stage] = 0
		sim.spawn_enemy(10000)
		var enemy: Dictionary = sim.enemies.back()
		enemy.pos = Vector2(770, 145)
		enemy.start = enemy.pos
		enemy.end = enemy.pos
		enemy.lifetime = 1000.0
		for slot in range(sim.BODIES[stage].size()):
			check(sim.convert_body(slot), "convert stage=%d slot=%d" % [stage, slot])
			var at: Vector2 = sim.body_position(stage, slot)
			var direction: Vector2 = Vector2.from_angle(slot * 1.1 + .2)
			field.on_body_fired(stage, slot, at, at + direction * 400, false)
			check(absf(angle_difference(float(field.body_aim[stage * 16 + slot]), direction.angle())) < .0001, "individual body firing axis")
			var i: int = field.b_age.size() - 1
			check(absf((field.b_ctrl[i] - field.b_from[i]).normalized().cross(direction)) < .0001, "bullet launch tangent follows barrel")
		# Real render at assembly, latch and settled frames for every chapter.
		field.clock = 0.0
		for frame in range(90):
			field.clock += 1.0 / 60.0
			field.animate(1.0 / 60.0)
			field.queue_redraw()
			await process_frame
			if stage == 2 and frame % 5 == 0:
				await capture("solar_anim_%02d" % (frame / 5))
			if frame in [12, 38, 78]:
				if frame == 78:
					field.banner.clear()
					field.queue_redraw()
				await capture("stage%d_frame%d" % [stage, frame])
		check(field.body_build.is_empty(), "assembly returns to rest")
		check(float(field.body_flash.get(stage * 16, 0.0)) == 0.0, "recoil returns to rest")
		if stage < 5:
			sim.mode = "transition"
			for moment in [.15, .6, 1.0]:
				sim.mode_time = sim.transition_length * moment
				field.queue_redraw()
				await process_frame
				await capture("transition%d_%02d" % [stage, int(moment * 100)])
			sim.mode = "wave"
	# Curved retargeting must preserve speed, even through a sharp reversal.
	field.spawn_barrage(5, Vector2(100, 100), Vector2(850, 300), false, 1)
	var round_i: int = field.b_age.size() - 1
	check_flight(field, round_i)
	field.b_age[round_i] = field.b_dur[round_i] * .4
	var before: Vector2 = field.round_position(round_i, .4)
	var target: Dictionary = {"id": 991, "pos": Vector2(120, 580), "start": Vector2(120, 580), "end": Vector2(120, 580), "lifetime": 1000.0}
	field.swerve(round_i, target)
	check(before.distance_to(field.round_position(round_i, 0.0)) < .001, "retarget position continuous")
	check_flight(field, round_i)
	var durations: Array[float] = []
	var intervals: Array[float] = []
	var physical_times: Array[float] = []
	for reload_level in [0, 10, 30]:
		sim.levels.reload = reload_level
		sim.levels.speed = reload_level
		field.spawn_barrage(0, Vector2(100, 100), Vector2(650, 100), false, 1)
		durations.append(field.b_dur[-1])
		intervals.append(sim.shot_interval(0))
		var stationary: Dictionary = sim.enemies.back()
		stationary.pos = sim.weapon_origin(0) + Vector2.RIGHT * 550
		sim.fire_weapon(0, stationary)
		physical_times.append(float(sim.shots.back().duration))
	check(is_equal_approx(durations[0], durations[1]) and is_equal_approx(durations[1], durations[2]), "upgrades preserve visual flight speed")
	check(intervals[0] > intervals[1] and intervals[1] > intervals[2], "reload upgrades increase cadence")
	check(is_equal_approx(physical_times[0], physical_times[1]) and is_equal_approx(physical_times[1], physical_times[2]), "upgrades preserve combat projectile speed")
	field.reduced_effects = true
	field.on_body_converted(5, 0)
	field.on_body_fired(5, 0, sim.body_position(5, 0), Vector2(770, 145), false)
	field.animate(.1)
	field.queue_redraw()
	await process_frame
	await capture("reduced")
	# All 30 converted bodies and the complete arsenal in a dense live battle.
	field.reduced_effects = false
	sim.levels.reload = 30
	sim.levels.damage = 10
	sim.levels.turrets = 60
	sim.clear_battle()
	sim.spawn_left = 1
	sim.spawn_clock = 1000
	for j in range(120):
		sim.spawn_enemy(10000)
		var e: Dictionary = sim.enemies.back()
		e.hp = 1e35
		e.unit_hp = 1e35
		e.lifetime = 1000.0
	for s in range(6):
		sim.bodies[s] = (1 << sim.BODIES[s].size()) - 1
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.set_process(true)
	var timings: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame in range(300):
		await process_frame
		var now: int = Time.get_ticks_usec()
		if frame >= 60:
			timings.append((now - previous) / 1000.0)
		previous = now
	timings.sort()
	print("MOTION_DENSE frames=", timings.size(), " p95_ms=", timings[int(timings.size() * .95)], " bullets=", field.b_age.size(), " bodies=", sim.total_bodies(), " enemies=", sim.enemies.size())
	check(field.b_age.size() <= field.BULLET_CAP and field.b_paths.size() == field.b_age.size(), "dense cosmetic pool bounded and aligned")
	await capture("dense")
	print("MOTION_RESULT failures=", failures, " flight_times=", durations, " shot_intervals=", intervals)
	quit(1 if failures else 0)
