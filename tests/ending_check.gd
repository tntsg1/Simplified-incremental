extends SceneTree
var failures := 0
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
	game.start_game()
	game.audio.set_enabled(false)
	game.set_process(false)
	await create_timer(.6).timeout
	game.sim.stage = 5
	game.sim.wave = 10
	game.sim.automation = true
	game.sim.start_boss()
	game.sim.enemies[0].hp = 1.0
	game.sim.boss_remaining = 300.0
	game.sim.enemies[0].lifetime = 300.0
	var boss_file := FileAccess.open("res://proofs/ending_boss_seed.json",FileAccess.WRITE)
	boss_file.store_string(JSON.stringify(game.sim.snapshot()))
	boss_file.close()
	game.cine_mode = "boss"
	for i in range(600):
		game.sim.advance(1.0/60.0)
		if game.sim.mode == "victory":
			break
	check(game.sim.mode == "victory", "Combat damage must defeat final boss")
	game._process(.016)
	check(game.cinema.ending_active(),"Actual final-boss defeat must start ending")
	check(game.menu == "", "Victory modal must wait for ending")
	game.cinema.set_process(false)
	var snapshot := JSON.stringify(game.sim.snapshot())
	for sample in [[1.5,"silence"],[7.0,"collapse"],[12.5,"singularity"],[15.0,"bang"],[23.0,"cosmos"],[29.0,"life"],[33.5,"galaxy"],[37.7,"solar"],[41.5,"earth"],[45.5,"city"],[49.8,"meteor"],[50.5,"cut"]]:
		game.cinema.t = sample[0]
		game.ending_skip.visible = sample[0] < 50.0
		game.pointer_frame.visible = sample[0] < 50.0
		game.pointer_frame.suppressed = sample[0] >= 50.0
		game.cinema.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://proofs/ending_%s.png" % sample[1])
	check(snapshot == JSON.stringify(game.sim.snapshot()), "Rendering must preserve campaign state")
	game.cinema.reduced_effects = true
	game.cinema.t = 15.0
	game.cinema.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/ending_soft.png")
	game.cinema.reduced_effects = false
	game.cinema.skip_ending()
	game._process(.016)
	check(game.menu == "result", "Skip must reveal victory result")
	game.play_ending()
	check(game.cinema.ending_active() and game.menu == "", "Replay must start ending without resetting campaign")
	game.cinema.t = 51.99
	game.cinema._process(.3)
	game._process(.016)
	check(game.menu == "result" and not game.cinema.ending_active(),"Natural completion must reveal victory result")
	var save: Dictionary = game.sim.snapshot()
	var c = preload("res://scripts/combat.gd").new()
	c.restore(save)
	check(c.mode == "victory" and c.stage == 5,"Completed campaign must survive restore")
	var f := FileAccess.open("res://proofs/ending_seed.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	f.close()
	game.close_modal()
	game.cine_mode = "victory"
	game.sim.restore(save)
	game._process(.016)
	check(not game.cinema.ending_active() and game.menu == "result","Restoring victory must offer replay without forcing cinematic")
	game.play_ending()
	game.show_title()
	check(not game.cinema.ending_active() and not game.ending_skip.visible and not game.pointer_frame.suppressed,"Returning home during ending must clear presentation state")
	game.saved = save
	game.continue_game()
	game._process(.016)
	check(game.menu == "result", "Continue in same instance must return to victory result")
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/ending_result.png")
	print("ENDING_CHECK failures=",failures)
	game.audio.free()
	quit(failures)
