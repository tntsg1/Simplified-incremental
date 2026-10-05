extends SceneTree
# Captures the "defense visibly grows" moment: buy upgrades in the paused panel,
# close it, then screenshot the replayed growth. Saves are disabled.
var game: Control

func _initialize() -> void:
	call_deferred("run")

func wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await process_frame

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("GROWTH_SHOT ", path)

func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://proofs/growth"
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	game.pause_on_focus_loss = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = 2
	sim.wave = 3
	sim.automation = true
	sim.owned[1] = true
	sim.levels.damage = 30
	sim.levels.reload = 35
	sim.levels.speed = 2
	sim.start_wave()
	game.field.reset_growth()
	await wait(2.0)
	game.open_shop()
	sim.money = 1e9
	sim.buy_upgrade(0, 25)
	sim.buy_upgrade(2, 20)
	sim.buy_upgrade(3, 30)
	sim.buy_upgrade(1, 8)
	sim.buy_weapon()
	await wait(.3)
	game.close_modal()
	await wait(.35)
	await shot(out + "_a.png")
	await wait(.45)
	await shot(out + "_b.png")
	print("GROWTH_EVENTS ", game.field.growth.size(), " levels=", sim.levels)
	quit()
