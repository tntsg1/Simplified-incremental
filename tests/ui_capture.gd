extends SceneTree
# HUD screenshots: a hovered bottom-bar button, then a live boss fight bar.
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	call_deferred("run")

func hover(game, node: Control) -> void:
	var at: Vector2 = node.get_global_rect().get_center() + Vector2(-40, 0)
	# Never move the real OS pointer: a synthetic motion event is enough for the game.
	var e := InputEventMouseMotion.new()
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
		if sim.stage == 1 and sim.mode == "boss":
			break
		sim.advance(1.0 / 60, false)
	game.field.reset_growth()
	var shop: Control = game.ui.get_node("Bottom/ShopButton")
	hover(game, shop)
	for i in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/ui_hover.png")
	var wait_until: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < wait_until:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/ui_boss.png")
	print("UI_CAPTURE mode=", sim.mode, " boss_hp=", sim.enemies[0].hp / sim.boss_max_hp() if not sim.enemies.is_empty() else -1)
	quit()
