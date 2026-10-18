extends SceneTree
# Every interface language: no untranslated Chinese leaks into non-CJK languages, and the
# widest panels still fit. Usage: --headless --script res://tests/multilang_check.gd [-- <code>...]

var game: Control
var failures := 0
var assertions := 0
var han := RegEx.new()
var code := ""

func _initialize() -> void:
	han.compile("[\\x{4e00}-\\x{9fff}]")
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("MULTILANG %s: %s" % [code, description])

func leaks(text: String) -> bool:
	# Japanese and Traditional Chinese are written with Han characters; the rest never are.
	if code in ["ja", "zh_TW"]:
		return false
	return han.search(text) != null

func scan(node: Node) -> void:
	if (node is Label or node is Button) and node.visible and node != game.language_button:
		check(not leaks(node.text), "untranslated control: " + node.text.replace("\n", " ").left(60))
	for child in node.get_children():
		scan(child)

func widest(node: Node, limit: float) -> void:
	# Names the controls that push a panel past its width, so a failure says what to shorten.
	for child in node.get_children():
		if child is Control and child.visible and child.get_combined_minimum_size().x > limit:
			if child.get_child_count() == 0 or child is Button or child is Label:
				print("   WIDE %.0f %s: %s" % [child.get_combined_minimum_size().x, child.get_class(), str(child.get("text")).left(70)])
			widest(child, limit)

func run() -> void:
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var codes: Array = Array(OS.get_cmdline_user_args())
	if codes.is_empty():
		codes = game.LANGUAGES.filter(func(c): return c != "zh")
	game.start_game()
	game.sim.paused = true
	game.sim.money = 1e12
	game.sim.automation = true
	for c in codes:
		code = c
		game.apply_language(code)
		check(game.language == code, "language selected")
		check(TranslationServer.translate("弹头") != "弹头", "catalogue loaded")
		for stage in range(game.sim.STAGE_COUNT):
			game.sim.stage = stage
			game.sim.owned[stage] = true
			game.sim.ult_charge = 1.0
			game.update_hud()
			check(not leaks(game.stage_label.text), "stage label %d" % stage)
			check(not leaks(game.hint.text), "hint %d: %s" % [stage, game.hint.text.left(50)])
			check(not leaks(game.ult_button.text), "ultimate %d" % stage)
			check(game.ult_button.get_combined_minimum_size().x <= 210.0, "ultimate button width %d: %.0f" % [stage, game.ult_button.get_combined_minimum_size().x])
			game.open_shop()
			await process_frame
			scan(game.modal)
			check(game.modal.get_combined_minimum_size().x <= 1140, "shop width %d: %.0f" % [stage, game.modal.get_combined_minimum_size().x])
			if game.modal.get_combined_minimum_size().x > 1140:
				widest(game.modal, 250)
			check(game.modal.get_combined_minimum_size().y <= 900, "shop height %d: %.0f" % [stage, game.modal.get_combined_minimum_size().y])
			game.close_modal()
			await process_frame
			for body in game.sim.BODIES[stage]:
				check(not leaks(TranslationServer.translate(body.name)), "body " + body.name)
				check(not leaks(TranslationServer.translate(body.weapon)), "weapon " + body.weapon)
			for arch in game.sim.ROSTER[stage]:
				check(not leaks(TranslationServer.translate(game.sim.ROSTER[stage][arch][0])), "enemy " + game.sim.ROSTER[stage][arch][0])
		game.sim.stage = 2
		game.open_body_card(1)
		await process_frame
		scan(game.body_card)
		check(game.body_card.get_combined_minimum_size().x < 400, "conversion card width %.0f" % game.body_card.get_combined_minimum_size().x)
		if game.body_card.get_combined_minimum_size().x >= 400:
			widest(game.body_card, 300)
		game.close_body_card()
		game.open_pause()
		await process_frame
		scan(game.modal)
		check(game.modal.get_combined_minimum_size().y < 900, "pause height %.0f" % game.modal.get_combined_minimum_size().y)
		game.close_modal()
		game.sim.mode = "failed"
		game.show_result()
		await process_frame
		scan(game.modal)
		check(game.modal.get_combined_minimum_size().x <= 1140, "result width")
		game.close_modal()
		game.menu = ""
		game.sim.mode = "playing"
		print("MULTILANG ", code, " done; failures so far ", failures)
	print("MULTILANG_CHECK ", assertions, " assertions; failures ", failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
