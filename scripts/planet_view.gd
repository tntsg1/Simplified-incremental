# planet_view.gd — 球面星球视图 v2（线框网格 / 深紫矿物星球 / 高光引导）
# 交互: 左键点击选中地块；按住拖动旋转（跟随手指）；拖拽里程记录在 drag_total。
# 由 main.gd 注入 sim（sim_core 实例）。
extends Control

signal tile_selected(tile: Vector2i)

const TEX := {
	"miner": preload("res://assets/miner.png"),
	"solar": preload("res://assets/solar.png"),
	"fusion": preload("res://assets/fusion.png"),
	"lab": preload("res://assets/lab.png"),
	"commerce": preload("res://assets/commerce.png"),
	"colony": preload("res://assets/colony.png"),
}
const PLANET_TEX := preload("res://assets/planet.png")
const SIZE_FIX := {"miner": 0.88, "solar": 1.00, "fusion": 0.95, "lab": 0.95, "commerce": 1.05, "colony": 1.18}
const PLANET_SCALE := 640.0 / 560.0   # 贴图含光晕边距
const DOT_COL := {
	"miner": Color(0.894, 0.639, 0.282),
	"solar": Color(0.44, 0.89, 0.95),
	"fusion": Color(0.44, 0.89, 0.95),
	"lab": Color(0.565, 0.765, 0.886),
	"commerce": Color(0.765, 0.643, 0.839),
	"colony": Color(0.92, 0.96, 1.0),
}

var sim = null                    # sim_core 实例（外部注入）
var spin := 0.0                   # 当前旋转角（弧度）
var zoom := 1.0
var selected := Vector2i(-99, -99)
var hovered := Vector2i(-99, -99)
var drag_total := 0.0             # 累计拖拽里程（教程用）
var tutorial_tile := Vector2i(-99, -99)
var tutorial_active := false

var _drag := false
var _drag_moved := 0.0
var _time := 0.0
var _stars: Array = []
var _floaters: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(200):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.35, 1.0)))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var i := _floaters.size() - 1
	while i >= 0:
		_floaters[i]["age"] = float(_floaters[i]["age"]) + delta
		if float(_floaters[i]["age"]) > 1.4:
			_floaters.remove_at(i)
		i -= 1
	queue_redraw()


func push_floater(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos, "text": text, "age": 0.0, "color": color})


# ---------- 球面投影 ----------

func _center() -> Vector2:
	return Vector2(size.x * 0.47, size.y * 0.54)


func _radius() -> float:
	return minf(size.x, size.y) * 0.40 * zoom


func _lon_lat(tile: Vector2i) -> Vector2:
	var lx := 1.25
	var ly := 0.78
	var fx := float(tile.x) / float(maxi(int(sim.grid_w) - 1, 1))
	var fy := float(tile.y) / float(maxi(int(sim.grid_h) - 1, 1))
	return Vector2(lerpf(-lx, lx, fx), lerpf(ly, -ly, fy))


# 返回 (屏幕x, 屏幕y, depth)；depth<=0.02 视为背面
func project_tile(tile: Vector2i) -> Vector3:
	var ll := _lon_lat(tile)
	var lon := ll.x - spin
	var lat := ll.y
	var depth := cos(lat) * cos(lon)
	var c := _center()
	var r := _radius()
	var px := c.x + r * cos(lat) * sin(lon)
	var py := c.y - r * sin(lat)
	return Vector3(px, py, depth)


func face_scale(depth: float) -> float:
	return 0.40 + 0.60 * clampf(depth, 0.0, 1.0)


