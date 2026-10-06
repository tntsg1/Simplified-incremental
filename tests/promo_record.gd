extends SceneTree
# Promo footage: fast-forwards a real campaign with the balanced route, then
# plays live for N seconds (run with --write-movie to record it).
# Usage: -- <stage> <wave> <seconds> [boss]
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0])
	var wave: int = int(args[1])
	var seconds: float = float(args[2])
	var boss: bool = args.size() > 3 and args[3] == "boss"
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.game_speed = 1
	game.refresh_speed_button()
	var sim = game.sim
	for tick in range(3000000):
		if tick % 120 == 0:
			Route.buy(sim)
		sim.manual_held = not sim.automation
		if not sim.automation:
			var target: Dictionary = sim.target_for_weapon()
			if not target.is_empty():
				sim.priority_id = int(target.id)
		if sim.mode == "failed":
			sim.retry()
		if boss and sim.stage == stage and sim.mode == "boss":
			break
		if not boss and (sim.stage > stage or (sim.stage == stage and sim.wave >= wave and sim.mode == "wave" and sim.wave_elapsed > 2.0)):
			break
		sim.advance(1.0 / 60, false)
	game.field.reset_growth()
	var frames: int = int(seconds * 60)
	for i in range(frames):
		if boss and i == frames / 3:
			game.dev_kill_boss()
		await process_frame
	quit()
