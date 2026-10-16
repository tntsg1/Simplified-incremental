extends SceneTree
# Steam trading-card art, rendered live from the game (no UI, no pointer):
#   card_<stage>.png  - the chapter boss in close-up, centred, 1920x1080 window
#   scene_<stage>.png - the chapter's battlefield with its celestial bodies, no threats
# Never moves the OS pointer: the pointer and its reticle are hidden inside the game.
# Usage (run with --resolution 1920x1080 --position 5000,5000): -- <out_dir> <stage> <scene|card>
# One shot per process: switching a live game between full combat and a lone boss in one
# process proved fragile, so tools/steam_cards.py runs each shot fresh.
var game: Control

func _initialize() -> void:
	call_deferred("run")

func hold_scene(focus: Vector2, zoom: float) -> void:
	game.sim.health = 100.0
	game.ui.hide()
	game.field.hover = Vector2(-9999, -9999)
	if game.get("pointer_frame") != null:
		game.pointer_frame.visible = false
	game.field.intro_t = 0.0
	# Wallpaper calm: no damage numbers or combo counter, at most a handful of threats.
	game.field.numbers.clear()
	game.field.combo = 0
	if focus != Vector2.INF:
		# Zoom round the subject and slide the field so the subject sits mid-frame.
		game.cam_hold = 99.0
		game.cam_target = zoom
		game.cam_zoom = zoom
		game.cam_focus = focus
		# Layout runs in the 1600x900 base space (canvas_items stretch), so centre there.
		game.field_origin = root.get_visible_rect().size * .5 - focus * game.field_zoom

func wait_real(seconds: float, focus_boss: bool, zoom: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		var focus: Vector2 = Vector2.INF
		if focus_boss:
			var boss: Dictionary = game.sim.boss_actor()
			if not boss.is_empty():
				focus = Vector2(boss.pos)
		hold_scene(focus, zoom)
		await process_frame

func wait_scene(seconds: float, focus: Vector2, zoom: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		hold_scene(focus, zoom)
		await process_frame

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CARD_SHOT ", path)

func setup(stage: int, bodies_all: bool) -> void:
	var sim = game.sim
	sim.stage = stage
	for i in range(sim.STAGE_COUNT):
		sim.owned[i] = false
	sim.levels.turrets = 0
	sim.automation = false
	for s in range(sim.STAGE_COUNT):
		sim.bodies[s] = (1 << sim.BODIES[s].size()) - 1 if bodies_all and s <= stage else 0
	sim.clear_battle()
	# A mid wave: wave 10 would raise the boss-warning frame over the scene.
	sim.wave = 3
	sim.start_wave()
	sim.spawn_left = 0
	sim.grace = 9999.0
	game.field.reset_growth()
	game.close_modal()

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	var st: int = int(args[1])
	var which: String = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.close_modal()
	var sim = game.sim
	if which == "scene":
		# The chapter's defense at full strength in a light wave - weapons, turrets and every
		# converted body firing - with the camera pushed in a little.
		setup(st, true)
		for i in range(st + 1):
			sim.owned[i] = true
		sim.levels.damage = 10 + st * 22
		sim.levels.reload = 10 + st * 13
		sim.levels.crit = 5 + st * 3
		sim.levels.area = st * 5
		sim.levels.turrets = mini(48, 12 + st * 4)
		sim.automation = true
		sim.wave = 2
		sim.start_wave()
		sim.spawn_left = mini(int(sim.spawn_left), 6)
		sim.grace = 0.0
		await wait_real(6.0, false, 1.0)
		await wait_scene(2.0, sim.defense_position() + Vector2(0, -150), 1.18)
		await shot("%s/scene_%d.png" % [out, st])
	else:
		# The boss alone, settled in, framed large.
		setup(st, false)
		sim.start_boss()
		await wait_real(4.5, true, 2.6)
		var boss: Dictionary = sim.boss_actor()
		if not boss.is_empty():
			var zoom: float = clampf(330.0 / (float(boss.radius) * 2.6), 1.6, 4.0)
			await wait_real(1.2, true, zoom)
			await shot("%s/card_%d.png" % [out, st])
	print("CARDS_DONE")
	quit()
