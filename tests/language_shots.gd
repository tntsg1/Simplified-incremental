extends SceneTree
# Rendered layout check for one interface language: title, battle HUD, upgrade shop, pause.
# Never moves the OS pointer: the in-game pointer is hidden. Saves and preferences stay off.
# Usage (run with --resolution 1600x900 --position 5000,5000): -- <out_dir> <language>
var game: Control
var out := ""
var code := ""

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		game.sim.health = 100.0
		game.field.hover = Vector2(-9999, -9999)
		if game.get("pointer_frame") != null:
			game.pointer_frame.visible = false
		await process_frame

func shot(name: String) -> void:
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, code, name])
	print("LANG_SHOT ", code, " ", name)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0]
	code = args[1]
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	if code != "zh":
		game.apply_language(code)
	await frames(240)
	await shot("title")
	game.start_game()
	game.close_modal()
	var sim = game.sim
	sim.stage = 5
	for i in range(sim.STAGE_COUNT):
		sim.owned[i] = i <= 5
	sim.levels.damage = 60
	sim.levels.reload = 40
	sim.levels.turrets = 20
	sim.automation = true
	sim.money = 2.4e14
	sim.clear_battle()
	sim.wave = 6
	sim.start_wave()
	game.field.reset_growth()
	await frames(90)
	await shot("hud")
	game.open_shop()
	await shot("shop")
	game.close_modal()
	game.open_pause()
	await shot("pause")
	quit()
