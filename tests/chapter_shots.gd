extends SceneTree
# Visual review captures for any chapter: live rendering, real sim, configured
# (not earned) progress. Health is held so the scene keeps running.
# Usage: -- <stage> <mode: wave|boss|ult|transition|bodies> <out_prefix> [times...]
#   wave/boss/bodies: times = seconds of live play before each capture
#   ult: times = ultimate ages at which to capture
#   transition: times = transition clock values
var game: Control

func _initialize() -> void:
	call_deferred("run")

func hold() -> void:
	game.sim.health = 100.0

func wait_real(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		hold()
		await process_frame

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SHOT ", path)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0])
	var mode: String = args[1]
	var prefix: String = args[2]
	var times: Array[float] = []
	for i in range(3, args.size()):
		times.append(float(args[i]))
	if times.is_empty():
		times = [6.0]
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = stage
	sim.wave = 6 if mode != "boss" else 10
	sim.automation = true
	for i in range(stage + 1):
		sim.owned[i] = true
	sim.levels.damage = 10 + stage * 22
	sim.levels.reload = 10 + stage * 13
	sim.levels.crit = 5 + stage * 3
	sim.levels.area = stage * 5
	sim.levels.pierce = maxi(0, stage - 2) * 4
	sim.levels.targets = maxi(0, stage - 3) * 3
	sim.levels.turrets = mini(48, 6 + stage * 5)
	sim.money = 1e30
	var death: bool = mode == "bossdeath"
	var boss_ult: String = mode.substr(8) if mode.begins_with("bossult:") else ""
	if death or boss_ult != "":
		mode = "bossonly"
	if mode == "bossonly":
		# Hold fire: nothing owned, no turrets, no bodies, so the boss reads alone.
		for i in range(sim.STAGE_COUNT):
			sim.owned[i] = false
		sim.levels.turrets = 0
		sim.automation = false
		mode = "boss"
	if mode == "weapon":
		# Only this chapter's weapon: no turrets, no bodies, nothing else firing.
		for i in range(sim.STAGE_COUNT):
			sim.owned[i] = i == stage
		sim.levels.turrets = 0
		sim.levels.damage = 2 + stage * 18
	elif mode == "bodies":
		for s in range(stage + 1):
			sim.bodies[s] = (1 << sim.BODIES[s].size()) - 1
	if mode not in ["bodies", "weapon"]:
		for s in range(stage):
			sim.bodies[s] = (1 << sim.BODIES[s].size()) - 1
		sim.bodies[stage] = 1
	sim.start_wave()
	game.field.reset_growth()
	game.close_modal()
	if mode == "boss":
		sim.start_boss()
	if mode in ["perf", "perf_nobodies"]:
		# Frame cost in the densest configuration: every weapon, every body, ultimate firing.
		for s2 in range(stage + 1):
			sim.bodies[s2] = 0 if mode == "perf_nobodies" else (1 << sim.BODIES[s2].size()) - 1
		await wait_real(4.0)
		game.field.profile.clear()
		var proc_sum: float = 0.0
		var frames: Array[float] = []
		var draws: Array[float] = []
		var last: int = Time.get_ticks_usec()
		var fired_ult: bool = false
		var until: int = Time.get_ticks_msec() + int(times[0] * 1000)
		while Time.get_ticks_msec() < until:
			hold()
			if not fired_ult and Time.get_ticks_msec() > until - int(times[0] * 500):
				sim.ult_charge = 1.0
				game.fire_ultimate_at(Vector2.INF)
				fired_ult = true
			await process_frame
			var now: int = Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			draws.append(game.field.draw_ms)
			proc_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			last = now
		var prof: Dictionary = game.field.profile
		var parts: Array[String] = []
		for key in prof:
			parts.append("%s=%.1f" % [key, float(prof[key]) / 1000.0 / maxi(1, frames.size())])
		print("PROFILE drawcalls=%.0f " % (proc_sum / maxi(1, frames.size())), " ".join(parts))
		frames.sort()
		draws.sort()
		print("PERF stage=%d frames=%d enemies=%d p50=%.1fms p95=%.1fms max=%.1fms draw_p95=%.1fms" % [stage, frames.size(), sim.enemies.size(), frames[frames.size() / 2], frames[int(frames.size() * .95)], frames.back(), draws[int(draws.size() * .95)]])
		quit()
		return
	if mode == "ending":
		sim.mode = "victory"
		game.play_ending()
		for i in range(times.size()):
			game.cinema.t = times[i]
			await wait_real(.1)
			game.cinema.t = times[i]
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	if mode == "transition":
		await wait_real(2.0)
		sim.clear_battle()
		sim.mode = "transition"
		sim.transition_from = stage
		sim.paused = true
		for i in range(times.size()):
			sim.mode_time = times[i]
			await wait_real(.15)
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	if boss_ult != "":
		# Fire a chosen ultimate with the boss and its escorts on the field.
		await wait_real(4.0)
		sim.ult_override = boss_ult
		sim.ult_charge = 1.0
		game.fire_ultimate_at(Vector2.INF)
		for i in range(times.size()):
			while not sim.ult.is_empty() and float(sim.ult.age) < times[i]:
				hold()
				await process_frame
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	if death:
		# Kill the boss outright, then catch its death at the given seconds after.
		await wait_real(3.0)
		var boss: Dictionary = sim.boss_actor()
		sim.apply_damage(boss, float(boss.hp) * 2.0, 1, 0, false, false)
		var start_ms: int = Time.get_ticks_msec()
		for i in range(times.size()):
			while Time.get_ticks_msec() - start_ms < int(times[i] * 1000):
				hold()
				await process_frame
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	if mode == "ult":
		await wait_real(9.0)
		sim.ult_charge = 1.0
		game.fire_ultimate_at(Vector2.INF)
		for i in range(times.size()):
			while not sim.ult.is_empty() and float(sim.ult.age) < times[i]:
				hold()
				await process_frame
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	if mode == "weapon":
		# Burst: catch the weapon's own animation right after it fires.
		await wait_real(5.0)
		var fired_box: Array = [false]
		sim.fired.connect(func(i, _o, _d, _c): if i == stage: fired_box[0] = true)
		while not fired_box[0]:
			hold()
			await process_frame
		var start_ms: int = Time.get_ticks_msec()
		for i in range(times.size()):
			while Time.get_ticks_msec() - start_ms < int(times[i] * 1000):
				hold()
				await process_frame
			await shot("%s_%d.png" % [prefix, i])
		quit()
		return
	var elapsed: float = 0.0
	for i in range(times.size()):
		await wait_real(maxf(0.0, times[i] - elapsed))
		elapsed = times[i]
		await shot("%s_%d.png" % [prefix, i])
	print("CHAPTER stage=", sim.stage, " mode=", sim.mode, " enemies=", sim.enemies.size())
	quit()
