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
var shell_bursts: int = 0
# Turret rounds: crisp grey needles, the ring's own signature.
const TURRET_STYLE: int = 6
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
const BODY_KICK_TIME: float = .28
const BODY_BUILD_TIME: float = 1.15
var body_build: Dictionary = {}
var body_aim: Dictionary = {}
var body_hover: int = -1
# Where the sim sent rounds whose target died (old id -> new id).
var redirects: Dictionary = {}
var banner_wave: String = ""
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
var b_paths: Array[PackedFloat32Array] = []
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
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	font = load("res://assets/fonts/SkyguardSC.ttf") if OS.has_feature("web") else system_font
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

func flight_time(_index: int, from: Vector2, to: Vector2) -> float:
	return maxf(.001, from.distance_to(to) / sim.PROJECTILE_SPEED)

func curve_lengths(from: Vector2, control: Vector2, to: Vector2) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0])
	var previous: Vector2 = from
	for j in range(1, 33):
		var t: float = j / 32.0
		var p: Vector2 = from.lerp(control, t).lerp(control.lerp(to, t), t)
		result.append(result[-1] + previous.distance_to(p))
		previous = p
	return result

func round_parameter(i: int, progress: float) -> float:
	var lengths: PackedFloat32Array = b_paths[i]
	var distance: float = clampf(progress, 0, 1) * lengths[-1]
	var lo: int = 0
	var hi: int = lengths.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if lengths[mid] < distance:
			lo = mid
		else:
			hi = mid
	return (lo + (distance - lengths[lo]) / maxf(.0001, lengths[hi] - lengths[lo])) / 32.0

func round_position(i: int, progress: float) -> Vector2:
	var t: float = round_parameter(i, progress)
	return b_from[i].lerp(b_ctrl[i], t).lerp(b_ctrl[i].lerp(b_to[i], t), t)

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
		var from: Vector2 = point
		var travel: float = flight_time(index, from, destination)
		# Tight volley: rounds leave close together, so successive volleys stay apart.
		var delay: float = j * .006
		var to: Vector2 = destination + velocity * (travel + delay) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var span: Vector2 = to - from
		# The initial tangent is the gun's firing axis, including predictive lead.
		var ctrl: Vector2 = from + (destination - point).normalized() * span.length() * .5
		var path: PackedFloat32Array = curve_lengths(from, ctrl, to)
		for prediction in range(3):
			travel = maxf(.001, path[-1] / sim.PROJECTILE_SPEED)
			to = destination + velocity * (travel + delay)
			ctrl = from + (destination - point).normalized() * from.distance_to(to) * .5
			path = curve_lengths(from, ctrl, to)
		travel = maxf(.001, path[-1] / sim.PROJECTILE_SPEED)
		b_from.append(from)
		b_ctrl.append(ctrl)
		b_to.append(to)
		b_age.append(-delay)
		b_dur.append(travel)
		b_style.append(index)
		b_crit.append(1 if critical else 0)
		b_value.append(share)
		b_target.append(target_id)
		b_paths.append(path)

func on_turret_fired(slot: int, origin: Vector2, destination: Vector2, critical: bool) -> void:
	ensure_turret_visuals()
	if slot < turret_flash.size():
		turret_flash[slot] = .12
		turret_aim[slot] = (destination - origin).angle()
	var direction: Vector2 = (destination - origin).normalized()
	var radius: float = 5.8 * (1.4 if sim.stage == 0 else 1.0) * (1.0 + core_pulse * .08 + growth_bounce * .22)
	spawn_barrage(TURRET_STYLE, origin + direction * (radius + 3), destination, critical, 1)

func on_fire(index: int, point: Vector2, destination: Vector2, critical: bool) -> void:
	last_target = destination
	recoil[index] = 1.0
	aims[index] = (destination - point).angle()
	var scale: float = .7 if sim.stage > 0 and index < sim.stage else 1.0
	var muzzle: Vector2 = point + Vector2.from_angle(aims[index]) * ((17 + index * 1.2) * scale - (3 + index))
	spawn_barrage(index, muzzle, destination, critical)
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
	animate_ultimates(delta)
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
	# Waves roll into each other now, so a short banner marks each new wave.
	if sim != null and sim.mode == "wave":
		var key: String = "%d-%d" % [sim.stage, sim.wave]
		if key != banner_wave:
			banner_wave = key
			show_banner("第 %02d 波" % sim.wave, sim.stage_data().title + "  ·  " + sim.stage_data().scale_label, 1.3)
	punch = maxf(0, punch - delta * 3.0)
	for key in body_flash.keys():
		body_flash[key] = maxf(0.0, float(body_flash[key]) - delta)
	for key in body_build.keys():
		body_build[key] = maxf(0.0, float(body_build[key]) - delta)
		if body_build[key] <= 0.0:
			body_build.erase(key)
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
		# The boss entrance is staged by the HUD cinematic.
		if sim.mode == "intermission":
			show_banner("第 10 波完成", "巨型威胁即将降临", 2.6)
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
			b_paths[i] = b_paths[alive]
		else:
			i += 1
	if alive != b_age.size():
		b_from.resize(alive)
		b_ctrl.resize(alive)
		b_to.resize(alive)
		b_age.resize(alive)
		b_dur.resize(alive)
		b_style.resize(alive)
		b_paths.resize(alive)
		b_crit.resize(alive)
		b_value.resize(alive)
		b_target.resize(alive)

func on_retargeted(old_target: int, new_target: int) -> void:
	if redirects.size() > 400:
		redirects.clear()
	redirects[old_target] = new_target

func on_focused(target_id: int) -> void:
	# Focus fire: every round on screen swerves onto the chosen threat.
	var target: Dictionary = sim.find_enemy(target_id)
	if target.is_empty():
		return
	for i in range(b_age.size()):
		if b_target[i] != target_id and b_age[i] < b_dur[i]:
			swerve(i, target)
	add_feedback("focus", target.pos, 0, float(target.radius), .55)
	add_wave(target.pos, 14.0, .9)
	punch = maxf(punch, .35)

func swerve(i: int, best: Dictionary) -> void:
	var t: float = clampf(b_age[i] / b_dur[i], 0, 1) if b_age[i] > 0 else 0.0
	var u: float = maxf(0, t - .03)
	var to: Vector2 = b_to[i]
	var f: Vector2 = b_from[i]
	var pos: Vector2 = round_position(i, t)
	var near: Vector2 = round_position(i, u)
	var dir: Vector2 = (pos - near).normalized() if pos.distance_to(near) > .001 else (to - f).normalized()
	var travel: float = maxf(.08, pos.distance_to(best.pos) / sim.PROJECTILE_SPEED)
	var velocity: Vector2 = (Vector2(best.end) - Vector2(best.start)) / maxf(.01, float(best.lifetime))
	var goal: Vector2 = Vector2(best.pos) + velocity * travel
	var span: float = pos.distance_to(goal)
	b_from[i] = pos
	b_ctrl[i] = pos + dir * span * .5
	b_to[i] = goal
	b_age[i] = minf(0.0, b_age[i])
	b_paths[i] = curve_lengths(b_from[i], b_ctrl[i], b_to[i])
	b_dur[i] = maxf(.001, b_paths[i][-1] / sim.PROJECTILE_SPEED)
	b_target[i] = int(best.id)
	b_crit[i] = b_crit[i] | 2

