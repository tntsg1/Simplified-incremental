# main.gd —《星际拓荒者》重做版主场景（zengliang）
# 装配: sim_core（数值内核）+ planet_view（球面星球）+ HUD（顶栏资源/建造/升级/拆除/瓶颈）
# 新手教程: 荒原开局 → 六步高光引导（点基地 → 建矿机 → 建能源 → 升级 → 旋转 → 再扩张）
# 对应《重设计稿》§3-§7、§10。参数见 data/balance.json。
extends Control

const SimCore := preload("res://scripts/sim_core.gd")
const PlanetView := preload("res://scripts/planet_view.gd")

const TUT_TOTAL := 6
const TUT_TEXT := [
	"教程 1/6 · 这是你的殖民中心——点它一下试试",
	"教程 2/6 · 点击高亮的金色矿点，建造第一台矿机（矿物是一切的基础）",
	"教程 3/6 · 建一座太阳能阵列稳住能源（+15 供能）",
	"教程 4/6 · 选中那台矿机，升级到 Lv.2 —— 回本时间会写在按钮上",
	"教程 5/6 · 按住画面拖动——可以旋转星球查看背面",
	"教程 6/6 · 在第二个金色矿点再造一台矿机，教程就完成啦",
]

var sim = SimCore.new()
var view = null

var speed := 1
var paused := false
var selected := Vector2i(-99, -99)
var tut_step := -1

var _acc := 0.0
var _toast_time := 0.0
var _shot_mode := 0.0
var _time := 0.0

var lbl_name: Label
var lbl_min: Label
var lbl_en: Label
var lbl_sci: Label
var lbl_cred: Label
var lbl_guide: Label
var lbl_sel: Label
var lbl_hint: Label
var lbl_toast: Label
var btn_upgrade: Button
var btn_remove: Button
var build_buttons: Dictionary = {}
var speed_buttons: Array = []


func _ready() -> void:
	view = PlanetView.new()
	view.sim = sim
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.tile_selected.connect(_on_tile_selected)
	_build_ui()
	if sim.save_exists():
		var off = sim.load_and_advance()
		if float(off) > 5.0:
			_toast("离线结算 +%.0f 秒" % float(off))
	# 新局 → 开教程；读档局 → 直接自由玩
	if sim.buildings.is_empty():
		tut_step = 0
	var args := OS.get_cmdline_user_args()
	if "--shot" in args:
		_shot_mode = 1.6
	elif "--shot2" in args:
		_shot_mode = 1.6
		tut_step = -1
		view.tutorial_active = false
		if sim.buildings.is_empty():
			sim.build("miner", sim.deposits[1])
			sim.build("solar", Vector2i(4, 1))
			sim.advance(150.0)
		selected = sim.deposits[1]
	_refresh_tut()
	_refresh_panels()
	_refresh_hud()


func _process(delta: float) -> void:
	_time += delta
	if not paused:
		sim.advance(delta * float(speed))
	_acc += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	if lbl_toast != null:
		lbl_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
	_tut_update()
	_update_tut_pulses()
	if _acc >= 0.2:
		_acc = 0.0
		_refresh_hud()
		_refresh_panels()
	if _shot_mode > 0.0:
		_shot_mode -= delta
		if _shot_mode <= 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot.png")
			get_tree().quit()


# ================= UI 构建 =================

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.106, 0.176, 0.216, 0.86)
	sb.border_color = Color(0.32, 0.42, 0.48, 0.30)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


func _topbar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.090, 0.157, 0.200, 0.96)
	sb.border_color = Color(0.35, 0.45, 0.50, 0.40)
	sb.border_width_bottom = 1
	sb.set_content_margin_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


