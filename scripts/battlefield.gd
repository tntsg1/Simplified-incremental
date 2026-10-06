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
const GROWTH_NAMES := {"damage": "弹头", "speed": "弹速", "reload": "装填", "crit": "暴击", "area": "范围", "pierce": "贯穿", "targets": "锁定", "turrets": "炮台"}
var prev_levels: Dictionary = {}
var prev_owned: Array = []
var growth: Array[Dictionary] = []
var growth_bounce: float = 0
var dock_age: Array[float] = [-1, -1, -1, -1, -1, -1]
var core_outer: float = 20
# Barrage layer: purely cosmetic rounds that show the real launcher count and
# fire rate. Combat timing and damage stay in the simulation untouched.
const BULLET_CAP: int = 900
const NUMBER_CAP: int = 80
# Additive glow layer: light trails, flashes and halos drawn over the flat field.
const GlowTexture = preload("res://assets/glow.svg")
const COIN_CAP: int = 70
var glow: Node2D
var glow_trails := PackedVector2Array()
var glow_heads := PackedVector2Array()
var coins: Array[Dictionary] = []
var coin_arrivals: int = 0
var money_anchor := Vector2(500, -80)
var last_mode: String = ""
# Shockwaves ripple the background grid (shader) on every kill and big event.
const WAVE_CAP: int = 12
var grid_rect: ColorRect
var grid_material: ShaderMaterial
var waves: Array[Dictionary] = []
# Sim time not yet stepped this frame: threats move linearly, so drawing them at
# age + lead is exact and stays smooth on any refresh rate.
var render_lead: float = 0
# Big-moment staging: wave/boss banners, cinematic bars, boss-death slow motion.
var banner: Dictionary = {}
var banner_cache: Dictionary = {}
var letterbox: float = 0
var slowmo_request: bool = false
# Camera punch (main scales the field by it) and a rolling kill-combo counter.
var punch: float = 0
var combo_events: Array[Vector2] = []
var combo: int = 0
var combo_pop: float = 0
var combo_line: TextLine
var combo_shown: int = -1
var kills_seen: int = -1
# Celestial bodies: hover/flash state and the body under the cursor.
var body_flash: Dictionary = {}
var body_hover: int = -1
# Where the sim sent rounds whose target died (old id -> new id).
var redirects: Dictionary = {}
# Mouse reticle: follows with a little inertia and snaps open around threats.
var show_reticle: bool = false
var reticle_pos := Vector2(500, 300)
var reticle_lock: float = 0
var lock_pos := Vector2.ZERO
var lock_radius: float = 12
var lock_priority: bool = false
# Ambient dust spiralling into the core keeps the field alive between waves.
const DUST: int = 70
var dust_angle := PackedFloat32Array()
var dust_radius := PackedFloat32Array()
var dust_speed := PackedFloat32Array()
var b_from := PackedVector2Array()
var b_ctrl := PackedVector2Array()
var b_to := PackedVector2Array()
var b_age := PackedFloat32Array()
var b_dur := PackedFloat32Array()
var b_style := PackedInt32Array()
var b_crit := PackedByteArray()
var b_value := PackedFloat32Array()
var b_target := PackedInt32Array()
# Shaped damage-number lines are reused by text; volleys repeat the same values.
var line_cache: Dictionary = {}
var numbers_this_frame: int = 0
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
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
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
	grid_material = ShaderMaterial.new()
	grid_material.shader = preload("res://assets/grid_warp.gdshader")
	grid_material.set_shader_parameter("origin", Vector2(-150, -20))
	grid_rect = ColorRect.new()
	grid_rect.position = Vector2(-150, -20)
	grid_rect.size = Vector2(1300, 660)
	grid_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_rect.material = grid_material
	grid_rect.show_behind_parent = true
	add_child(grid_rect)
	for i in range(DUST):
		dust_angle.append(randf() * TAU)
		dust_radius.append(randf_range(60, 680))
		dust_speed.append(randf_range(14, 40))
	glow = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	add_child(glow)
	glow.draw.connect(draw_glow)

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

func shape_squash(center: Vector2, radius: float, sides: int, rotation: float, fill: Color, along: float, across: float, axis: float) -> void:
	# Squash and stretch: scale `along` the axis and `across` it, then fill.
	if radius <= .3:
		return
	var u := Vector2.from_angle(axis)
	var v := u.orthogonal()
	var points := PackedVector2Array()
	for i in range(sides):
		var a: float = rotation + i * TAU / sides
		var offset: Vector2 = Vector2(cos(a), sin(a)) * radius
		points.append(center + u * offset.dot(u) * along + v * offset.dot(v) * across)
	if batching:
		var base: int = tri_points.size()
		for point in points:
			tri_points.append(point)
			tri_colors.append(fill)
		for i in range(1, sides - 1):
			tri_indices.append(base)
			tri_indices.append(base + i)
			tri_indices.append(base + i + 1)
	else:
		draw_colored_polygon(points, fill)

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