func redirect_round(i: int, living: Dictionary) -> void:
	var t: float = clampf(b_age[i] / b_dur[i], 0, 1)
	var u: float = maxf(0, t - .03)
	var to: Vector2 = b_to[i]
	var f: Vector2 = b_from[i]
	var pos: Vector2 = round_position(i, t)
	var near: Vector2 = round_position(i, u)
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
	# Preserve the incoming tangent; arc-length timing preserves travel speed.
	b_ctrl[i] = pos + dir * span * .5
	b_crit[i] = b_crit[i] | 2
	b_to[i] = goal
	b_age[i] = 0.0
	b_paths[i] = curve_lengths(b_from[i], b_ctrl[i], b_to[i])
	b_dur[i] = maxf(.001, b_paths[i][-1] / sim.PROJECTILE_SPEED)
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
	var needles := PackedVector2Array()
	for i in range(b_age.size()):
		var age: float = b_age[i]
		if age < 0:
			continue
		var t: float = age / b_dur[i]
		var style: int = b_style[i]
		var u: float = maxf(0, t - .03)
		var pos: Vector2 = round_position(i, t)
		var near: Vector2 = round_position(i, u)
		var dir: Vector2 = (pos - near).normalized()
		# Fixed-length tracer that grows out of the muzzle: a glowing pellet,
		# not a hair-thin line spanning half the screen.
		# Fresh rounds grow their tracer out of the muzzle; swerved ones (flag 2) keep it.
		var grow: float = 1.0 if b_crit[i] & 2 else minf(1.0, t * 8.0)
		var back: Vector2 = pos - dir * (22.0 if style == 1 else 14.0) * grow
		var crit: bool = b_crit[i] & 1 == 1
		if style == TURRET_STYLE:
			if crit:
				hot.append(pos - dir * 10.0 * grow)
				hot.append(pos)
			else:
				needles.append(pos - dir * 10.0 * grow)
				needles.append(pos)
			continue
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
	if needles.size() > 1:
		draw_multiline(needles, Color(GREY, .95), 1.3)

func coin_position(c: Dictionary) -> Vector2:
	var t: float = clampf(float(c.age) / float(c.dur), 0, 1)
	var e: float = t * t
	var from: Vector2 = c.from
	var ctrl: Vector2 = c.ctrl
	return from.lerp(ctrl, e).lerp(ctrl.lerp(money_anchor, e), e)

func show_banner(title: String, subtitle: String, duration: float, cinematic: bool = false) -> void:
	banner = {"title": banner_line(title, 46), "subtitle": banner_line(subtitle, 15), "age": 0.0, "dur": duration, "cinematic": cinematic, "text": title}

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
	var size: Vector2 = title.get_size()
	# Glyphs rise into place one after another, each with a slight overshoot.
	var text: String = str(banner.get("text", ""))
	var gx: float = center.x - size.x * .5
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		var k: float = clampf((age - i * .045) / .4, 0, 1)
		var e: float = ease_out_back(k)
		var a: float = smoothstep(0.0, 1.0, k) * (1 - leave)
		var lift: float = (1.0 - e) * 22.0 - leave * 18.0
		var at := Vector2(gx, center.y + size.y * .3 + lift)
		draw_string_outline(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, 8, Color(BG, .9 * a))
		draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(INK, a))
		gx += cw
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
			"burst":
				var size: float = r * (.5 + t * .7)
				glow.draw_texture_rect(GlowTexture, Rect2(p - Vector2.ONE * size, Vector2.ONE * size * 2), false, Color(1, 1, 1, (1 - t) * (1 - t) * .35))
			"sweep":
				var radius: float = r * (1 - pow(1 - t, 3))
				glow.draw_arc(p, radius, 0, TAU, 128, Color(1, 1, 1, (1 - t) * .35), 10.0 * (1 - t) + 2, true)
	for c in coins:
		if float(c.age) < 0:
			continue
		var q: Vector2 = coin_position(c)
		glow.draw_texture_rect(GlowTexture, Rect2(q - Vector2.ONE * 9, Vector2.ONE * 18), false, Color(1, 1, 1, .5))
	# Converted bodies glow, brighter on each shot: they should read as trophies.
	if sim.mode != "transition":
		for s in range(sim.stage + 1):
			for k in range(sim.BODIES[s].size()):
				if not sim.body_converted_at(s, k):
					continue
				var at: Vector2 = sim.body_position(s, k)
				var lit: float = pow(clampf(float(body_flash.get(s * 16 + k, 0.0)) / BODY_KICK_TIME, 0, 1), 3.0)
				var body_halo: float = (float(sim.BODIES[s][k].size) * 3.2 + 26.0) * (1.0 if s == sim.stage else .4)
				glow.draw_texture_rect(GlowTexture, Rect2(at - Vector2.ONE * body_halo, Vector2.ONE * body_halo * 2), false, Color(1, 1, 1, .18 + lit * .35))
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
			"burst":
				var reach: float = r * (1 - pow(1 - t, 3))
				var col: Color = ACCENT if int(fx.weapon) == 1 else INK
				ring(p, reach, Color(col, fade * .85), 1.0 + 2.0 * (1 - t))
				if t < .35:
					draw_circle(p, r * .35 * (1 - t / .35), Color(col, .5 * (1 - t / .35)))
				for j in range(8):
					var a: float = j * TAU / 8 + seed_value
					stroke(p + Vector2.from_angle(a) * reach * .8, p + Vector2.from_angle(a) * reach, Color(col, fade * .6), 1.2)
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
			"focus":
				# Lock lines from the core and every gun to the focused threat.
				var reach: float = 1 - pow(1 - minf(1.0, t * 3.0), 2)
				var origins: Array[Vector2] = [sim.defense_position()]
				for w in range(6):
					if sim.owned[w]:
						origins.append(sim.weapon_origin(w))
				for o in origins:
					stroke(o, o.lerp(p, reach), Color(ACCENT, fade * .55), 1.2)
				ring(p, r + 14 + (1 - fade) * 26, Color(ACCENT, fade), 1.6)
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
	ensure_turret_visuals()
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
		var aim: float = turret_aim[j]
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

func ensure_turret_visuals() -> void:
	var previous: int = turret_aim.size()
	var count: int = sim.turret_count()
	turret_flash.resize(count)
	turret_aim.resize(count)
	for j in range(previous, count):
		turret_aim[j] = -PI * .5

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
	var key: int = body_stage * 16 + slot
	body_flash[key] = BODY_KICK_TIME
	body_aim[key] = (destination - origin).angle()
	var style: int = int(sim.BODIES[body_stage][slot].get("style", mini(body_stage, 5)))
	var radius: float = (float(sim.BODIES[body_stage][slot].size) + 7.0) * 1.5 if body_stage == sim.stage else 6.0
	var build_t: float = 1.0 - float(body_build.get(key, 0.0)) / BODY_BUILD_TIME
	if not reduced_effects:
		radius *= 1.0 + sin(build_t * PI * 3.0) * pow(1.0 - build_t, 2.0) * .15
	var muzzle: Vector2 = origin + (destination - origin).normalized() * (radius + 7)
	add_feedback("muzzle", muzzle, style, 7.0 if body_stage == sim.stage else 4.0, .18)

const SHELL_SIDES: Dictionary = {"twin": 4, "pods": 3, "panels": 4, "dish": 4, "tri": 3, "penta": 5, "octa": 8, "dyson": 6, "node": 6}

func draw_shells() -> void:
	# Celestial cannons fire heavy shells shaped like their own silhouette, slow
	# and bright, trailing ghosts — never confused with the turret or arsenal rounds.
	for p in sim.shots:
		if not p.has("body") or p.has("swarm"):
			continue
		var bs: int = int(p.get("body_stage", 0))
		var slot: int = int(p.body)
		if bs >= sim.BODIES.size() or slot >= sim.BODIES[bs].size():
			continue
		var form: String = str(sim.BODIES[bs][slot].get("form", "node"))
		var at: Vector2 = p.pos
		var dir: Vector2 = (Vector2(p.end) - Vector2(p.from)).normalized()
		var col: Color = ACCENT if bool(p.crit) else INK
		var r: float = 6.5 if bs == sim.stage else 5.0
		var spin: float = clock * 5.0 + slot
		for g in range(4, 0, -1):
			var ghost: Vector2 = at - dir * g * (r * 1.5)
			shell_shape(form, ghost, r * (1.0 - g * .15), spin - g * .35, Color(col, .32 - g * .06), 1.0)
		shell_shape(form, at, r, spin, col, 1.7)