func _mk_top_label(text_color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", text_color)
	return l


func _build_ui() -> void:
	# 顶部：全宽资源栏
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _topbar_style())
	top.anchor_right = 1.0
	top.offset_bottom = 44.0
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	top.add_child(hb)
	lbl_name = _mk_top_label(Color(0.72, 0.78, 0.80))
	lbl_name.text = "星际拓荒者 · 母星"
	hb.add_child(lbl_name)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	lbl_min = _mk_top_label(Color(0.894, 0.639, 0.282))
	lbl_en = _mk_top_label(Color(0.89, 0.82, 0.35))
	lbl_sci = _mk_top_label(Color(0.565, 0.765, 0.886))
	lbl_cred = _mk_top_label(Color(0.765, 0.643, 0.839))
	hb.add_child(lbl_min)
	hb.add_child(lbl_en)
	hb.add_child(lbl_sci)
	hb.add_child(lbl_cred)
	# 顶部引导 / 教程
	lbl_guide = Label.new()
	lbl_guide.anchor_right = 1.0
	lbl_guide.offset_top = 54.0
	lbl_guide.offset_bottom = 84.0
	lbl_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_guide.add_theme_font_size_override("font_size", 19)
	lbl_guide.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	add_child(lbl_guide)
	# 左下：状态提示
	lbl_toast = Label.new()
	lbl_toast.anchor_top = 1.0
	lbl_toast.anchor_bottom = 1.0
	lbl_toast.offset_left = 16.0
	lbl_toast.offset_right = 620.0
	lbl_toast.offset_top = -96.0
	lbl_toast.offset_bottom = -70.0
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_toast.add_theme_font_size_override("font_size", 15)
	lbl_toast.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
	add_child(lbl_toast)
	# 右侧：选择/建造面板
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _panel_style())
	rp.anchor_left = 1.0
	rp.anchor_right = 1.0
	rp.offset_left = -318.0
	rp.offset_right = -12.0
	rp.offset_top = 58.0
	rp.offset_bottom = 58.0
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rp.grow_vertical = Control.GROW_DIRECTION_END
	add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(rv)
	lbl_sel = Label.new()
	lbl_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sel.add_theme_font_size_override("font_size", 16)
	rv.add_child(lbl_sel)
	for kind in ["miner", "solar", "fusion", "lab", "commerce"]:
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_try_build.bind(kind))
		rv.add_child(btn)
		build_buttons[kind] = btn
	btn_upgrade = Button.new()
	btn_upgrade.add_theme_font_size_override("font_size", 14)
	btn_upgrade.pressed.connect(_do_upgrade)
	rv.add_child(btn_upgrade)
	btn_remove = Button.new()
	btn_remove.add_theme_font_size_override("font_size", 14)
	btn_remove.pressed.connect(_do_remove)
	rv.add_child(btn_remove)
	lbl_hint = Label.new()
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.add_theme_font_size_override("font_size", 14)
	lbl_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90))
	rv.add_child(lbl_hint)
	# 右下：速度 / 存档
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -340.0
	bar.offset_right = -14.0
	bar.offset_top = -58.0
	bar.offset_bottom = -14.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(bar)
	for s in [1, 2, 4]:
		var b := Button.new()
		b.text = "%d×" % s
		b.pressed.connect(_set_speed.bind(s))
		bar.add_child(b)
		speed_buttons.append(b)
	var bp := Button.new()
	bp.text = "暂停"
	bp.pressed.connect(_toggle_pause)
	bar.add_child(bp)
	var bs := Button.new()
	bs.text = "存档"
	bs.pressed.connect(_do_save)
	bar.add_child(bs)


# ================= 教程 =================

func _count_kind(kind: String) -> int:
	var n := 0
	for k in sim.buildings.keys():
		var b: Dictionary = sim.buildings[k]
		if String(b.get("type", "")) == kind:
			n += 1
	return n


func _has_upgraded() -> bool:
	for k in sim.buildings.keys():
		var b: Dictionary = sim.buildings[k]
		if int(b["level"]) >= 2:
			return true
	return false


