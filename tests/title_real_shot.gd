extends SceneTree
# Title screen against the real save (read only: nothing is started or saved).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(150):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("TITLE saved_version=", game.saved.get("version", -1), " resume_stage=", game.sim.saved_stage(game.saved) if not game.saved.is_empty() else -1)
	game.store.enabled = false
	quit()
