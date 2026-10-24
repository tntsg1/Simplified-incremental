extends Node
# City configuration is opened deliberately from Settings, never over a model.
var game: Control
var main_choices: Array[Button]=[]
var rows: Array[Dictionary]=[]
var main_note: Label
var hints: Button

func setup(owner_game: Control) -> void:
	game=owner_game

func tabs(parent: VBoxContainer, active: String) -> void:
	var bar:=HBoxContainer.new()
	bar.add_theme_constant_override("separation",8)
	parent.add_child(bar)
	for entry in [["weapons",game.words("城市武器","City weapons")],["general",game.words("声音与画面","Audio & display")],["help",game.words("操作说明","Controls")]]:
		var page: String=entry[0]
		var choice: Button=game.button(entry[1],func():
			if page=="general": game.open_pause(true)
			else: open_settings(page))
		choice.custom_minimum_size.y=40
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		choice.disabled=page==active
		bar.add_child(choice)

func open_settings(page: String="weapons") -> void:
	if game.sim.stage!=0: return
	if page=="debug" and (not OS.is_debug_build() or not game.dev_mode): return
	game.close_body_card()
	game.menu={"weapons":"city_settings","help":"city_controls","debug":"city_debug"}.get(page,"city_settings")
	game.sim.paused=true
	game.sim.manual_held=false; game.sim.manual_queued=false
	main_choices.clear(); rows.clear()
	var outer: VBoxContainer=game.new_modal(minf(700,game.size.x-64),game.words("设置","Settings"),game.words("战斗与计时已暂停","Battle and timers paused"))
	outer.add_theme_constant_override("separation",10)
	tabs(outer,page)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(0,minf(420,game.size.y-270))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	if page=="weapons":
		content.add_child(game.label(game.words("导弹发射井","Missile silo"),18))
		var salvo:=HBoxContainer.new()
		salvo.add_theme_constant_override("separation",8)
		content.add_child(salvo)
		for value in range(2):
			var selected: int=value
			var choice: Button=game.button("",func():game.sim.set_city_mode(selected); game.save_game(); refresh())
			choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			salvo.add_child(choice); main_choices.append(choice)
		main_note=game.label("",13,Color("a6a6a6"))
		main_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		content.add_child(main_note)
		content.add_child(game.label(game.words("改造炮台 · 分别设置","Converted installations · Independent settings"),18))
		for slot in range(3):
			var selected_slot: int=slot
			var row:=HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			content.add_child(row)
			var title: Label=game.label(TranslationServer.translate(str(game.sim.BODIES[0][slot].name)),15)
			title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			row.add_child(title)
			var single: Button=game.button(game.words("单发","Single"),func():set_body(selected_slot,1))
			var triple: Button=game.button(game.words("三连发","Triple burst"),func():set_body(selected_slot,3))
			for choice in [single,triple]: choice.custom_minimum_size=Vector2(110,40); row.add_child(choice)
			var convert: Button=game.button("",func():
				if game.sim.convert_body(selected_slot): game.play_tone("buy"); game.save_game(); refresh())
			convert.custom_minimum_size=Vector2(228,40); row.add_child(convert)
			rows.append({"title":title,"single":single,"triple":triple,"convert":convert})
		hints=game.button("",func():game.city_combat_hints=not game.city_combat_hints; game.field.city_combat_hints=game.city_combat_hints; game.save_game(); refresh())
		content.add_child(hints)
		refresh()
	elif page=="debug":
		var grid:=GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		content.add_child(grid)
		for entry in [[game.words("资金 ×10","Funds ×10"),game.dev_money],[game.words("上一波","Previous wave"),game.dev_prev_wave],[game.words("跳过本波","Skip wave"),game.dev_skip_wave],[game.words("击毁 Boss","Destroy Boss"),game.dev_kill_boss],[game.words("上一章","Previous chapter"),game.dev_prev_stage],[game.words("直达下一章","Next chapter"),game.dev_next_stage],[game.dev_god_button.text,game.dev_toggle_god],[game.dev_ult_button.text,game.dev_toggle_ult],[game.dev_ult_kind_button.text,game.dev_cycle_ult_kind]]:
			var action: Callable=entry[1]
			var choice: Button=game.button(entry[0],func():action.call(); game.close_modal())
			choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			grid.add_child(choice)
	else:
		for pair in [
			["城市炮台","City installations"],
			["每座改造炮台分别选择单发或三连发。三连发每次保留原伤害，间隔 0.12 秒，从下一轮攻击生效。","Each converted installation has its own single or triple burst. Each shot keeps its damage, 0.12 s apart; applies next volley."],
			["导弹发射井","Missile silo"],
			["重点拦截集中火力；分路拦截最多攻击三个不同目标，每路得到三分之一伤害。战斗中改模式，下波生效。","Focused fire concentrates damage. Split fire hits up to three targets with one third each. Combat changes apply next wave."],
			["Boss 裂隙","Boss fissure"],
			["直接点击发光裂隙集火。蓄力末段裂隙变亮时，按住并跟住它约半秒，可打断一次陨石雨。移开或松开会重置进度；每个 Boss 一次。","Click the glowing fissure to focus it. When it flashes late in the charge, hold aim on it for about half a second to interrupt one meteor rain. Moving off or releasing resets progress; once per Boss."],
			["靠武器破坏裂隙后，后续陨石雨从十枚减为四枚。也可以直接攻击本体击杀。","Destroying the fissure with weapons reduces later rain from ten meteors to four. You can also defeat the Boss by attacking its body."]]:
			var text: Label=game.label(game.words(pair[0],pair[1]),15)
			text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			content.add_child(text)
	if OS.is_debug_build() and game.dev_mode:
		content.add_child(game.button(game.words("开发工具","Developer tools"),func():open_settings("debug")))
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	outer.add_child(footer)
	for entry in [[game.words("继续战斗  [Esc]","Resume  [Esc]"),game.close_modal],[game.words("升级防线","Upgrade defense"),game.open_shop]]:
		var choice: Button=game.button(entry[0],entry[1])
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		footer.add_child(choice)

