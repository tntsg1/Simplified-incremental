extends Control
# Native port of stellar-web/public/stellar/skyguard/play/index.html.
# Decorative orbital motion has no access to campaign simulation or progress.
var game: Control
var canvas: Control
var sheet: Control
var new_button: Button
var continue_button: Button
var export_button: Button
var dialog: Control
var active_view := ""
var clock := 0.0
var enemies: Array[Dictionary] = []
var bodies := [{"r":175.0,"sp":.22,"a":0.0,"sides":5}, {"r":250.0,"sp":-.15,"a":2.4,"sides":0}, {"r":320.0,"sp":.1,"a":4.1,"sides":3}]
var rng := RandomNumberGenerator.new()
# The dot grid is baked into a texture once per window size; drawing ~1300
# antialiased circles every frame was the main cost of this screen.
var grid_tex: ImageTexture
var grid_size := Vector2i.ZERO
var draw_usec := 0

func setup(owner_game: Control) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.seed = 5427620
	for i in range(65):
		enemies.append({"angle":rng.randf()*TAU,"phase":rng.randf(),"duration":rng.randf_range(9,15),"size":rng.randf_range(5,12),"sides":[3,4,4,6][i%4],"spin":rng.randf_range(-.7,.7)})
	resized.connect(arrange)
	refresh()

func words(zh: String, en: String) -> String:
	return en if game.language == "en" else zh