func _hex_pts(px: float, py: float, rr: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(6):
		var a := TAU * float(k) / 6.0 + 0.5236
		pts.append(Vector2(px + rr * cos(a), py + rr * 0.72 * sin(a)))
	return pts


# ---------- 绘制 ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.031, 0.043, 0.075))
	for s in _stars:
		var sx := float(s.x) * size.x
		var sy := float(s.y) * size.y
		var tw := 0.55 + 0.45 * sin(_time * float(s.z) * 2.0 + float(s.x) * 20.0)
		draw_circle(Vector2(sx, sy), 1.0, Color(0.72, 0.82, 1.0, 0.24 * float(s.z) * tw))
	if sim == null:
		return
	var c := _center()
	var r := _radius()
	# 大气垫光 + 轨道弧线
	draw_circle(c, r * 1.16, Color(0.30, 0.18, 0.50, 0.07))
	draw_circle(c, r * 1.06, Color(0.42, 0.26, 0.62, 0.06))
	draw_arc(c, r * 1.36, deg_to_rad(205.0), deg_to_rad(338.0), 48, Color(0.45, 0.55, 0.75, 0.10), 1.0)
	draw_arc(c, r * 1.55, deg_to_rad(28.0), deg_to_rad(150.0), 48, Color(0.45, 0.55, 0.75, 0.07), 1.0)
	# 星球
	var pr := r * PLANET_SCALE
	draw_texture_rect(PLANET_TEX, Rect2(c - Vector2(pr, pr), Vector2(pr * 2.0, pr * 2.0)), false)

	# ---- 网格：线框（去重边），按深度淡出 ----
	var meta := {}
	var edges := {}
	for ty in range(int(sim.grid_h)):
		for tx in range(int(sim.grid_w)):
			var t := Vector2i(tx, ty)
			var p := project_tile(t)
			if p.z <= 0.02:
				continue
			var s := face_scale(p.z)
			var rr := r * 0.108 * s
			if Vector2(p.x, p.y).distance_to(c) > r - rr * 1.2:
				continue
			var pts := _hex_pts(p.x, p.y, rr)
			meta[t] = [pts, p, rr]
			for i in range(6):
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % 6]
				var key := "%d:%d" % [int((a.x + b.x) * 0.5), int((a.y + b.y) * 0.5)]
				if not edges.has(key):
					edges[key] = [a, b, p.z]
	for key in edges.keys():
		var e: Array = edges[key]
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var alpha := (0.09 + 0.40 * clampf(float(e[2]), 0.0, 1.0))
		draw_line(a, b, Color(0.66, 0.72, 0.86, alpha), 1.0)

	# ---- 矿点：琥珀色光点（呼吸） ----
	for d in sim.deposits:
		var t: Vector2i = d
		if not meta.has(t):
			continue
		var m: Array = meta[t]
		var p: Vector3 = m[1]
		var rr2: float = m[2]
		var breathe := 0.7 + 0.3 * sin(_time * 2.0 + float(t.x + t.y))
		draw_circle(Vector2(p.x, p.y), rr2 * 0.5, Color(1.0, 0.72, 0.30, 0.10 * breathe))
		draw_circle(Vector2(p.x, p.y), rr2 * 0.26, Color(1.0, 0.72, 0.30, 0.85))
		draw_circle(Vector2(p.x, p.y), rr2 * 0.10, Color(1.0, 0.92, 0.75, 0.9))

	# ---- 选中 / 悬停 / 殖民中心 ----
	if meta.has(selected):
		var m2: Array = meta[selected]
		var sp: Vector3 = m2[1]
		var srr: float = m2[2]
		var spts: PackedVector2Array = m2[0]
		draw_circle(Vector2(sp.x, sp.y), srr * 1.9, Color(0.45, 0.95, 1.0, 0.07))
		draw_colored_polygon(spts, Color(0.45, 0.95, 1.0, 0.20))
		for i in range(3):
			var k := 1.16 + 0.14 * float(i)
			var gp := PackedVector2Array()
			for v in spts:
				gp.append(Vector2(sp.x + (v.x - sp.x) * k, sp.y + (v.y - sp.y) * k))
			gp.append(gp[0])
			draw_polyline(gp, Color(0.79, 1.0, 1.0, 0.30 / (i + 1)), 1.5)
		var op := spts.duplicate()
		op.append(op[0])
		draw_polyline(op, Color(0.85, 1.0, 1.0, 0.98), 2.5)
	elif meta.has(hovered):
		var m3: Array = meta[hovered]
		var hpts: PackedVector2Array = m3[0]
		var hp := hpts.duplicate()
		hp.append(hp[0])
		draw_polyline(hp, Color(0.80, 0.92, 1.0, 0.45), 1.5)
	# ---- 建筑（远→近排序） ----
	var items: Array = []
	for k in sim.buildings.keys():
		var parts := String(k).split(",")
		items.append(Vector2i(int(parts[0]), int(parts[1])))
	items.append(sim.colony_tile)
	items.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return project_tile(a).z < project_tile(b).z)
	for t in items:
		var p := project_tile(t)
		if p.z <= 0.02:
			continue
		var b: Dictionary = sim.building_at(t)
		var kind := "colony" if t == sim.colony_tile else String(b.get("type", "miner"))
		var tex: Texture2D = TEX.get(kind, TEX["miner"])
		var s := face_scale(p.z)
		var base := r * 0.52 * s * float(SIZE_FIX.get(kind, 1.0))
		var alpha := 0.25 + 0.75 * clampf(p.z * 1.2, 0.0, 1.0)
		var epts := PackedVector2Array()
		var ew := base * 0.34
		var eh := base * 0.11
		for ei in range(14):
			var ea := TAU * float(ei) / 14.0
			epts.append(Vector2(p.x + ew * cos(ea), p.y + base * 0.04 + eh * sin(ea)))
		draw_colored_polygon(epts, Color(0.0, 0.0, 0.0, 0.30 * alpha))
		var rc := Rect2(Vector2(p.x - base * 0.5, p.y - base * 0.86), Vector2(base, base))
		draw_texture_rect(tex, rc, false, Color(1, 1, 1, alpha))
		# 状态灯（呼吸）
		var dc: Color = DOT_COL.get(kind, Color.WHITE)
		var dot_pulse := 0.55 + 0.45 * sin(_time * 2.2 + float(t.x * 3 + t.y))
		var dot_y := p.y - base * 0.86 - 5.0
		draw_circle(Vector2(p.x, dot_y), 3.6, Color(dc.r, dc.g, dc.b, 0.13 * dot_pulse))
		draw_circle(Vector2(p.x, dot_y), 1.8, Color(dc.r, dc.g, dc.b, 0.78))
		if not b.is_empty() and int(b["level"]) > 1:
			var f: Font = get_theme_default_font()
			draw_string(f, Vector2(p.x - 10, p.y - base * 0.60), "Lv%d" % int(b["level"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))

	# ---- 无人机（殖民中心 → 矿机） ----
	var cp := project_tile(sim.colony_tile)
	if cp.z > 0.02:
		var idx := 0
		for k in sim.buildings.keys():
			var b: Dictionary = sim.buildings[k]
			if String(b.get("type", "")) != "miner":
				continue
			var parts := String(k).split(",")
			var mp := project_tile(Vector2i(int(parts[0]), int(parts[1])))
			if mp.z <= 0.02:
				continue
			var tt := fmod(_time * 0.22 + float(idx) * 0.37, 1.0)
			var phases: Array[float] = [tt, fmod(tt + 0.5, 1.0)]
			for ph in phases:
				var pos := Vector2(cp.x, cp.y).lerp(Vector2(mp.x, mp.y), ph)
				pos.y -= sin(PI * ph) * r * 0.06
				draw_circle(pos, 2.2, Color(0.37, 0.84, 0.91, 0.90))
				draw_circle(pos, 4.5, Color(0.37, 0.84, 0.91, 0.18))
			idx += 1

	# ---- 教程高光（暗幕 + 聚光 + 指示箭头） ----
	if tutorial_active and meta.has(tutorial_tile):
		var tm: Array = meta[tutorial_tile]
		var tp: Vector3 = tm[1]
		var trr: float = tm[2]
		draw_circle(c, r * 1.18, Color(0.01, 0.01, 0.03, 0.30))
		var pulse := 0.75 + 0.25 * sin(_time * 3.0)
		draw_circle(Vector2(tp.x, tp.y), trr * 3.0 * pulse, Color(0.55, 0.90, 1.0, 0.06))
		draw_circle(Vector2(tp.x, tp.y), trr * 2.0 * pulse, Color(0.65, 0.95, 1.0, 0.10))
		draw_circle(Vector2(tp.x, tp.y), trr * 1.25 * pulse, Color(0.75, 1.0, 1.0, 0.16))
		var tpts: PackedVector2Array = tm[0]
		draw_colored_polygon(tpts, Color(0.55, 0.90, 1.0, 0.14))
		var top := tpts.duplicate()
		top.append(top[0])
		draw_polyline(top, Color(0.85, 1.0, 1.0, 0.90), 2.0)
		draw_arc(Vector2(tp.x, tp.y), trr * 1.35, 0.0, TAU, 48, Color(0.85, 1.0, 1.0, 0.55), 1.5)
		var bob := sin(_time * 2.4) * 5.0
		var ay := tp.y - trr * 2.4 + bob
		var tri := PackedVector2Array([Vector2(tp.x, ay + 13.0), Vector2(tp.x - 9.0, ay - 3.0), Vector2(tp.x + 9.0, ay - 3.0)])
		draw_colored_polygon(tri, Color(0.90, 1.0, 1.0, 0.90))

	# ---- 飘字 ----
	var f2: Font = get_theme_default_font()
	for fl in _floaters:
		var age := float(fl["age"])
		var a := 1.0 - age / 1.4
		var pos: Vector2 = fl["pos"]
		pos.y -= age * 34.0
		draw_string(f2, pos, String(fl["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(fl["color"].r, fl["color"].g, fl["color"].b, a * 0.95))


# ---------- 交互 ----------

func _tile_at(pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	var r := _radius()
	for ty in range(int(sim.grid_h)):
		for tx in range(int(sim.grid_w)):
			var t := Vector2i(tx, ty)
			var p := project_tile(t)
			if p.z <= 0.05:
				continue
			var rr := r * 0.108 * face_scale(p.z) * 1.25
			if Vector2(p.x, p.y).distance_to(_center()) > r - rr * 1.2:
				continue
			var d := pos.distance_to(Vector2(p.x, p.y))
			if d < rr and d < best_d:
				best_d = d
				best = t
	return best


func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				_drag = false
				if _drag_moved < 9.0:
					var t := _tile_at(mb.position)
					if t.x >= 0:
						selected = t
						tile_selected.emit(t)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag:
			var d := mm.relative.x * 0.006
			spin -= d                    # 跟随手指：往左拖 → 球面往左转
			drag_total += absf(d)
			_drag_moved += absf(mm.relative.x) + absf(mm.relative.y)
		else:
			hovered = _tile_at(mm.position)