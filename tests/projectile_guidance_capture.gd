extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_game()
	game.set_process(false)
	game.audio.set_enabled(false)
	game.sim.clear_battle()
	game.field.banner = {}
	game.field.spawn_barrage(0,Vector2(260,450),Vector2(850,350),false,8)
	var target: Dictionary = {"id":99,"pos":Vector2(900,280),"start":Vector2(900,280),"end":Vector2(900,280),"lifetime":20.0,"radius":15.0}
	for i in range(game.field.b_age.size()):
		game.field.b_age[i] = .12
		game.field.swerve(i,target)
	for step in range(3):
		for i in range(game.field.b_age.size()):game.field.b_age[i] = .06 + step * .12 + i * .035
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/guidance-%d.png" % step)
	print("GUIDANCE_VISUAL_PASS: incoming tangent preserved, three rendered trajectory frames")
	game.audio.free()
	quit()
