extends SceneTree
# Internal viewport capture. Configured combat states, real 60 Hz progression.
var game: Control
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://proofs/action_frames"))
	game=load("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	game.pause_on_focus_loss=false
	root.add_child(game)
	await process_frame
	game.start_game()
	game.audio.set_enabled(false)
	game.sim.wave=10
	game.sim.automation=true
	game.sim.levels.damage=4
	game.sim.levels.reload=4
	game.sim.levels.speed=4
	game.sim.start_wave()
	var started: int=Time.get_ticks_msec()
	var part: int=0
	var clip_frame: int=0
	var target_changes: int=0
	for frame in range(2500):
		await process_frame
		var elapsed: float=(Time.get_ticks_msec()-started)/1000.0
		if elapsed>=12 and part==0:
			part=1
			game.sim.levels.damage=10
			game.sim.levels.reload=10
		if elapsed>=20 and part==1:
			part=2
			game.sim.stage=5
			game.sim.wave=10
			game.sim.owned.assign([true,true,true,true,true,true])
			game.sim.levels={"damage":104,"speed":23,"reload":101,"crit":95,"area":93,"pierce":91,"targets":88}
			game.sim.start_wave()
		if frame%150==0 and not game.sim.enemies.is_empty():
			var e: Dictionary=game.sim.enemies.back()
			game.sim.select_target(e.pos)
			target_changes+=1
		if frame%2==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg("res://proofs/action_frames/%05d.jpg"%clip_frame,.9)
			clip_frame+=1
		if elapsed>=36:break
	print("ACTION_CLIP frames=",clip_frame," wall_seconds=",float(Time.get_ticks_msec()-started)/1000," target_changes=",target_changes," kills=",game.sim.kills," capture=internal_viewport configured_states=true")
	game.queue_free()
	await process_frame
	quit()