func text(value: String, point: Vector2, width: float, font_size: int, color := Color("ededed")) -> Label:
	var l: Label = game.label(value, font_size, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = value
	l.position = point
	l.size = Vector2(width, 36)
	canvas.add_child(l)
	return l

func refresh() -> void:
	if is_instance_valid(canvas):
		dialog = null
		remove_child(canvas)
		canvas.queue_free()
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = Vector2(1600,900)
	add_child(canvas)
	var nav := Panel.new()
	nav.position = Vector2(28,22)
	nav.size = Vector2(1544,52)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_theme_stylebox_override("panel",game.panel_style(Color(.035,.035,.035,.85),Color(1,1,1,.11),0))
	canvas.add_child(nav)
	text("✦  S K Y G U A R D",Vector2(52,35),350,14)
	var language: Button = game.button("中文   /   EN", game.toggle_language)
	language.position = Vector2(739,30)
	language.size = Vector2(122,36)
	language.custom_minimum_size.y = 36
	for state in ["normal","hover","pressed","disabled"]:
		var style = language.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		language.add_theme_stylebox_override(state,style)
	canvas.add_child(language)
	game.language_button = language
	var exit: Button = game.button(words("退出  ↗","EXIT  ↗"),func():game.get_tree().quit())
	exit.position = Vector2(1434,30)
	exit.size = Vector2(112,36)
	exit.custom_minimum_size.y = 36
	for state in ["normal","hover","pressed","disabled"]:
		var style = exit.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		exit.add_theme_stylebox_override(state,style)
	canvas.add_child(exit)
	var achievements: Button = game.button(words("成就","ACHIEVEMENTS"),func():open_view("achievements"))
	achievements.position = Vector2(1240,30)
	achievements.size = Vector2(165,36)
	achievements.custom_minimum_size.y = 36
	for state in ["normal","hover","pressed","disabled"]:
		var style = achievements.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		achievements.add_theme_stylebox_override(state,style)
	canvas.add_child(achievements)
	text("—  T H E  L A S T  L I G H T  O F  C I V I L I Z A T I O N",Vector2(128,219),660,10,Color("b4b4b4"))
	text("S K Y G U A R D",Vector2(122,249),780,68)
	text(words("天 穹 防 线","ORBITAL DEFENSE"),Vector2(128,337),500,18,Color("b4b4b4"))
	text(words("从第一枚导弹，到宇宙最后的光。","From the first missile to the last light in the universe."),Vector2(128,378),570,14,Color("898989"))
	new_button = row("01",words("新游戏","New campaign"),"NEW CAMPAIGN ↗",425,func():
		if game.saved.is_empty(): game.start_game()
		else: game.confirm_new(),true)
	var chapter := words("暂无存档","NO CAMPAIGN")
	if not game.saved.is_empty():
		var index: int = game.sim.saved_stage(game.saved)
		chapter = TranslationServer.translate(game.sim.catalog.stages[index].title) + " · " + words("第 %d 波","WAVE %d") % int(game.saved.get("wave",1))
	continue_button = row("02",words("继续战役","Continue campaign"),chapter,491,game.continue_game)
	continue_button.disabled = game.saved.is_empty()
	for child in continue_button.get_children():
		if child is Label: child.modulate.a = .65 if continue_button.disabled else 1.0
	row("03",words("设置","Settings"),"SETTINGS",557,func():open_view("settings"))
	row("04",words("操作指南","Field manual"),"FIELD MANUAL",623,func():open_view("manual"))
	export_button = row("05",words("导出存档","Export campaign"),"LOCAL BACKUP ↓",689,game.export_campaign)
	export_button.disabled = game.saved.is_empty()
	for child in export_button.get_children():
		if child is Label: child.modulate.a = .65 if export_button.disabled else 1.0
	text(words("战役已保存 · 本机进度" if not game.saved.is_empty() else "准备开始你的第一道防线。","Campaign saved · On this computer" if not game.saved.is_empty() else "Your first line of defense awaits."),Vector2(128,765),580,12,Color("898989"))
	text(words("点击 / 按住目标发射 · F 加速 · U 升级 · Esc 暂停 · F11 全屏","Click / hold to fire · F speed · U upgrades · Esc pause · F11 fullscreen"),Vector2(128,854),1000,12,Color("777777"))
	text("O R B I T A L   D E F E N S E   N E T W O R K",Vector2(1250,760),350,9,Color("777777"))
	text(words("最后的光，留给文明。","The last light belongs to civilization."),Vector2(1250,786),340,13,Color("a2a2a2"))
	arrange()
	if active_view == "": call_deferred("focus_default")
	if active_view != "": open_view(active_view)

func focus_default() -> void:
	if is_visible_in_tree() and active_view == "" and game.modal == null and is_instance_valid(new_button) and new_button.is_inside_tree() and new_button.focus_mode == Control.FOCUS_ALL:
		new_button.grab_focus()

func row(index: String, caption: String, tag: String, y: float, callback: Callable, primary := false) -> Button:
	var b: Button = game.button("",callback)
	b.name = "Menu" + index
	b.position = Vector2(128,y)
	b.size = Vector2(440,56)
	b.custom_minimum_size = Vector2(440,56)
	var ink := Color("0b0b0b") if primary else Color("ededed")
	b.add_theme_stylebox_override("normal",game.panel_style(Color("ededed") if primary else Color(.045,.045,.045,.94),Color("ededed") if primary else Color("2a2a2a"),0))
	b.add_theme_stylebox_override("hover",game.panel_style(Color("ffffff") if primary else Color("242424"),Color("ededed"),0))
	b.add_theme_stylebox_override("pressed",game.panel_style(Color("b4b4b4") if primary else Color("383838"),Color.WHITE,0))
	canvas.add_child(b)
	for data in [[index,Vector2(20,0),28,10],[caption,Vector2(50,0),240,17],[tag,Vector2(255,0),163,10]]:
		var l: Label = game.label(str(data[0]),int(data[3]),ink if data[0] == caption else (Color("777777") if primary else Color("999999")))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.text = str(data[0])
		l.position = data[1]
		l.size = Vector2(data[2],56)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if data[0] == tag: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(l)
	return b

func arrange() -> void:
	if not is_instance_valid(canvas): return
	var k := minf(size.x/1600.0,size.y/900.0)
	canvas.scale = Vector2.ONE*k
	canvas.position = (size-Vector2(1600,900)*k)*.5
	queue_redraw()

func set_menu_focus(enabled: bool) -> void:
	for item in canvas.find_children("*","BaseButton",true,false):
		if is_instance_valid(dialog) and dialog.is_ancestor_of(item): continue
		item.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func open_view(view: String) -> void:
	active_view = view
	set_menu_focus(false)
	if is_instance_valid(dialog):
		canvas.remove_child(dialog)
		dialog.queue_free()
	dialog = Control.new()
	dialog.size = Vector2(1600,900)
	canvas.add_child(dialog)
	var veil := ColorRect.new()
	veil.color = Color(0,0,0,.84)
	veil.size = dialog.size
	dialog.add_child(veil)
	var panel := PanelContainer.new()
	panel.position = Vector2(510,150)
	panel.size = Vector2(580,600)
	panel.add_theme_stylebox_override("panel",game.panel_style(Color("111111"),Color("454545"),0))
	dialog.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",18)
	panel.add_child(v)
	var heading := words("设置","SETTINGS") if view == "settings" else (words("成就","ACHIEVEMENTS") if view == "achievements" else words("操作指南","FIELD MANUAL"))
	v.add_child(game.label(heading,28))
	if view == "settings":
		for entry in [["sound_on",words("声音","Sound")],["reduced_effects",words("柔和战斗特效","Softer combat effects")],["ui_motion",words("主页与界面动态效果","Menu and interface motion")],["camera_comfort",words("关闭镜头运动","Disable camera motion")]]:
			var toggle := CheckButton.new()
			var key := str(entry[0])
			toggle.text = entry[1]
			toggle.custom_minimum_size.y = 42
			toggle.button_pressed = game.get(key)
			toggle.toggled.connect(func(on: bool):game.set(key,on);game.audio.set_enabled(game.sound_on);game.persist_preferences();game.save_game();queue_redraw())
			v.add_child(toggle)
		for key in ["music_level","effects_level"]:
			var line := HBoxContainer.new()
			var caption: Label = game.label(words("音乐","Music") if key == "music_level" else words("音效","Effects"),16)
			caption.custom_minimum_size.x = 90
			line.add_child(caption)
			var slider := HSlider.new()
			slider.min_value = 0
			slider.max_value = 100
			slider.step = 1
			slider.value = float(game.audio.get(key))*100
			slider.size_flags_horizontal = SIZE_EXPAND_FILL
			line.add_child(slider)
			var value: Label = game.label("%.0f%%" % slider.value,14)
			value.custom_minimum_size.x = 60
			line.add_child(value)
			slider.value_changed.connect(func(amount: float):game.audio.set(key,amount/100.0);value.text="%.0f%%" % amount;game.persist_preferences())
			v.add_child(line)
		v.add_child(game.button(words("窗口 / 全屏  [F11]","Window / fullscreen  [F11]"),func():
			var mode := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)))
		v.add_child(game.label(words("设置会保存在本机，下次启动继续生效。","Preferences are saved on this computer."),13,Color("969696")))
	elif view == "achievements":
		var features = game.steam_features
		var status_line: Label = game.label(words("已解锁 %d / %d","UNLOCKED %d / %d") % [features.unlocked.size(),features.CATALOG.size()],16)
		v.add_child(status_line)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(530,385)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation",14)
		scroll.add_child(list)
		for item in features.CATALOG:
			var name_text: String = words(item.name_zh,item.name_en)
			var desc: String = words(item.description_zh,item.description_en)
			var row_box := VBoxContainer.new()
			row_box.add_child(game.label(("✓  " if features.unlocked.has(item.id) else "□  ")+name_text,17))
			var detail: Label = game.label(desc,13,Color("969696"))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 500
			row_box.add_child(detail)
			list.add_child(row_box)
		v.add_child(scroll)
		var hint := words("本机成就已保存，Steam 可用时会重试同步。","Achievements save locally and retry syncing when Steam is available.")
		if features.status == "awaiting_configuration": hint = words("Steam 成就同步尚未启用，本机记录已保留。","Steam achievement sync is not enabled yet. Local progress is preserved.")
		var caption: Label = game.label(hint,13,Color("969696"))
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size.x = 530
		v.add_child(caption)
	else:
		var copy: Label = game.label(words("01  点击或按住来袭目标，手动发射导弹。\n\n02  按 U 打开升级面板，升级时战斗暂停。\n\n03  自动防御开放后，在升级面板购买自动化；\n      之后点击目标即可指定集火。\n\n04  按 Q 发动已充能的大招，按 F 切换 ×1 / ×2。\n\n05  Esc 暂停；F11 切换全屏。\n\n战役会自动保存，可随时继续或导出本地备份。","01  Click or hold incoming targets to fire missiles.\n\n02  Press U to upgrade. Combat pauses while upgrading.\n\n03  Buy automation when it becomes available.\n      Click targets to focus your automated defenses.\n\n04  Q fires a charged ultimate. F switches ×1 / ×2 speed.\n\n05  Esc pauses. F11 toggles fullscreen.\n\nYour campaign saves automatically. Continue or export a backup."),16)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.custom_minimum_size = Vector2(530,400)
		v.add_child(copy)
	var back: Button = game.button(words("返回主页  [Esc]","BACK TO MENU  [Esc]"),dismiss_view,true)
	v.add_child(back)
	back.grab_focus()

