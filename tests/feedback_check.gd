extends SceneTree
var game: Control
var samples:=PackedVector2Array()
var capture: AudioEffectCapture
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func frame_shot(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/"+path)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store.enabled=false
	game.pause_on_focus_loss=false
	game.close_modal()
	game.sim.start_new(122)
	game.sim.paused=true
	game.audio.set_enabled(true)
	AudioServer.set_bus_volume_db(0,-80)
	capture=AudioEffectCapture.new()
	capture.buffer_length=2
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Skyguard Mix"),capture)
	for stage in range(6):
		game.sim.stage=stage
		game.sim.wave=10
		game.sim.clear_battle()
		game.sim.owned.assign([true,stage>=1,stage>=2,stage>=3,stage>=4,stage>=5])
		game.sim.levels.reload=10+stage*10
		game.sim.mode="boss"
		game.sim.start_boss()
		game.sim.paused=true
		game.sim.automation=true
		var p:=Vector2(480,210)
		var boss: Dictionary=game.sim.enemies[0]
		boss.pos=p
		for i in range(6):
			if not game.sim.owned[i]:continue
			var origin: Vector2=game.sim.weapon_origin(i)
			game.sim.fire_weapon(i,boss)
		game.sim.apply_damage(boss,float(boss.hp)*.02,1,stage,true)
		await process_frame
		await frame_shot("feedback_fire_%d.png"%stage)
		for f in range(150):
			if f==65:
				game.sim.apply_damage(boss,float(boss.hp)*2,1,stage,false)
			if f==69:await frame_shot("feedback_death_%d.png"%stage)
			if f==110:game.sim.mode="transition" if stage<5 else "victory"
			await process_frame
			if capture.can_get_buffer(1):samples.append_array(capture.get_buffer(capture.get_frames_available()))
	var bytes:=PackedByteArray()
	var peak: float=0
	var energy: float=0
	bytes.resize(samples.size()*4)
	for i in range(samples.size()):
		peak=maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		energy+=samples[i].length_squared()
		bytes.encode_s16(i*4,int(clampf(samples[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,int(clampf(samples[i].y,-1,1)*32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.stereo=true
	stream.mix_rate=int(AudioServer.get_mix_rate())
	stream.data=bytes
	stream.save_to_wav("res://proofs/runtime_audio.wav")
	print("FEEDBACK frames=",samples.size()," seconds=",float(samples.size())/AudioServer.get_mix_rate()," peak_db=",linear_to_db(peak)," rms_db=",linear_to_db(sqrt(energy/maxi(1,samples.size())/2))," voices=",game.audio.voices.size()," stages=6")
	game.audio.set_enabled(false)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
