extends SceneTree
# Doomsday weapon screenshots: fast-forward to a stage, fire its ultimate and
# capture the given sim-time moments. Usage: -- <stage> <prefix> <t1,t2,...>
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0])
	var prefix: String = args[1]
	var times: PackedStringArray = args[2].split(",")
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	for tick in range(2000000):
		if tick % 120 == 0:
			Route.buy(sim)
		sim.manual_held = not sim.automation
		if not sim.automation:
			var target: Dictionary = sim.target_for_weapon()
			if not target.is_empty():
				sim.priority_id = int(target.id)
		if sim.mode == "failed":
			sim.retry()
		if sim.stage > stage or (sim.stage == stage and sim.wave >= (6 if stage == 0 else 3) and sim.mode == "wave" and sim.wave_elapsed > 1.0):
			break
		sim.advance(1.0 / 60, false)
	game.field.reset_growth()
	var wait_until: int = Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < wait_until:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s_pre.png" % prefix)
	sim.ult_charge = 1.0
	var ok: bool = game.sim.fire_ultimate(Vector2.INF)
	print("ULT fired=", ok, " kind=", sim.ultimate_kind(), " enemies=", sim.enemies.size())
	var started: float = sim.elapsed
	for t in times:
		while sim.elapsed - started < float(t) and not sim.ult.is_empty():
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s_%s.png" % [prefix, t])
	print("ULT done enemies=", sim.enemies.size(), " hold=", sim.spawn_hold)
	quit()