func add_wave(pos: Vector2, strength: float, duration: float = 1.1) -> void:
	if reduced_effects:
		strength *= .4
	if waves.size() >= WAVE_CAP:
		waves.pop_front()
	waves.append({"pos": pos, "age": 0.0, "dur": duration, "strength": strength})

func update_waves(delta: float) -> void:
	var packed: Array[Vector4] = []
	for i in range(waves.size() - 1, -1, -1):
		waves[i].age = float(waves[i].age) + delta
		if float(waves[i].age) >= float(waves[i].dur):
			waves.remove_at(i)
	for w in waves:
		var t: float = float(w.age) / float(w.dur)
		var pos: Vector2 = w.pos
		packed.append(Vector4(pos.x, pos.y, float(w.age) * 520.0, float(w.strength) * (1 - t) * (1 - t)))
	while packed.size() < WAVE_CAP:
		packed.append(Vector4.ZERO)
	grid_material.set_shader_parameter("waves", packed)
	grid_material.set_shader_parameter("wave_count", waves.size())
	grid_material.set_shader_parameter("time", clock)

func add_feedback(kind: String, point: Vector2, index: int, size: float, duration: float, destination: Vector2 = Vector2.ZERO) -> void:
	if feedback.size() >= 140:
		return
	var fx: Dictionary = feedback_pool.pop_back() if not feedback_pool.is_empty() else {}
	fx.clear()
	fx.merge({"kind": kind, "pos": point, "weapon": index, "size": size, "age": 0.0, "duration": duration, "end": destination, "seed": int(point.x * 17 + point.y * 23)})
	feedback.append(fx)

func barrage_size(index: int) -> int:
	var launchers: float = float(sim.launcher_count())
	var packets: float = sim.salvo_packets(index)
	# Even the first silo volley is a small swarm; it thickens with every launcher
	# doubling, fire-rate packing and turret bought.
	var size: float = 3.0 + log(launchers) / log(2.0) * 1.6 + (ceilf(log(packets) / log(2.0)) if packets > 1.0 else 0.0)
	return clampi(int(size), 3, 24)

func flight_time(index: int, from: Vector2, to: Vector2) -> float:
	if bool(sim.catalog.weapons[index].beam):
		return .22
	return maxf(.08, from.distance_to(to) / sim.PROJECTILE_SPEED)

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
	var share: float = 0.0
	var target_id: int = -1
	if not sim.shots.is_empty():
		share = float(sim.shots.back().effective) / count
		target_id = int(sim.shots.back().target)
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
		b_value.append(share)
		b_target.append(target_id)

func on_turret_fired(slot: int, origin: Vector2, destination: Vector2, critical: bool) -> void:
	if slot < turret_flash.size():
		turret_flash[slot] = .12
		turret_aim[slot] = (destination - origin).angle()
	spawn_barrage(0, origin, destination, critical, 1)

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
	# Rounds pop their own small numbers on arrival; whole-hit numbers are kept
	# for the big moments: criticals and boss hits.
	if amount > 0 and (boss or critical) and (number_limits[index] <= 0 or critical) and numbers.size() < NUMBER_CAP:
		if boss:
			# One weapon at a time over the boss, spread across its hull.
			for i in range(6):
				number_limits[i] = maxf(number_limits[i], .18)
		number_limits[index] = .1 if not boss else .18
		var spread: Vector2 = Vector2(randf_range(-90, 90), randf_range(-60, 50)) if boss else Vector2(randf_range(-10, 10), -10)
		add_number(point + spread, amount, critical, boss, 22 if boss else 18)
	if spark_limits[index] > 0:
		return
	spark_limits[index] = .085
	add_feedback("spark", point, index, 16 if critical else 10, .22)

func add_number(pos: Vector2, value: float, critical: bool, boss: bool, size: int) -> void:
	var text: String = sim.Catalog.number(value)
	var key: String = text + "|" + str(size)
	var line: TextLine = line_cache.get(key)
	if line == null:
		if line_cache.size() > 400:
			line_cache.clear()
		line = TextLine.new()
		line.add_string(text, font, size)
		line_cache[key] = line
	numbers.append({"pos": pos, "line": line, "age": 0.0, "color": ACCENT if critical else INK if boss else Color("cfcfcf")})

func count_kills(members: int) -> void:
	combo_events.append(Vector2(clock, members))
	combo += members
	combo_pop = 1.0

func on_members_removed(point: Vector2, index: int, members: int, _kind: String) -> void:
	add_feedback("shards", point, index, 10 + minf(14, log(maxf(1, members)) * 1.2), .5)

