extends SceneTree
# Screenshots of the big beats: boss entrance, then boss destroyed + scale jump.
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/%s.png" % name)

func wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame

func run() -> void:
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
			var t: Dictionary = sim.target_for_weapon()
			if not t.is_empty():
				sim.priority_id = int(t.id)
		if sim.mode == "failed":
			sim.retry()
		if sim.stage == 1 and sim.mode == "intermission" and sim.mode_time > 2.4:
			break
		sim.advance(1.0 / 60, false)
	game.field.reset_growth()
	while sim.mode != "boss":
		await process_frame
	await wait(.45)
	await shot("cine_boss_a")
	await wait(.7)
	await shot("cine_boss_b")
	await wait(1.2)
	game.dev_kill_boss()
	await wait(.35)
	await shot("cine_jump_a")
	await wait(1.6)
	await shot("cine_jump_b")
	await wait(1.4)
	await shot("cine_jump_c")
	await wait(1.1)
	await shot("cine_jump_d")
	print("CINEMA mode=", sim.mode, " stage=", sim.stage)
	quit()
