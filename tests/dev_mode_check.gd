extends SceneTree
# Developer mode: the ` key toggles it; shortcuts skip waves, kill bosses, jump stages.
var game: Control
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("DEV_CHECK ", description, " ", ok)
	if not ok:
		failures += 1

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func frames(n: int) -> void:
	for i in range(n):
		await process_frame

func until(condition: Callable, seconds: float = 3.0) -> void:
	# Boss kills trigger slow motion, so wait on the outcome, not a frame count.
	var stop: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < stop:
		await process_frame

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	key(KEY_QUOTELEFT)
	check(game.dev_mode and game.dev_bar.visible, "` opens developer bar")
	var before: float = sim.money
	game.dev_money()
	check(sim.money >= before * 10.0 + 1000.0 - 0.01, "money x10")
	game.dev_skip_wave()
	await frames(4)
	check(sim.mode == "wave" and sim.wave == 2, "skip wave rolls into the next")
	game.dev_prev_wave()
	check(sim.wave == 1 and sim.mode == "wave", "previous wave steps back")
	sim.wave = 10
	sim.start_boss()
	game.dev_kill_boss()
	await until(func(): return sim.mode == "transition")
	check(sim.mode == "transition" and sim.stage_bosses == 1, "kill boss finishes the stage")
	sim.mode_time = 99
	await until(func(): return sim.stage == 1)
	check(sim.stage == 1, "transition reaches next stage")
	game.dev_next_stage()
	await until(func(): return sim.mode == "transition")
	sim.mode_time = 99
	await until(func(): return sim.stage == 2)
	check(sim.stage == 2, "next-stage shortcut jumps ahead")
	game.dev_prev_stage()
	check(sim.stage == 1 and sim.wave == 1 and sim.mode == "wave", "previous stage steps back")
	game.dev_toggle_god()
	sim.health = 5
	await frames(2)
	check(sim.health == 100, "god mode holds the line")
	game.game_speed = 8
	game.cycle_speed()
	check(game.game_speed == 16, "dev mode unlocks x16")
	key(KEY_QUOTELEFT)
	check(not game.dev_mode and game.game_speed == 8 and not game.dev_god, "closing dev mode restores limits")
	print("DEV_RESULT failures=", failures)
	quit(1 if failures else 0)
