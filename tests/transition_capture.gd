extends SceneTree
# Screenshots right after a scale jump: how the first threats stream in.
# Usage: -- <target_stage> <prefix>
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: int = int(args[0])
	var prefix: String = args[1]
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
		if sim.mode == "transition" and sim.stage == target - 1 and sim.mode_time > sim.transition_length - 1.0:
			break
		sim.advance(1.0 / 60, false)
	game.field.reset_growth()
	var shots: Array[float] = [0.4, 1.5, 3.0, 6.0]
	var k: int = 0
	while k < shots.size():
		await process_frame
		if sim.mode == "wave" and sim.wave_elapsed >= shots[k]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
			print("TRANSITION t=", shots[k], " alive=", sim.living_count())
			k += 1
	quit()
