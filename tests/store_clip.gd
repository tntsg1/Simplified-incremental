extends SceneTree
# Store-page clips, recorded with Godot's Movie Maker (--write-movie, fixed fps) so every
# frame renders whatever the frame time. Waits count frames, never wall-clock time.
# Never moves the OS pointer: the in-game pointer and its reticle are hidden instead.
# Usage: --write-movie <out.avi> --fixed-fps 30 --resolution 1280x720 --position 5000,5000
#        --script res://tests/store_clip.gd -- <scenario> <seconds> [language]
#   scenarios: city | bodies | weapons | boss | jump | ult:<kind>
var game: Control

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		game.sim.health = 100.0
		game.field.hover = Vector2(-9999, -9999)
		if game.get("pointer_frame") != null:
			game.pointer_frame.visible = false
		await process_frame

func setup(stage: int, wave: int, power: float = 1.0) -> void:
	# power scales the defense down for showcase shots: threats must live long enough to read.
	var sim = game.sim
	sim.stage = stage
	for i in range(sim.STAGE_COUNT):
		sim.owned[i] = i <= stage
	sim.levels.damage = int((10 + stage * 22) * power)
	sim.levels.reload = int((10 + stage * 13) * power)
	sim.levels.crit = int((5 + stage * 3) * power)
	sim.levels.area = int(stage * 5 * power)
	sim.levels.pierce = int(maxi(0, stage - 2) * 4 * power)
	sim.levels.targets = int(maxi(0, stage - 3) * 3 * power)
	sim.levels.turrets = mini(48, int((8 + stage * 5) * power))
	sim.automation = true
	sim.money = 2400.0 * pow(10.0, stage * 2.4)
	for s in range(sim.STAGE_COUNT):
		sim.bodies[s] = (1 << sim.BODIES[s].size()) - 1 if s <= stage else 0
	sim.clear_battle()
	sim.wave = wave
	sim.start_wave()
	sim.grace = 0.0
	game.field.reset_growth()
	game.close_modal()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenario: String = args[0]
	var seconds: float = float(args[1]) if args.size() > 1 else 8.0
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	if args.size() > 2:
		# Store pages show each language its own interface; saves and preferences stay off.
		game.apply_language(args[2])
	game.start_game()
	game.close_modal()
	var sim = game.sim
	var warm: int = 90
	match scenario:
		"city":
			setup(0, 8, .25)
		"bodies":
			setup(2, 8, .55)
		"weapons":
			setup(6, 8, .6)
		"boss":
			setup(7, 10)
			sim.start_boss()
			warm = 150
		"jump":
			setup(2, 10)
			sim.start_boss()
		_:
			if scenario.begins_with("ult:"):
				var kind: String = scenario.substr(4)
				setup(sim.ULT_KINDS.find(kind), 6)
	await frames(warm)
	print("CLIP_START ", Engine.get_frames_drawn())
	if scenario.begins_with("ult:"):
		sim.ult_charge = 1.0
		game.fire_ultimate_at(Vector2.INF)
	if scenario == "jump":
		# Finish the boss: its death, the stamp and the full jump cinematic follow.
		var boss: Dictionary = sim.boss_actor()
		if not boss.is_empty():
			boss.hp = 1.0
	await frames(int(seconds * 30.0))
	print("CLIP_END ", Engine.get_frames_drawn(), " mode=", sim.mode, " enemies=", sim.enemies.size(), " left=", sim.spawn_left, " paused=", sim.paused, " grace=", sim.grace)
	quit()
