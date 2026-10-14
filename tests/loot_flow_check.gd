extends SceneTree
const Field = preload("res://scripts/battlefield.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var field = Field.new()
	field.money_anchor = Vector2(500, -80)
	var coin: Dictionary = {"from": Vector2(250, 400), "ctrl": Vector2(130, 480), "age": 0.0, "dur": 1.8, "ultimate": true, "lane": 25.0, "phase": 1.0}
	check(field.coin_position(coin) == coin.from, "Stream starts at enemy")
	coin.age = 1.8
	check(field.coin_position(coin).distance_to(field.money_anchor) < .001, "Stream ends at wallet")
	# Numerical velocity across the old scatter/pull boundary must be continuous.
	coin.age = 1.8 * .28
	var dt: float = .0001
	var before: Vector2 = (field.coin_position(coin) - field.coin_position(coin, -dt)) / dt
	var after: Vector2 = (field.coin_position(coin, dt) - field.coin_position(coin)) / dt
	check(before.distance_to(after) < 1.0, "Scatter/pull velocity jumps")
	coin.age = 0.0
	check(field.coin_position(coin, .001).distance_to(coin.from) < .01, "Start snaps outward")
	coin.age = 1.8
	check(field.coin_position(coin, -.001).distance_to(field.money_anchor) < .01, "Arrival snaps into wallet")
	field.free()
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_game()
	game.sim.queue_ultimate_reward(Vector2(250, 400), 10, 100.0)
	for tick in range(45):
		game.advance_frame(1.0 / 60.0, 8.0)
	check(is_equal_approx(game.sim.reward_batches[0].age, .75), "8x compresses reward animation")
	check(game.sim.money == 0, "Fast-forward pays before flight")
	game.field.on_ultimate_loot(Vector2(250, 400), 10, 1.8)
	game.field.animate(8.0 / 60.0, 1.0 / 60.0)
	check(is_equal_approx(game.field.coins[0].age, 1.0 / 60.0), "Coins use simulation clock instead of real time")
	game.sim.paused = true
	game.advance_frame(1.0, 8.0)
	game.field.animate(8.0, 1.0)
	check(is_equal_approx(game.sim.reward_batches[0].age, .75), "Pause advances reward clock")
	check(is_equal_approx(game.field.coins[0].age, 1.0 / 60.0), "Pause advances coin flight")
	game.queue_free()
	await process_frame
	print("LOOT_FLOW failures=", failures)
	quit(1 if failures else 0)
