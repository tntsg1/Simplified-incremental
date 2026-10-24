extends Node
# General settings contain no weapons. Missile options belong to the clicked silo.
var game: Control

func setup(owner_game: Control) -> void:
	game=owner_game

func open_pause_root() -> void:
	game.close_body_card()
	game.menu="city_pause"
	game.sim.paused=true
	game.sim.manual_held=false; game.sim.manual_queued=false
	var column: VBoxContainer=game.new_modal(minf(640,game.size.x-64),game.words("暂停","Paused"),game.words("战斗与计时已暂停","Battle and timers paused"))
	column.add_theme_constant_override("separation",10)
	column.add_child(game.button(game.words("继续","Continue"),game.close_modal,true))
	column.add_child(game.button(game.words("设置","Settings"),func():game.open_pause(true)))
	var quit: Button=game.button(game.words("退出","Quit"),func():game.save_game(); game.get_tree().quit())
	quit.tooltip_text=game.words("保存进度并退出游戏","Save progress and quit the game")
	column.add_child(quit)
	if OS.is_debug_build() and game.dev_mode:
		var grid:=GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		column.add_child(grid)
		for entry in [[game.words("资金 ×10","Funds ×10"),game.dev_money],[game.words("上一波","Previous wave"),game.dev_prev_wave],[game.words("跳过本波","Skip wave"),game.dev_skip_wave],[game.words("击毁 Boss","Destroy Boss"),game.dev_kill_boss],[game.words("上一章","Previous chapter"),game.dev_prev_stage],[game.words("直达下一章","Next chapter"),game.dev_next_stage],[game.dev_god_button.text,game.dev_toggle_god],[game.dev_ult_button.text,game.dev_toggle_ult],[game.dev_ult_kind_button.text,game.dev_cycle_ult_kind]]:
			var action: Callable=entry[1]
			var choice: Button=game.button(entry[0],func():action.call(); game.close_modal())
			choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			grid.add_child(choice)

func refresh() -> void:
	pass

func open_silo() -> void:
	if game.sim.stage!=0: return
	game.close_body_card()
	game.menu="city_silo"
	game.sim.paused=true
	game.sim.manual_held=false; game.sim.manual_queued=false
	var column: VBoxContainer=game.new_modal(minf(590,game.size.x-64),game.words("导弹发射井","Missile silo"),game.words("只调整这座发射井 · 战斗中修改，下波生效","This silo only · Combat changes apply next wave"))
	var unlocked: bool=game.sim.wave>=6
	for value in range(2):
		var selected: int=value
		var title: String=game.words("重点拦截","Focused fire") if value==0 else game.words("分路拦截","Split fire")
		var choice: Button=game.button(("● " if game.sim.city_mode_next==value else "")+title,func():game.sim.set_city_mode(selected); game.save_game(); open_silo())
		choice.disabled=not unlocked or game.sim.city_mode_next==value
		column.add_child(choice)
		var explanation: Label=game.label(game.words("集中攻击所选目标。","Concentrate fire on the selected target.") if value==0 else game.words("最多攻击三个目标，每路得到三分之一火力。","Hit up to three targets with one third of the payload each."),14)
		explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(explanation)
	if not unlocked: column.add_child(game.label(game.words("第六波解锁射击模式","Fire modes unlock at wave six"),14))
	column.add_child(game.button(game.words("关闭","Close"),game.close_modal))