func on_pierced(origin: Vector2, destination: Vector2, index: int) -> void:
	if pierce_limits[index] > 0:
		return
	pierce_limits[index] = .14
	add_feedback("pierce", origin, index, 1, .22, destination)

func on_destroyed(point: Vector2, index: int, members: int, boss: bool, _kind: String) -> void:
	if boss and feedback.size() >= 140:
		feedback_pool.append(feedback.pop_front())
	var size: float = 110 if boss else 18 + minf(20, log(maxf(1, members)) * 2)
	add_feedback("boss_death" if boss else "shards", point, index, size, 2.2 if boss else .7)
	add_feedback("flash", point, index, size * (5.0 if boss else 2.6), .9 if boss else .28)
	add_feedback("embers", point, index, size, 1.6 if boss else 1.0)
	add_wave(point, 60.0 if boss else 5.0 + minf(9.0, log(maxf(1, members))), 1.8 if boss else 1.0)
	# Loot flies to the money counter: the visible half of every reward.
	for k in range(3 if boss else (1 if members < 50 else 2)):
		if coins.size() >= COIN_CAP:
			break
		var burst := Vector2.from_angle(randf() * TAU) * randf_range(30, 80)
		coins.append({"from": point, "ctrl": point + burst, "age": -k * .05, "dur": randf_range(.55, .8)})
	# Shake is reserved for big moments; constant hit shake read as stutter.
	if boss:
		trauma = .75
		slowmo_request = true
		punch = 1.0

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
	update_waves(delta)
	if not banner.is_empty():
		banner.age = float(banner.age) + delta
		if float(banner.age) >= float(banner.dur):
			banner = {}
	# The combo reads the sim's own kill counter, so it is always exact.
	if sim != null:
		if kills_seen < 0 or sim.kills < kills_seen:
			kills_seen = sim.kills
		elif sim.kills > kills_seen:
			count_kills(sim.kills - kills_seen)
			kills_seen = sim.kills
	punch = maxf(0, punch - delta * 3.0)
	for key in body_flash.keys():
		body_flash[key] = maxf(0.0, float(body_flash[key]) - delta)
	reticle_pos = reticle_pos.lerp(hover, minf(1.0, delta * 24.0))
	var locked: Dictionary = {}
	if sim != null and show_reticle:
		var best: float = INF
		for e in sim.enemies:
			if bool(e.dead):
				continue
			var d: float = hover.distance_to(e.pos)
			if d < float(e.radius) + 16 and d < best:
				best = d
				locked = e
	if not locked.is_empty():
		lock_pos = lock_pos.lerp(locked.pos, minf(1.0, delta * 30.0)) if reticle_lock > .05 else Vector2(locked.pos)
		lock_radius = lerpf(lock_radius, float(locked.radius), minf(1.0, delta * 20.0))
		lock_priority = int(locked.id) == sim.priority_id
	reticle_lock = move_toward(reticle_lock, 1.0 if not locked.is_empty() else 0.0, delta * 9.0)
	combo_pop = maxf(0, combo_pop - delta * 5.0)
	while not combo_events.is_empty() and clock - combo_events[0].x > 1.5:
		combo -= int(combo_events[0].y)
		combo_events.pop_front()
	var bars_wanted: float = 1.0 if not banner.is_empty() and bool(banner.cinematic) and float(banner.age) < float(banner.dur) - .4 else 0.0
	letterbox = move_toward(letterbox, bars_wanted, delta * 3.5)
	for i in range(DUST):
		dust_radius[i] -= dust_speed[i] * delta * (1.0 + 60.0 / maxf(30.0, dust_radius[i]))
		dust_angle[i] += delta * 26.0 / maxf(30.0, dust_radius[i])
		if dust_radius[i] < 26:
			dust_radius[i] = randf_range(520, 700)
			dust_angle[i] = randf() * TAU
	for j in range(turret_flash.size()):
		turret_flash[j] = maxf(0, turret_flash[j] - delta)
	numbers_this_frame = 0
	for i in range(coins.size() - 1, -1, -1):
		coins[i].age = float(coins[i].age) + delta
		if float(coins[i].age) >= float(coins[i].dur):
			coins.remove_at(i)
			coin_arrivals += 1
	if sim != null and sim.mode != last_mode:
		if sim.mode == "wave":
			show_banner("第 %02d 波" % sim.wave, sim.stage_data().title + "  ·  " + sim.stage_data().scale_label, 1.6)
		elif sim.mode == "boss":
			show_banner(sim.stage_data().boss_title.split(" · ")[0], "巨型威胁接近  ·  " + sim.stage_data().boss_title.split(" · ")[-1], 2.4, true)
		if sim.mode == "intermission":
			show_banner("拦截完成", "防线恢复  ·  下一波即将来袭", 2.6)
			add_feedback("sweep", sim.defense_position(), 0, 900, 1.0)
			add_wave(sim.defense_position(), 22.0, 1.6)
		last_mode = sim.mode
	if glow != null:
		glow.queue_redraw()
	# Rounds whose target died swerve onto the threat the sim retargeted their
	# shot to (it still deals damage there), or fly off-screen if none is left.
	var living: Dictionary = {}
	if sim != null:
		for e in sim.enemies:
			if not bool(e.dead):
				living[int(e.id)] = e
	var alive: int = b_age.size()
	var i: int = 0
	while i < alive:
		b_age[i] += delta
		if b_age[i] >= 0 and b_target[i] >= 0 and not living.has(b_target[i]) and b_age[i] < b_dur[i]:
			redirect_round(i, living)
		if b_age[i] >= b_dur[i]:
			if b_value[i] >= 1.0 and numbers.size() < NUMBER_CAP and numbers_this_frame < 10:
				numbers_this_frame += 1
				add_number(b_to[i] + Vector2(randf_range(-22, 22), randf_range(-14, 6)), b_value[i], b_crit[i] & 1 == 1, false, 11)
			# Swap-remove: draw order of rounds does not matter.
			alive -= 1
			b_from[i] = b_from[alive]
			b_ctrl[i] = b_ctrl[alive]
			b_to[i] = b_to[alive]
			b_age[i] = b_age[alive]
			b_dur[i] = b_dur[alive]
			b_style[i] = b_style[alive]
			b_crit[i] = b_crit[alive]
			b_value[i] = b_value[alive]
			b_target[i] = b_target[alive]
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
		b_value.resize(alive)
		b_target.resize(alive)

