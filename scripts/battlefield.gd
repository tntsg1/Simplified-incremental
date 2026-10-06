extends Node2D
# Minimal monochrome battlefield: flat grey geometry, white threats, one amber
# accent for criticals, bosses and danger. Every shape is drawn in _draw; no textures.

const BG := Color("141414")
const DOT := Color("262626")
const INK := Color("ededed")
const GREY := Color("b4b4b4")
const DIM := Color("6a6a6a")
const DARK := Color("2c2c2c")
const SHADE := Color("1c1c1c")
const ACCENT := Color("ffc94d")

var sim: RefCounted
var font: Font
var clock: float = 0.0
var hover: Vector2 = Vector2(-1000, -1000)
var scene_transform := Transform2D.IDENTITY
var draw_ms: float = 0
var reduced_effects: bool = false
var trauma: float = 0
var labels_left: int = 24
var dot_mesh: MultiMesh
var galaxy_mesh: MultiMesh
var galaxy_points: PackedVector2Array = []
var feedback: Array[Dictionary] = []
var feedback_pool: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var number_limits: Array[float] = [0, 0, 0, 0, 0, 0]
var recoil: Array[float] = [0, 0, 0, 0, 0, 0]
var aims: Array[float] = [-PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5]
var muzzle_limits: Array[float] = [0, 0, 0, 0, 0, 0]
var spark_limits: Array[float] = [0, 0, 0, 0, 0, 0]
var pierce_limits: Array[float] = [0, 0, 0, 0, 0, 0]
var core_pulse: float = 0
# Visible growth: purchases made in the (paused) upgrade panel replay on the
# battlefield once combat resumes, so the defense is seen to grow.
const GROWTH_NAMES := {"damage": "弹头", "speed": "射程", "reload": "装填", "crit": "暴击", "area": "范围", "pierce": "贯穿", "targets": "锁定", "turrets": "炮台"}
var prev_levels: Dictionary = {}
var prev_owned: Array = []
var growth: Array[Dictionary] = []
var growth_bounce: float = 0
var dock_age: Array[float] = [-1, -1, -1, -1, -1, -1]
var shown_range: float = -1
var core_outer: float = 20
# Barrage layer: purely cosmetic rounds that show the real launcher count and
# fire rate. Combat timing and damage stay in the simulation untouched.
const BULLET_CAP: int = 1500
var b_from := PackedVector2Array()
var b_ctrl := PackedVector2Array()
var b_to := PackedVector2Array()
var b_age := PackedFloat32Array()
var b_dur := PackedFloat32Array()
var b_style := PackedInt32Array()
var b_crit := PackedByteArray()
var turret_flash := PackedFloat32Array()
var turret_aim := PackedFloat32Array()
var last_target := Vector2(500, 200)
# Fill-only shapes are fan-triangulated into one array and submitted in a single
# canvas call per layer; hundreds of draw_colored_polygon calls were the bottleneck.
var batching: bool = false
var tri_points := PackedVector2Array()
var tri_colors := PackedColorArray()
var tri_indices := PackedInt32Array()
var trail_lines := PackedVector2Array()
# Rings, arcs and short strokes collect here as coloured segments: hundreds of
# antialiased draw_arc calls per frame were the other big cost late game.
var seg_points := PackedVector2Array()
var seg_colors := PackedColorArray()

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	dot_mesh = MultiMesh.new()
	dot_mesh.transform_format = MultiMesh.TRANSFORM_2D
	dot_mesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	dot_mesh.mesh = quad
	var dots: Array[Vector2] = []
	for x in range(-144, 1150, 24):
		for y in range(-12, 640, 24):
			dots.append(Vector2(x, y))
	dot_mesh.instance_count = dots.size()
	for i in range(dots.size()):
		dot_mesh.set_instance_transform_2d(i, Transform2D(0, dots[i]))
		dot_mesh.set_instance_color(i, DOT)
	var random := RandomNumberGenerator.new()
	random.seed = 9294
	for i in range(1400):
		var t: float = random.randf()
		var r: float = sqrt(t) * 235
		var a: float = t * 7.5 + (i % 4) * TAU / 4 + random.randfn(0, 0.13)
		galaxy_points.append(Vector2(cos(a), sin(a)) * r)
	galaxy_mesh = MultiMesh.new()
	galaxy_mesh.transform_format = MultiMesh.TRANSFORM_2D
	galaxy_mesh.use_colors = true
	galaxy_mesh.mesh = quad
	galaxy_mesh.instance_count = galaxy_points.size()
	for i in range(galaxy_points.size()):
		galaxy_mesh.set_instance_transform_2d(i, Transform2D(0, Vector2.ONE * (0.8 if i % 4 else 1.6), 0, galaxy_points[i]))
		galaxy_mesh.set_instance_color(i, Color(GREY, .18 + (i % 7) * .05))
	for i in range(160):
		feedback_pool.append({})

# ---------- shape helpers ----------

