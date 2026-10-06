extends SceneTree
# Realistic screenshots: fast-forwards a real campaign with the balanced purchase
# route to the requested stage/wave, then plays it live and captures frames.
# Usage: -- <stage> <wave> <out_prefix> [frames=3] [gap_seconds=0.5]
const Route = preload("res://tests/purchase_route.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0])
	var wave: int = int(args[1])
	var prefix: String = args[2]
	var count: int = int(args[3]) if args.size() > 3 else 3
	var gap: float = float(args[4]) if args.size() > 4 else .5
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.paused = true
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
		if sim.stage > stage or (sim.stage == stage and sim.wave >= wave and sim.mode == "wave" and sim.wave_elapsed > 6.0):
			break
		sim.paused = false
		sim.advance(1.0 / 60, false)
		sim.paused = true
	game.field.reset_growth()
	sim.paused = false
	var wait_until: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < wait_until:
		await process_frame
	for i in range(count):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s_%d.png" % [prefix, i])
		var until: int = Time.get_ticks_msec() + int(gap * 1000)
		while Time.get_ticks_msec() < until:
			await process_frame
	print("SHOWCASE stage=", sim.stage, " wave=", sim.wave, " mode=", sim.mode, " health=", sim.health, " enemies=", sim.enemies.size(), " turrets=", sim.levels.turrets)
	quit()
