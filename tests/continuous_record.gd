extends SceneTree
# Representative real-time combat: configured states, no save writes or acceleration.
var game: Control
var capture: AudioEffectCapture
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/"+path)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	game.pause_on_focus_loss=false
	root.add_child(game)
	await process_frame
	game.start_game()
	game.sim.wave=10
	game.sim.levels.damage=4
	game.sim.levels.reload=2
	game.sim.levels.speed=3
	game.sim.automation=true
	game.sim.start_wave()
	game.audio.set_enabled(true)
	# Capture the mix bus before the muted hardware output, so tests stay quiet.
	AudioServer.set_bus_volume_db(0,-80)
	capture=AudioEffectCapture.new()
	capture.buffer_length=3
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Skyguard Mix"),capture)
	var started: int=Time.get_ticks_msec()
	var part: int=0
	var last_shot: int=-1
	var finished_at: int=0
	var raw:=FileAccess.open("res://proofs/continuous_audio.f32",FileAccess.WRITE)
	var sample_frames: int=0
	for frame in range(18000):
		await process_frame
		if capture.can_get_buffer(1):
			var buffer: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
			raw.store_buffer(buffer.to_byte_array())
			sample_frames+=buffer.size()
		var seconds: float=(Time.get_ticks_msec()-started)/1000.0
		if "--audio-smoke" in OS.get_cmdline_user_args() and seconds>=3:
			part=4
			break
		if part==0 and seconds>=10:
			part=1
			game.sim.levels.damage=10
			game.sim.levels.reload=10
			game.sim.notice.emit("发射器进化 · 第二发射井上线")
		elif part==1 and seconds>=20:
			part=2
			game.sim.stage=5
			game.sim.wave=10
			game.sim.owned.assign([true,true,true,true,true,true])
			game.sim.levels={"damage":104,"speed":23,"reload":101,"crit":95,"area":93,"pierce":91,"targets":88}
			game.sim.start_wave()
		elif part==2 and seconds>=38:
			part=3
			game.sim.start_boss()
		if part==3 and game.sim.mode=="victory":
			part=4
			finished_at=Time.get_ticks_msec()
		if part==4 and Time.get_ticks_msec()-finished_at>=5000:break
		if game.sim.mode=="failed":
			print("CONTINUOUS unexpected failure phase=",part," health=",game.sim.health)
			break
		var frame_id: int=int(seconds/1.5)
		if frame_id!=last_shot:
			last_shot=frame_id
			if DisplayServer.get_name()!="headless":await screenshot("natural_%02d.png"%frame_id)
		if frame%180==0:print("CONTINUOUS seconds=",snappedf(seconds,.1)," phase=",part," mode=",game.sim.mode," actors=",game.sim.enemies.size()," shots=",game.sim.shots.size()," kills=",game.sim.kills)
	raw.flush()
	raw.close()
	print("CONTINUOUS_AUDIO seconds=",float(sample_frames)/AudioServer.get_mix_rate()," sample_rate=",AudioServer.get_mix_rate()," frames=",sample_frames," phase=",part)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if part==4 else 1)
