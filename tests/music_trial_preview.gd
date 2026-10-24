extends SceneTree
# Local audition only. Configured combat states, no player save writes or Steam.
var game: Control
var selected := 0
var held := false
var proof := false
var elapsed := 0.0
var capture: AudioEffectCapture
var samples := PackedVector2Array()
var names := ["城市 · Orbital", "深空 · Dockside", "银河 · Glass", "Boss · Tactical", "狂暴 · Tactical 长版强段", "跃迁 · Expanding Scale"]
var caption: Label

func _initialize() -> void:
	Engine.max_fps = 30
	proof = "--music-proof" in OS.get_cmdline_user_args()
	call_deferred("run")

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	game.preferences_path = "user://music-trial-preview.cfg"
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.sound_on = true
	game.audio.music_level = .7
	game.audio.effects_level = .35
	game.audio.set_enabled(true)
	caption = Label.new()
	caption.position = Vector2(40, 125)
	caption.add_theme_font_size_override("font_size", 16)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui.add_child(caption)
	if proof:
		AudioServer.set_bus_volume_db(0, -80.0)
		capture = AudioEffectCapture.new()
		capture.buffer_length = 2.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Skyguard Mix"), capture)
	select_scene(0)

func select_scene(which: int) -> void:
	selected = which
	game.close_modal()
	var sim = game.sim
	sim.stage = [0, 3, 6, 0, 0, 0][which]
	sim.wave = 10 if which in [3, 4] else 4
	sim.automation = true
	sim.levels.damage = 10 + sim.stage * 16
	sim.levels.reload = 10 + sim.stage * 12
	sim.levels.turrets = 6
	sim.health = 100.0
	for i in range(sim.STAGE_COUNT):
		sim.owned[i] = i <= sim.stage
		sim.bodies[i] = 1 if i <= sim.stage else 0
	if which in [3, 4]:
		sim.start_boss()
		if which == 4:
			sim.boss_actor().hp *= .45
			sim.enraged = true
	else:
		sim.start_wave()
	if which == 5:
		sim.mode = "transition"
		sim.transition_from = 0
	game.field.reset_growth()
	caption.text = "本地音乐试听 · 测试场景 · 不保存进度\n1 城市  2 深空  3 银河  4 Boss  5 狂暴  6 跃迁\n正在播放：" + names[which]
	print("PREVIEW_SCENE ", which, " ", names[which])

func _process(delta: float) -> bool:
	if game == null or caption == null:
		return false
	elapsed += delta
	var pressed := false
	for i in range(6):
		if Input.is_key_pressed(KEY_1 + i):
			pressed = true
			if not held:
				select_scene(i)
	held = pressed
	if proof:
		if capture.can_get_buffer(1):
			samples.append_array(capture.get_buffer(capture.get_frames_available()))
		var next_scene: int = mini(5, int(elapsed / 4.0))
		if next_scene != selected:
			select_scene(next_scene)
		if elapsed > 25.0:
			var path := "E:/godot/zengliang/build/music-trial/"
			var bytes := PackedByteArray()
			bytes.resize(samples.size()*4)
			var peak := 0.0
			for i in range(samples.size()):
				peak = maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
				bytes.encode_s16(i*4,int(clampf(samples[i].x,-1,1)*32767))
				bytes.encode_s16(i*4+2,int(clampf(samples[i].y,-1,1)*32767))
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.stereo = true
			wav.mix_rate = int(AudioServer.get_mix_rate())
			wav.data = bytes
			wav.save_to_wav(path + "gameplay-mix.wav")
			print("GAMEPLAY_MUSIC_CAPTURE seconds=",float(samples.size())/wav.mix_rate," peak_db=",linear_to_db(peak)," cue=",game.audio.current_music_key)
			game.queue_free()
			quit(0 if peak > .001 and peak < 1.0 else 1)
	return false
