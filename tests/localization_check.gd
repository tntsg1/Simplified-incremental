extends SceneTree

var game: Control
var failures := 0
var assertions := 0
var han := RegEx.new()

func _initialize() -> void:
	han.compile("[\\x{4e00}-\\x{9fff}]")
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("LOCALIZATION: " + description)

func english_tree(node: Node) -> void:
	if node is Label or node is Button:
		var text: String = node.text
		check(han.search(text) == null or text == "中文 / English", "English control: " + text)
	for child in node.get_children():
		english_tree(child)

func run() -> void:
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.apply_language("en")
	check(TranslationServer.translate("太阳系") == "Solar System", "Native translation resource loaded")
	english_tree(game.modal)
	game.start_game()
	game.sim.paused = true
	game.sim.money = 1e12
	game.sim.automation = true
	var original_stage_titles: Array[String] = []
	for stage in range(6):
		game.sim.stage = stage
		game.sim.owned[stage] = true
		game.sim.ult_charge = 1.0
		original_stage_titles.append(game.sim.stage_data().title)
		game.update_hud()
		check(han.search(game.stage_label.text) == null, "English stage " + str(stage))
		check(han.search(game.hint.text) == null, "English hint " + str(stage))
		check(han.search(game.ult_button.text) == null, "English ultimate " + str(stage))
		check(game.ult_button.get_combined_minimum_size().x <= 210.0, "Ultimate fits reserved button width")
		game.open_shop()
		await process_frame
		english_tree(game.modal)
		check(game.modal.get_combined_minimum_size().x <= 1140, "English shop fits viewport")
		game.close_modal()
		await process_frame
		for resource in [game.sim.catalog.stages[stage], game.sim.catalog.weapons[stage]]:
			for key in ["title", "boss_title", "briefing", "role"]:
				if key in resource:
					check(han.search(TranslationServer.translate(resource.get(key))) == null, "Resource translation " + key)
		for body in game.sim.BODIES[stage]:
			check(han.search(TranslationServer.translate(body.name)) == null, "Celestial name translated")
			check(han.search(TranslationServer.translate(body.weapon)) == null, "Celestial weapon translated")
	game.sim.stage = 2
	game.open_body_card(1)
	await process_frame
	english_tree(game.body_card)
	check(game.body_card.get_combined_minimum_size().x < 400, "English conversion card wraps")
	game.close_body_card()
	game.open_pause()
	await process_frame
	english_tree(game.modal)
	check(game.modal.get_combined_minimum_size().y < 900, "Pause panel fits height")
	var snapshot: String = JSON.stringify(game.sim.snapshot())
	game.apply_language("zh")
	check(JSON.stringify(game.sim.snapshot()) == snapshot, "Language switch preserves campaign snapshot")
	check(game.stage_label.text.contains("太阳系"), "Chinese HUD restored")
	check(game.ui.get_node("Bottom/ShopButton").text == "升级防线  [U]", "Static upgrade button restores Chinese")
	check(game.ui.get_node("Bottom/PauseButton").text == "暂停  [Esc]", "Static pause button restores Chinese")
	check(game.ending_skip.text == "跳过结局  Esc", "Static cinematic action restores Chinese")
	game.apply_language("en")
	check(game.ui.get_node("Bottom/ShopButton").text == "Upgrade Defense  [U]", "Static upgrade button restores English")
	check(game.settings_payload().language == "en", "Language stored in settings")
	var payload: Dictionary = game.store.build(game.sim, game.settings_payload())
	var restored = load("res://scripts/combat.gd").new()
	check(restored.restore(payload), "Existing save schema accepts language preference")
	check(restored.stage == game.sim.stage and restored.money == game.sim.money, "Save preserves gameplay values")
	game.close_modal()
	game.sim.mode = "failed"
	game.show_result()
	await process_frame
	english_tree(game.modal)
	game.menu = ""
	game.sim.mode = "victory"
	game.show_result()
	await process_frame
	english_tree(game.modal)
	for stage in range(6):
		check(game.sim.catalog.stages[stage].title == original_stage_titles[stage], "Catalog source strings remain intact")
	print("LOCALIZATION_CHECK ", assertions, " assertions; failures ", failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