func shell_shape(form: String, at: Vector2, r: float, spin: float, col: Color, w: float) -> void:
	var none := Color(0, 0, 0, 0)
	if SHELL_SIDES.has(form):
		shape(at, r, int(SHELL_SIDES[form]), spin, none, col, w)
		if form == "dyson":
			ring(at, r * 1.6, Color(col, col.a * .6))
		return
	match form:
		"crescent":
			draw_arc(at, r, spin, spin + TAU * .7, 12, col, w * 1.6, true)
		"ringed":
			draw_circle(at, r * .55, col)
			draw_arc(at, r * 1.3, spin, spin + TAU * .8, 14, col, w * .8, true)
		"hole":
			for j in range(3):
				draw_arc(at, r * (.45 + j * .3), spin * (1.0 + j * .3) + j, spin * (1.0 + j * .3) + j + 4.0, 12, Color(col, col.a * (1.0 - j * .25)), w * .9, true)
		"spiral":
			for j in range(3):
				var a: float = spin + j * TAU / 3
				draw_line(at, at + Vector2.from_angle(a) * r * 1.2, col, w, true)
				draw_line(at + Vector2.from_angle(a) * r * 1.2, at + Vector2.from_angle(a + .7) * r * 1.6, col, w, true)
		_:
			if form.begins_with("star"):
				var points: int = int(form.substr(4))
				var outline := PackedVector2Array()
				for j in range(points * 2 + 1):
					outline.append(at + Vector2.from_angle(spin + j * PI / points) * (r * 1.25 if j % 2 == 0 else r * .55))
				draw_polyline(outline, col, w, true)
			else:
				shape(at, r, 6, spin, none, col, w)

func on_shell_burst(point: Vector2, radius: float, body_stage: int, critical: bool) -> void:
	# Suppression made visible: a ring sweeps the whole blast area.
	add_feedback("burst", point, 1 if critical else 0, radius, .5)
	shell_bursts += 1
	if shell_bursts % 3 == 0:
		add_wave(point, 14.0, .9)

func on_body_converted(body_stage: int, slot: int) -> void:
	var at: Vector2 = sim.body_position(body_stage, slot)
	var size: float = float(sim.BODIES[body_stage][slot].size)
	body_build[body_stage * 16 + slot] = BODY_BUILD_TIME
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
			var key: int = s * 16 + k
			var kick_t: float = 1.0 - clampf(float(body_flash.get(key, 0.0)) / BODY_KICK_TIME, 0, 1)
			var lit: float = pow(1.0 - kick_t, 3.0)
			if s == stage_now:
				# The body itself: rooftops are blocks, everything else a flat disc.
				if s == 0:
					draw_rect(Rect2(at - Vector2(size, size * .5), Vector2(size * 2, size)), Color("2a2a2a"))
				elif not (s == 2 and k == 5) and s != 4 and s != 5:
					draw_circle(at, size, Color("2c2c2c").lerp(GREY, .25 if converted else 0.0))
			if converted:
				var scale: float = 1.5 if s == stage_now else .5
				var radius: float = (size + 7.0) * scale
				var aim := Vector2.from_angle(float(body_aim.get(key, -PI * .5)))
				# Fast mechanical recoil, then a small damped return; no simulation movement.
				var kick: float = sin(kick_t * PI * 2.0) * exp(-kick_t * 5.0) * 9.0
				var build_t: float = 1.0 - float(body_build.get(key, 0.0)) / BODY_BUILD_TIME
				var settle: float = 1.0 if reduced_effects else 1.0 + sin(build_t * PI * 3.0) * pow(1.0 - build_t, 2.0) * .15
				var mount: Vector2 = at - aim * kick * scale * (.2 if reduced_effects else 1.0)
				draw_form(str(sim.BODIES[s][k].get("form", "node")), mount, radius * settle, lit, k, s == stage_now, aim, build_t)
				if build_t < 1.0:
					draw_body_assembly(at, radius, build_t, k)
				if lit > .01 and build_t > .35:
					draw_body_muzzle(mount, radius, aim, lit, int(sim.BODIES[s][k].get("style", s)))
				if s == stage_now and hover.distance_to(at) < size + 16:
					ink(str(sim.BODIES[s][k].weapon), at + Vector2(-24, -size - 22), INK, 12)
			elif s == stage_now:
				var hovered: bool = k == body_hover
				var dash_r: float = size + 9 + sin(clock * 3 + k) * 1.5
				for j in range(0, 16, 2):
					var a0: float = clock * .4 + j * TAU / 16
					draw_arc(at, dash_r, a0, a0 + TAU / 16, 4, Color(ACCENT if hovered else GREY, .9 if hovered else .45), 1.4, true)
				if hovered:
					ink("改造 " + str(sim.BODIES[s][k].name) + "  $" + sim.Catalog.number(sim.body_cost()), at + Vector2(-40, -dash_r - 10), ACCENT, 12)

