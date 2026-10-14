extends SceneTree
# Plays a real chapter with sound on and reports which designed effects fired.
# Usage: -- <stage> <seconds> [ult|boss|bodies]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0]) if args.size() > 0 else 0
	var seconds: float = float(args[1]) if args.size() > 1 else 12.0
	var game: Control = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = stage
	sim.wave = 4
	for i in range(stage + 1):
		sim.owned[i] = true
	sim.levels.turrets = 12
	sim.levels.damage = 10 + stage * 22
	sim.levels.reload = 10 + stage * 13
	sim.automation = true
	sim.money = 1e30
	if args.size() > 2 and args[2] == "bodies":
		for s2 in range(stage + 1):
			sim.bodies[s2] = (1 << sim.BODIES[s2].size()) - 1
	sim.start_wave()
	game.close_modal()
	game.audio.set_enabled(true)
	var fire_ult: bool = args.size() > 2 and args[2] == "ult"
	if args.size() > 2 and args[2] == "boss":
		sim.wave = 10
		sim.start_boss()
	var fired: bool = false
	var started: int = Time.get_ticks_msec()
	var until: int = started + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		sim.health = 100.0
		if fire_ult and not fired and Time.get_ticks_msec() - started > 3000:
			# Count only what plays from the ultimate onward.
			game.audio.played.clear()
			sim.ult_charge = 1.0
			game.fire_ultimate_at(Vector2.INF)
			fired = true
		await process_frame
	var keys: Array = game.audio.played.keys()
	keys.sort()
	var line: String = ""
	for k in keys:
		line += "%s=%d " % [k, game.audio.played[k]]
	print("SFX_PLAYED ", line)
	quit()
