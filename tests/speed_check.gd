extends SceneTree
# Fast-forward: pressing F cycles x1/x2/x3, sim time advances that much faster
# per real second, and barrage rounds still land on their targets.
var game: Control
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("SPEED_CHECK ", description, " ", ok)
	if not ok:
		failures += 1

func press_f() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.pressed = true
	game._unhandled_input(event)

func sim_rate(seconds: float) -> float:
	var start: float = game.sim.elapsed
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < int(seconds * 1000):
		await process_frame
	return (game.sim.elapsed - start) / ((Time.get_ticks_msec() - began) / 1000.0)

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.sim.automation = true
	game.game_speed = 1
	game.refresh_speed_button()
	var base: float = await sim_rate(1.5)
	press_f()
	check(game.game_speed == 2 and game.speed_button.text.contains("×2"), "F switches to x2")
	var double: float = await sim_rate(1.5)
	press_f()
	check(game.game_speed == 3, "F switches to x3")
	var triple: float = await sim_rate(1.5)
	press_f()
	check(game.game_speed == 1, "F wraps back to x1")
	print("SPEED rates x1=", snappedf(base, .01), " x2=", snappedf(double, .01), " x3=", snappedf(triple, .01))
	check(absf(double / base - 2.0) < .25 and absf(triple / base - 3.0) < .35, "sim time scales with speed")
	check(game.settings_payload().get("game_speed") == 1, "speed is saved with settings")
	game.open_shop()
	press_f()
	check(game.game_speed == 1, "F ignored while upgrade panel is open")
	print("SPEED_RESULT failures=", failures)
	quit(1 if failures else 0)
