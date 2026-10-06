extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director = load("res://scripts/audio_director.gd").new()
	root.add_child(director)
	var failures: int = 0
	for key in ["clean_fire_0", "clean_hit_rock", "clean_destroy", "clean_boss", "alarm", "failed", "victory"]:
		director.play(key, -80, 1, false, true)
		if director.streams.has(key):
			failures += 1
	for key in ["purchase", "wave_clear", "milestone"]:
		director.play(key, -80, 1, false, true)
		if not director.streams.has(key):
			failures += 1
	var sim = load("res://scripts/combat.gd").new()
	sim.start_new()
	sim.mode = "boss"
	sim.boss_remaining = 5
	director.update(sim, .1)
	if director.tension.playing:
		failures += 1
	print("AUDIO_POLICY_RESULT failures=", failures, " allowed=purchase,wave_clear,milestone boss_pulse=off")
	director.free()
	sim = null
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