func on_retargeted(old_target: int, new_target: int) -> void:
	if redirects.size() > 400:
		redirects.clear()
	redirects[old_target] = new_target

func redirect_round(i: int, living: Dictionary) -> void:
	var t: float = clampf(b_age[i] / b_dur[i], 0, 1)
	var u: float = maxf(0, t - .03)
	var f: Vector2 = b_from[i]
	var c: Vector2 = b_ctrl[i]
	var to: Vector2 = b_to[i]
	var pos: Vector2 = f.lerp(c, t).lerp(c.lerp(to, t), t)
	var near: Vector2 = f.lerp(c, u).lerp(c.lerp(to, u), u)
	var dir: Vector2 = (pos - near).normalized() if pos.distance_to(near) > .001 else (to - f).normalized()
	# Follow the sim's own choice so the round lands where the damage does.
	var best: Dictionary = {}
	var nearest: float = INF
	var followed: int = int(redirects.get(b_target[i], -1))
	if living.has(followed):
		best = living[followed]
		nearest = pos.distance_to(best.pos)
	else:
		for e in living.values():
			var d: float = pos.distance_to(e.pos)
			if d < nearest:
				nearest = d
				best = e
	var goal: Vector2
	if best.is_empty():
		goal = pos + dir * 1400.0
		b_target[i] = -1
	else:
		var travel: float = maxf(.08, nearest / sim.PROJECTILE_SPEED)
		var velocity: Vector2 = (Vector2(best.end) - Vector2(best.start)) / maxf(.01, float(best.lifetime))
		goal = Vector2(best.pos) + velocity * travel
		b_target[i] = int(best.id)
	var span: float = pos.distance_to(goal)
	b_from[i] = pos
	# Control point at half the span keeps the launch speed equal to the average
	# speed, so a swerving round never visibly slows down.
	b_ctrl[i] = pos + dir * span * .5
	b_crit[i] = b_crit[i] | 2
	b_to[i] = goal
	b_age[i] = 0.0
	b_dur[i] = maxf(.08, span / sim.PROJECTILE_SPEED)
	if best.is_empty():
		b_value[i] = 0.0

