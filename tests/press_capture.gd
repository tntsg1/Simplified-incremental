extends SceneTree
# Screenshots of the panel unfold and of the click/purchase burst.
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/%s.png" % name)

func mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	root.push_input(e)

func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	for i in range(30):
		await process_frame
	game.sim.money = 5000
	game.open_shop()
	for i in range(5):
		await process_frame
	await shot("press_unfold_a")
	for i in range(8):
		await process_frame
	await shot("press_unfold_b")
	for i in range(40):
		await process_frame
	var b: Button = game.cards[0].button
	var at: Vector2 = b.get_global_rect().get_center() + Vector2(30, 4)
	Input.warp_mouse(at)
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	root.push_input(m)
	for i in range(10):
		await process_frame
	mouse(at, true)
	await process_frame
	mouse(at, false)
	for i in range(4):
		await process_frame
	await shot("press_burst")
	print("PRESS damage=", game.sim.levels.damage)
	quit()
