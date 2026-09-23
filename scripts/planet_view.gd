# planet_view.gd — 球面星球视图（全自绘：星野 / 星球 / 地块 / 建筑 / 无人机 / 飘字）
# 交互: 左键点击选中地块；按住拖动旋转星球。
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

var sim = null                    # sim_core 实例（外部注入）
var spin := 0.0                   # 当前旋转角（弧度）
var zoom := 1.0
var selected := Vector2i(-99, -99)
var hovered := Vector2i(-99, -99)

var _drag := false
var _drag_moved := 0.0
var _time := 0.0
var _stars: Array = []
var _floaters: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(220):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0)))
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
	return Vector2(size.x * 0.47, size.y * 0.52)


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


# ---------- 绘制 ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.043, 0.060, 0.100))
	for s in _stars:
		var sx := float(s.x) * size.x
		var sy := float(s.y) * size.y
		var tw := 0.55 + 0.45 * sin(_time * float(s.z) * 2.0 + float(s.x) * 20.0)
		draw_circle(Vector2(sx, sy), 1.1, Color(0.75, 0.85, 1.0, 0.35 * float(s.z) * tw))
	if sim == null:
		return
	var c := _center()
	var r := _radius()
	draw_texture_rect(PLANET_TEX, Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false)
	# 地块
	var tiles: Array = []
	for ty in range(int(sim.grid_h)):
		for tx in range(int(sim.grid_w)):
			tiles.append(Vector2i(tx, ty))
	for t in tiles:
		var p := project_tile(t)
		if p.z <= 0.02:
			continue
		var s := face_scale(p.z)
		var rr := r * 0.108 * s
		if Vector2(p.x, p.y).distance_to(c) > r - rr * 1.2:
			continue
		var pts := PackedVector2Array()
		for k in range(6):
			var a := TAU * float(k) / 6.0 + 0.5236
			pts.append(Vector2(p.x + rr * cos(a), p.y + rr * 0.72 * sin(a)))
		var dep: bool = sim.is_deposit(t)
		var is_colony: bool = t == sim.colony_tile
		var fill := Color(0, 0, 0, 0)
		var edge := Color(0.55, 0.66, 0.85, 0.16)
		if dep:
			fill = Color(1.0, 0.72, 0.30, 0.10 + 0.10 * clampf(p.z, 0.0, 1.0))
			edge = Color(1.0, 0.72, 0.30, 0.55)
		if is_colony:
			edge = Color(0.55, 0.85, 1.0, 0.80)
		if t == selected:
			fill = Color(1, 1, 1, 0.10)
			edge = Color(1, 1, 1, 0.95)
		elif t == hovered:
			edge = Color(0.80, 0.90, 1.0, 0.60)
		if fill.a > 0.001:
			draw_colored_polygon(pts, fill)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, edge, 1.6)
	# 建筑（近的盖远的 → 按 depth 升序画，远的先画）
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
		var rc := Rect2(Vector2(p.x - base * 0.5, p.y - base * 0.86), Vector2(base, base))
		draw_texture_rect(tex, rc, false, Color(1, 1, 1, alpha))
		if not b.is_empty() and int(b["level"]) > 1:
			var f: Font = get_theme_default_font()
			draw_string(f, Vector2(p.x - 10, p.y - base * 0.60), "Lv%d" % int(b["level"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))
	# 无人机（殖民中心 → 矿机，来回两架相位）
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
	# 飘字
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
			spin += mm.relative.x * 0.006
			_drag_moved += absf(mm.relative.x) + absf(mm.relative.y)
		else:
			hovered = _tile_at(mm.position)