func reset_growth() -> void:
	prev_levels = {}
	growth.clear()
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
	for i in range(growth.size() - 1, -1, -1):
		var before: float = float(growth[i].age)
		growth[i].age = before + delta
		if before < 0 and float(growth[i].age) >= 0:
			growth_bounce = 1.0
			add_wave(sim.defense_position(), 12.0, 1.0)
			core_pulse = 1.0
		if float(growth[i].age) > 1.6:
			growth.remove_at(i)
	for i in range(6):
		if dock_age[i] >= 0:
			dock_age[i] += delta
			if dock_age[i] >= .9:
				dock_age[i] = -1
				add_feedback("shards", sim.weapon_origin(i), i, 26, .6)
				add_wave(sim.weapon_origin(i), 24.0, 1.2)
				trauma = minf(.5, trauma + .2)
				punch = maxf(punch, .5)

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
		var f: Vector2 = b_from[i]
		var c: Vector2 = b_ctrl[i]
		var to: Vector2 = b_to[i]
		var u: float = maxf(0, t - .03)
		var pos: Vector2 = f.lerp(c, t).lerp(c.lerp(to, t), t)
		var near: Vector2 = f.lerp(c, u).lerp(c.lerp(to, u), u)
		if style == 2:
			var side: Vector2 = (to - f).orthogonal().normalized()
			# Wobble only mid-flight so the round still lands on target.
			pos += side * sin(t * 22 + age) * 5 * sin(t * PI)
			near += side * sin(u * 22 + age) * 5 * sin(u * PI)
		var dir: Vector2 = (pos - near).normalized()
		# Fixed-length tracer that grows out of the muzzle: a glowing pellet,
		# not a hair-thin line spanning half the screen.
		# Fresh rounds grow their tracer out of the muzzle; swerved ones (flag 2) keep it.
		var grow: float = 1.0 if b_crit[i] & 2 else minf(1.0, t * 8.0)
		var back: Vector2 = pos - dir * (22.0 if style == 1 else 14.0) * grow
		var crit: bool = b_crit[i] & 1 == 1
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
	glow_trails = trails
	glow_heads = heads
	if trails.size() > 1:
		draw_multiline(trails, Color(INK, .45), 1.4)
	if hot.size() > 1:
		draw_multiline(hot, Color(ACCENT, .75), 1.6)
	if heads.size() > 1:
		draw_multiline(heads, INK, 3.0)

func coin_position(c: Dictionary) -> Vector2:
	var t: float = clampf(float(c.age) / float(c.dur), 0, 1)
	var e: float = t * t
	var from: Vector2 = c.from
	var ctrl: Vector2 = c.ctrl
	return from.lerp(ctrl, e).lerp(ctrl.lerp(money_anchor, e), e)

func show_banner(title: String, subtitle: String, duration: float, cinematic: bool = false) -> void:
	banner = {"title": banner_line(title, 46), "subtitle": banner_line(subtitle, 15), "age": 0.0, "dur": duration, "cinematic": cinematic}

func banner_line(text: String, size: int) -> TextLine:
	var key: String = text + "|" + str(size)
	if not banner_cache.has(key):
		if banner_cache.size() > 40:
			banner_cache.clear()
		var line := TextLine.new()
		line.add_string(text, font, size)
		banner_cache[key] = line
	return banner_cache[key]

func ease_out_back(t: float) -> float:
	var c: float = 1.70158
	return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)

func on_click(point: Vector2) -> void:
	add_feedback("click", point, 0, 26, .42)
	add_wave(point, 9.0, .8)

func draw_reticle() -> void:
	if not show_reticle:
		return
	var k: float = smoothstep(0.0, 1.0, reticle_lock)
	var center: Vector2 = reticle_pos.lerp(lock_pos, k)
	var radius: float = lerpf(13.0, lock_radius + 12.0, k)
	var col: Color = (ACCENT if lock_priority else INK).lerp(INK, 1.0 - k) if k > 0 else INK
	var spin: float = clock * 1.4 * (1.0 - k)
	for j in range(4):
		var a: float = spin + PI * .25 + j * PI * .5
		draw_arc(center, radius, a - .32, a + .32, 8, col, 2.0, true)
	draw_circle(reticle_pos, 2.0, INK)
	if k > .5:
		for j in range(4):
			var dir := Vector2.from_angle(j * PI * .5)
			draw_line(center + dir * (radius + 3), center + dir * (radius + 9), Color(col, k), 1.5, true)