func draw_form(form: String, at: Vector2, r: float, lit: float, k: int, big: bool, aim: Vector2 = Vector2.UP, build: float = 1.0) -> void:
	# All geometry shares the same local firing axis; only interior rotors spin.
	draw_set_transform_matrix(scene_transform * Transform2D(aim.angle(), at))
	at = Vector2.ZERO
	aim = Vector2.RIGHT
	# Each converted body gets its own silhouette so the player can tell them apart.
	var col: Color = Color(INK.lerp(Color.WHITE, lit), .2 + .8 * smoothstep(.1, .65, build))
	var w: float = 1.6 if big else 1.1
	var spin: float = 0.0
	var none := Color(0, 0, 0, 0)
	match form:
		"twin":
			draw_rect(Rect2(at - Vector2(r * .7, r * .5), Vector2(r * 1.4, r)), none, false, w)
			for side in [-1.0, 1.0]:
				var base: Vector2 = at + aim.orthogonal() * side * r * .3
				draw_line(base, base + aim * (r + 7), col, 2.0, true)
		"pods":
			shape(at, r, 3, -PI * .5, none, col, w)
			for j in range(3):
				draw_circle(at + Vector2.from_angle(-PI * .5 + j * TAU / 3) * r * .55, r * .18, col)
		"crescent":
			draw_arc(at, r, aim.angle() + .7, aim.angle() + TAU - .7, 24, col, w * 2.0, true)
			draw_line(at, at + aim * (r + 7), col, 2.5, true)
		"panels":
			draw_rect(Rect2(at - Vector2.ONE * r * .45, Vector2.ONE * r * .9), none, false, w)
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(at + Vector2(side * r * .6 - (r * .9 if side < 0 else 0.0), -r * .25), Vector2(r * .9, r * .5)), Color(col, .5), true)
		"dish":
			shape(at, r * .7, 4, 0, none, col, w)
			draw_arc(at + aim * r * .5, r * .6, aim.angle() - 1.1, aim.angle() + 1.1, 12, col, w, true)
		"tri":
			shape(at, r, 3, spin, none, col, w)
		"penta":
			shape(at, r, 5, spin, none, col, w)
		"star4", "star5", "star6", "star7", "star8":
			var points: int = int(form.substr(4))
			var outline := PackedVector2Array()
			for j in range(points * 2 + 1):
				var a: float = spin + j * PI / points
				outline.append(at + Vector2.from_angle(a) * (r if j % 2 == 0 else r * .5))
			draw_polyline(outline, col, w, true)
		"octa":
			shape(at, r, 8, spin * .5, none, col, w)
			draw_line(at + Vector2(-r * .8, -r * .25), at + Vector2(r * .8, -r * .25), Color(col, .6), 1.0, true)
			draw_line(at + Vector2(-r * .8, r * .25), at + Vector2(r * .8, r * .25), Color(col, .6), 1.0, true)
		"ringed":
			ring(at, r * .7, col, w)
			ring(at, r * 1.25, Color(col, .7), w)
		"dyson":
			shape(at, r, 6, spin, none, col, w)
			shape(at, r + 10, 12, -clock * .3, none, Color(ACCENT, .7), 1.4)
		"hole":
			for j in range(4):
				var a0: float = clock * (1.2 - j * .2) + j
				draw_arc(at, r * (.5 + j * .2), a0, a0 + 4.2, 24, Color(col, 1.0 - j * .18), w, true)
		"spiral":
			# Barred, triangular, diffuse, compact, spindle, binary and ring galaxies.
			var arms: int = [2, 3, 4, 2, 2, 2, 5][k % 7]
			for j in range(arms):
				var arm := PackedVector2Array()
				for q in range(12):
					var a: float = spin + j * TAU / arms + q * (.16 if k == 4 else .28)
					var offset: Vector2 = Vector2.from_angle(a) * r * (.15 + q * .075)
					if k in [0, 4]:
						offset.y *= .48 if k == 4 else .7
					arm.append(at + offset)
				draw_polyline(arm, col, w, true)
			if k == 1:
				shape(at, r * 1.12, 3, spin, none, col, w)
			elif k in [3, 6]:
				ring(at, r * (1.15 if k == 6 else .5), col, w)
			elif k == 5:
				for side in [-1.0, 1.0]:
					ring(at + Vector2(side * r * .45, 0), r * .35, col, w)
			elif k == 0:
				draw_line(at - Vector2(r * .55, 0), at + Vector2(r * .55, 0), col, w * 2, true)
		_:
			var sides: int = [6, 3, 4, 5, 8, 6][k % 6]
			shape(at, r, sides, spin, none, col, w)
			if k == 5:
				ring(at, r * .55, col, w * 2.0)
			elif k == 4:
				shape(at, r * .65, 4, -spin, none, col, w)
			else:
				for j in range(sides):
					var dir := Vector2.from_angle(spin + j * TAU / sides)
					draw_line(at + dir * r * .4, at + dir * r, Color(col, .5), 1.0, true)
					draw_circle(at + dir * (r + 4), 2.0, col)
	if form not in ["crescent", "twin"]:
		# Twin sliding rails give the muzzle a readable direction at every scale.
		for side in [-1.0, 1.0]:
			var root_at: Vector2 = at + aim * r * .6 + aim.orthogonal() * side * (2.5 if big else 1.3)
			draw_line(root_at, root_at + aim * (r * .4 + 7), col, w, true)
	draw_set_transform_matrix(scene_transform)

func draw_body_assembly(at: Vector2, r: float, t: float, slot: int) -> void:
	var fade: float = 1.0 - smoothstep(.68, 1.0, t)
	if reduced_effects:
		ring(at, r + 5, Color(INK, fade * .5), 1.2)
		return
	# Six staggered engineering brackets gather, latch, then release a clean ring.
	for j in range(6):
		var progress: float = clampf((t - j * .025) / .58, 0, 1)
		var distance: float = r + 5 + pow(1.0 - progress, 3.0) * 55
		var angle: float = j * TAU / 6 + slot * .3 + (1 - progress) * .35
		var dir := Vector2.from_angle(angle)
		var tip: Vector2 = at + dir * distance
		var side: Vector2 = dir.orthogonal() * 4
		draw_polyline(PackedVector2Array([tip + dir * 7 - side, tip - side, tip + side, tip + side + dir * 7]), Color(INK, fade * smoothstep(0, .1, t)), 1.6, true)
	if t > .55:
		var release: float = (t - .55) / .45
		ring(at, r + 7 + (1 - pow(1 - release, 3)) * 35, Color(INK, (1 - release) * .65), 1.4)

func draw_body_muzzle(at: Vector2, r: float, aim: Vector2, light: float, style: int) -> void:
	var p: Vector2 = at + aim * (r + 7)
	var side: Vector2 = aim.orthogonal()
	var reach: float = (8 + style * 1.5) * light
	var col := Color(INK, light * .85)
	if reduced_effects:
		draw_circle(p, 2.0 * light, col)
		return
	# Directional diamond blast and expanding paired magnetic collars.
	draw_colored_polygon(PackedVector2Array([p - aim * 2, p + side * reach * .3, p + aim * reach, p - side * reach * .3]), col)
	for j in range(2):
		var center: Vector2 = p + aim * (1.0 - light) * (12 + j * 7)
		draw_line(center - side * (3 + j * 2) * light, center + side * (3 + j * 2) * light, Color(INK, light * .55), 1.4, true)

func draw_transition_bodies(outgoing: Transform2D, t: float) -> void:
	# Collected bodies visibly travel into the next chapter's legacy orbit.
	var global_slot: int = 0
	for s in range(sim.stage + 1):
		for k in range(sim.BODIES[s].size()):
			var index: int = global_slot
			global_slot += 1
			if not sim.body_converted_at(s, k):
				continue
			var angle: float = index * .71 + sim.elapsed * .25
			var destination: Vector2 = Vector2(500, 325) + Vector2.from_angle(angle) * (150.0 + index % 3 * 14.0)
			var from: Vector2 = outgoing * sim.body_position(s, k)
			var gather: float = smoothstep(.35, 1.0, t)
			var at: Vector2 = from.lerp(destination, gather)
			var original: float = (float(sim.BODIES[s][k].size) + 7) * 1.5 if s == sim.stage else 6.0
			var radius: float = lerpf(maxf(3, original * pow(.04, t)), 6.0, gather)
			var aim := Vector2.from_angle(float(body_aim.get(s * 16 + k, -PI * .5)))
			draw_form(str(sim.BODIES[s][k].get("form", "node")), at, radius, 0, k, false, aim)

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
		# Threats materialise at the screen edge: they fade up behind their warp-in streak.
		fill.a *= smoothstep(0.0, 1.0, float(e.age) / .45)
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
	if not boss and born < .55:
		# Arrival rift: a bright tear across the flight line that seals behind it.
		var rift: float = 1.0 - born / .55
		var across_dir := Vector2(-trail.y, trail.x)
		stroke(p + across_dir * radius * 2.6 * rift, p - across_dir * radius * 2.6 * rift, Color(1, 1, 1, .9 * rift * rift))
		ring(p, radius * (1.2 + (1.0 - rift) * 3.2), Color(INK, .45 * rift))
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
		var outgoing: Transform2D = scene_transform
		scene_transform = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO)
		draw_transition_bodies(outgoing, t)
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
		draw_shells()
		draw_swarm()
		draw_strikes()
		draw_ultimate()
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
	if ult_flash > 0.001:
		draw_rect(Rect2(-400, -400, 1800, 1450), Color(1, 1, 1, minf(1.0, ult_flash)))
	inspector()
	draw_reticle()
	draw_ms = (Time.get_ticks_usec() - started) / 1000.0

# ================= Celestial attack styles =================

var strikes: Array[Dictionary] = []
var imprints: Array[Dictionary] = []
var prime_marks: Array[Dictionary] = []
var ulam: PackedVector2Array = PackedVector2Array()
const STRIKE_TIME: Dictionary = {"beam": .34, "rail": .42, "chain": .32, "ring": .6, "gravity": .3, "wave": .7, "quake": .3, "meteor": .2, "prism": .4}

