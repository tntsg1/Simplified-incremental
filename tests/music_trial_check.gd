extends SceneTree
const Director = preload("res://scripts/audio_director.gd")
const Combat = preload("res://scripts/combat.gd")
var failures := 0
var checks := 0
var director: Node
var sim: RefCounted
var capture: AudioEffectCapture
var recording := PackedVector2Array()

func _initialize() -> void:
	Engine.max_fps = 30
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func run_for(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		director.update(sim, 1.0 / 30.0)
		await process_frame
		if capture.can_get_buffer(1):
			recording.append_array(capture.get_buffer(capture.get_frames_available()))

func run() -> void:
	director = Director.new()
	root.add_child(director)
	sim = Combat.new()
	sim.start_new()
	director.set_enabled(true)
	director.effects_level = 0.0
	director.set_enabled(true)
	AudioServer.set_bus_volume_db(0, -80.0)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Skyguard Music"), capture)
	for key in ["music/ch01_city","music/solar_wind","music/dockside","music/glass","music/boss_tactical","music/boss_fury","music/scale_jump"]:
		check(director.get_stream(key) != null, "stream loads: " + key)
	for sample in [["wave",0,false,"music/ch01_city"],["wave",1,false,"music/solar_wind"],["wave",2,false,"music/solar_wind"],["boss",0,false,"music/boss_tactical"],["boss",0,true,"music/boss_fury"],["transition",0,false,"music/scale_jump"],["wave",3,false,"music/dockside"],["wave",6,false,"music/glass"]]:
		sim.mode = sample[0]
		sim.stage = sample[1]
		sim.enraged = sample[2]
		await run_for(3.0)
		check(director.current_music_key == sample[3], "correct cue: " + sample[3])
		var player: AudioStreamPlayer = director.music[director.active_music]
		check(player.playing, "cue actually plays")
		check(player.stream.loop == (sample[0] != "transition"), "only transition is one-shot")
		check(not director.music[1-director.active_music].playing, "outgoing cue stops after fade")
		print("MUSIC_CUE ",sample[3]," position=",player.get_playback_position()," db=",player.volume_db)
		if sample[3] in ["music/ch01_city", "music/solar_wind"]:
			var expected_length: float = 208.416 if sample[3] == "music/ch01_city" else 224.016
			check(absf(player.stream.get_length() - expected_length) < .1, "recording keeps full duration: " + sample[3])
			player.seek(player.stream.get_length() - .15)
			await run_for(1.6)
			check(player.playing and player.get_playback_position() < 3.0, "recording loops at end: " + sample[3])
	# Adjacent waves and chapters using the same cue must not restart it.
	var player: AudioStreamPlayer = director.music[director.active_music]
	var before: float = player.get_playback_position()
	sim.stage = 7
	sim.wave += 1
	await run_for(.3)
	check(player.get_playback_position() > before, "same-theme chapter and wave preserve playback")
	var full_volume: float = player.volume_db
	sim.paused = true
	await run_for(.1)
	check(is_equal_approx(player.volume_db, full_volume - 7.0), "pause softens music")
	sim.paused = false
	# A quiet interval and final fade make the transitions audible in the preview.
	director.music_level = 0.0
	director.set_enabled(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Skyguard Music")), "zero music level mutes bus")
	director.music_level = .55
	director.set_enabled(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Skyguard Music")), "global mute covers music")
	director.set_enabled(true)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Skyguard Music")), "unmute restores music")
	# Verify wrap-around using the short boss-fury loop.
	sim.mode = "boss"
	sim.enraged = true
	director.update(sim, .1)
	player = director.music[director.active_music]
	player.seek(player.stream.get_length() - .15)
	await run_for(1.6)
	check(player.playing and player.get_playback_position() < 3.0, "music loops at end")
	# Non-looping transition must end and stay stopped while its state persists.
	sim.mode = "transition"
	director.update(sim, .1)
	player = director.music[director.active_music]
	player.seek(player.stream.get_length() - .15)
	await run_for(1.6)
	check(not player.playing, "transition finishes once without restarting")
	var peak: float = 0.0
	var energy: float = 0.0
	var bytes := PackedByteArray()
	bytes.resize(recording.size()*4)
	for i in range(recording.size()):
		peak = maxf(peak,maxf(absf(recording[i].x),absf(recording[i].y)))
		energy += recording[i].length_squared()
		bytes.encode_s16(i*4,int(clampf(recording[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,int(clampf(recording[i].y,-1,1)*32767))
	check(peak > .001 and peak < 1.0, "captured real non-silent audio without clipping")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = bytes
	wav.save_to_wav(ProjectSettings.globalize_path("res://build/music-trial/runtime-preview.wav"))
	print("MUSIC_TRIAL checks=",checks," failures=",failures," peak_db=",linear_to_db(peak)," rms_db=",linear_to_db(sqrt(energy/maxi(1,recording.size())/2)))
	director.free()
	await process_frame
	quit(1 if failures else 0)