func draw_staging() -> void:
	if combo >= 10:
		if combo != combo_shown:
			combo_line = TextLine.new()
			combo_line.add_string("连击 ×" + sim.Catalog.number(combo), font, 26)
			combo_shown = combo
		var hot: bool = combo >= 100
		var scale: float = 1.0 + combo_pop * (.25 if hot else .12)
		var anchor := Vector2(1120, 30)
		var size: Vector2 = combo_line.get_size()
		draw_set_transform(anchor, 0, Vector2.ONE * scale)
		combo_line.draw_outline(get_canvas_item(), Vector2(-size.x, -size.y * .5), 6, Color(BG, .9))
		combo_line.draw(get_canvas_item(), Vector2(-size.x, -size.y * .5), ACCENT if hot else INK)
		draw_set_transform(Vector2.ZERO)
	# Cinematic bars for the boss entrance.
	if letterbox > 0:
		var h: float = 52 * smoothstep(0.0, 1.0, letterbox)
		draw_rect(Rect2(-150, -20, 1300, h), Color(BG, .96))
		draw_rect(Rect2(-150, 640 - h, 1300, h), Color(BG, .96))
	if banner.is_empty():
		return
	var age: float = banner.age
	var dur: float = banner.dur
	var enter: float = clampf(age / .3, 0, 1)
	var leave: float = clampf((age - (dur - .4)) / .4, 0, 1)
	var alpha: float = smoothstep(0.0, 1.0, enter) * (1 - leave)
	var title: TextLine = banner.title
	var subtitle: TextLine = banner.subtitle
	var center := Vector2(500, 210)
	var grow: float = 1.12 - .12 * ease_out_back(enter)
	var rise: float = (1 - smoothstep(0.0, 1.0, enter)) * 26 - leave * 18
	draw_set_transform(center + Vector2(0, rise), 0, Vector2.ONE * grow)
	var size: Vector2 = title.get_size()
	title.draw_outline(get_canvas_item(), -size * .5, 8, Color(BG, .9 * alpha))
	title.draw(get_canvas_item(), -size * .5, Color(INK, alpha))
	draw_set_transform(Vector2.ZERO)
	var span: float = 240 * smoothstep(0.0, 1.0, clampf((age - .1) / .45, 0, 1))
	var line_y: float = center.y + rise + size.y * .5 + 10
	draw_line(Vector2(center.x - span, line_y), Vector2(center.x - 20, line_y), Color(GREY, .7 * alpha), 1.2, true)
	draw_line(Vector2(center.x + 20, line_y), Vector2(center.x + span, line_y), Color(GREY, .7 * alpha), 1.2, true)
	var sub_size: Vector2 = subtitle.get_size()
	subtitle.draw(get_canvas_item(), Vector2(center.x - sub_size.x * .5, line_y + 8), Color(ACCENT if bool(banner.cinematic) else GREY, alpha))

func draw_glow() -> void:
	# Everything here is additive: overlaps brighten instead of covering.
	if sim == null or sim.mode == "transition" or reduced_effects:
		return
	if glow_trails.size() > 1:
		glow.draw_multiline(glow_trails, Color(.55, .55, .55, .07), 6.0)
	# Every round's head carries a soft light; dense fire becomes a rain of light.
	for j in range(0, glow_heads.size(), 4):
		var head: Vector2 = glow_heads[j]
		glow.draw_texture_rect(GlowTexture, Rect2(head - Vector2.ONE * 7, Vector2.ONE * 14), false, Color(1, 1, 1, .32))
	if glow_heads.size() > 1:
		glow.draw_multiline(glow_heads, Color(.8, .8, .8, .18), 7.0)
	var core_at: Vector2 = sim.defense_position()
	var halo: float = core_outer * (2.2 + core_pulse * .6)
	glow.draw_texture_rect(GlowTexture, Rect2(core_at - Vector2.ONE * halo, Vector2.ONE * halo * 2), false, Color(1, 1, 1, .16 + core_pulse * .12))
	for fx in feedback:
		var t: float = float(fx.age) / float(fx.duration)
		var p: Vector2 = fx.pos
		var r: float = float(fx.size)
		match str(fx.kind):
			"flash":
				var size: float = r * (.6 + t * .8)
				glow.draw_texture_rect(GlowTexture, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2), false, Color(1, 1, 1, (1 - t) * (1 - t) * .9))
				# Shockwave: a bright ring that thins as it races outward.
				var shock: float = r * .45 * (1 - pow(1 - t, 2.5))
				glow.draw_arc(p, shock, 0, TAU, 40, Color(1, 1, 1, (1 - t) * .55), 1 + 6 * (1 - t), true)
			"embers":
				for j in range(9):
					var a: float = j * 2.399 + int(fx.seed) * .7
					var drift: Vector2 = Vector2(cos(a), sin(a)) * r * (.5 + t * (.6 + (j % 3) * .25)) + Vector2(0, t * t * 16)
					var size: float = (5.0 - (j % 3)) * (1 - t)
					glow.draw_texture_rect(GlowTexture, Rect2(p + drift - Vector2.ONE * size, Vector2.ONE * size * 2), false, Color(1, .92, .8, (1 - t) * (1 - t) * .7))
			"convert":
				var bloom: float = clampf((t - .45) / .55, 0, 1)
				if bloom > 0:
					var size: float = r * 3 + bloom * r * 6 + 40
					glow.draw_texture_rect(GlowTexture, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2), false, Color(1, .92, .7, (1 - bloom) * .9))
			"muzzle":
				glow.draw_texture_rect(GlowTexture, Rect2(p - Vector2.ONE * r * 2.4, Vector2.ONE * r * 4.8), false, Color(1, 1, 1, (1 - t) * .5))
			"spark", "critical":
				var col: Color = Color(ACCENT, (1 - t) * .8) if fx.kind == "critical" else Color(1, 1, 1, (1 - t) * .45)
				glow.draw_texture_rect(GlowTexture, Rect2(p - Vector2.ONE * r * 1.6, Vector2.ONE * r * 3.2), false, col)
			"beam":
				glow.draw_line(p, fx.end, Color(1, 1, 1, (1 - t) * .25), r * 9, true)
			"sweep":
				var radius: float = r * (1 - pow(1 - t, 3))
				glow.draw_arc(p, radius, 0, TAU, 128, Color(1, 1, 1, (1 - t) * .35), 10.0 * (1 - t) + 2, true)
	for c in coins:
		if float(c.age) < 0:
			continue
		var q: Vector2 = coin_position(c)
		glow.draw_texture_rect(GlowTexture, Rect2(q - Vector2.ONE * 9, Vector2.ONE * 18), false, Color(1, 1, 1, .5))
	for i in range(DUST):
		var r: float = dust_radius[i]
		var spot: Vector2 = core_at + Vector2.from_angle(dust_angle[i]) * r
		var near: float = clampf(1.0 - r / 600.0, 0, 1)
		var size: float = 2.5 + near * 2.5
		glow.draw_texture_rect(GlowTexture, Rect2(spot - Vector2.ONE * size, Vector2.ONE * size * 2), false, Color(1, 1, 1, .1 + near * .25))

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
			"convert":
				if t < .5:
					var k: float = t / .5
					for j in range(3):
						var gather: float = (1 - pow(k, 1.6)) * (90 + j * 26) + r
						ring(p, gather, Color(ACCENT if j == 0 else INK, k * .9), 1.4)
				else:
					var k: float = (t - .5) / .5
					ring(p, r + 10 + k * 120, Color(INK, (1 - k) * .8), 1.4)
			"click":
				var ease: float = 1 - pow(1 - t, 3)
				ring(p, r * (.3 + ease), Color(INK, fade * .8), 1.4)
				for j in range(6):
					var dir := Vector2.from_angle(j * TAU / 6 + .3)
					stroke(p + dir * r * (.4 + ease * .7), p + dir * r * (.6 + ease * .9), Color(INK, fade))
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
					# Shards fly at different speeds with a short motion trail.
					var lag: float = 1 - pow(1 - maxf(0, t - .08), 3)
					for j in range(28 if boss else 11):
						var a: float = j * 2.399 + seed_value
						var dir := Vector2(cos(a), sin(a))
						var reach: float = r * (.6 + (j % 5) * .32)
						var q: Vector2 = p + dir * reach * travel
						var size: float = (6.0 if boss else 3.4) * (1 - t * .8) + .6
						stroke(p + dir * reach * lag, q, Color(INK, fade * .45), 1.0)
						shape(q, size, 3, a + t * 11, Color(INK if j % 3 else GREY, fade))

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
			if index != sim.stage or sim.mode == "transition":
				draw_circle(c + Vector2(247, -33), 9, DARK)
			ink("地球", c + Vector2(-15, 106), DIM, 13)
		2:
			for i in range(5):
				ring(c, 70 + i * 55, DARK)
				if index != sim.stage or sim.mode == "transition":
					var a: float = i * 1.72 + .2
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