func _best_deposit(unbuilt_only: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_z := -2.0
	for d in sim.deposits:
		var t: Vector2i = d
		if unbuilt_only and not sim.building_at(t).is_empty():
			continue
		var p: Vector3 = view.project_tile(t)
		if p.z > best_z:
			best_z = p.z
			best = t
	return best


func _best_miner_tile() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_z := -2.0
	for k in sim.buildings.keys():
		var b: Dictionary = sim.buildings[k]
		if String(b.get("type", "")) != "miner":
			continue
		var parts := String(k).split(",")
		var t := Vector2i(int(parts[0]), int(parts[1]))
		var p: Vector3 = view.project_tile(t)
		if p.z > best_z:
			best_z = p.z
			best = t
	return best


func _refresh_tut() -> void:
	if tut_step < 0 or tut_step >= TUT_TOTAL:
		view.tutorial_active = false
		view.tutorial_tile = Vector2i(-99, -99)
		return
	var t := Vector2i(-99, -99)
	if tut_step == 0:
		t = sim.colony_tile
	elif tut_step == 1:
		t = _best_deposit(true)
	elif tut_step == 2:
		t = Vector2i(4, 1)
	elif tut_step == 3:
		t = _best_miner_tile()
	elif tut_step == 5:
		t = _best_deposit(true)
	view.tutorial_tile = t
	view.tutorial_active = t.x >= 0


func _tut_update() -> void:
	if tut_step < 0 or tut_step >= TUT_TOTAL:
		return
	var done := false
	if tut_step == 0:
		done = selected == sim.colony_tile
	elif tut_step == 1:
		done = _count_kind("miner") >= 1
	elif tut_step == 2:
		done = _count_kind("solar") >= 1
	elif tut_step == 3:
		done = _has_upgraded()
	elif tut_step == 4:
		done = float(view.drag_total) > 1.5
	elif tut_step == 5:
		done = _count_kind("miner") >= 2
	if done:
		tut_step += 1
		if tut_step >= TUT_TOTAL:
			_toast("教程完成！自由发展吧 —— 目标：星港 1500 矿 / 800 信")
			_refresh_tut()
		else:
			_refresh_tut()
		_refresh_hud()


func _update_tut_pulses() -> void:
	var tt := 0.5 + 0.5 * sin(_time * 4.0)
	var hi := Color(1.0, 0.92 + 0.08 * tt, 0.68 + 0.22 * tt)
	if btn_upgrade != null:
		btn_upgrade.modulate = hi if tut_step == 3 else Color.WHITE
	for k in build_buttons.keys():
		var btn: Button = build_buttons[k]
		var on: bool = (tut_step == 1 and k == "miner") or (tut_step == 2 and k == "solar")
		btn.modulate = hi if on else Color.WHITE


# ================= 刷新 =================

func _refresh_hud() -> void:
	if lbl_min == null:
		return
	var r: Dictionary = sim.rates()
	var eff: float = sim.efficiency()
	lbl_min.text = "矿物 %s  +%s/s" % [sim.fmt_num(sim.minerals), sim.fmt_num(float(r["minerals"]))]
	lbl_sci.text = "科研 %s  +%s/s" % [sim.fmt_num(sim.science), sim.fmt_num(float(r["science"]))]
	lbl_cred.text = "信用 %s  +%s/s" % [sim.fmt_num(sim.credits), sim.fmt_num(float(r["credits"]))]
	# 能源：不足时泛红警示
	lbl_en.text = "能源 %.0f/%.0f" % [sim.energy_supply(), sim.energy_demand()]
	if eff < 0.999:
		lbl_en.add_theme_color_override("font_color", Color(0.95, 0.52, 0.35))
	else:
		lbl_en.add_theme_color_override("font_color", Color(0.89, 0.82, 0.35))
	# 引导 / 教程文本
	if tut_step >= 0 and tut_step < TUT_TOTAL:
		lbl_guide.text = String(TUT_TEXT[tut_step])
		return
	var n_miner := _count_kind("miner")
	if eff < 0.95:
		lbl_guide.text = "⚠ 能源不足：建太阳能阵列，或升级设备提升效率"
	elif n_miner < 3:
		lbl_guide.text = "继续扩张：开新矿点，或升级现有矿机（产出 ×1.6/级）"
	elif _count_kind("commerce") == 0:
		lbl_guide.text = "商业中心产出信用点——为星港做准备"
	else:
		lbl_guide.text = "目标：星港 1500 矿 / 800 信 → 探针与殖民（下一刀）"


func _sel_anchor() -> Vector2:
	if selected.x < 0 or selected.y < 0:
		return Vector2(size.x * 0.5, size.y * 0.5)
	var p: Vector3 = view.project_tile(selected)
	return Vector2(p.x, p.y)


func _refresh_panels() -> void:
	if lbl_sel == null:
		return
	var b: Dictionary = sim.building_at(selected) if selected.x >= 0 else {}
	if selected.x < 0:
		lbl_sel.text = "未选中 — 点击星球上的地块"
	elif selected == sim.colony_tile:
		lbl_sel.text = "殖民中心（母港）\n所有运输无人机的起点"
	elif b.is_empty():
		if sim.is_deposit(selected):
			lbl_sel.text = "金色矿点 (%d,%d)\n可建：矿机（矿脉产出）" % [selected.x, selected.y]
		else:
			lbl_sel.text = "地块 (%d,%d)\n可建：太阳能/聚变堆/科研站/商业中心" % [selected.x, selected.y]
	else:
		var kind := String(b["type"])
		var nm: String = sim.building_defs[kind]["name"]
		lbl_sel.text = "%s Lv.%d  (%d,%d)\n产出 %s/s　能源需求 %.0f" % [
			nm, int(b["level"]), selected.x, selected.y,
			sim.fmt_num(sim.output_for(b)), float(sim.building_defs[kind]["energy"]) * float(int(b["level"]))]
	# 建造按钮
	for kind in build_buttons.keys():
		var btn: Button = build_buttons[kind]
		var cost: Dictionary = sim.build_cost(kind)
		var nm2: String = sim.building_defs[kind]["name"]
		btn.text = "%s  %s矿/%s信" % [nm2, sim.fmt_num(float(cost["minerals"])), sim.fmt_num(float(cost["credits"]))]
		btn.disabled = not (selected.x >= 0 and sim.can_build(kind, selected))
	# 升级 / 拆除
	if b.is_empty():
		btn_upgrade.disabled = true
		btn_upgrade.text = "升级 —"
		btn_remove.disabled = true
		btn_remove.text = "拆除 —"
	else:
		var kind2 := String(b["type"])
		var lv := int(b["level"])
		if lv >= int(sim.max_level):
			btn_upgrade.disabled = true
			btn_upgrade.text = "已满级 Lv.%d" % lv
		else:
			var uc: Dictionary = sim.upgrade_cost(b)
			btn_upgrade.disabled = not sim.can_upgrade(selected)
			var cur: float = sim.output_for(b)
			var nxt: float = cur * float(sim.upgrade_out_mult)
			var extra: float = nxt - cur
			var pb: float = sim.payback(float(uc["minerals"]), extra)
			if float(sim.building_defs[kind2]["energy"]) == 0.0:
				btn_upgrade.text = "升级 Lv.%d→%d  %s矿/%s信　供能 +%s" % [
					lv, lv + 1, sim.fmt_num(float(uc["minerals"])), sim.fmt_num(float(uc["credits"])),
					sim.fmt_num(extra)]
			elif pb >= 0.0:
				btn_upgrade.text = "升级 Lv.%d→%d  %s矿/%s信　+%s/s，约 %.0f 秒回本" % [
					lv, lv + 1, sim.fmt_num(float(uc["minerals"])), sim.fmt_num(float(uc["credits"])),
					sim.fmt_num(extra), pb]
			else:
				btn_upgrade.text = "升级 Lv.%d→%d" % [lv, lv + 1]
		btn_remove.disabled = false
		btn_remove.text = "拆除（返还 %s矿/%s信）" % [
			sim.fmt_num(float(b["spent_m"])), sim.fmt_num(float(b["spent_c"]))]
	# 瓶颈提示（带两个方案）
	var eff: float = sim.efficiency()
	if eff < 0.999:
		lbl_hint.text = "瓶颈：能源（效率 %d%%）\n① 建太阳能阵列 +15 供能（50矿/25信）\n② 升级发电机类 ×1.6 或拆除低效设备" % int(eff * 100.0)
	elif selected.x >= 0 and not sim.building_at(selected).is_empty():
		lbl_hint.text = "提示：回本时间 = 升级成本 ÷ 新增产出，优先选短回本。"
	else:
		lbl_hint.text = "提示：矿机只能建在金色矿点；其他建筑建在普通地块。"


# ================= 操作 =================

func _on_tile_selected(t: Vector2i) -> void:
	selected = t
	_refresh_panels()


func _try_build(kind: String) -> void:
	if selected.x < 0:
		return
	if sim.build(kind, selected):
		var nm: String = sim.building_defs[kind]["name"]
		view.push_floater(_sel_anchor(), "+" + nm, Color(0.37, 0.84, 0.91))
	else:
		_toast("无法建造：位置不符或资源不足")
	_refresh_panels()


func _do_upgrade() -> void:
	if selected.x < 0:
		return
	if sim.upgrade(selected):
		view.push_floater(_sel_anchor(), "升级!", Color(1.0, 0.72, 0.30))
	else:
		_toast("无法升级：资源不足或已满级")
	_refresh_panels()


func _do_remove() -> void:
	if selected.x < 0:
		return
	if sim.remove(selected):
		view.push_floater(_sel_anchor(), "拆除返还", Color(0.85, 0.85, 0.85))
		_refresh_panels()


func _set_speed(s: int) -> void:
	speed = s
	paused = false


func _toggle_pause() -> void:
	paused = not paused


func _do_save() -> void:
	sim.save_now()
	_toast("已存档")


func _toast(text: String) -> void:
	if lbl_toast == null:
		return
	lbl_toast.text = text
	_toast_time = 2.2