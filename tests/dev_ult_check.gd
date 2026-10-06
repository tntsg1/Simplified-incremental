extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	for i in range(600):
		sim.advance(1.0 / 60, false)
	game.toggle_dev_mode()
	game.dev_toggle_ult()
	var a: bool = sim.fire_ultimate(Vector2(500, 300))
	sim.advance(0.1, false)
	var b: bool = sim.fire_ultimate(Vector2(500, 300))
	game.dev_cycle_ult_kind()
	game.dev_cycle_ult_kind()
	var c: bool = sim.fire_ultimate()
	print("DEV_ULT mode=", sim.mode, " first=", a, " refire_mid_strike=", b, " override=", sim.ultimate_kind(), " fired_override=", c, " active=", sim.ult.get("kind", ""), " charge=", sim.ult_charge, " button=", game.dev_ult_kind_button.text)
	game.toggle_dev_mode()
	print("DEV_ULT after_off unlimited=", sim.ult_unlimited, " kind=", sim.ultimate_kind())
	quit()
