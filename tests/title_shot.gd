extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	for i in range(120):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("build/shots/title_after.png")
	quit()
