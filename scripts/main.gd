# main.gd —《星际拓荒者》重做版主场景（zengliang）
# 装配: sim_core（数值内核）+ planet_view（球面星球）+ HUD（四资源/建造/升级/拆除/回本/瓶颈提示）
# 对应《重设计稿》§3-§7、§10。全数据驱动，参数见 data/balance.json。
extends Control

const SimCore := preload("res://scripts/sim_core.gd")
const PlanetView := preload("res://scripts/planet_view.gd")

var sim = SimCore.new()
var view = null

var speed := 1
var paused := false
var selected := Vector2i(-99, -99)

var _acc := 0.0
var _toast_time := 0.0
var _shot_mode := 0.0

var lbl_res: Label
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
	var args := OS.get_cmdline_user_args()
	if "--shot" in args:
		_shot_mode = 1.6
		if sim.buildings.is_empty():
			sim.build("miner", sim.deposits[0])
			sim.build("solar", Vector2i(3, 1))
			selected = sim.deposits[0]
	_refresh_panels()
	_refresh_hud()


func _process(delta: float) -> void:
	if not paused:
		sim.advance(delta * float(speed))
	_acc += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	if lbl_toast != null:
		lbl_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
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
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.88)
	sb.border_color = Color(0.30, 0.42, 0.55, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


func _build_ui() -> void:
	# 左上：资源面板
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.offset_left = 14.0
	p.offset_top = 12.0
	p.offset_right = 14.0
	p.offset_bottom = 12.0
	p.grow_horizontal = Control.GROW_DIRECTION_END
	p.grow_vertical = Control.GROW_DIRECTION_END
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	lbl_res = Label.new()
	lbl_res.add_theme_font_size_override("font_size", 15)
	v.add_child(lbl_res)
	# 顶部引导
	lbl_guide = Label.new()
	lbl_guide.anchor_right = 1.0
	lbl_guide.offset_top = 16.0
	lbl_guide.offset_bottom = 46.0
	lbl_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_guide.add_theme_font_size_override("font_size", 18)
	lbl_guide.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	add_child(lbl_guide)
	lbl_toast = Label.new()
	lbl_toast.anchor_right = 1.0
	lbl_toast.offset_top = 50.0
	lbl_toast.offset_bottom = 74.0
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.add_theme_font_size_override("font_size", 16)
	lbl_toast.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
	add_child(lbl_toast)
	# 右侧：选择/建造面板
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _panel_style())
	rp.anchor_left = 1.0
	rp.anchor_right = 1.0
	rp.offset_left = -342.0
	rp.offset_right = -12.0
	rp.offset_top = 12.0
	rp.offset_bottom = 12.0
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
		btn.pressed.connect(_try_build.bind(kind))
		rv.add_child(btn)
		build_buttons[kind] = btn
	btn_upgrade = Button.new()
	btn_upgrade.pressed.connect(_do_upgrade)
	rv.add_child(btn_upgrade)
	btn_remove = Button.new()
	btn_remove.pressed.connect(_do_remove)
	rv.add_child(btn_remove)
	lbl_hint = Label.new()
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.add_theme_font_size_override("font_size", 14)
	lbl_hint.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	rv.add_child(lbl_hint)
	# 底部：速度 / 存档
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -58.0
	bar.offset_bottom = -14.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
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


# ================= 刷新 =================

func _count_kind(kind: String) -> int:
	var n := 0
	for k in sim.buildings.keys():
		var b: Dictionary = sim.buildings[k]
		if String(b.get("type", "")) == kind:
			n += 1
	return n


func _refresh_hud() -> void:
	if lbl_res == null:
		return
	var r: Dictionary = sim.rates()
	var eff: float = sim.efficiency()
	lbl_res.text = ("矿物    %10s   +%s/s\n" % [sim.fmt_num(sim.minerals), sim.fmt_num(float(r["minerals"]))]) \
		+ ("信用点  %10s   +%s/s\n" % [sim.fmt_num(sim.credits), sim.fmt_num(float(r["credits"]))]) \
		+ ("科 学   %10s   +%s/s\n" % [sim.fmt_num(sim.science), sim.fmt_num(float(r["science"]))]) \
		+ ("能 源   %5.0f / %.0f   效率 %d%%" % [sim.energy_supply(), sim.energy_demand(), int(eff * 100.0)])
	# 引导链
	var n_miner := _count_kind("miner")
	var n_solar := _count_kind("solar")
	var g := ""
	if sim.buildings.is_empty():
		g = "① 点击金色矿点 → 建造第一座矿机"
	elif n_miner == 1 and n_solar == 0:
		g = "② 数字在涨！建一座太阳能阵列，能源留出余量"
	elif eff < 0.95:
		g = "⚠ 能源不足：建太阳能阵列，或升级设备提升效率"
	elif n_miner < 3:
		g = "③ 再开新矿点，或升级现有矿机（产出 ×1.6/级）"
	elif _count_kind("commerce") == 0:
		g = "④ 商业中心产出信用点——为星港做准备"
	else:
		g = "⑤ 目标：星港 1500 矿 / 800 信 → 探针与殖民（下一刀）"
	lbl_guide.text = g


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