func set_body(slot: int, count: int) -> void:
	if game.sim.set_body_shots(0,slot,count): game.save_game(); refresh()

func refresh() -> void:
	if game.menu!="city_settings" or rows.size()!=3: return
	var unlocked: bool=game.sim.wave>=6
	for i in range(main_choices.size()):
		main_choices[i].text=("● " if game.sim.city_mode_next==i else "")+ (game.words("重点拦截","Focused fire") if i==0 else game.words("分路拦截","Split fire"))
		main_choices[i].disabled=not unlocked or game.sim.city_mode_next==i
	main_note.text=game.words("第六波开放主导弹模式。","Missile modes unlock at wave six.") if not unlocked else game.words("集中打强敌，或分给多个目标；战斗中修改，下波生效。","Focus tough targets or split across threats. Combat changes apply next wave.")
	for slot in range(rows.size()):
		var converted: bool=game.sim.body_converted_at(0,slot)
		var shots: int=game.sim.body_modes.count(0,slot)
		rows[slot].title.text=TranslationServer.translate(str(game.sim.BODIES[0][slot].name))
		if converted:
			var stats: Dictionary=game.sim.body_weapon_stats(0,slot)
			rows[slot].title.text+="\n"+(game.words("每轮基础 %s · %.2f s", "Base volley %s · %.2f s") % [game.Catalog.number(stats.volley_damage),stats.interval])
		rows[slot].single.visible=converted; rows[slot].triple.visible=converted
		rows[slot].single.disabled=shots==1; rows[slot].triple.disabled=shots==3
		rows[slot].convert.visible=not converted
		rows[slot].convert.text=game.words("改造  $", "Convert  $")+game.Catalog.number(game.sim.body_cost())
		rows[slot].convert.disabled=game.sim.money<game.sim.body_cost()
	hints.text=game.words("战斗文字提示：开启","Combat text hints: On") if game.city_combat_hints else game.words("战斗文字提示：关闭","Combat text hints: Off")