func ngon(sides: int, radius: float, rotation: float, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var a: float = rotation + i * TAU / sides
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

func shape(center: Vector2, radius: float, sides: int, rotation: float, fill: Color, outline: Color = Color(0, 0, 0, 0), width: float = 1.5) -> void:
	if radius <= .3:
		return
	if batching and outline.a <= 0:
		var base: int = tri_points.size()
		for i in range(sides):
			var a: float = rotation + i * TAU / sides
			tri_points.append(center + Vector2(cos(a), sin(a)) * radius)
			tri_colors.append(fill)
		for i in range(1, sides - 1):
			tri_indices.append(base)
			tri_indices.append(base + i)
			tri_indices.append(base + i + 1)
		return
	var points := ngon(sides, radius, rotation, center)
	if fill.a > 0:
		draw_colored_polygon(points, fill)
	if outline.a > 0:
		points.append(points[0])
		draw_polyline(points, outline, width, true)

func begin_batch() -> void:
	batching = true

func flush_batch() -> void:
	batching = false
	if not trail_lines.is_empty():
		draw_multiline(trail_lines, Color(GREY, .14), 3.0)
		trail_lines.clear()
	if not tri_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), tri_indices, tri_points, tri_colors)
	if not seg_points.is_empty():
		draw_multiline_colors(seg_points, seg_colors, 1.4)
	seg_points.clear()
	seg_colors.clear()
	tri_points.clear()
	tri_colors.clear()
	tri_indices.clear()

func star(center: Vector2, radius: float, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var a: float = rotation + i * TAU / 10
		points.append(center + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * .48))
	draw_colored_polygon(points, color)

