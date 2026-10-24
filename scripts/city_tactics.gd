extends PanelContainer
# Stable screen-space controls: no need to chase a moving weak point.
var game: Control
var modes: Button
var body: Button
var rift: Button
var status: Label
var health: ProgressBar
var details: Label
var boss_controls: VBoxContainer

func setup(owner_game: Control) -> void:
	game = owner_game
	position = Vector2(24, 132)
	custom_minimum_size.x = 270
	size.x = 270
	add_theme_stylebox_override("panel", game.panel_style(Color("141414ed"), Color("454545"), 3))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	modes = game.button("", open_modes)
	column.add_child(modes)
	boss_controls = VBoxContainer.new()
	boss_controls.add_theme_constant_override("separation", 7)
	column.add_child(boss_controls)
	status = game.label("", 15)
	boss_controls.add_child(status)
	body = game.button("", func(): game.sim.select_city_part(false))
	boss_controls.add_child(body)
	rift = game.button("", func(): game.sim.select_city_part(true))
	boss_controls.add_child(rift)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 7
	health.show_percentage = false
	boss_controls.add_child(health)
	details = game.label("", 13, Color("b4b4b4"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 240
	boss_controls.add_child(details)
	refresh()

func mode_name(value: int) -> String:
	return game.words("重点拦截", "Focused interception") if value == 0 else game.words("分路拦截", "Split interception")

func open_modes() -> void:
	game.menu = "city_modes"
	game.sim.paused = true
	game.sim.manual_held = false
	game.sim.manual_queued = false
	var column: VBoxContainer = game.new_modal(minf(620, game.size.x - 64), game.words("导弹发射井 · 射击模式", "Missile silo · Fire mode"), game.words("免费调整。战斗中更改，下波生效；准备时立即生效。", "Free to change. Combat changes apply next wave; preparation changes apply now."))
	for value in range(2):
		var chosen: int = value
		var description: String = game.words("一枚完整导弹打向所选目标。适合本体或裂隙。", "One full missile hits your target. Good for the body or fissure.") if value == 0 else game.words("最多三枚小导弹，各打一个目标，每枚伤害为原来的 1/3。目标不足不补发。", "Up to three small missiles hit different targets, each at 1/3 damage. Empty lanes waste firepower.")
		column.add_child(game.button(mode_name(value), func(): game.sim.set_city_mode(chosen); game.close_modal(); refresh()))
		var explanation: Label = game.label(description, 15)
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(explanation)
	column.add_child(game.button(game.words("返回战场", "Return"), game.close_modal))

func refresh() -> void:
	var sim = game.sim
	visible = game.menu == "" and sim.mode in ["wave", "boss", "intermission"] and (sim.stage > 0 or sim.wave >= 6)
	if not visible: return
	modes.text = game.words("导弹 · ", "Missiles · ") + mode_name(sim.city_mode)
	if sim.city_mode != sim.city_mode_next:
		modes.text += "\n" + game.words("下波：", "Next: ") + mode_name(sim.city_mode_next)
	var boss: Dictionary = sim.boss_actor()
	boss_controls.visible = sim.CityBoss.available(boss)
	if not boss_controls.visible: return
	var intact: bool = float(boss.rift_hp) > 0.0
	var selected: bool = bool(boss.rift_selected) and sim.priority_id == int(boss.id)
	body.text = ("● " if not selected and (sim.priority_id == int(boss.id) or sim.priority_id < 0) else "") + game.words("攻击本体 · 尽快击杀", "Body · destroy it sooner")
	rift.text = ("● " if selected else "") + game.words("攻击喷发裂隙", "Target eruption fissure") if intact else game.words("裂隙已封闭 · 陨石雨减少", "Fissure sealed · fewer meteors")
	rift.disabled = not intact
	health.value = float(boss.rift_hp) / float(boss.rift_max) * 100.0
	health.visible = intact
	var charging: bool = sim.CityBoss.charging(sim)
	if charging:
		var left: float = maxf(0.0, sim.boss_skill_windup("meteor_rain") - float(sim.skill.age))
		status.text = game.words("陨石雨 · %.1f 秒后释放", "Rain releases in %.1f s") % left
	else:
		status.text = game.words("下次喷发 · %.1f 秒", "Next eruption · %.1f s") % maxf(0.0, sim.skill_clock) if sim.skill.is_empty() else game.words("陨石雨已释放 · 拦截碎片", "Rain released · intercept fragments")
	if intact:
		details.text = game.words("裂隙耐久 %d%%\n蓄力时受到双倍部位伤害。封闭可打断本次蓄力，后续陨石由 10 枚减至 4 枚。攻击裂隙有 60%% 伤害传到本体。", "Fissure integrity %d%%\nTakes double part damage while charging. Seal it to interrupt the charge and reduce future rain from 10 to 4. 60%% of part damage reaches the body.") % int(ceil(health.value))
	else:
		details.text = game.words("已永久封闭，狂暴也不会恢复。场上已有的碎片仍需拦截。现在可集中攻击本体。", "Permanently sealed, even during enrage. Existing fragments still need interception. Focus on the body now.")
