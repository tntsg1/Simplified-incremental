extends SceneTree
# Celestial conversion: clicking a body opens its card; converting spends the
# right price, the body starts firing, and conversions survive save/restore.
const Combat = preload("res://scripts/combat.gd")
var game: Control
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("BODY_CHECK ", description, " ", ok)
	if not ok:
		failures += 1

func click_field(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.field.to_global(point)
	game._unhandled_input(event)

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = 1
	sim.automation = true
	sim.owned[1] = true
	sim.start_wave()
	await process_frame
	var moon: Vector2 = sim.body_position(1, 0)
	check(game.field.body_at(moon) == 0, "moon is clickable")
	sim.money = 10.0
	click_field(moon)
	await process_frame
	check(is_instance_valid(game.body_card) and game.body_card_slot == 0, "click opens the conversion card")
	check(game.body_card_button.disabled and game.body_card_button.text.begins_with("还差"), "card shows the missing amount")
	game.confirm_body_card()
	check(not sim.body_converted_at(1, 0) and is_equal_approx(sim.money, 10.0), "cannot convert without funds")
	var price: float = sim.body_cost()
	sim.money = price + 5.0
	game.confirm_body_card()
	check(sim.body_converted_at(1, 0) and is_equal_approx(sim.money, 5.0), "conversion spends the exact price")
	check(not is_instance_valid(game.body_card), "card closes after converting")
	check(sim.body_cost() > price * 2.0, "next body costs more")
	check(game.field.body_at(sim.body_position(1, 0)) == -1, "converted body is no longer offered")
	var fired: Array[int] = [0]
	sim.body_fired.connect(func(_s, _k, _o, _d, _c): fired[0] += 1)
	var until: int = Time.get_ticks_msec() + 3000
	while fired[0] == 0 and Time.get_ticks_msec() < until:
		await process_frame
	check(fired[0] > 0, "converted body fires")
	var copy = Combat.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))) and copy.body_converted_at(1, 0), "conversions survive save and restore")
	var old_save: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	old_save.erase("bodies")
	check(copy.restore(old_save) and copy.total_bodies() == 0, "older saves load with no conversions")
	print("BODY_RESULT failures=", failures)
	quit(1 if failures else 0)
