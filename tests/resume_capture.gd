extends SceneTree
# Continue-campaign transition: loader, iris and hand-off to the live battle.
const Route = preload("res://tests/purchase_route.gd")
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/%s.png" % name)
func wait(sec: float) -> void:
	var until: int = Time.get_ticks_msec() + int(sec * 1000)
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
		if sim.mode == "failed":
			sim.retry()
		if sim.stage == 2 and sim.mode == "wave" and sim.wave >= 3:
			break
		sim.advance(1.0 / 60, false)
	game.saved = sim.snapshot()
	game.show_title()
	await wait(1.0)
	game.title_screen.continue_button.pressed.emit()
	print("RESUME paused=", sim.paused, " title_visible=", game.title_screen.visible)
	var e0: float = sim.elapsed
	var last: float = 0.0
	for pair in [[.25, "res_a"], [.68, "res_b"], [.85, "res_c"], [1.4, "res_d"]]:
		await wait(pair[0] - last)
		last = pair[0]
		await shot(pair[1])
	print("RESUME sim_advanced=", sim.elapsed - e0)
	quit()