func dismiss_view() -> void:
	active_view = ""
	if is_instance_valid(dialog):
		dialog.queue_free()
		dialog = null
	set_menu_focus(true)
	new_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and active_view != "" and event.is_action_pressed("ui_cancel"):
		dismiss_view()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if game.ui_motion:
		clock += minf(delta,.05)
		queue_redraw()

func polygon(center: Vector2, radius: float, sides: int, rotation: float, color: Color, filled := false) -> void:
	var points := PackedVector2Array()
	for i in range(sides): points.append(center+Vector2.from_angle(rotation+TAU*i/sides)*radius)
	if filled: draw_colored_polygon(points,color)
	else:
		points.append(points[0])
		draw_polyline(points,color,1.0,true)

func _draw() -> void:
	var started := Time.get_ticks_usec()
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b0b0b"))
	var k := minf(size.x/1600.0,size.y/900.0)
	var offset := (size-Vector2(1600,900)*k)*.5
	var core := offset+Vector2(1056,450)*k
	var parallax := (get_local_mouse_position()-size*.5)*-.012 if is_instance_valid(game) and game.ui_motion else Vector2.ZERO
	var want := Vector2i(int(size.x)+68,int(size.y)+68)
	if grid_tex == null or grid_size != want:
		grid_size = want
		var img := Image.create(want.x,want.y,false,Image.FORMAT_RGBA8)
		for x in range(0,want.x,34):
			for y in range(0,want.y,34):
				var alpha := .09 if x-34 > offset.x+600*k else .025
				for dx in range(2):
					for dy in range(2):
						img.set_pixel(mini(x+dx,want.x-1),mini(y+dy,want.y-1),Color(1,1,1,alpha*.8))
		grid_tex = ImageTexture.create_from_image(img)
	draw_texture(grid_tex,Vector2(-34,-34)+parallax)
	for body in bodies:
		var radius: float = float(body.r)*k
		draw_arc(core,radius,0,TAU,100,Color(1,1,1,.07),1,true)
		var angle: float = float(body.a)+clock*float(body.sp)
		var pos := core+Vector2(cos(angle),sin(angle)*.9)*radius
		if body.sides == 0: draw_arc(pos,12*k,clock,clock+TAU*.72,24,Color(1,1,1,.6),3*k,true)
		else: polygon(pos,12*k,int(body.sides),clock*.3,Color(1,1,1,.58))
		for j in range(3):
			draw_arc(pos,(27+j*18)*k,0,TAU,40,Color(1,1,1,.08),1,true)
	for j in range(4): polygon(core,(12+j*11)*k,6,clock*(.3 if j%2 == 0 else -.25),Color(1,1,1,.24))
	polygon(core,10*k,6,0,Color("b4b4b4"),true)
	for j in range(14):
		var angle := j*TAU/14+clock*.2
		polygon(core+Vector2.from_angle(angle)*60*k,3.6*k,3,angle,Color(1,1,1,.42),true)
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var phase := fposmod(float(e.phase)+clock/float(e.duration),1.0)
		var distance := lerpf(950,90,phase)*k
		var pos := core+Vector2.from_angle(float(e.angle))*distance+parallax
		# A soft veil keeps the left menu readable, like the web launcher's radial overlay.
		var opacity := .66 if pos.x > offset.x+610*k else .13
		polygon(pos,float(e.size)*k,int(e.sides),clock*float(e.spin),Color(1,1,1,opacity),true)
		if i%3 == 0:
			draw_line(pos,pos+Vector2.from_angle(float(e.angle))*24*k,Color(1,1,1,opacity*.15),1,true)
		if i%5 == 0:
			var shot := fposmod(clock*1.4+float(e.phase),1.0)
			var point := core.lerp(pos,shot)
			draw_line(point,point+(pos-core).normalized()*10*k,Color(1,1,1,opacity*.5),1.3*k,true)
	draw_string(game.font,offset+Vector2(1250,834)*k,"INTERCEPTED  %d" % int(clock*4),HORIZONTAL_ALIGNMENT_LEFT,-1,int(11*k),Color("898989"))
	for i in range(3):
		var pulse := fposmod(clock*.35+i/3.0,1.0)
		draw_arc(core,(80+pulse*250)*k,0,TAU,100,Color(1,1,1,(1-pulse)*.07),1,true)
	draw_usec = Time.get_ticks_usec()-started
