extends Control

const Combat = preload("res://scripts/combat.gd")
const Battlefield = preload("res://scripts/battlefield.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Catalog = preload("res://scripts/catalog.gd")
const AudioDirector=preload("res://scripts/audio_director.gd")
var audio: Node
var reduced_effects: bool=false
var field_origin:=Vector2.ZERO
var sim = Combat.new()
var store = SaveStore.new()
var field: Node2D
var font: SystemFont
var ui: Control
var shade: ColorRect
var modal: PanelContainer
var stage_label: Label
var money_label: Label
var wave_label: Label
var health_label: Label
var hint: Label
var scale_label: Label
var boss_box: Control
var boss_title: Label
var boss_timer: Label
var boss_bar: ProgressBar
var wave_bar: ProgressBar
var toast: Label
var toast_time: float = 0
var accumulator: float = 0
var save_timer: float = 0
var ui_timer: float = 0
var purchase_count: int = 1
var menu: String = ""
var cards: Array[Dictionary] = []
var auto_button: Button
var hud_auto_button: Button
var weapon_button: Button
var saved: Dictionary = {}
var proof: bool = false
var proof_frame: int = 0
var capture_at: int = 120
var capture_path: String = ""
var benchmark: bool = false
var performance_frames: Array[float] = []
var sound_on: bool = true
var old_kills: int = 0
var old_shots: int = 0
var display_mode: String=""
var display_stage: int=-1
# Money rolls toward the real value and pops on income.
var shown_money: float=0
# UI tests drive an unfocused window; they turn the focus-loss pause off.
var pause_on_focus_loss: bool=true
var money_pulse: float=0

func panel_style(color: Color, edge: Color = Color("373737"), radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

func label(text: String, size: int = 18, color: Color = Color("eeeeee")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0,46)
	b.add_theme_stylebox_override("normal",panel_style(Color("262626") if primary else Color("1e1e1e"),Color("8a8a8a") if primary else Color("3a3a3a"),8))
	b.add_theme_stylebox_override("hover",panel_style(Color("303030") if primary else Color("282828"),Color("ededed"),8))
	b.add_theme_stylebox_override("pressed",panel_style(Color("3a3a3a"),Color("ffffff"),8))
	b.add_theme_stylebox_override("disabled",panel_style(Color("1a1a1a"),Color("2a2a2a"),8))
	b.add_theme_color_override("font_color",Color("efefef"))
	b.add_theme_color_override("font_disabled_color",Color("6c6c6c"))
	b.pressed.connect(callback)
	return b

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 16
	theme = skin
	var bg := ColorRect.new()
	bg.color = Color("141414")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	field = Battlefield.new()
	field.sim = sim
	add_child(field)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	build_hud()
	shade = ColorRect.new()
	shade.color = Color(0.03,0.03,0.03,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.hide()
	sim.notice.connect(show_notice)
	sim.checkpoint.connect(save_game)
	sim.stage_entered.connect(func(): show_notice(sim.stage_data().briefing))
	audio=AudioDirector.new()
	add_child(audio)
	audio.set_enabled(false)
	sim.fired.connect(audio.fire)
	sim.hit.connect(audio.impact)
	sim.destroyed.connect(audio.destruction)
	sim.fired.connect(field.on_fire)
	sim.hit.connect(field.on_hit)
	sim.destroyed.connect(field.on_destroyed)
	sim.members_removed.connect(field.on_members_removed)
	sim.pierced.connect(field.on_pierced)
	resized.connect(layout)
	parse_proof()
	audio.set_enabled(sound_on and (not proof or "--listen" in OS.get_cmdline_user_args()))
	if not proof:
		saved = store.read_game()
		sound_on = bool(saved.get("settings",{}).get("sound",true))
		reduced_effects=bool(saved.get("settings",{}).get("reduced_effects",false))
		audio.music_level=clampf(float(saved.get("settings",{}).get("music_level",.55)),0,1)
		audio.effects_level=clampf(float(saved.get("settings",{}).get("effects_level",.65)),0,1)
		audio.set_enabled(sound_on)
		show_title()
	if DisplayServer.get_name()=="headless":audio.set_enabled(false)
	if "--silent-output" in OS.get_cmdline_user_args():AudioServer.set_bus_volume_db(0,-80)
	layout()
	update_hud()

func build_hud() -> void:
	var line := ColorRect.new()
	line.color = Color("2d2d2d")
	line.position = Vector2(36,116)
	line.size = Vector2(1528,1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(line)
	stage_label = label("城市",30)
	ui.add_child(stage_label)
	scale_label = label("",13,Color("8a8a8a"))
	ui.add_child(scale_label)
	money_label = label("$ 0",28,Color("ededed"))
	ui.add_child(money_label)
	wave_label = label("第 01 / 10 波",19)
	ui.add_child(wave_label)
	health_label = label("防线 100%",18,Color("b4b4b4"))
	ui.add_child(health_label)
	wave_bar = ProgressBar.new()
	wave_bar.show_percentage = false
	wave_bar.add_theme_stylebox_override("background",panel_style(Color("262626"),Color("262626"),2))
	wave_bar.add_theme_stylebox_override("fill",panel_style(Color("ededed"),Color("ededed"),2))
	for key in ["background","fill"]:
		var bar_style: StyleBoxFlat = wave_bar.get_theme_stylebox(key)
		bar_style.content_margin_top=0
		bar_style.content_margin_bottom=0
	ui.add_child(wave_bar)
	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(boss_box)
	boss_title = label("巨型威胁",16,Color("ededed"))
	boss_box.add_child(boss_title)
	boss_timer = label("",16,Color("ffc94d"))
	boss_box.add_child(boss_timer)
	boss_timer.position = Vector2(470,0)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.position = Vector2(0,30)
	boss_bar.size = Vector2(640,5)
	boss_bar.add_theme_stylebox_override("background",panel_style(Color("2a2a2a"),Color("2a2a2a"),2))
	boss_bar.add_theme_stylebox_override("fill",panel_style(Color("ffc94d"),Color("ffc94d"),2))
	for key in ["background","fill"]:
		var bar_style: StyleBoxFlat = boss_bar.get_theme_stylebox(key)
		bar_style.content_margin_top=0
		bar_style.content_margin_bottom=0
	boss_box.add_child(boss_bar)
	var bottom := Panel.new()
	bottom.name = "Bottom"
	bottom.add_theme_stylebox_override("panel",panel_style(Color("161616"),Color("323232"),12))
	ui.add_child(bottom)
	ui.move_child(boss_box,-1)
	hint = label("",15,Color("a6a6a6"))
	bottom.add_child(hint)
	hint.position = Vector2(24,23)
	hud_auto_button = button("开启自动防御 · $200",buy_automation_from_hud,true)
	hud_auto_button.name = "AutomationButton"
	hud_auto_button.visible = false
	bottom.add_child(hud_auto_button)
	var shop := button("升级防线  [U]",func():open_shop(),true)
	shop.name = "ShopButton"
	bottom.add_child(shop)
	var pause := button("暂停  [Esc]",func():open_pause())
	pause.name = "PauseButton"
	bottom.add_child(pause)
	toast = label("",17,Color("dbdbdb"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)

func layout() -> void:
	if field == null:
		return
	var w: float = size.x
	var h: float = size.y
	var zoom: float = minf((w-90)/1100,(h-265)/620)
	field.scale = Vector2.ONE*zoom
	field.position = Vector2(w*.5-500*zoom,145)
	field_origin=field.position
	stage_label.position = Vector2(40,26)
	scale_label.position = Vector2(42,72)
	money_label.position = Vector2(w*.45,29)
	wave_label.position = Vector2(w-395,32)
	health_label.position = Vector2(w-180,35)
	wave_bar.position = Vector2(w-395,75)
	wave_bar.size = Vector2(340,4)
	var line: Control = ui.get_child(0)
	line.size.x = w-72
	boss_box.position = Vector2(36+(360 if hud_auto_button.visible else 24),h-101+14)
	var bottom: Control = ui.get_node("Bottom")
	bottom.position = Vector2(36,h-101)
	bottom.size = Vector2(w-72,72)
	hud_auto_button.position = Vector2(24,13)
	hud_auto_button.size = Vector2(320,46)
	var shop: Control = bottom.get_node("ShopButton")
	shop.position = Vector2(w-504,13)
	shop.size = Vector2(222,46)
	var pause: Control = bottom.get_node("PauseButton")
	pause.position = Vector2(w-263,13)
	pause.size = Vector2(167,46)
	toast.position = Vector2(w*.2,h-142)
	toast.size = Vector2(w*.6,30)
	if is_instance_valid(modal):
		modal.position = (size-modal.size)*.5

func new_modal(width: float, title: String, subtitle: String) -> VBoxContainer:
	if is_instance_valid(modal):
		modal.queue_free()
	shade.show()
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel",panel_style(Color("161616"),Color("454545"),16))
	modal.size.x = width
	add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",16)
	modal.add_child(v)
	v.add_child(label(title,30))
	v.add_child(label(subtitle,14,Color("a2a2a2")))
	call_deferred("center_modal")
	return v

func center_modal() -> void:
	if is_instance_valid(modal):
		modal.size = modal.get_combined_minimum_size()
		modal.position = (size-modal.size)*.5

func show_title() -> void:
	menu = "title"
	ui.hide()
	var v: VBoxContainer = new_modal(610,"天穹防线","SKYGUARD  /  从第一枚导弹，到宇宙最后的光")
	var emblem := TextureRect.new()
	emblem.texture = preload("res://assets/emblem.svg")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(0,96)
	v.add_child(emblem)
	v.add_child(label("城市  →  地球  →  太阳系  →  银河  →  星系团  →  宇宙",15,Color("c3c3c3")))
	var intro := label("击毁威胁赚取资金，让防御体系不断进化。\n早期点击目标发射；购买自动化后，点击指定集火。\n六道防线，六个巨型威胁，一场完整的太空战役。",16,Color("bababa"))
	intro.custom_minimum_size.y = 87
	v.add_child(intro)
	if not saved.is_empty():
		v.add_child(button("继续战役 · "+sim.catalog.stages[int(saved.get("stage",0))].title,continue_game,true))
	v.add_child(button("开始新战役",func():
		if saved.is_empty():
			start_game()
		else:
			confirm_new(),saved.is_empty()))
	v.add_child(button("退出",func():get_tree().quit()))
	v.add_child(label("鼠标优先  ·  U 升级  ·  Esc 暂停  ·  F11 全屏",13,Color("7f7f7f")))

func confirm_new() -> void:
	var v: VBoxContainer = new_modal(540,"开始新的防线？","新战役会覆盖当前进度。")
	v.add_child(button("开始新战役",start_game,true))
	v.add_child(button("返回",show_title))

func start_game() -> void:
	close_modal()
	sim.start_new()
	show_notice("点击或按住来袭目标发射导弹 · 升级面板暂停战斗")

func continue_game() -> void:
	if sim.restore(saved):
		close_modal()
		show_notice("战役已恢复 · 没有离线时间结算")
	else:
		show_notice("存档无法读取，请开始新战役")

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	shade.hide()
	menu = ""
	ui.show()
	sim.paused = false
	sim.manual_held = false
	sim.manual_queued = false
	cards.clear()
	auto_button = null
	weapon_button = null
	accumulator = 0
	save_game()

func open_shop() -> void:
	if sim.mode in ["title","victory"]:
		return
	menu = "shop"
	sim.paused = true
	sim.manual_held = false
	sim.manual_queued = false
	cards.clear()
	var v: VBoxContainer = new_modal(minf(1120,size.x-80),"升级防线","战斗、撞击计时与收入已暂停 · 所有已购武器共享升级")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	var wallet := label("$ "+Catalog.number(sim.money),24,Color("ededed"))
	wallet.name = "Wallet"
	wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wallet)
	for pair in [[1,"购买 ×1"],[10,"购买 ×10"],[1000,"购买最多"]]:
		var count: int = pair[0]
		row.add_child(button(pair[1],func():purchase_count=count;update_shop()))
	if sim.automation_available():
		auto_button = button("自动防御  $200  ·  导弹自主索敌",func():
			if sim.buy_automation():
				play_tone("buy")
				open_shop(),true)
		v.add_child(auto_button)
	if not sim.owned[sim.stage]:
		weapon_button = button("部署"+sim.catalog.weapons[sim.stage].title+"  $"+Catalog.number(sim.stage_data().weapon_price)+"  ·  "+sim.catalog.weapons[sim.stage].role,func():
			if sim.buy_weapon():
				play_tone("buy")
				open_shop(),true)
		v.add_child(weapon_button)
	var grid := GridContainer.new()
	grid.columns = 4 if sim.stage>=4 else 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	v.add_child(grid)
	for i in range(sim.catalog.upgrades.size()):
		var spec: Resource = sim.catalog.upgrades[i]
		if sim.stage < int(spec.unlock_stage):
			continue
		var p := PanelContainer.new()
		var card_width: float=(minf(1120,size.x-80)-40-12*(grid.columns-1))/grid.columns
		p.custom_minimum_size = Vector2(card_width,149)
		p.add_theme_stylebox_override("panel",panel_style(Color("1e1e1e"),Color("363636"),9))
		grid.add_child(p)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",7)
		p.add_child(card)
		var title := label("",19)
		card.add_child(title)
		var detail := label(spec.description,12,Color("acacac"))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(card_width-40,48 if grid.columns==4 else 36)
		card.add_child(detail)
		var index: int = i
		var buy := button("",func():
			if sim.buy_upgrade(index,purchase_count)>0:
				play_tone("buy")
				update_shop(),true)
		card.add_child(buy)
		cards.append({"index":i,"title":title,"button":buy})
	var milestones := label("",13,Color("969696"))
	milestones.name="Milestones"
	v.add_child(milestones)
	var power := label("",14,Color("c9c9c9"))
	power.name="Power"
	v.add_child(power)
	v.add_child(button("继续防御  [U / Esc]",close_modal,true))
	update_shop()

func update_shop() -> void:
	if not is_instance_valid(modal):
		return
	var wallet: Label = modal.find_child("Wallet",true,false)
	if wallet:
		wallet.text = "$ "+Catalog.number(sim.money)
	var milestones: Label=modal.find_child("Milestones",true,false)
	if milestones:
		var next_damage: int=-1
		for threshold in [10,25,50,75,100,125,150]:
			if int(sim.levels.damage)<threshold:
				next_damage=threshold
				break
		var damage_text: String="弹头突破全部完成" if next_damage<0 else "弹头 Lv.%d 伤害翻倍"%next_damage
		var reload_text: String="发射器已达最大规模" if int(sim.levels.reload)>=140 else "装填 Lv.%d 发射器翻倍"%((int(sim.levels.reload)/10+1)*10)
		milestones.text="下一突破："+damage_text+"   ·   "+reload_text+"   ·   老武器始终在役"
	var power: Label = modal.find_child("Power",true,false)
	if power:
		power.text="理论单体火力 $d / s   ·   齐射发射器 $l   ·   最大覆盖 $c 成员".replace("$d",Catalog.number(sim.nominal_dps())).replace("$l",Catalog.number(sim.launcher_count())).replace("$c",Catalog.number(sim.coverage(sim.stage) if sim.owned[sim.stage] else sim.coverage(maxi(0,sim.stage-1))))
	for c in cards:
		var spec: Resource = sim.catalog.upgrades[int(c.index)]
		c.title.text = spec.title+"  Lv."+str(sim.levels[spec.key])
		var count: int = purchase_count
		if count==1000:
			var first: float = sim.upgrade_cost(int(c.index))
			count = maxi(1,int(floor(log(1+sim.money*.18/first)/log(1.18))))
		var price: float = sim.upgrade_cost(int(c.index),count)
		c.button.text = "+%d  ·  $%s" %[count,Catalog.number(price)]
		c.button.disabled = sim.money+0.00001<price
	if is_instance_valid(auto_button):
		auto_button.disabled = sim.money<200
	if is_instance_valid(weapon_button):
		weapon_button.disabled = sim.money<float(sim.stage_data().weapon_price)

func open_pause() -> void:
	if sim.mode=="title":
		return
	menu = "pause"
	sim.paused = true
	sim.manual_held = false
	sim.manual_queued = false
	var v: VBoxContainer = new_modal(510,"防线暂停","所有模拟与计时已停止 · 进度已保存")
	v.add_child(button("继续防御",close_modal,true))
	v.add_child(button("升级防线",open_shop))
	var audio_toggle := button("声音：开启" if sound_on else "声音：关闭",func():
		sound_on = not sound_on
		audio.set_enabled(sound_on)
		open_pause()
		save_game())
	v.add_child(audio_toggle)
	for setting in ["music_level","effects_level"]:
		var audio_row:=HBoxContainer.new()
		audio_row.add_theme_constant_override("separation",14)
		var caption:=label("音乐" if setting=="music_level" else "音效",14)
		caption.custom_minimum_size=Vector2(58,30)
		audio_row.add_child(caption)
		var slider:=HSlider.new()
		slider.min_value=0
		slider.max_value=100
		slider.value=float(audio.get(setting))*100
		slider.step=1
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		audio_row.add_child(slider)
		var value_label:=label("%.0f%%"%slider.value,14)
		value_label.custom_minimum_size=Vector2(48,30)
		audio_row.add_child(value_label)
		var key: String=setting
		slider.value_changed.connect(func(value: float):audio.set(key,value/100);audio.set_enabled(sound_on);value_label.text="%.0f%%"%value)
		v.add_child(audio_row)
	v.add_child(button("特效：柔和" if reduced_effects else "特效：标准",func():reduced_effects=not reduced_effects;open_pause();save_game()))
	v.add_child(button("保存并返回主菜单",func():
		save_game()
		saved = store.read_game()
		show_title()))
	v.add_child(label("累计防御 %.1f 分钟  ·  击毁 %s 个目标" %[sim.elapsed/60,Catalog.number(sim.kills)],14,Color("969696")))
	save_game()

func show_result() -> void:
	if menu in ["result","shop"]:
		return
	menu = "result"
	var victory: bool = sim.mode=="victory"
	var v: VBoxContainer = new_modal(660,"最后的光，留给文明。" if victory else "防线已被突破","战役完成  /  SKYGUARD" if victory else "本阶段重启，资金、全部升级与已购武器保留")
	var advice: String="巨型威胁未在撞击前击毁。升级伤害与暴击，缩短 Boss 战。" if sim.health>0 else "群落超出了拦截能力。装填 Lv.%d 增加发射器。"%((int(sim.levels.reload)/10+1)*10)
	if not victory and sim.health<=0 and sim.stage>=2:advice+="\n范围与贯穿能消灭更多成员；部署本阶段的新炮。"
	v.add_child(label("六道防线全部守住。\n你让城市的第一座发射井，一直战斗到宇宙尽头。" if victory else advice,17,Color("c1c1c1")))
	v.add_child(label("防御时间 %.1f 分钟   ·   击毁 %s   ·   重试 %d" %[sim.elapsed/60,Catalog.number(sim.kills),sim.attempts],16,Color("d5d5d5")))
	if victory:
		v.add_child(button("返回主菜单",func():saved=store.read_game();show_title(),true))
	else:
		v.add_child(button("重启本阶段",func():close_modal();sim.retry(),true))
		v.add_child(button("先升级防线",open_shop))

func buy_automation_from_hud() -> void:
	if sim.buy_automation():
		play_tone("buy")
		update_hud()

func update_hud() -> void:
	stage_label.text = "%02d   %s" %[sim.stage+1,sim.stage_data().title]
	scale_label.text = sim.stage_data().subtitle+"     /     "+sim.stage_data().scale_label
	wave_label.text = "巨型威胁" if sim.mode=="boss" else "第 %02d / 10 波" %sim.wave
	health_label.text = "防线 %.0f%%" %sim.health
	health_label.modulate = Color("ffc94d") if sim.health<40 else Color.WHITE
	wave_bar.value = sim.progress()*100
	boss_box.visible = sim.mode=="boss" and menu==""
	if sim.mode=="boss":
		boss_title.text = sim.stage_data().boss_title
		boss_timer.text = "撞击倒计时  %.1f s" %sim.boss_remaining
		if not sim.enemies.is_empty():
			boss_bar.value = float(sim.enemies[0].hp)/sim.boss_max_hp()*100
			boss_title.text += "   /   HP "+Catalog.number(sim.enemies[0].hp)
	var parts: Array[String] = []
	for i in range(6):
		if sim.owned[i]:
			parts.append(sim.catalog.weapons[i].title.trim_suffix("阵列"))
	var auto_available: bool = sim.automation_available() and sim.mode not in ["title","victory"]
	if auto_available and not hud_auto_button.visible:
		show_notice("自动防御已开放 · 花 $200 购买，所有武器自主索敌")
	hud_auto_button.visible = auto_available
	hud_auto_button.disabled = sim.money<200
	hud_auto_button.text = "开启自动防御 · $200" if sim.money>=200 else "自动防御 · $200（还差 $%d）"%ceili(200-sim.money)
	hud_auto_button.tooltip_text = "购买后所有武器自动索敌；点击目标可指定集火。"
	hint.position.x = 360 if auto_available else 24
	hint.visible = sim.mode!="boss"
	boss_box.position.x = 36+(360 if auto_available else 24)
	if auto_available:
		hint.text = "已开放购买 · 开启后自动攻击"
	elif not sim.automation:
		hint.text = "点击 / 按住目标发射 · 第六波可花 $200 购买自动防御"
	elif not sim.owned[sim.stage]:
		hint.text = "新武器可部署："+sim.catalog.weapons[sim.stage].title+"  ·  打开升级防线"
	else:
		hint.text = "自动拦截  ·  点击集火    /    "+" + ".join(parts)
	if hint.text.length()>52:
		hint.add_theme_font_size_override("font_size",12)
	else:
		hint.add_theme_font_size_override("font_size",15)

func show_notice(message: String) -> void:
	toast.text = message
	toast_time = 5.0
	if is_instance_valid(audio) and (message.contains("突破") or message.contains("进化")):
		audio.play("milestone",-11,1,false,true)

func save_game() -> void:
	store.save_game(sim,{"sound":sound_on,"reduced_effects":reduced_effects,"music_level":audio.music_level,"effects_level":audio.effects_level})

func play_tone(kind: String) -> void:
	if kind=="buy":audio.play("purchase",-12)

func _process(delta: float) -> void:
	var started: int=Time.get_ticks_usec()
	if proof and benchmark:
		sim.mode="wave"
		sim.health=100
		sim.spawn_clock=1000
		sim.spawn_left=1
		while sim.enemies.size()<120:
			sim.spawn_enemy(maxi(1,int(sim.stage_data().count_multiplier)/16))
			var actor: Dictionary=sim.enemies.back()
			actor.age=float(actor.lifetime)*(.1+float(int(actor.id)%12)*.04)
	field.clock += delta
	field.reduced_effects=reduced_effects
	field.animate(delta)
	field.position=field_origin+field.shake_offset()
	audio.update(sim,delta)
	field.hover = field.to_local(get_global_mouse_position())
	if proof and "--inspect" in OS.get_cmdline_user_args() and not sim.enemies.is_empty():field.hover=sim.enemies[mini(3,sim.enemies.size()-1)].pos
	if not sim.paused:
		accumulator += minf(delta,.1)
		while accumulator>=1.0/60:
			sim.advance(1.0/60)
			accumulator -= 1.0/60
	if sim.money<shown_money or shown_money<=0 or sim.money<=0:
		shown_money=sim.money
	elif sim.money>shown_money*1.0001+.5:
		money_pulse=1.0
		shown_money=exp(lerpf(log(shown_money),log(sim.money),minf(1,delta*9)))
	else:
		shown_money=sim.money
	money_pulse=maxf(0,money_pulse-delta*4)
	money_label.text="$ "+Catalog.number(shown_money)
	money_label.pivot_offset=Vector2(0,money_label.size.y*.5)
	money_label.scale=Vector2.ONE*(1+money_pulse*.07)
	ui_timer += delta
	if ui_timer>.1 or display_mode!=sim.mode or display_stage!=sim.stage:
		ui_timer = 0
		update_hud()
		display_mode=sim.mode
		display_stage=sim.stage
	toast_time = maxf(0,toast_time-delta)
	toast.modulate.a = minf(1,toast_time)
	save_timer += delta
	if save_timer>=10 and not sim.paused:
		save_timer = 0
		save_game()
	if sim.mode in ["failed","victory"] and menu=="":
		show_result()
	field.queue_redraw()
	if proof:
		proof_frame += 1
		if benchmark and proof_frame>60:
			performance_frames.append(delta*1000)
			if proof_frame%30==0:
				print("BENCH_PROGRESS frame=",proof_frame," fps=",Engine.get_frames_per_second()," actors=",sim.enemies.size()," process_ms=",(Time.get_ticks_usec()-started)/1000.0," draw_ms=",field.draw_ms," shots=",sim.shots.size())
		if proof_frame==capture_at:
			capture_frame.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:
			var window_mode: int = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if window_mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode in [KEY_U,KEY_ESCAPE] and sim.mode!="title" and menu!="title":
			if menu!="":
				close_modal()
			elif event.keycode==KEY_U:
				open_shop()
			else:
				open_pause()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			sim.manual_held = false
		elif menu=="" and sim.mode in ["wave","boss"]:
			var point: Vector2 = field.to_local(event.position)
			var selected: int = sim.select_target(point)
			if selected>=0 and not sim.automation:
				sim.manual_held = true
				sim.manual_queued = true

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and not proof and menu=="" and sim.mode in ["wave","boss","intermission","transition"]:
		open_pause()

func parse_proof() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
			proof = true
		if arg.begins_with("--frames="):
			capture_at = int(arg.trim_prefix("--frames="))
		if arg=="--benchmark":
			benchmark = true
	if not proof:
		return
	if benchmark:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	store.enabled = false
	start_game()
	var idx: int = 0
	var proof_mode: String = "wave"
	for arg in args:
		if arg.begins_with("--stage="):
			idx = clampi(int(arg.trim_prefix("--stage=")),0,5)
		if arg.begins_with("--mode="):
			proof_mode = arg.trim_prefix("--mode=")
	sim.stage = idx
	sim.wave = 10
	sim.money = 850*pow(24,idx)
	sim.levels.damage = 8+idx*23
	sim.levels.reload = 7+idx*12
	sim.levels.speed = 5+idx*4
	sim.levels.area = idx*4
	sim.levels.pierce = maxi(0,idx-2)*4
	sim.levels.targets = maxi(0,idx-3)*3
	sim.automation = true
	for i in range(idx+1):
		sim.owned[i] = true
	sim.start_wave()
	toast_time=0
	if proof_mode=="boss":
		sim.start_boss()
		sim.wave_elapsed = 4
	else:
		for i in range(28 if idx>0 else 10):
			sim.spawn_enemy(1 if idx==0 else 5+idx*idx*85)
			var e: Dictionary = sim.enemies.back()
			e.age = e.lifetime*(.1+float(i%10)*.045)
	if proof_mode=="shop":
		open_shop()
	if proof_mode=="pause":
		open_pause()
	if proof_mode=="transition":
		sim.clear_battle()
		sim.mode = "transition"
		sim.mode_time = 2.5
	if proof_mode=="title":
		show_title()
	if "--save-smoke" in args:
		store.path="user://skyguard_export_check.json"
		store.enabled=true
		var written: bool=store.save_game(sim,{"sound":false})
		var restored=Combat.new()
		var data: Dictionary=store.read_game()
		var loaded: bool=restored.restore(data)
		var passed: bool=written and loaded and is_equal_approx(sim.money,restored.money) and sim.enemies.size()==restored.enemies.size() and sim.stage==restored.stage
		print("EXPORT_SAVE_SMOKE ",passed," stage=",restored.stage," enemies=",restored.enemies.size())
		if passed:
			saved=data
			sim.clear_battle()
			sim.mode="title"
			sim.money=0
			continue_game()
			passed=sim.mode==restored.mode and is_equal_approx(sim.money,restored.money) and sim.enemies.size()==restored.enemies.size()
			print("EXPORT_CONTINUE_SMOKE ",passed)
		store.enabled=false
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path+".bak"))
		if not passed:
			get_tree().quit(1)
	if proof_mode=="wave" and not benchmark:
		for i in range(idx+1):
			if not sim.enemies.is_empty():
				sim.fire_weapon(i,sim.enemies[mini(i*3,sim.enemies.size()-1)])
		for projectile in sim.shots:
			projectile.age=projectile.duration*.42
			projectile.pos=Vector2(projectile.from).lerp(projectile.end,.42)
		for actor in sim.enemies:
			actor.pos=Vector2(actor.start).lerp(actor.end,float(actor.age)/float(actor.lifetime))
		sim.paused=true

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var err: int = picture.save_png(capture_path)
	print("CAPTURE ",capture_path," result=",err," size=",picture.get_size())
	if benchmark and not performance_frames.is_empty():
		performance_frames.sort()
		var total: float = 0
		for ms in performance_frames:
			total += ms
		print("RENDER_BENCH frames=",performance_frames.size()," mean_ms=",total/performance_frames.size()," p95_ms=",performance_frames[int(performance_frames.size()*.95)]," fps=",Engine.get_frames_per_second()," actors=",sim.enemies.size()," shots=",sim.shots.size())
	get_tree().quit()