func body_at(point: Vector2) -> int:
	# The unconverted body of the current scale under the cursor, or -1.
	if sim == null or sim.mode in ["title", "transition", "victory"]:
		return -1
	var best: int = -1
	var nearest: float = INF
	for k in range(sim.BODIES[sim.stage].size()):
		if sim.body_converted_at(sim.stage, k):
			continue
		var d: float = point.distance_to(sim.body_position(sim.stage, k))
		if d < float(sim.BODIES[sim.stage][k].size) + 16.0 and d < nearest:
			nearest = d
			best = k
	return best

func on_body_fired(body_stage: int, slot: int, origin: Vector2, destination: Vector2, critical: bool) -> void:
	body_flash[body_stage * 16 + slot] = .14
	spawn_barrage(mini(body_stage, 5), origin, destination, critical, 4)
	if body_stage == sim.stage:
		add_feedback("muzzle", origin, mini(body_stage, 5), 10, .14)

func on_body_converted(body_stage: int, slot: int) -> void:
	var at: Vector2 = sim.body_position(body_stage, slot)
	var size: float = float(sim.BODIES[body_stage][slot].size)
	add_feedback("convert", at, 0, size, 1.1)
	add_wave(at, 34.0, 1.6)
	punch = maxf(punch, .7)
	trauma = minf(.55, trauma + .25)
	show_banner(str(sim.BODIES[body_stage][slot].weapon) + "上线", str(sim.BODIES[body_stage][slot].name) + "  ·  天体改造完成", 1.9)

