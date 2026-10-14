extends "res://scripts/web_main.gd"

# Web-only controls; the browser gate authorizes the entry hotkey.
func cycle_speed() -> void:
	var steps: Array[int]=allowed_speeds().duplicate()
	if dev_mode:
		steps.append_array([16,32])
	game_speed = steps[(steps.find(game_speed)+1)%steps.size()]
	refresh_speed_button()

func toggle_dev_mode() -> void:
	dev_mode = not dev_mode
	dev_bar.visible = dev_mode
	if not dev_mode:
		dev_god = false
		dev_god_button.text = TranslationServer.translate("无敌：关")
		sim.ult_unlimited = false
		sim.ult_override = ""
		dev_ult_button.text = TranslationServer.translate("大招冷却：正常")
		dev_ult_kind_button.text = TranslationServer.translate("大招：本章")
		if game_speed not in allowed_speeds():
			game_speed = allowed_speeds().back()
			refresh_speed_button()
	show_notice(TranslationServer.translate("开发者模式：") + (TranslationServer.translate("开启 · 加速可到 ×32") if dev_mode else TranslationServer.translate("关闭")))

func dev_money() -> void:
	sim.money = sim.money * 10.0 + 1000.0
	update_hud()

func dev_skip_wave() -> void:
	if sim.mode == "wave":
		sim.clear_battle()
		sim.spawn_left = 0

func dev_prev_wave() -> void:
	if sim.mode == "boss":
		sim.wave = 10
	elif sim.mode in ["wave","intermission","failed"] and sim.wave > 1:
		sim.wave -= 1
	else:
		show_notice(TranslationServer.translate("已经是本章第一波"))
		return
	sim.start_wave()
	show_notice(TranslationServer.translate("回到第 %d 波") % sim.wave)

func dev_prev_stage() -> void:
	if sim.stage <= 0:
		show_notice(TranslationServer.translate("已经是第一章"))
		return
	sim.stage -= 1
	sim.wave = 1
	sim.start_wave()
	field.reset_growth()
	show_notice(TranslationServer.translate("回到") + TranslationServer.translate(sim.stage_data().title))

func dev_kill_boss() -> void:
	if sim.mode != "boss":
		show_notice(TranslationServer.translate("当前不是 Boss 战"))
		return
	for e in sim.enemies:
		if bool(e.boss) and not bool(e.dead):
			sim.apply_damage(e, float(e.hp) + 1.0, 1, 0)

func dev_next_stage() -> void:
	if sim.stage >= sim.LAST_STAGE:
		show_notice(TranslationServer.translate("已经是最后一章"))
		return
	if sim.mode in ["wave","intermission","boss"]:
		sim.finish_boss()

func dev_toggle_god() -> void:
	dev_god = not dev_god
	dev_god_button.text = TranslationServer.translate("无敌：开") if dev_god else TranslationServer.translate("无敌：关")

func dev_toggle_ult() -> void:
	sim.ult_unlimited = not sim.ult_unlimited
	if sim.ult_unlimited:
		sim.ult_charge = 1.0
	dev_ult_button.text = TranslationServer.translate("大招冷却：0") if sim.ult_unlimited else TranslationServer.translate("大招冷却：正常")
	update_ult_button()

func dev_cycle_ult_kind() -> void:
	# 本章 → 核弹 → 光粒打击 → … → 改写 π → 本章
	var kinds: Array[String] = sim.ULT_KINDS
	var i: int = kinds.find(sim.ult_override)
	sim.ult_override = kinds[i + 1] if i + 1 < kinds.size() else ""
	dev_ult_kind_button.text = TranslationServer.translate("大招：本章") if sim.ult_override == "" else TranslationServer.translate("大招：")+sim.ultimate_name()
	update_ult_button()


func _process(delta: float) -> void:
	if web_bridge != null and not web_home:
		if int(web_bridge.cheat_pause) >= 0:
			sim.paused = int(web_bridge.cheat_pause) == 1
			web_bridge.cheat_pause = -1
		if bool(web_bridge.cheat_toggle):
			web_bridge.cheat_toggle = false
			toggle_dev_mode()
	super._process(delta)
	if web_bridge != null:
		web_bridge.cheat_panel = dev_mode
		web_bridge.cheat_money = sim.money