func ink(text: String, pos: Vector2, color: Color = DIM, size: int = 12) -> void:
	if not scene_transform.is_equal_approx(Transform2D.IDENTITY):
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func ink_outlined(text: String, pos: Vector2, color: Color, size: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(BG, .9 * color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func arc_segments(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	var steps: int = clampi(int(radius * .35 * absf(to - from) / TAU), 8, 40)
	var step: float = (to - from) / steps
	var last: Vector2 = center + Vector2.from_angle(from) * radius
	for i in range(1, steps + 1):
		var next: Vector2 = center + Vector2.from_angle(from + i * step) * radius
		seg_points.append(last)
		seg_points.append(next)
		seg_colors.append(color)
		last = next

func stroke(a: Vector2, b: Vector2, color: Color, width: float = 1.5) -> void:
	if batching:
		seg_points.append(a)
		seg_points.append(b)
		seg_colors.append(color)
	else:
		draw_line(a, b, color, width, true)

func ring(center: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	if batching and width <= 2.0:
		arc_segments(center, radius, 0, TAU, color)
		return
	draw_arc(center, radius, 0, TAU, maxi(32, int(radius * .6)), color, width, true)

func pop(age: float) -> float:
	# Ease-out-back from 0 to 1 over ~0.28 s for spawns.
	var t: float = clampf(age / .28, 0, 1)
	var c: float = 1.70158
	return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)

# ---------- feedback events ----------

func add_feedback(kind: String, point: Vector2, index: int, size: float, duration: float, destination: Vector2 = Vector2.ZERO) -> void:
	if feedback.size() >= 64:
		return
	var fx: Dictionary = feedback_pool.pop_back() if not feedback_pool.is_empty() else {}
	fx.clear()
	fx.merge({"kind": kind, "pos": point, "weapon": index, "size": size, "age": 0.0, "duration": duration, "end": destination, "seed": int(point.x * 17 + point.y * 23)})
	feedback.append(fx)

func barrage_size(index: int) -> int:
	var launchers: float = float(sim.launcher_count())
	var packets: float = sim.salvo_packets(index)
	var size: float = 1.0 + log(launchers) / log(2.0) * 1.6 + (ceilf(log(packets) / log(2.0)) if packets > 1.0 else 0.0)
	return clampi(int(size), 1, 20)

func flight_time(index: int, from: Vector2, to: Vector2) -> float:
	var speed_scale: float = pow(1.08, int(sim.levels.speed))
	if bool(sim.catalog.weapons[index].beam):
		return maxf(.12, .30 / sqrt(speed_scale) + .1)
	return maxf(.08, from.distance_to(to) / (220.0 * minf(20.0, speed_scale)))

func spawn_barrage(index: int, point: Vector2, destination: Vector2, critical: bool, override: int = -1) -> void:
	var count: int = barrage_size(index) if override < 0 else override
	if reduced_effects:
		count = maxi(1, count / 3)
	var room: int = BULLET_CAP - b_age.size()
	if room <= 0:
		return
	count = mini(count, room)
	# Lead the target: threats fly in straight lines at constant speed, so aiming
	# at where it will be on arrival keeps rounds on it instead of trailing behind.
	var velocity := Vector2.ZERO
	if not sim.shots.is_empty():
		var target: Dictionary = sim.find_enemy(int(sim.shots.back().target))
		if not target.is_empty():
			velocity = (Vector2(target.end) - Vector2(target.start)) / maxf(.01, float(target.lifetime))
	for j in range(count):
		var from: Vector2 = point + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var travel: float = flight_time(index, from, destination) * randf_range(.92, 1.08)
		var delay: float = j * .014
		var to: Vector2 = destination + velocity * (travel + delay) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var span: Vector2 = to - from
		var side: Vector2 = span.orthogonal().normalized()
		var bend: float = 0.0
		match index:
			0: bend = randf_range(-.45, .45)
			2: bend = randf_range(-.15, .15)
			5: bend = (1.0 if j % 2 else -1.0) * randf_range(.6, 1.1)
		var ctrl: Vector2 = from.lerp(to, .5) + side * span.length() * bend
		if index == 5:
			ctrl = from + Vector2.from_angle(j * 2.399 + clock) * span.length() * .55
		b_from.append(from)
		b_ctrl.append(ctrl)
		b_to.append(to)
		b_age.append(-delay)
		b_dur.append(travel)
		b_style.append(index)
		b_crit.append(1 if critical else 0)

func on_turret_fired(slot: int, origin: Vector2, destination: Vector2, critical: bool) -> void:
	if slot < turret_flash.size():
		turret_flash[slot] = .12
		turret_aim[slot] = (destination - origin).angle()
	spawn_barrage(0, origin, destination, critical, maxi(1, barrage_size(0) / 4))

func on_fire(index: int, point: Vector2, destination: Vector2, critical: bool) -> void:
	last_target = destination
	spawn_barrage(index, point, destination, critical)
	recoil[index] = 1.0
	aims[index] = (destination - point).angle()
	core_pulse = 1.0
	if muzzle_limits[index] > 0:
		return
	muzzle_limits[index] = .075
	add_feedback("muzzle", point + Vector2(cos(aims[index]), sin(aims[index])) * 14, index, 7 + index, .12)
	if index >= 2:
		add_feedback("beam", point, index, 1.2 + index * .25, .16, destination)
	if critical:
		add_feedback("critical", destination, index, 16, .3)

func on_hit(point: Vector2, index: int, amount: float, critical: bool, boss: bool, _kind: String) -> void:
	if amount > 0 and (number_limits[index] <= 0 or critical) and numbers.size() < 28:
		if boss:
			# One weapon at a time over the boss, spread across its hull.
			for i in range(6):
				number_limits[i] = maxf(number_limits[i], .22)
		number_limits[index] = .12 if not boss else .22
		var spread: Vector2 = Vector2(randf_range(-90, 90), randf_range(-60, 50)) if boss else Vector2(randf_range(-10, 10), -6)
		var line := TextLine.new()
		line.add_string(sim.Catalog.number(amount), font, 21 if boss else 17 if critical else 13)
		numbers.append({"pos": point + spread, "line": line, "age": 0.0, "color": ACCENT if critical else INK if boss else Color("d6d6d6")})
	if spark_limits[index] > 0:
		return
	spark_limits[index] = .085
	add_feedback("spark", point, index, 16 if critical else 10, .22)

func on_members_removed(point: Vector2, index: int, members: int, _kind: String) -> void:
	add_feedback("shards", point, index, 10 + minf(14, log(maxf(1, members)) * 1.2), .5)

func on_pierced(origin: Vector2, destination: Vector2, index: int) -> void:
	if pierce_limits[index] > 0:
		return
	pierce_limits[index] = .14
	add_feedback("pierce", origin, index, 1, .22, destination)

func on_destroyed(point: Vector2, index: int, members: int, boss: bool, _kind: String) -> void:
	if boss and feedback.size() >= 64:
		feedback_pool.append(feedback.pop_front())
	var size: float = 110 if boss else 18 + minf(20, log(maxf(1, members)) * 2)
	add_feedback("boss_death" if boss else "shards", point, index, size, 2.2 if boss else .7)
	# Shake is reserved for big moments; constant hit shake read as stutter.
	if boss:
		trauma = .75

func animate(delta: float) -> void:
	trauma = maxf(0, trauma - delta * 2.3)
	core_pulse = maxf(0, core_pulse - delta * 6)
	for i in range(6):
		recoil[i] = maxf(0, recoil[i] - delta * 6.5)
		muzzle_limits[i] = maxf(0, muzzle_limits[i] - delta)
		spark_limits[i] = maxf(0, spark_limits[i] - delta)
		pierce_limits[i] = maxf(0, pierce_limits[i] - delta)
		number_limits[i] = maxf(0, number_limits[i] - delta)
	for i in range(numbers.size() - 1, -1, -1):
		numbers[i].age = float(numbers[i].age) + delta
		if float(numbers[i].age) >= .75:
			numbers.remove_at(i)
	for i in range(feedback.size() - 1, -1, -1):
		feedback[i].age = float(feedback[i].age) + delta
		if float(feedback[i].age) >= float(feedback[i].duration):
			feedback_pool.append(feedback[i])
			feedback.remove_at(i)
	track_growth(delta)
	for j in range(turret_flash.size()):
		turret_flash[j] = maxf(0, turret_flash[j] - delta)
	var alive: int = b_age.size()
	var i: int = 0
	while i < alive:
		b_age[i] += delta
		if b_age[i] >= b_dur[i]:
			# Swap-remove: draw order of rounds does not matter.
			alive -= 1
			b_from[i] = b_from[alive]
			b_ctrl[i] = b_ctrl[alive]
			b_to[i] = b_to[alive]
			b_age[i] = b_age[alive]
			b_dur[i] = b_dur[alive]
			b_style[i] = b_style[alive]
			b_crit[i] = b_crit[alive]
		else:
			i += 1
	if alive != b_age.size():
		b_from.resize(alive)
		b_ctrl.resize(alive)
		b_to.resize(alive)
		b_age.resize(alive)
		b_dur.resize(alive)
		b_style.resize(alive)
		b_crit.resize(alive)

func reset_growth() -> void:
	prev_levels = {}
	growth.clear()
	shown_range = -1
	for i in range(6):
		dock_age[i] = -1

func track_growth(delta: float) -> void:
	growth_bounce = maxf(0, growth_bounce - delta * 3)
	if sim == null or sim.paused or sim.mode == "title":
		return
	if prev_levels.is_empty():
		prev_levels = sim.levels.duplicate()
		prev_owned = sim.owned.duplicate()
	else:
		var delay: float = 0
		for key in sim.levels:
			var gained: int = int(sim.levels[key]) - int(prev_levels.get(key, 0))
			if gained > 0:
				growth.append({"key": key, "gained": gained, "age": -delay, "slot": growth.size() % 6})
				delay += .22
		for i in range(6):
			if sim.owned[i] and not bool(prev_owned[i]):
				dock_age[i] = 0.0
		prev_levels = sim.levels.duplicate()
		prev_owned = sim.owned.duplicate()
	var target_range: float = sim.weapon_range()
	shown_range = target_range if shown_range < 0 else lerpf(shown_range, target_range, minf(1, delta * 3))
	for i in range(growth.size() - 1, -1, -1):
		var before: float = float(growth[i].age)
		growth[i].age = before + delta
		if before < 0 and float(growth[i].age) >= 0:
			growth_bounce = 1.0
			core_pulse = 1.0
		if float(growth[i].age) > 1.6:
			growth.remove_at(i)
	for i in range(6):
		if dock_age[i] >= 0:
			dock_age[i] += delta
			if dock_age[i] >= .9:
				dock_age[i] = -1
				add_feedback("shards", sim.weapon_origin(i), i, 26, .6)
				trauma = minf(.5, trauma + .2)

func shake_offset() -> Vector2:
	if reduced_effects:
		return Vector2.ZERO
	return Vector2(sin(clock * 19), sin(clock * 23 + 1.7)) * trauma * trauma * 9

func draw_bullets() -> void:
	# All rounds go out in three batched calls: white trails, amber trails, heads.
	var trails := PackedVector2Array()
	var hot := PackedVector2Array()
	var heads := PackedVector2Array()
	for i in range(b_age.size()):
		var age: float = b_age[i]
		if age < 0:
			continue
		var t: float = age / b_dur[i]
		var style: int = b_style[i]
		var tail: float = .22 if style == 1 else .1
		var f: Vector2 = b_from[i]
		var c: Vector2 = b_ctrl[i]
		var to: Vector2 = b_to[i]
		var u: float = maxf(0, t - tail)
		var pos: Vector2 = f.lerp(c, t).lerp(c.lerp(to, t), t)
		var back: Vector2 = f.lerp(c, u).lerp(c.lerp(to, u), u)
		if style == 2:
			var side: Vector2 = (to - f).orthogonal().normalized()
			# Wobble only mid-flight so the round still lands on target.
			pos += side * sin(t * 22 + age) * 5 * sin(t * PI)
			back += side * sin(u * 22 + age) * 5 * sin(u * PI)
		var dir: Vector2 = (pos - back).normalized()
		var crit: bool = b_crit[i] == 1
		if style == 4 and t > .5:
			# Quasar rounds split into three halfway and reconverge on the target.
			var spread: float = (t - .5) * (1 - t) * 4 * 26
			for k in [-1, 0, 1]:
				var fork: Vector2 = dir.orthogonal() * k * spread
				if crit:
					hot.append(back + fork * .6)
					hot.append(pos + fork)
				else:
					trails.append(back + fork * .6)
					trails.append(pos + fork)
				heads.append(pos + fork)
				heads.append(pos + fork + dir * 2.5)
		else:
			if crit:
				hot.append(back)
				hot.append(pos)
			else:
				trails.append(back)
				trails.append(pos)
			heads.append(pos)
			heads.append(pos + dir * 2.5)
		if style == 3:
			var spin: Vector2 = Vector2.from_angle(age * 30) * 5
			heads.append(pos + spin)
			heads.append(pos + spin * 1.3)
	if trails.size() > 1:
		draw_multiline(trails, Color(INK, .45), 1.4)
	if hot.size() > 1:
		draw_multiline(hot, Color(ACCENT, .75), 1.6)
	if heads.size() > 1:
		draw_multiline(heads, INK, 3.0)

func draw_feedback() -> void:
	for fx in feedback:
		var t: float = float(fx.age) / float(fx.duration)
		var p: Vector2 = fx.pos
		var fade: float = (1 - t) * (.55 if reduced_effects else 1.0)
		var r: float = float(fx.size)
		var seed_value: int = int(fx.seed)
		match str(fx.kind):
			"pierce":
				var destination: Vector2 = fx.end
				for j in range(4):
					stroke(p.lerp(destination, j * .25), p.lerp(destination, j * .25 + .14), Color(GREY, fade * .7), 1.2)
				ring(destination, 4 + 6 * t, Color(GREY, fade * .6))
			"beam":
				var destination: Vector2 = fx.end
				draw_line(p, destination, Color(INK, fade * .08), r * 6, true)
				draw_line(p, destination, Color(INK, fade * .9), r, true)
			"muzzle":
				draw_circle(p, r * (1 - t * .5), Color(INK, fade))
			"spark", "critical":
				var col: Color = ACCENT if fx.kind == "critical" else INK
				ring(p, r * (.4 + t), Color(col, fade), 1.5)
				for j in range(4):
					var a: float = j * TAU / 4 + seed_value
					var dir := Vector2(cos(a), sin(a))
					stroke(p + dir * r * t, p + dir * r * (t + .35), Color(col, fade))
				if fx.kind == "critical":
					ink("暴击", p + Vector2(14, -16 - t * 12), Color(ACCENT, fade), 12)
			"shards", "boss_death":
				var boss: bool = fx.kind == "boss_death"
				var travel: float = 1 - pow(1 - t, 3)
				if boss:
					for k in range(3):
						ring(p, r * (.2 + travel * (1.2 + k * .5)), Color(ACCENT if k == 0 else INK, fade * .7), 3.0 - k)
				else:
					ring(p, r * (.3 + travel * 1.4), Color(INK, fade * .5), 1.0)
				if not reduced_effects or boss:
					for j in range(24 if boss else 7):
						var a: float = j * 2.399 + seed_value
						var dir := Vector2(cos(a), sin(a))
						var reach: float = r * (.7 + (j % 4) * .35)
						var q: Vector2 = p + dir * reach * travel
						var size: float = (6.0 if boss else 3.2) * (1 - t * .8) + .6
						shape(q, size, 3, a + t * 9, Color(INK if j % 3 else GREY, fade))

# ---------- scene ----------

func galaxy(center: Vector2, size: float, rotation: float = 0) -> void:
	draw_set_transform_matrix(scene_transform * Transform2D(rotation + clock * .02, Vector2.ONE * size, 0, center))
	draw_multimesh(galaxy_mesh, null)
	draw_circle(Vector2.ZERO, 10, Color(GREY, .5))
	draw_set_transform_matrix(scene_transform)

func core(center: Vector2, layers: int, live: bool = false) -> void:
	# One hexagonal shell per scale reached; the live core also shows upgrades:
	# damage grows the heart and adds a shell per doubling milestone, launcher
	# tiers orbit as nodes, crit lights amber sparks, pierce/lock links the nodes.
	var swell: float = 1 + core_pulse * .08 + (growth_bounce * .22 if live else 0.0)
	var inner: float = 9.0
	var shells: int = layers
	if live:
		var damage: int = int(sim.levels.damage)
		inner += minf(10.0, damage * .06)
		for threshold in [10, 25, 50, 75, 100, 125, 150]:
			if damage >= threshold:
				shells += 1
		shells = mini(shells, 10)
	inner *= swell
	var gap: float = 5.0 * swell
	for i in range(shells, 0, -1):
		var spin: float = clock * (.25 if i % 2 else -.18) + i * .3
		shape(center, inner + i * gap, 6, spin, Color(0, 0, 0, 0), Color(GREY if i == 1 else DIM, .9), 1.4 if i <= layers else 1.0)
	shape(center, inner, 6, clock * .4, INK)
	var outer: float = inner + shells * gap
	if not live:
		return
	var sparks: int = mini(16, int(sim.levels.crit) / 3)
	for j in range(sparks):
		var a: float = j * TAU / maxi(1, sparks) - clock * .3
		draw_circle(center + Vector2(cos(a), sin(a)) * (outer + 4), 1.6, ACCENT)
	# Turrets bought with the turret upgrade: each one is a real shooter in the
	# sim and flashes and recoils on its own staggered beat.
	var count: int = sim.turret_count()
	if turret_flash.size() != count:
		turret_flash.resize(count)
		turret_aim.resize(count)
	var city: bool = sim.stage == 0
	if count >= 3 and not city and (int(sim.levels.pierce) > 0 or int(sim.levels.targets) > 0):
		var loop := PackedVector2Array()
		for j in range(mini(sim.TURRET_RINGS[0], count)):
			loop.append(sim.turret_position(j))
		loop.append(loop[0])
		draw_polyline(loop, Color(GREY, .3), 1.0, true)
	begin_batch()
	var far: float = outer
	for j in range(count):
		var lit: float = clampf(turret_flash[j] / .12, 0, 1)
		var home: Vector2 = sim.turret_position(j)
		far = maxf(far, home.distance_to(center))
		var aim: float = turret_aim[j] if turret_aim[j] != 0.0 else (last_target - home).angle()
		var barrel := Vector2.from_angle(aim)
		var spot: Vector2 = home - barrel * 3.0 * lit
		var size: float = (4.6 + 1.2 * lit) * swell * (1.4 if city else 1.0)
		shape(spot, size, 3, aim, GREY.lerp(INK, lit))
		stroke(spot, spot + barrel * (size + 6), Color(GREY.lerp(INK, lit), .9))
	flush_batch()
	var owned_turrets: int = int(sim.levels.get("turrets", 0))
	if owned_turrets > count and count > 0:
		ink("×" + str(owned_turrets), sim.turret_position(count - 1) + Vector2(16, 6), GREY, 12)
	core_outer = outer + 16 if city or count == 0 else far + 6

func stage_scene(index: int) -> void:
	var c := Vector2(500, 325)
	match index:
		0:
			for i in range(30):
				var x: float = -150 + i * 44
				var height: float = 26 + fmod(i * 37.3, 96) + (34 if i % 7 == 0 else 0)
				draw_rect(Rect2(x, 600 - height, 34, height), SHADE if i % 2 else Color("191919"))
			draw_line(Vector2(-150, 600), Vector2(1150, 600), DIM, 1.5)
			ink("01  /  防御控制中心", Vector2(540, 624), DIM, 12)
		1:
			ring(c, 190, DARK)
			ring(c, 247, DARK)
			draw_circle(c, 81, SHADE)
			ring(c, 81, DIM, 2)
			draw_circle(c + Vector2(247, -33), 9, DARK)
			ink("地球", c + Vector2(-15, 106), DIM, 13)
		2:
			for i in range(5):
				ring(c, 70 + i * 55, DARK)
				var a: float = i * 1.72 + .2 + clock * .03 / (i + 1)
				draw_circle(c + Vector2(cos(a), sin(a)) * (70 + i * 55), 4 + i * 1.5, DIM if i != 1 else GREY)
			draw_circle(c, 42, SHADE)
			ring(c, 42, GREY, 2)
			ink("太阳", c + Vector2(-15, 62), DIM, 13)
		3:
			galaxy(c, 1.15, -.2)
			ring(c, 285, DARK)
			draw_circle(c + Vector2(160, 16), 3, GREY)
			ink("太阳系", c + Vector2(168, 22), DIM, 12)
		4:
			for i in range(7):
				var a: float = i * 2.4
				var p: Vector2 = c + Vector2(cos(a), sin(a)) * 215
				draw_line(c, p, DARK, 1)
				galaxy(p, .3, a * .3)
			galaxy(c, .6, -.4)
			ring(c, 295, DARK)
			ink("本星系群", c + Vector2(-25, 68), DIM, 13)
		5:
			for i in range(34):
				var a: float = i * 2.399
				var r: float = sqrt(float(i) / 34) * 290
				var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
				var p2: Vector2 = c + Vector2(cos(a + 1.5), sin(a + 1.5)) * r * .75
				draw_line(p, p2, DARK, 1)
				draw_circle(p, 2 + i % 3, DIM)
			ring(c, 300, DARK, 1.4)
			ink("可观测宇宙 · 防御枢纽", c + Vector2(-65, 56), DIM, 13)
	core(Vector2(500, 572) if index == 0 else c, index + 1, index == sim.stage and sim.mode != "transition")

func weapon(index: int, point: Vector2, small: bool = false) -> void:
	# Turret i is a (3+i)-gon, so older weapons stay recognisable at larger scales.
	var s: float = .7 if small else 1.0
	if dock_age[index] >= 0 and not small:
		# A newly deployed turret flies out of the core and snaps into place.
		var k: float = clampf(dock_age[index] / .9, 0, 1)
		var travel: float = 1 - pow(1 - k, 3)
		var from: Vector2 = sim.defense_position()
		draw_line(from, from.lerp(point, travel), Color(INK, .35 * (1 - k)), 1.5, true)
		point = from.lerp(point, travel)
		s *= .4 + .6 * travel + sin(k * PI) * .35
	var direction := Vector2(cos(aims[index]), sin(aims[index]))
	var p: Vector2 = point - direction * recoil[index] * (3 + index)
	var radius: float = (10 + index * 1.2) * s
	shape(p, radius, 3 + index, aims[index], BG, INK, 1.6)
	draw_line(p, p + direction * (radius + 7 * s), INK, 2.0 * s, true)
	var tier: int = mini(5, int(sim.levels.reload) / 10)
	for j in range(tier):
		draw_circle(p + Vector2(-radius + j * 4.5, radius + 6), 1.3, GREY)
	if not small and (index == sim.stage or hover.distance_to(point) < 48):
		ink(sim.catalog.weapons[index].title, point + Vector2(-26, radius + 24), DIM, 10)
	if hover.distance_to(point) < 30:
		var panel: Vector2 = point + Vector2(-115, -96)
		draw_rect(Rect2(panel, Vector2(230, 65)), Color("1a1a1a"))
		draw_rect(Rect2(panel, Vector2(230, 65)), DARK, false, 1)
		ink(sim.catalog.weapons[index].title + " · 在役", panel + Vector2(10, 19), INK, 13)
		ink("齐射 " + sim.Catalog.number(sim.shot_damage(index)) + " / " + ("%.2f s" % sim.shot_interval(index)), panel + Vector2(10, 38), GREY, 11)
		ink("每次覆盖 " + sim.Catalog.number(sim.coverage(index)) + " 成员", panel + Vector2(10, 55), DIM, 11)

func boss_shape(p: Vector2, radius: float, kind: String, flash: float) -> void:
	var fill: Color = SHADE.lerp(INK, flash)
	match kind:
		"planet":
			draw_circle(p, radius, fill)
			ring(p, radius, INK, 3)
			ring(p, radius * .62, Color(GREY, .8), 1.5)
		"star":
			star(p, radius * 1.1, clock * .3, fill)
			ring(p, radius * .55, INK, 2.5)
			draw_arc(p, radius + 12, clock, clock + 5.2, 80, Color(ACCENT, .7), 2, true)
		"rift":
			for j in range(6, 0, -1):
				draw_arc(p, radius * (.5 + j * .1), clock * (.1 + j * .05), clock * (.1 + j * .05) + 5.4, 80, Color(GREY, .25 + j * .05), 2, true)
			draw_circle(p, radius * .45, BG)
			ring(p, radius * .45, INK, 3)
		"mothership":
			shape(p, radius, 5, -PI * .5, fill, INK, 3)
			shape(p, radius * .55, 5, PI * .5 + clock * .4, Color(0, 0, 0, 0), GREY, 2)
		_:
			shape(p, radius, 7, clock * .15, fill, INK, 3)
			shape(p, radius * .5, 4, -clock * .5, Color(0, 0, 0, 0), GREY, 2)

func enemy(e: Dictionary) -> void:
	var p: Vector2 = e.pos
	var radius: float = float(e.radius)
	var boss: bool = bool(e.boss)
	var focused: bool = int(e.id) == sim.priority_id or hover.distance_to(p) < radius + 13
	var dense: bool = sim.enemies.size() > 70
	if dense and not boss and not focused:
		radius *= .75
	var flash: float = clampf(float(e.get("flash", 0)) / .12, 0, 1)
	var appear: float = pop(float(e.age)) if not boss else 1.0
	var danger: float = float(e.age) / float(e.lifetime)
	var heading: float = (Vector2(e.end) - Vector2(e.start)).angle()
	var trail: Vector2 = -Vector2(cos(heading), sin(heading))
	if not boss:
		if batching:
			trail_lines.append(p)
			trail_lines.append(p + trail * radius * 2.6)
		else:
			draw_line(p, p + trail * radius * 2.6, Color(GREY, .14), maxf(1.0, radius * .35), true)
	if boss:
		boss_shape(p, radius * (1 + flash * .04), str(e.kind), flash)
	else:
		var size: float = radius * .78 * appear * (1 + flash * .18)
		var spin: float = clock * (.6 + float(int(e.seed) % 7) * .15) + int(e.seed)
		var ship: bool = str(e.kind).contains("ship")
		var fill: Color = (INK if ship else GREY).lerp(Color.WHITE, flash)
		if dense and not focused:
			fill.a = clampf(.5 + danger * .5 + flash, .5, 1)
		if bool(e.elite):
			shape(p, size * 1.15, 6 if ship else 8, spin * .5, Color(0, 0, 0, 0), INK, 1.5)
			shape(p, size * .7, 3 if ship else 4, heading if ship else spin, fill)
		elif ship:
			shape(p, size, 3, heading, fill)
		else:
			shape(p, size, 4, spin, fill)
		if int(e.members) > 1:
			var companions: int = 5 if not dense else 2 if focused or danger > .8 else 0
			for j in range(mini(companions, int(e.members) - 1)):
				var a: float = j * TAU / 5 + clock * .9 + int(e.seed)
				var q: Vector2 = p + Vector2(cos(a), sin(a)) * radius * 1.45 * appear
				shape(q, 2.6 * appear, 3 if ship else 4, a, Color(fill, fill.a * .8))
			if labels_left > 0 or focused:
				ink("×" + sim.Catalog.number(e.members), p + Vector2(-14, radius + 18), DIM, 11)
				labels_left -= 1
	if danger > .7 and not boss:
		if batching:
			arc_segments(p, radius + 8, -PI * .5, -PI * .5 + TAU * danger, Color(ACCENT, .85))
		else:
			draw_arc(p, radius + 8, -PI * .5, -PI * .5 + TAU * danger, 40, Color(ACCENT, .85), 1.5, true)
	if focused:
		var col: Color = INK if int(e.id) == sim.priority_id else GREY
		for j in range(4):
			var a: float = PI * .25 + j * PI * .5
			draw_arc(p, radius + 13, a, a + .45, 8, col, 2, true)
		if not boss and int(e.id) == sim.priority_id and not hover.distance_to(p) < radius + 13:
			ink("HP %s   /   %.1fs" % [sim.Catalog.number(float(e.hp) + (int(e.members) - 1) * float(e.unit_hp)), float(e.lifetime) - float(e.age)], p + Vector2(24, -radius - 16), col, 11)

func inspector() -> void:
	var selected: Dictionary = {}
	var distance: float = INF
	for e in sim.enemies:
		if bool(e.dead):
			continue
		var d: float = hover.distance_to(e.pos)
		if d < distance and d < float(e.radius) + 13:
			selected = e
			distance = d
	if selected.is_empty():
		return
	var p := Vector2(-120 if hover.x > 500 else 865, 35)
	draw_rect(Rect2(p, Vector2(250, 190)), Color("1a1a1a"))
	draw_rect(Rect2(p, Vector2(250, 190)), DARK, false, 1)
	var kind: String = selected.kind
	var boss: bool = selected.boss
	var title: String = sim.stage_data().boss_title.split(" · ")[0] if boss else "精英舰船" if kind == "elite_ship" else "外星舰群" if kind == "ship" else "精英天体" if selected.elite else "自然威胁群" if int(selected.members) > 1 else "来袭天体"
	ink(title, p + Vector2(14, 26), INK, 15)
	var icon: Vector2 = p + Vector2(55, 92)
	if boss:
		boss_shape(icon, 34, kind, 0)
	else:
		shape(icon, 30, 3 if kind.contains("ship") else 4, clock * .5, INK if kind.contains("ship") else GREY)
	ink("成员 " + sim.Catalog.number(selected.members), p + Vector2(110, 62), GREY, 12)
	ink("总生命", p + Vector2(110, 84), DIM, 11)
	var hp: float = float(selected.hp) + (int(selected.members) - 1) * float(selected.unit_hp)
	ink(sim.Catalog.number(hp), p + Vector2(110, 106), INK, 14)
	var remaining: float = maxf(0, float(selected.lifetime) - float(selected.age))
	ink("撞击 %.1f 秒" % remaining, p + Vector2(14, 146), ACCENT if remaining < 10 else GREY, 12)
	ink("在途伤害 " + sim.Catalog.number(selected.reserved), p + Vector2(14, 165), DIM, 11)
	ink("点击指定全体系优先目标" if sim.automation else "点击 / 按住目标发射", p + Vector2(14, 182), DIM, 11)

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	if sim == null or font == null:
		return
	draw_multimesh(dot_mesh, null)
	var idx: int = sim.stage
	labels_left = 6 if sim.enemies.size() > 70 else 24
	if sim.mode == "transition":
		# The previous defense shrinks into the next scale's centre.
		var t: float = smoothstep(0.0, 1.0, sim.mode_time / sim.transition_length)
		var future_scale: float = lerpf(3.0, 1.0, t)
		scene_transform = Transform2D(0, Vector2.ONE * future_scale, 0, Vector2(500, 325) * (1 - future_scale))
		draw_set_transform_matrix(scene_transform)
		stage_scene(idx + 1)
		var scale_value: float = pow(0.04, t)
		var previous_center: Vector2 = Vector2(500, 570) if idx == 0 else Vector2(500, 325)
		var anchors: Array[Vector2] = [Vector2(547, 356), Vector2(456, 386), Vector2(660, 341), Vector2(500, 325), Vector2(500, 325)]
		var anchor: Vector2 = Vector2(500, 325) + (anchors[idx] - Vector2(500, 325)) * future_scale
		scene_transform = Transform2D(0, Vector2.ONE * scale_value, 0, anchor - previous_center * scale_value)
		draw_set_transform_matrix(scene_transform)
		stage_scene(idx)
		for i in range(6):
			if sim.owned[i]:
				weapon(i, sim.weapon_origin(i), idx > 0 and i < idx)
		scene_transform = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO)
		ink("尺度跃迁  /  " + sim.catalog.stages[idx + 1].title, Vector2(405, 100), INK, 22)
	else:
		stage_scene(idx)
		# Interception ring: threats are engaged once they cross it.
		if sim.mode in ["wave", "intermission"]:
			var ring_from: float = PI if idx == 0 else 0.0
			var segments: int = 96
			var step: float = (TAU - ring_from) / segments
			var dashes := PackedVector2Array()
			var radius: float = shown_range if shown_range > 0 else sim.weapon_range()
			var middle: Vector2 = sim.defense_position()
			for j in range(0, segments, 2):
				dashes.append(middle + Vector2.from_angle(ring_from + j * step) * radius)
				dashes.append(middle + Vector2.from_angle(ring_from + (j + 1) * step) * radius)
			draw_multiline(dashes, Color(GREY, .32), 1.4)
		for i in range(6):
			if sim.owned[i]:
				weapon(i, sim.weapon_origin(i), idx > 0 and i < idx)
		begin_batch()
		for e in sim.enemies:
			if not bool(e.dead):
				enemy(e)
		flush_batch()
		for p in sim.shots:
			if bool(p.beam):
				draw_line(p.from, p.end, Color(INK, .06), 9 + int(p.weapon) * 1.5, true)
				draw_line(p.from, p.end, Color(INK, .85), 1.2 + int(p.weapon) * .2, true)
		draw_bullets()
		var rewards_left: int = 16
		begin_batch()
		for fx in sim.effects:
			var t: float = float(fx.age) / float(fx.duration)
			if fx.kind == "reward":
				if rewards_left > 0:
					ink("+$" + sim.Catalog.number(fx.amount), Vector2(fx.pos) + Vector2(8, -16 - t * 22), Color(GREY, 1 - t), 11)
					rewards_left -= 1
			else:
				var r: float = 4 + float(fx.amount) * (t + .1)
				ring(fx.pos, r, Color(ACCENT if fx.kind == "breach" else GREY, (1 - t) * .7), 1.4)
		flush_batch()
		if sim.mode == "intermission":
			ink("拦截完成 · 下一波即将来袭", Vector2(395, 190), GREY, 18)
	begin_batch()
	draw_feedback()
	flush_batch()
	if sim.mode != "transition":
		var center: Vector2 = sim.defense_position()
		for g in growth:
			if float(g.age) < 0:
				continue
			var t: float = float(g.age) / 1.6
			var col: Color = ACCENT if g.key == "crit" else INK
			ring(center, core_outer + t * 150, Color(col, (1 - t) * .8), 2.0 * (1 - t) + .5)
			var label: String = "%s +%d" % [GROWTH_NAMES.get(g.key, g.key), int(g.gained)]
			var rise: float = 8 * (1 - pow(1 - minf(1, t * 3), 2))
			ink_outlined(label, center + Vector2(core_outer + 18, -20 - int(g.slot) * 23 - rise), Color(col, 1 - t * t * t), 15)
	for n in numbers:
		var t: float = float(n.age) / .75
		var lift: float = 22 * (1 - pow(1 - t, 2))
		var grow: float = 1.0 + .35 * maxf(0, 1 - t * 6)
		var line: TextLine = n.line
		var alpha: float = 1 - t * t
		# Shaped once on hit; the pop is a transform, so no per-frame text shaping.
		draw_set_transform(Vector2(n.pos) + Vector2(-8, -lift), 0, Vector2.ONE * grow)
		var top := Vector2(0, -line.get_line_ascent())
		line.draw_outline(get_canvas_item(), top, 5, Color(BG, .9 * alpha))
		line.draw(get_canvas_item(), top, Color(n.color, alpha))
	draw_set_transform(Vector2.ZERO)
	inspector()
	draw_ms = (Time.get_ticks_usec() - started) / 1000.0