func draw_bodies() -> void:
	if sim.mode == "transition":
		return
	var stage_now: int = sim.stage
	body_hover = body_at(hover)
	for s in range(stage_now + 1):
		for k in range(sim.BODIES[s].size()):
			var converted: bool = sim.body_converted_at(s, k)
			if s < stage_now and not converted:
				continue
			var at: Vector2 = sim.body_position(s, k)
			var size: float = float(sim.BODIES[s][k].size) if s == stage_now else 5.0
			var lit: float = clampf(float(body_flash.get(s * 16 + k, 0.0)) / .14, 0, 1)
			if s == stage_now:
				# The body itself: rooftops are blocks, everything else a flat disc.
				if s == 0:
					draw_rect(Rect2(at - Vector2(size, size * .5), Vector2(size * 2, size)), Color("2a2a2a"))
				elif not (s == 2 and k == 5) and s != 4 and s != 5:
					draw_circle(at, size, Color("2c2c2c").lerp(GREY, .25 if converted else 0.0))
			if converted:
				var spin: float = clock * (.9 if k % 2 == 0 else -.7)
				var ring_size: float = size + (7.0 if s == stage_now else 3.0) + lit * 3.0
				shape(at, ring_size, 6, spin, Color(0, 0, 0, 0), INK.lerp(Color.WHITE, lit), 1.6 if s == stage_now else 1.2)
				var aim: Vector2 = (last_target - at).normalized()
				draw_line(at + aim * ring_size, at + aim * (ring_size + 7 + lit * 3), INK, 2.0, true)
				if s == stage_now and (s == 2 and k == 5):
					# Dyson sphere: a second counter-rotating lattice round the sun.
					shape(at, size + 16, 12, -clock * .3, Color(0, 0, 0, 0), Color(ACCENT, .7), 1.4)
			elif s == stage_now:
				var hovered: bool = k == body_hover
				var dash_r: float = size + 9 + sin(clock * 3 + k) * 1.5
				for j in range(0, 16, 2):
					var a0: float = clock * .4 + j * TAU / 16
					draw_arc(at, dash_r, a0, a0 + TAU / 16, 4, Color(ACCENT if hovered else GREY, .9 if hovered else .45), 1.4, true)
				if hovered:
					ink("改造 " + str(sim.BODIES[s][k].name) + "  $" + sim.Catalog.number(sim.body_cost()), at + Vector2(-40, -dash_r - 10), ACCENT, 12)

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
	var lead_ratio: float = clampf((float(e.age) + render_lead) / float(e.lifetime), 0.0, 1.0)
	var p: Vector2 = Vector2(e.start).lerp(e.end, lead_ratio) if not sim.paused else Vector2(e.pos)
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
		# Hit: squashed along the flight line and bulging sideways; newborn
		# threats are stretched along it, carrying their entry speed.
		var young: float = clampf(1.0 - float(e.age) / .4, 0, 1)
		var along: float = 1.0 - .26 * flash + .55 * young
		var across: float = 1.0 + .22 * flash - .2 * young
		if bool(e.elite):
			shape(p, size * 1.15, 6 if ship else 8, spin * .5, Color(0, 0, 0, 0), INK, 1.5)
			shape_squash(p, size * .7, 3 if ship else 4, heading if ship else spin, fill, along, across, heading)
		elif ship:
			shape_squash(p, size, 3, heading, fill, along, across, heading)
		else:
			shape_squash(p, size, 4, spin, fill, along, across, heading)
		if int(e.members) > 1:
			var companions: int = 5 if not dense else 2 if focused or danger > .8 else 0
			for j in range(mini(companions, int(e.members) - 1)):
				var a: float = j * TAU / 5 + clock * .9 + int(e.seed)
				var q: Vector2 = p + Vector2(cos(a), sin(a)) * radius * 1.45 * appear
				shape(q, 2.6 * appear, 3 if ship else 4, a, Color(fill, fill.a * .8))
			if labels_left > 0 or focused:
				ink("×" + sim.Catalog.number(e.members), p + Vector2(-14, radius + 18), DIM, 11)
				labels_left -= 1
	var born: float = float(e.age)
	if not boss and born < .3:
		# Warp-in: a streak of light behind a threat that just dropped in.
		var fade: float = 1.0 - born / .3
		stroke(p, p + trail * radius * (4.0 + 14.0 * fade), Color(INK, .55 * fade))
	if not boss and born < .35:
		ring(p, radius * (1.0 + born * 5.0), Color(INK, (1 - born / .35) * .6))
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
		for i in range(6):
			if sim.owned[i]:
				weapon(i, sim.weapon_origin(i), idx > 0 and i < idx)
		draw_bodies()
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
	begin_batch()
	for c in coins:
		if float(c.age) >= 0:
			shape(coin_position(c), 3.2, 4, clock * 6, INK)
	flush_batch()
	if sim.mode != "transition":
		draw_staging()
	inspector()
	draw_reticle()
	draw_ms = (Time.get_ticks_usec() - started) / 1000.0
