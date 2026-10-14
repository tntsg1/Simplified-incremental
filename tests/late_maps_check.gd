extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.saved = {}
	game.start_game()
	game.audio.set_enabled(false)
	await create_timer(.6).timeout
	var c = game.sim
	for stage in [3, 4, 5]:
		c.clear_battle()
		c.stage = stage
		c.mode = "wave"
		c.spawn_left = 100
		c.spawn_clock = 1000000.0
		c.money = 1e18
		c.elapsed = 15.0
		c.bodies[stage] = 0
		for slot in range(c.BODIES[stage].size()):
			check(game.field.body_at(c.body_position(stage, slot)) == slot, "Map body must be selectable at visual center")
		game._process(1.0 / 60.0)
		game.field.hover = c.body_position(stage, 0)
		game.field.atlas.advance(.25, game.field)
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/maps_hover_%d.png" % stage)
		check(float(game.field.atlas.hover_strength[stage * 16]) > .9, "Hover must reveal actual node")
		var before: Dictionary = c.snapshot()
		game.field.clock += .5
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(c.snapshot() == before, "Rendering map animation must not change gameplay or random state")
		check(c.convert_body(0), "Actual map body conversion")
		check(game.field.body_at(c.body_position(stage, 0)) != 0, "Converted node must not offer duplicate purchase")
		game.field.on_body_fired(stage, 0, c.body_position(stage, 0), Vector2(500, 50), false)
		check(game.field.body_flash[stage * 16] > 0.0, "Fire signal reaches map node")
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/maps_converted_%d.png" % stage)
		var restored = preload("res://scripts/combat.gd").new()
		check(restored.restore(c.snapshot()) and restored.body_converted_at(stage, 0), "Map conversion survives save restore")
		game.field.reduced_effects = true
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/maps_soft_%d.png" % stage)
		game.field.reduced_effects = false
	# Transition rendering must restore the field transform before combat draws.
	for stage in [2, 3, 4]:
		c.stage = stage
		c.mode = "transition"
		c.mode_time = c.transition_length * .5
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(game.field.scene_transform == Transform2D.IDENTITY, "Scale transition restores identity transform")
	print("LATE_MAPS_CHECK failures=", failures, " cached_clouds=", game.field.atlas.scaled_clouds.size(), " filaments=", game.field.atlas.filaments.size())
	game.audio.free()
	quit(1 if failures else 0)