func on_body_strike(kind: String, body_stage: int, slot: int, origin: Vector2, destination: Vector2, points: PackedVector2Array, critical: bool) -> void:
	if strikes.size() > 90:
		strikes.pop_front()
	strikes.append({"kind": kind, "age": 0.0, "dur": float(STRIKE_TIME.get(kind, .4)), "from": origin, "to": destination, "points": points, "crit": critical, "seed": randi() % 1000, "big": body_stage == sim.stage})
	match kind:
		"beam", "rail", "prism":
			add_feedback("flash", destination, 0, 26.0 if kind != "rail" else 18.0, .28)
		"ring":
			add_wave(origin, 22.0, 1.0)
		"wave":
			add_wave(origin.lerp(destination, .5), 16.0, 1.0)

func centered(text: String, pos: Vector2, size: int, color: Color, outline: bool = false) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = pos - Vector2(w * .5, -size * .35)
	if outline:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(BG, .85 * color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func jagged(a: Vector2, b: Vector2, seed_value: int, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var n: Vector2 = (b - a).orthogonal().normalized()
	for j in range(1, 7):
		var t: float = j / 7.0
		var wob: float = sin(seed_value * 1.7 + j * 2.3 + clock * 40.0) * amp * sin(t * PI)
		out.append(a.lerp(b, t) + n * wob)
	out.append(b)
	return out

func draw_strikes() -> void:
	for st in strikes:
		var t: float = float(st.age) / float(st.dur)
		if t < 0 or t > 1:
			continue
		var a: Vector2 = st.from
		var b: Vector2 = st.to
		var col: Color = ACCENT if bool(st.crit) else INK
		var fade: float = 1.0 - t
		match str(st.kind):
			"beam":
				# Charge for a beat, then a thick lance that thins out.
				var w: float = (7.0 if bool(st.big) else 4.0) * sqrt(fade)
				draw_line(a, b, Color(col, .14 * fade), w * 4.0, true)
				draw_line(a, b, Color(col, .9 * fade), w, true)
				draw_line(a, b, Color(1, 1, 1, fade), maxf(1.0, w * .3), true)
				draw_circle(b, w * 1.6, Color(1, 1, 1, fade))
				for q in st.points:
					ring(q, 6 + t * 14, Color(col, fade * .8), 1.2)
			"rail":
				# Instant slug: a hairline to the edge of space with shock ripples along it.
				draw_line(a, b, Color(1, 1, 1, fade), 2.2 * fade + .6, true)
				var dir: Vector2 = (b - a).normalized()
				var n: Vector2 = dir.orthogonal()
				var length: float = a.distance_to(b)
				var d: float = 30.0
				while d < length:
					var c: Vector2 = a + dir * d
					var spread: float = 4.0 + t * 16.0
					draw_line(c - n * spread, c + n * spread, Color(col, fade * .35), 1.0, true)
					d += 46.0
				ring(a, 10 + t * 40, Color(col, fade), 1.6)
			"chain":
				var pts: PackedVector2Array = st.points
				for j in range(pts.size() - 1):
					var bolt: PackedVector2Array = jagged(pts[j], pts[j + 1], int(st.seed) + j * 13, 9.0)
					draw_polyline(bolt, Color(col, .25 * fade), 5.0, true)
					draw_polyline(bolt, Color(1, 1, 1, fade), 1.4, true)
					draw_circle(pts[j + 1], 3.0 * fade + 1, Color(1, 1, 1, fade))
			"ring":
				var r: float = 240.0 * (1.0 - pow(1.0 - t, 3))
				draw_arc(a, r, 0, TAU, 96, Color(col, .9 * fade), 3.0 * fade + .5, true)
				draw_arc(a, r * .82, 0, TAU, 96, Color(col, .35 * fade), 1.0, true)
				for q in st.points:
					if q.distance_to(a) < r:
						draw_circle(q, 3.0 * fade, Color(1, 1, 1, fade))
			"wave":
				# Three ripple fronts roll out in a cone, each a sine-wobbled arc.
				var axis: float = (b - a).angle()
				for k in range(3):
					var p: float = clampf(t * 1.25 - k * .12, 0, 1)
					if p <= 0:
						continue
					var r: float = 560.0 * (1.0 - pow(1.0 - p, 2))
					var arc := PackedVector2Array()
					for j in range(25):
						var ang: float = axis - .38 + .76 * j / 24.0
						var wob: float = sin(j * 1.1 + clock * 18.0 + k) * 5.0 * (1.0 - p)
						arc.append(a + Vector2.from_angle(ang) * (r + wob))
					draw_polyline(arc, Color(col, (1.0 - p) * (.9 - k * .25)), 2.4 - k * .6, true)
			"prism":
				var pts: PackedVector2Array = st.points
				if pts.size() > 0:
					draw_line(a, pts[0], Color(1, 1, 1, fade), 3.0 * fade + .6, true)
					# The refracted fan picks up faint spectral-grey bands.
					for j in range(1, pts.size()):
						for k in range(3):
							var off: Vector2 = (pts[j] - pts[0]).orthogonal().normalized() * (k - 1) * 2.0
							draw_line(pts[0], pts[j] + off, Color(col, fade * (.85 - k * .25)), 1.3, true)
					shape(pts[0], 8 * (1.0 - t * .5), 3, clock * 6.0, Color(0, 0, 0, 0), Color(1, 1, 1, fade), 1.4)
			"quake":
				var bolt: PackedVector2Array = jagged(a, b, int(st.seed), 3.0)
				draw_polyline(bolt, Color(col, .5 * fade), 1.2, true)
	# Gravity wells, quakes and meteors are owned by the sim; draw them from it.
	for w in sim.wells:
		var age: float = float(w.age)
		var at: Vector2 = w.pos
		match str(w.get("kind", "gravity")):
			"gravity":
				var k: float = clampf(age / float(w.dur), 0, 1)
				var open: float = minf(1.0, age / .25) * (1.0 - pow(k, 6))
				var r: float = float(w.radius) * open
				draw_circle(at, r, Color(0, 0, 0, .45 * open))
				draw_arc(at, r, clock * 2.0, clock * 2.0 + TAU * .8, 48, Color(INK, .7 * open), 1.4, true)
				for arm in range(4):
					var spiral := PackedVector2Array()
					for j in range(14):
						var q: float = j / 13.0
						spiral.append(at + Vector2.from_angle(clock * 5.0 + arm * TAU / 4 + q * 3.2) * r * (1.0 - q * .92))
					draw_polyline(spiral, Color(INK, .55 * open), 1.2, true)
				for j in range(10):
					var phase: float = fmod(clock * 1.6 + j * .37, 1.0)
					var ang: float = j * 2.399 + clock
					draw_circle(at + Vector2.from_angle(ang + phase * 2.0) * r * (1.0 - phase), 1.6, Color(1, 1, 1, open * phase))
			"quake":
				for shock in range(4):
					var since: float = age - shock * .3
					if since < 0 or since > .45:
						continue
					var q: float = since / .45
					var r: float = (90.0 + 40.0 * shock) * (.35 + .65 * (1.0 - pow(1.0 - q, 3)))
					var pts := PackedVector2Array()
					for j in range(33):
						var ang: float = j * TAU / 32
						pts.append(at + Vector2.from_angle(ang) * (r + sin(j * 7.0 + shock * 3.0) * 6.0 * (1.0 - q)))
					draw_polyline(pts, Color(INK, (1.0 - q) * .9), 2.2 * (1.0 - q) + .6, true)
					if since < .05:
						trauma = minf(1.0, trauma + .06)
			"meteor":
				if age < 0:
					continue
				var q: float = clampf(age / float(w.dur), 0, 1)
				var sky: Vector2 = at + Vector2(-140, -420)
				var head: Vector2 = sky.lerp(at, q * q)
				draw_line(sky.lerp(at, maxf(0, q * q - .18)), head, Color(INK, .5), 2.0, true)
				shape(head, 5.0, 4, clock * 9.0, INK)
				draw_arc(at, 10 + (1.0 - q) * 26, 0, TAU, 24, Color(INK, .25 + q * .4), 1.0, true)

func draw_swarm() -> void:
	# Micro-missiles weave on curved paths with a short smoke trail.
	for p in sim.shots:
		if not p.has("swarm"):
			continue
		var t: float = clampf(float(p.age) / float(p.duration), 0, 1)
		var j: int = int(p.swarm)
		var side: float = 1.0 if j % 2 == 0 else -1.0
		var dir: Vector2 = (Vector2(p.end) - Vector2(p.from)).normalized()
		var n: Vector2 = dir.orthogonal()
		var curve := func(u: float) -> Vector2: return Vector2(p.from).lerp(p.end, u) + n * side * sin(u * PI) * (24.0 + j * 9.0)
		var head: Vector2 = curve.call(t)
		var back: Vector2 = curve.call(maxf(0, t - .04))
		for k in range(1, 6):
			var puff: Vector2 = curve.call(maxf(0, t - k * .035))
			draw_circle(puff, 1.6 + k * .35, Color(GREY, .28 - k * .045))
		var heading: Vector2 = (head - back).normalized() if head != back else dir
		var col: Color = ACCENT if bool(p.crit) else INK
		draw_colored_polygon(PackedVector2Array([head + heading * 5.0, head - heading * 3.0 + heading.orthogonal() * 2.6, head - heading * 3.0 - heading.orthogonal() * 2.6]), col)

# ================= Doomsday weapons =================

func on_ultimate_fired(kind: String, point: Vector2) -> void:
	var subtitles: Dictionary = {"nuke": "半径 300 · 一切蒸发", "photoid": "一颗以光速飞行的粒子", "foil": "空间维度 3 → 2", "prime": "2 · 3 · 5 · 7 · 11 · 13 · 17 · 19 · 23 · 29", "lightspeed": "c = 299,792 km/s → 16.7 km/s", "pi": "π = 3.14159265… → 3"}
	# The HUD overlay carries the title card; the field keeps a quiet subtitle.
	banner = {}
	punch = maxf(punch, .5)
	if kind == "prime" and ulam.is_empty():
		# An Ulam spiral of primes: the maths the strike is drawn from.
		var x: int = 0
		var y: int = 0
		var dx: int = 1
		var dy: int = 0
		var leg: int = 1
		var walked: int = 0
		var turns: int = 0
		for n in range(1, 1600):
			if is_prime(n):
				ulam.append(Vector2(x, y))
			x += dx
			y += dy
			walked += 1
			if walked == leg:
				walked = 0
				var tmp: int = dx
				dx = -dy
				dy = tmp
				turns += 1
				if turns % 2 == 0:
					leg += 1

func is_prime(n: int) -> bool:
	if n < 2:
		return false
	var d: int = 2
	while d * d <= n:
		if n % d == 0:
			return false
		d += 1
	return true

func on_ultimate_impact(kind: String, point: Vector2) -> void:
	trauma = 1.0
	punch = 1.2
	slowmo_request = true
	add_wave(point, 60.0, 1.6)
	add_wave(point, 40.0, 2.2)
	if kind == "nuke":
		add_feedback("flash", point, 0, 420.0, .9)

func on_prime_strike(prime: int, points: PackedVector2Array) -> void:
	prime_marks.append({"p": prime, "points": points, "age": 0.0})
	trauma = minf(1.0, trauma + .25)
	for q in points:
		add_wave(q, 10.0, .7)

func on_flattened(point: Vector2) -> void:
	if imprints.size() < 160:
		imprints.append({"pos": point, "age": 0.0, "w": 14.0 + randf() * 16.0})

func animate_ultimates(delta: float) -> void:
	# The photoid bends space-time as it passes: the grid ripples along its path.
	if sim != null and not sim.ult.is_empty() and str(sim.ult.kind) == "photoid":
		var u: float = float(sim.ult.age)
		if u > .6 and u < sim.PHOTOID_IMPACT:
			photoid_ripple -= delta
			if photoid_ripple <= 0:
				photoid_ripple = .07
				add_wave(photoid_head(u), 9.0, .8)
			trauma = maxf(trauma, .25 * clampf((u - 1.4) / .8, 0, 1))
	for i in range(strikes.size() - 1, -1, -1):
		strikes[i].age = float(strikes[i].age) + delta
		if float(strikes[i].age) > float(strikes[i].dur):
			strikes.remove_at(i)
	for i in range(imprints.size() - 1, -1, -1):
		imprints[i].age = float(imprints[i].age) + delta
		if float(imprints[i].age) > 4.0:
			imprints.remove_at(i)
	for i in range(prime_marks.size() - 1, -1, -1):
		prime_marks[i].age = float(prime_marks[i].age) + delta
		if float(prime_marks[i].age) > .9:
			prime_marks.remove_at(i)

const PHOTOID_START := Vector2(70, 40)
var photoid_ripple: float = 0.0

func photoid_head(u: float) -> Vector2:
	var hit_t: float = sim.PHOTOID_IMPACT
	var p: float = clampf((u - .6) / (hit_t - .6), 0, 1)
	return PHOTOID_START.lerp(sim.ult.get("point", Vector2(500, 325)), pow(p, 2.6))

func ease_out(t: float, power: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0, 1), power)

var ult_flash: float = 0.0

func draw_ultimate() -> void:
	ult_flash = 0.0
	var core_at: Vector2 = sim.defense_position()
	# Flattened imprints outlive the foil: threats pressed into lines.
	for im in imprints:
		var q: float = float(im.age) / 4.0
		var squash: float = ease_out(float(im.age) / .25)
		var w: float = float(im.w) * (.4 + squash * 1.6)
		var p: Vector2 = im.pos
		draw_line(p - Vector2(w, 0), p + Vector2(w, 0), Color(INK, (1.0 - q) * .8), 1.0, true)
		draw_line(p - Vector2(w * .6, 2), p + Vector2(w * .6, 2), Color(INK, (1.0 - q) * .3), 1.0, true)
	var spiral_at: Vector2 = sim.defense_position()
	for pm in prime_marks:
		var q: float = float(pm.age) / .9
		var fade: float = 1.0 - q
		var prime: int = int(pm.p)
		var pts: PackedVector2Array = pm.points
		for j in range(pts.size()):
			# The beam leaves the spiral at a prime of its own.
			var src: Vector2 = spiral_at + (ulam[(prime * 5 + j * 11) % ulam.size()] * 6.0 if not ulam.is_empty() else Vector2.ZERO)
			var travel: float = ease_out(q / .18)
			draw_line(src, src.lerp(pts[j], travel), Color(1, 1, 1, fade * .85), 1.6, true)
			draw_circle(src, 2.5 * fade + 1, Color(ACCENT, fade))
			# A prime-sided polygon draws itself around the target, then collapses.
			var sides: int = mini(prime, 31)
			var draw_on: float = clampf((q - .1) / .3, 0, 1)
			var collapse: float = ease_out(clampf((q - .45) / .4, 0, 1))
			var r: float = 24.0 * (1.0 - collapse) + 2.0
			var gon: PackedVector2Array = ngon(sides, r, -PI / 2 + q * 2.0, pts[j])
			gon.append(gon[0])
			var shown: int = int(ceil(draw_on * sides)) + 1
			if shown > 1:
				draw_polyline(gon.slice(0, mini(shown, gon.size())), Color(1, 1, 1, .95 * fade), 1.4, true)
			if collapse > .9:
				draw_circle(pts[j], 5.0 * (1.0 - q), Color.WHITE)
			if j < 8:
				ink(str(prime), pts[j] + Vector2(14, -14), Color(ACCENT, fade), 12)
		# The formula for the latest pulse only: p-subscript-n = prime, and the count erased.
		if pm != prime_marks.back():
			continue
		var index: int = sim.PRIMES.find(prime) + 1
		var grow: float = 1.0 + .6 * maxf(0, 1.0 - q * 5.0)
		draw_set_transform(Vector2(500, 540), 0, Vector2.ONE * grow)
		# p with a hand-set subscript index (the web font has no subscript digits).
		var col_f := Color(1, 1, 1, fade * .95)
		var rest: String = " = %d" % prime
		var w_p: float = font.get_string_size("p", HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		var w_i: float = font.get_string_size(str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var w_r: float = font.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
		var x0: float = -(w_p + w_i + w_r) * .5
		for part in [["p", 48, Vector2(x0, 17)], [str(index), 24, Vector2(x0 + w_p, 26)], [rest, 48, Vector2(x0 + w_p + w_i, 17)]]:
			draw_string_outline(font, part[2], part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, part[1], 6, Color(BG, .85 * col_f.a))
			draw_string(font, part[2], part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, part[1], col_f)
		draw_set_transform(Vector2.ZERO)
		var erased: int = 0
		for k in range(index):
			erased += sim.PRIMES[k]
		centered("Σ  已抹除 %d" % erased, Vector2(500, 578), 14, Color(ACCENT, fade))
	if sim.ult.is_empty():
		if sim.spawn_hold > 0 and sim.mode in ["wave", "boss"]:
			var k: float = clampf(sim.spawn_hold / 5.0, 0, 1)
			draw_arc(core_at, 96, -PI / 2, -PI / 2 + TAU * k, 64, Color(INK, .7), 2.0, true)
			centered("敌踪消失  %.1f s" % sim.spawn_hold, core_at + Vector2(0, 122), 13, Color(GREY, .9))
		return
	var kind: String = sim.ult.kind
	var u: float = float(sim.ult.age)
	var at: Vector2 = sim.ult.point
	match kind:
		"nuke":
			var hit_t: float = sim.NUKE_IMPACT
			if u < hit_t:
				# Launch flare, then a warhead climbing an arc with a thick smoke trail
				# while lock rings tighten round the target and the countdown runs.
				var k: float = clampf((u - .1) / (hit_t - .1), 0, 1)
				var e: float = k * k * (3.0 - 2.0 * k)
				var ctrl: Vector2 = core_at.lerp(at, .5) + Vector2(0, -300)
				var head: Vector2 = core_at.lerp(ctrl, e).lerp(ctrl.lerp(at, e), e)
				if u < .4:
					var f: float = 1.0 - u / .4
					draw_circle(core_at, 26.0 * f + 6.0, Color(1, 1, 1, .5 * f))
				for j in range(26):
					var g: float = maxf(0, e - j * .018)
					var q: Vector2 = core_at.lerp(ctrl, g).lerp(ctrl.lerp(at, g), g)
					var spread: float = j * .9
					q += Vector2(sin(j * 1.7 + clock * 3.0), cos(j * 1.3)) * spread
					draw_circle(q, 2.0 + j * .35, Color(GREY, .32 * (1.0 - j / 26.0)))
				var dir: Vector2 = (ctrl.lerp(at, e) - core_at.lerp(ctrl, e)).normalized()
				draw_colored_polygon(PackedVector2Array([head + dir * 9.0, head - dir * 5.0 + dir.orthogonal() * 4.0, head - dir * 5.0 - dir.orthogonal() * 4.0]), Color.WHITE)
				draw_circle(head - dir * 6.0, 3.0 + sin(clock * 40.0) * 1.2, Color(ACCENT, .9))
				for j in range(3):
					var r: float = lerpf(170.0 - j * 34, 16.0, ease_out(k, 2))
					draw_arc(at, r, clock * (2 + j), clock * (2 + j) + TAU * .7, 48, Color(ACCENT, .35 + k * .55), 1.6, true)
				draw_line(at + Vector2(-26, 0), at + Vector2(26, 0), Color(ACCENT, .8), 1.0, true)
				draw_line(at + Vector2(0, -26), at + Vector2(0, 26), Color(ACCENT, .8), 1.0, true)
				centered("NUCLEAR  ·  T-%.2f" % (hit_t - u), at + Vector2(0, -190), 14, Color(ACCENT, .95), true)
				if hit_t - u < .18:
					draw_circle(at, 30.0 * (1.0 - (hit_t - u) / .18), Color(1, 1, 1, .9))
			else:
				var n: float = u - hit_t
				var flash: float = pow(maxf(0, 1.0 - n / .45), 2)
				var fb: float = 300.0 * ease_out(n / .5)
				var fade: float = clampf(1.0 - (n - .3) / 1.9, 0, 1)
				draw_circle(at, fb, Color(INK, .22 * fade))
				draw_circle(at, fb * .55, Color(1, 1, 1, .35 * fade))
				draw_arc(at, fb, 0, TAU, 128, Color(1, 1, 1, fade), 3.0, true)
				for j in range(3):
					var r: float = 300.0 + n * 700.0 * (1.0 + j * .35)
					draw_arc(at, r, 0, TAU, 128, Color(INK, fade * (.6 - j * .15)), 2.0 - j * .5, true)
				# Stylised mushroom: a rising stem and a spreading cap.
				var rise: float = ease_out(n / 1.4)
				var top: Vector2 = at + Vector2(0, -230 * rise)
				for j in range(9):
					var off: float = (j - 4) * 7.0 * (1.0 - rise * .4)
					var wob: float = sin(clock * 8.0 + j) * 3.0
					draw_line(at + Vector2(off, 0), top + Vector2(off * .6 + wob, 0), Color(INK, fade * .45), 1.2, true)
				draw_set_transform(top, 0, Vector2(1.0, .32))
				draw_arc(Vector2.ZERO, 40 + 120 * rise, 0, TAU, 64, Color(1, 1, 1, fade * .8), 3.0, true)
				draw_arc(Vector2.ZERO, 20 + 70 * rise, 0, TAU, 48, Color(1, 1, 1, fade * .4), 2.0, true)
				draw_set_transform(Vector2.ZERO)
				for j in range(36):
					var ang: float = j * TAU / 36 + .1
					var r0: float = fb * .9
					var r1: float = r0 + 40 + n * 260
					draw_line(at + Vector2.from_angle(ang) * r0, at + Vector2.from_angle(ang) * r1, Color(INK, fade * .35), 1.0, true)
				ult_flash = flash * .92
		"photoid":
			var hit_t: float = sim.PHOTOID_IMPACT
			var origin: Vector2 = PHOTOID_START
			if u < hit_t:
				# 1) It materialises: a point of light with cross spikes and a label.
				var appear: float = ease_out(u / .6)
				var p: float = clampf((u - .6) / (hit_t - .6), 0, 1)
				var head: Vector2 = photoid_head(u)
				var speed: float = pow(p, 1.6)
				# 2) The predicted path to the target, marching amber dashes.
				var to_go: float = head.distance_to(at)
				var dash_dir: Vector2 = (at - head).normalized()
				var d: float = fmod(clock * 120.0, 18.0)
				while d < to_go - 10.0:
					draw_line(head + dash_dir * d, head + dash_dir * minf(d + 8.0, to_go), Color(ACCENT, .55 * appear), 1.2, true)
					d += 18.0
				for j in range(3):
					var r: float = lerpf(120.0 - j * 26, 14.0, ease_out(p, 2))
					draw_arc(at, r, -clock * (2 + j), -clock * (2 + j) + TAU * .7, 48, Color(ACCENT, .3 + p * .6), 1.4, true)
				centered("T-%.2f" % (hit_t - u), at + Vector2(0, -150), 14, Color(ACCENT, .9 * appear), true)
				# 3) The trail: faint from the origin, white-hot near the head, with afterimages.
				draw_line(origin, head, Color(INK, .18 + .3 * speed), 1.0, true)
				draw_line(origin.lerp(head, maxf(0, 1.0 - .12 - speed * .25)), head, Color(1, 1, 1, .95), 2.2, true)
				for j in range(1, 6):
					var ghost: Vector2 = photoid_head(u - j * .05)
					draw_circle(ghost, 3.0 - j * .4, Color(1, 1, 1, .45 - j * .07))
				var spike: float = 14.0 + 70.0 * appear * (.5 + speed)
				draw_line(head - Vector2(spike, 0), head + Vector2(spike, 0), Color(1, 1, 1, .8), 1.2, true)
				draw_line(head - Vector2(0, spike * .7), head + Vector2(0, spike * .7), Color(1, 1, 1, .8), 1.2, true)
				draw_line(head - Vector2(spike, spike) * .3, head + Vector2(spike, spike) * .3, Color(1, 1, 1, .4), 1.0, true)
				draw_line(head - Vector2(spike, -spike) * .3, head + Vector2(spike, -spike) * .3, Color(1, 1, 1, .4), 1.0, true)
				draw_circle(head, 4.0 + 2.0 * sin(clock * 30.0) * (1.0 - p), Color.WHITE)
				for j in range(2):
					var rr: float = fmod(u * 1.6 + j * .5, 1.0)
					draw_arc(head, 6.0 + rr * 40.0, 0, TAU, 32, Color(1, 1, 1, (1.0 - rr) * .5 * (1.0 - p)), 1.0, true)
				# 4) Telemetry riding next to it.
				var c_speed: float = lerpf(.31, .999, pow(p, .8))
				ink_outlined("光粒  PHOTOID", head + Vector2(18, -22), Color(1, 1, 1, appear), 13)
				ink_outlined("v = %.3f c" % c_speed, head + Vector2(18, -6), Color(ACCENT, appear), 12)
			else:
				var n: float = u - hit_t
				var flash: float = pow(maxf(0, 1.0 - n / .5), 2)
				var fade: float = clampf(1.0 - n / 1.5, 0, 1)
				for j in range(64):
					var ang: float = j * TAU / 64 + sin(j * 3.1) * .05
					var reach_len: float = 80 + ease_out(n / .6) * (900 + (j % 5) * 60)
					draw_line(at + Vector2.from_angle(ang) * reach_len * .2, at + Vector2.from_angle(ang) * reach_len, Color(1, 1, 1, fade * (.25 + (j % 3) * .2)), 1.0, true)
				draw_arc(at, ease_out(n / 1.2) * 900, 0, TAU, 160, Color(1, 1, 1, fade), 2.5, true)
				ult_flash = flash
		"foil":
			if u < 1.3:
				# A card-sized piece of two-dimensional space drifts in, almost gently.
				var k: float = ease_out(u / 1.3, 2)
				var p: Vector2 = (at + Vector2(-260, -240)).lerp(at, k)
				draw_set_transform(p, clock * .9, Vector2(1.0, .3 + .7 * abs(sin(clock * 1.7))))
				draw_rect(Rect2(-11, -7, 22, 14), Color(1, 1, 1, .9))
				draw_rect(Rect2(-11, -7, 22, 14), Color(1, 1, 1, 1), false, 1.0)
				draw_set_transform(Vector2.ZERO)
				draw_arc(p, 18 + sin(clock * 6) * 3, 0, TAU, 32, Color(INK, .3), 1.0, true)
			else:
				var r: float = (u - 1.3) * 400.0
				var fade: float = clampf(1.0 - (u - 4.2) / .8, 0, 1)
				draw_circle(at, r, Color(INK, .05 * fade))
				var y: float = -r
				while y <= r:
					var half: float = sqrt(maxf(0, r * r - y * y))
					draw_line(at + Vector2(-half, y), at + Vector2(half, y), Color(INK, .16 * fade), 1.0)
					y += 7.0
				draw_arc(at, r, 0, TAU, 160, Color(1, 1, 1, .95 * fade), 2.4, true)
				draw_arc(at, r + 6, 0, TAU, 160, Color(1, 1, 1, .25 * fade), 1.0, true)
				centered("3D → 2D", at + Vector2(0, -r - 18).clamp(Vector2(0, 30), Vector2(1000, 640)), 14, Color(1, 1, 1, .8 * fade))
		"prime":
			# The Ulam spiral of primes grows out of the core, its path traced in light.
			var k: float = minf(1.0, u / .5) * clampf((4.4 - u) / .8, 0, 1)
			var reveal: int = int(ulam.size() * clampf(u / 2.6, 0, 1))
			var path := PackedVector2Array()
			for i in range(reveal):
				path.append(core_at + ulam[i] * 6.0)
			if path.size() > 1:
				draw_polyline(path, Color(INK, .14 * k), 1.0, true)
			for i in range(reveal):
				var fresh: float = clampf(1.0 - (reveal - i) / 40.0, 0, 1)
				draw_rect(Rect2(path[i] - Vector2.ONE * (1.0 + fresh), Vector2.ONE * (2.0 + fresh * 2.0)), Color(INK.lerp(ACCENT, fresh), (.3 + fresh * .6) * k))
			centered("p ∈ P        π(x) ~ x / ln x", Vector2(500, 70), 15, Color(GREY, k))
		"lightspeed":
			var k: float = ease_out(u / .9)
			var collapse: float = clampf((u - 4.0) / .45, 0, 1)
			var r: float = 950.0 * k * (1.0 - ease_out(collapse, 2))
			draw_circle(core_at, r, Color(0, 0, 0, .5 * (1.0 - collapse * .5)))
			draw_arc(core_at, r, 0, TAU, 160, Color(1, 1, 1, .85), 2.0, true)
			# The speed of light rolls down toward a crawl.
			var speed: float = lerpf(299792.0, 16.7, ease_out(u / 2.2, 4))
			centered("c = %s km/s" % (("%.1f" % speed) if speed < 100 else str(int(speed))), Vector2(500, 82), 22, Color(1, 1, 1, .9 * (1.0 - collapse)), true)
			for e in sim.enemies:
				if not bool(e.dead):
					draw_arc(e.pos, float(e.radius) + 5, 0, TAU, 24, Color(INK, .35), 1.0, true)
			ult_flash = (1.0 - collapse) * collapse * 2.4
		"pi":
			# π loses its digits one by one; every circle becomes a hexagon.
			var digits: String = "14159265358979323846"
			var keep: int = int(round(lerpf(20.0, 0.0, ease_out(u / 1.8, 2))))
			var text: String = "π = 3" + ("." + digits.substr(0, keep) if keep > 0 else "")
			if keep > 0 and keep < 20:
				text += str(int(clock * 60.0) % 10)
			centered(text, Vector2(500, 86), 30 if u < 2.0 else 40, Color(1, 1, 1, .95 * clampf((4.2 - u) / .6, 0, 1)), true)
			var sides: int = int(round(lerpf(64.0, 6.0, ease_out(u / 1.9, 3))))
			var fade: float = clampf((4.2 - u) / .9, 0, 1)
			for j in range(6):
				var r: float = 70.0 + j * 75.0 + (maxf(0, u - 2.0) * 260.0)
				var pts: PackedVector2Array = ngon(sides, r, PI / 6 + clock * (.05 if j % 2 == 0 else -.05), core_at)
				pts.append(pts[0])
				draw_polyline(pts, Color(INK, (.5 - j * .06) * fade), 1.4, true)
			if u >= 2.0:
				var n: float = u - 2.0
				var flash: float = pow(maxf(0, 1.0 - n / .7), 2)
				ult_flash = flash * .95
				if flash > 0:
					draw_set_transform(core_at, 0, Vector2.ONE * (1.0 + n * 2.0))
					for j in range(3):
						var pts: PackedVector2Array = ngon(6, 60.0 + j * 50.0, PI / 6)
						pts.append(pts[0])
						draw_polyline(pts, Color(0, 0, 0, flash), 2.0, true)
					draw_set_transform(Vector2.ZERO)
