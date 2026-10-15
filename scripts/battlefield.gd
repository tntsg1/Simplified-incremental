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
var atlas = preload("res://scripts/cosmic_atlas.gd").new()
var ultimate_art = preload("res://scripts/ultimate_art.gd").new()
var feedback: Array[Dictionary] = []
var feedback_pool: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var number_limits: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var recoil: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var aims: Array[float] = [-PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5, -PI * .5]
var muzzle_limits: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var spark_limits: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var pierce_limits: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var core_pulse: float = 0
# Visible growth: purchases made in the (paused) upgrade panel replay on the
# battlefield once combat resumes, so the defense is seen to grow.
const GROWTH_NAMES := {"damage": "弹头", "speed": "弹速", "reload": "装填", "crit": "暴击", "area": "范围", "pierce": "贯穿", "targets": "锁定", "turrets": "炮台"}
var prev_levels: Dictionary = {}
var prev_owned: Array = []
var growth: Array[Dictionary] = []
var growth_bounce: float = 0
var dock_age: Array[float] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
var core_outer: float = 20
# Barrage layer: purely cosmetic rounds that show the real launcher count and
# fire rate. Combat timing and damage stay in the simulation untouched.
const BULLET_CAP: int = 900
var shell_bursts: int = 0
# Turret rounds: crisp grey needles, the ring's own signature.
const TURRET_STYLE: int = 16
const WEAPONS: int = 10
const NUMBER_CAP: int = 56
# Additive glow layer: light trails, flashes and halos drawn over the flat field.
const GlowTexture = preload("res://assets/glow.svg")
const COIN_CAP: int = 70
const ULT_COIN_CAP: int = 720
var glow: Node2D
var boss_fx: ColorRect
var boss_sparks: CPUParticles2D
const BOSS_FX_KIND: Dictionary = {"star": 0, "magnetar": 1, "asteroid": 3, "planet": 4, "dwarf": 5, "mothership": 6, "cigar": 7, "cathedral": 8, "rift": 9, "brane": 10}
# Where the body sits inside the shader square (0.5 = its edge): smaller leaves room for tails.
const BOSS_FX_BODY: Dictionary = {"star": .3, "magnetar": .3, "asteroid": .14, "planet": .2, "dwarf": .16, "mothership": .2, "cigar": .18, "cathedral": .16, "rift": .18, "brane": .2}
var boss_fx_kind: String = ""
var boss_hit_age: float = 9.0
var boss_dying: float = -1.0
var boss_last: Dictionary = {}
var glow_trails := PackedVector2Array()
var glow_heads := PackedVector2Array()
var coins: Array[Dictionary] = []
var coin_arrivals: int = 0
var ult_arrivals: int = 0
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
var unified_cursor: bool = false
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
# Times each cosmetic round has changed target; after MAX_RETARGETS it flies off.
var b_turns := PackedByteArray()
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
	# Boss energy layer: a GPU shader square that follows the boss (plasma, field
	# light, corona) plus a particle stream; the line silhouette stays on top.
	boss_fx = ColorRect.new()
	boss_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx_mat := ShaderMaterial.new()
	fx_mat.shader = preload("res://assets/boss_fx.gdshader")
	boss_fx.material = fx_mat
	boss_fx.visible = false
	add_child(boss_fx)
	boss_sparks = CPUParticles2D.new()
	boss_sparks.texture = GlowTexture
	var spark_mat := CanvasItemMaterial.new()
	spark_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	boss_sparks.material = spark_mat
	boss_sparks.amount = 90
	boss_sparks.lifetime = 1.8
	boss_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	boss_sparks.direction = Vector2.UP
	boss_sparks.spread = 180.0
	boss_sparks.gravity = Vector2.ZERO
	boss_sparks.initial_velocity_min = 20.0
	boss_sparks.initial_velocity_max = 70.0
	boss_sparks.radial_accel_min = 10.0
	boss_sparks.radial_accel_max = 40.0
	boss_sparks.damping_min = 5.0
	boss_sparks.damping_max = 20.0
	boss_sparks.scale_amount_min = .03
	boss_sparks.scale_amount_max = .09
	var fade := Gradient.new()
	fade.set_color(0, Color(1, .85, .5, .9))
	fade.set_color(1, Color(1, .79, .3, 0))
	boss_sparks.color_ramp = fade
	boss_sparks.emitting = false
	add_child(boss_sparks)

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
	if batching and outline.a > 0 and width <= 2.0:
		if fill.a > 0:
			var base_fill: int = tri_points.size()
			for i in range(sides):
				var a: float = rotation + i * TAU / sides
				tri_points.append(center + Vector2(cos(a), sin(a)) * radius)
				tri_colors.append(fill)
			for i in range(1, sides - 1):
				tri_indices.append(base_fill)
				tri_indices.append(base_fill + i)
				tri_indices.append(base_fill + i + 1)
		var prev: Vector2 = center + Vector2(cos(rotation), sin(rotation)) * radius
		for i in range(1, sides + 1):
			var a: float = rotation + i * TAU / sides
			var next: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			seg_points.append(prev)
			seg_points.append(next)
			seg_colors.append(outline)
			prev = next
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
	text = TranslationServer.translate(text)
	if not scene_transform.is_equal_approx(Transform2D.IDENTITY):
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func ink_outlined(text: String, pos: Vector2, color: Color, size: int) -> void:
	text = TranslationServer.translate(text)
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

func mandel_orbit(point: Vector2) -> Dictionary:
	# Map the threat's screen position to its c in the fractal currently on screen
	# (the same mapping the shader uses), then iterate z -> z^2 + c from z = 0.
	var u: float = float(sim.ult.get("age", 0.0))
	var view_h: float = maxf(1.0, get_viewport_rect().size.y)
	var px: float = get_global_transform().get_scale().y
	var disc: float = sim.mandel_radius(u) * px / view_h
	var per_unit: float = maxf(1e-9, ultimate_art.mandel_scale(u, disc) * px / view_h)
	var focus: Vector2 = ultimate_art.mandel_focus(u)
	var core: Vector2 = sim.defense_position()
	var c: Vector2 = focus + Vector2(point.x - core.x, core.y - point.y) * per_unit
	var z := Vector2.ZERO
	var points := PackedVector2Array([point])
	var bounds: Rect2 = sim.spawn_rect.grow(60)
	var escaped: bool = false
	for i in range(16):
		z = Vector2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c
		var q: Vector2 = core + Vector2(z.x - focus.x, focus.y - z.y) / per_unit
		if z.length() > 2.0 or not bounds.has_point(q):
			# Escapes to infinity: one last leap straight off the screen.
			var away: Vector2 = (q - points[points.size() - 1])
			if away.length() < 1.0:
				away = point - core
			points.append(points[points.size() - 1] + away.normalized() * 1400.0)
			escaped = true
			break
		points.append(q)
	return {"points": points, "escaped": escaped}

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
		b_turns.append(0)
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
	# Only the silo fires a cosmetic barrage; every later weapon has its own attack art.
	if index == 0:
		spawn_barrage(index, muzzle, destination, critical)
	core_pulse = 1.0
	if muzzle_limits[index] > 0:
		return
	muzzle_limits[index] = .075
	add_feedback("muzzle", point + Vector2(cos(aims[index]), sin(aims[index])) * 14, index, 7 + index, .12)
	if critical:
		add_feedback("critical", destination, index, 16, .3)

func on_hit(point: Vector2, index: int, amount: float, critical: bool, boss: bool, _kind: String) -> void:
	# Rounds pop their own small numbers on arrival; whole-hit numbers are kept
	# for the big moments: criticals and boss hits.
	if boss and amount > 0:
		# Boss hits from every gun are summed and shown as one number on the rim,
		# never piled over the boss itself.
		boss_hit_sum += amount
		boss_hit_crit = boss_hit_crit or critical
		if boss_hit_clock <= 0.0 and numbers.size() < NUMBER_CAP:
			var target: Dictionary = sim.boss_actor()
			var r: float = float(target.radius) if not target.is_empty() else 60.0
			var rim: Vector2 = point + Vector2.from_angle(randf_range(-PI * .95, -PI * .05)) * (r * 1.35 + 18.0)
			add_number(rim, boss_hit_sum, boss_hit_crit, true, 22)
			boss_hit_sum = 0.0
			boss_hit_crit = false
			boss_hit_clock = .16
	elif amount > 0 and critical and number_limits[index] <= 0 and numbers.size() < NUMBER_CAP:
		number_limits[index] = .1
		add_number(point + Vector2(randf_range(-10, 10), -10), amount, critical, false, 18)
	if spark_limits[index] > 0:
		return
	spark_limits[index] = .085
	add_feedback("spark", point, index, 16 if critical else 10, .22)

var boss_hit_sum: float = 0.0
var boss_hit_crit: bool = false
var boss_hit_clock: float = 0.0

func add_number(pos: Vector2, value: float, critical: bool, boss: bool, size: int) -> void:
	# Skip a number that would land on top of a fresh one: overlapping digits read as noise.
	if not boss:
		for n in numbers:
			if float(n.age) < .3 and Vector2(n.pos).distance_squared_to(pos) < 26.0 * 26.0:
				return
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
	if sim.deferred_kill and str(sim.ult.get("kind", "")) in ["foil", "prime", "lightspeed", "pi", "droplet", "fourier", "mandelbrot", "strings"]:
		return
	add_feedback("shards", point, index, 10 + minf(14, log(maxf(1, members)) * 1.2), .5)

func on_pierced(origin: Vector2, destination: Vector2, index: int) -> void:
	if pierce_limits[index] > 0:
		return
	pierce_limits[index] = .14
	add_feedback("pierce", origin, index, 1, .22, destination)

func on_destroyed(point: Vector2, index: int, members: int, boss: bool, _kind: String) -> void:
	# These clears have their own physical language. Ordinary explosion rings
	# would conceal the unfolding faces, execution columns and metric rupture.
	if not boss and sim.deferred_kill and str(sim.ult.get("kind", "")) in ["foil", "prime", "lightspeed", "pi", "droplet", "fourier", "mandelbrot", "strings"]:
		if str(sim.ult.get("kind", "")) == "mandelbrot" and feedback.size() < 120:
			# The threat runs its own iteration z -> z^2 + c from where it stands.
			var orbit: Dictionary = mandel_orbit(point)
			add_feedback("mandel", point, index, 8.0 + minf(10.0, log(maxf(1, members)) * 2.0), 1.1 if bool(orbit.escaped) else 1.3)
			feedback.back()["orbit"] = orbit.points
			feedback.back()["escaped"] = orbit.escaped
		return
	if boss and feedback.size() >= 140:
		feedback_pool.append(feedback.pop_front())
	var size: float = 110 if boss else 18 + minf(20, log(maxf(1, members)) * 2)
	add_feedback("boss_death" if boss else "shards", point, index, size, 2.2 if boss else .7)
	add_feedback("flash", point, index, size * (5.0 if boss else 2.6), .9 if boss else .28)
	add_feedback("embers", point, index, size, 1.6 if boss else 1.0)
	add_wave(point, 60.0 if boss else 5.0 + minf(9.0, log(maxf(1, members))), 1.8 if boss else 1.0)
	# Loot flies to the money counter: the visible half of every reward.
	for k in range(0 if sim.deferred_kill else (3 if boss else (1 if members < 50 else 2))):
		if coins.size() >= COIN_CAP:
			break
		var burst := Vector2.from_angle(randf() * TAU) * randf_range(30, 80)
		coins.append({"from": point, "ctrl": point + burst, "age": -k * .05, "dur": randf_range(.55, .8)})
	# Shake is reserved for big moments; constant hit shake read as stutter.
	if boss:
		trauma = .75
		slowmo_request = true
		punch = 1.0
		# The energy layer outlives the body by a breath: it flares, ruptures and rings out.
		boss_dying = 0.0

func on_ultimate_loot(point: Vector2, members: int, flight: float) -> void:
	# Continuous curved streams share a soft inlet below the wallet. Slightly
	# different flight times keep the shower from moving as one rigid sheet.
	add_wave(point, 14.0, .45)
	for k in range(8 if members < 50 else 12):
		if coins.size() >= ULT_COIN_CAP:
			break
		var burst := Vector2.from_angle(randf() * TAU) * randf_range(90, 155)
		coins.append({"from": point, "ctrl": point + burst, "age": 0.0, "dur": flight * (1.0 if k == 0 else randf_range(.86, 1.0)), "ultimate": true, "lane": randf_range(-35, 35), "phase": randf() * TAU})

func update_boss_fx(delta: float) -> void:
	var boss: Dictionary = sim.boss_actor() if sim != null and sim.mode == "boss" else {}
	var live: bool = not boss.is_empty() and not reduced_effects
	if live:
		var radius: float = float(boss.radius)
		var lead: float = clampf((float(boss.age) + render_lead) / float(boss.lifetime), 0, 1)
		boss_last = {"kind": str(boss.kind), "radius": radius, "at": Vector2(boss.start).lerp(boss.end, lead) if not sim.paused else Vector2(boss.pos), "heading": (Vector2(boss.end) - Vector2(boss.start)).angle(), "hurt": 1.0 - clampf(float(boss.hp) / maxf(1.0, sim.boss_max_hp()), 0, 1)}
		boss_dying = -1.0
		var flash: float = clampf(float(boss.get("flash", 0.0)) / .09, 0, 1)
		boss_hit_age += delta
		if flash > .5 and boss_hit_age > .9:
			boss_hit_age = 0.0
	elif boss_dying >= 0.0:
		boss_dying += delta
		if boss_dying > 1.8:
			boss_dying = -1.0
	var on: bool = (live or boss_dying >= 0.0) and not boss_last.is_empty() and not reduced_effects
	boss_fx.visible = on
	boss_sparks.emitting = live
	if not on:
		return
	var kind: String = str(boss_last.kind)
	var radius: float = float(boss_last.radius)
	var at: Vector2 = boss_last.at
	# The shader square is sized so its body matches the drawn silhouette; dying, it grows to hold the blast.
	var body: float = float(BOSS_FX_BODY.get(kind, .3)) / (2.4 if boss_dying >= 0.0 else 1.0)
	var side: float = radius * (1.15 if kind == "star" else 1.0) / body
	boss_fx.position = at - Vector2.ONE * side * .5
	boss_fx.size = Vector2.ONE * side
	var m: ShaderMaterial = boss_fx.material
	m.set_shader_parameter("kind", int(BOSS_FX_KIND.get(kind, 2)))
	m.set_shader_parameter("time", clock)
	m.set_shader_parameter("body", body)
	m.set_shader_parameter("flash", clampf(float(boss.get("flash", 0.0)) / .09, 0, 1) if live else 0.0)
	m.set_shader_parameter("hit_age", boss_hit_age)
	m.set_shader_parameter("enrage", 1.0 if sim.enraged and live else 0.0)
	m.set_shader_parameter("spin", clock * (.55 if kind == "cigar" else .9))
	m.set_shader_parameter("heading", float(boss_last.heading))
	m.set_shader_parameter("aim", (sim.defense_position() - at).angle())
	m.set_shader_parameter("hurt", float(boss_last.hurt))
	m.set_shader_parameter("dying", maxf(0.0, boss_dying))
	var dk: float = doppler_k() if live else 0.0
	var motion: Vector2 = Vector2.from_angle(float(boss_last.heading))
	var approach: float = motion.dot((sim.defense_position() - at).normalized())
	m.set_shader_parameter("doppler", dk)
	m.set_shader_parameter("approach", approach)
	boss_sparks.modulate = Color.WHITE.lerp(BLUE_SHIFT if approach > 0 else RED_SHIFT, dk * .9)
	boss_sparks.position = at
	if kind != boss_fx_kind:
		boss_fx_kind = kind
		style_boss_sparks(kind, radius, float(boss_last.heading))

func style_boss_sparks(kind: String, radius: float, heading: float) -> void:
	# Each boss sheds its own matter: embers, exhaust, motes, infalling light.
	var s: CPUParticles2D = boss_sparks
	s.emission_sphere_radius = radius * (1.1 if kind == "star" else .5 if kind == "magnetar" else .9)
	s.direction = Vector2.UP
	s.spread = 180.0
	s.gravity = Vector2.ZERO
	s.initial_velocity_min = 20.0
	s.initial_velocity_max = 70.0
	s.radial_accel_min = 10.0
	s.radial_accel_max = 40.0
	s.lifetime = 1.8
	s.scale_amount_min = .03
	s.scale_amount_max = .09
	match kind:
		"asteroid":
			# Burning entry: embers ripped off the face and streamed back along the fire.
			var back := -Vector2.from_angle(heading)
			s.direction = back
			s.spread = 28.0
			s.gravity = back * 140.0
			s.initial_velocity_min = 80.0
			s.initial_velocity_max = 220.0
			s.radial_accel_min = 0.0
			s.radial_accel_max = 0.0
			s.lifetime = 1.2
		"dwarf", "mothership":
			s.direction = Vector2.UP
			s.spread = 22.0
			s.gravity = Vector2(0, -90)
			s.initial_velocity_min = 60.0
			s.initial_velocity_max = 160.0
			s.lifetime = 1.1
		"cathedral":
			s.gravity = Vector2(0, -25)
			s.initial_velocity_min = 8.0
			s.initial_velocity_max = 30.0
			s.lifetime = 2.6
		"rift":
			# Light falling in, never coming out.
			s.emission_sphere_radius = radius * 2.4
			s.initial_velocity_min = 0.0
			s.initial_velocity_max = 10.0
			s.radial_accel_min = -260.0
			s.radial_accel_max = -160.0
			s.lifetime = 1.0
		"brane":
			s.emission_sphere_radius = radius * 1.25
			s.radial_accel_min = 30.0
			s.radial_accel_max = 80.0
			s.lifetime = 2.2

func animate(delta: float, real_delta: float = -1.0) -> void:
	update_boss_fx(delta)
	intro_t = maxf(0.0, intro_t - (real_delta if real_delta >= 0.0 else delta))
	if not skill_pop.is_empty():
		skill_pop.age = float(skill_pop.age) + delta
	animate_ultimates(delta)
	trauma = maxf(0, trauma - delta * 2.3)
	boss_hit_clock = maxf(0.0, boss_hit_clock - delta)
	core_pulse = maxf(0, core_pulse - delta * 6)
	for i in range(WEAPONS):
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
	atlas.advance(delta, self)
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
			show_banner(TranslationServer.translate("第 %02d 波") % sim.wave, TranslationServer.translate(sim.stage_data().title) + "  ·  " + TranslationServer.translate(sim.stage_data().scale_label), 1.3)
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
		if bool(coins[i].get("ultimate", false)) and sim.paused:
			continue
		var coin_delta: float = real_delta if bool(coins[i].get("ultimate", false)) and real_delta >= 0.0 else delta
		coins[i].age = float(coins[i].age) + coin_delta
		if float(coins[i].age) >= float(coins[i].dur):
			if bool(coins[i].get("ultimate", false)):
				ult_arrivals += 1
			coins.remove_at(i)
			coin_arrivals += 1
	if sim != null and sim.mode != last_mode:
		# The boss entrance is staged by the HUD cinematic.
		if sim.mode == "intermission":
			show_banner(TranslationServer.translate("第 10 波完成"), TranslationServer.translate("巨型威胁即将降临"), 2.6)
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
	var field_r: float = sim.magnet_field_radius() if sim != null else 0.0
	var field_boss: int = -1
	var field_at := Vector2.ZERO
	if field_r > 0.0:
		var magnetar: Dictionary = sim.boss_actor()
		field_boss = int(magnetar.id)
		field_at = magnetar.pos
	while i < alive:
		b_age[i] += delta
		if b_age[i] >= 0 and b_target[i] >= 0 and not living.has(b_target[i]) and b_age[i] < b_dur[i]:
			redirect_round(i, living)
		elif field_r > 0.0 and b_target[i] == field_boss and b_crit[i] & 4 == 0 and b_age[i] >= 0 and b_age[i] < b_dur[i]:
			var here: Vector2 = round_position(i, clampf(b_age[i] / b_dur[i], 0, 1))
			if here.distance_to(field_at) <= field_r:
				b_crit[i] = b_crit[i] | 4
				if randf() < sim.MAGNET_DEFLECT:
					deflect_round(i, here)
		if b_age[i] >= b_dur[i]:
			if b_value[i] >= 1.0 and numbers.size() < NUMBER_CAP and numbers_this_frame < 4:
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
			b_turns[i] = b_turns[alive]
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
		b_turns.resize(alive)

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
		if b_target[i] != target_id and b_target[i] >= 0 and b_turns[i] < sim.MAX_RETARGETS and b_age[i] < b_dur[i]:
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
	b_turns[i] = b_turns[i] + 1
	b_crit[i] = b_crit[i] | 2

func deflect_round(i: int, here: Vector2) -> void:
	# Bent by the magnetar's field: a curving exit off the screen, no damage.
	var t: float = clampf(b_age[i] / b_dur[i], 0, 1)
	var dir: Vector2 = (here - round_position(i, maxf(0, t - .03))).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var side: float = 1.0 if randf() < .5 else -1.0
	var out: Vector2 = dir.rotated(side * randf_range(.9, 1.5))
	b_from[i] = here
	b_ctrl[i] = here + dir * 90.0
	b_to[i] = here + out * 1400.0
	b_age[i] = 0.0
	b_paths[i] = curve_lengths(b_from[i], b_ctrl[i], b_to[i])
	b_dur[i] = maxf(.001, b_paths[i][-1] / sim.PROJECTILE_SPEED)
	b_target[i] = -1
	b_value[i] = 0.0
	b_crit[i] = b_crit[i] | 2
	if spark_limits[0] <= 0:
		spark_limits[0] = .05
		add_feedback("spark", here, 0, 9.0, .2)

func on_shot_deflected(point: Vector2, heading: Vector2, turned: float) -> void:
	add_feedback("spark", point, 1, 12.0, .25)

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
	if b_turns[i] >= sim.MAX_RETARGETS:
		# Out of turns: no new target; the round flies straight off the screen.
		followed = -1
		living = {}
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
		b_turns[i] = b_turns[i] + 1
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
	coins.clear()
	coin_arrivals = 0
	ult_arrivals = 0
	prev_levels = {}
	growth.clear()
	for i in range(WEAPONS):
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
		for i in range(WEAPONS):
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
	for i in range(WEAPONS):
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

# Inside the lowered-light-speed domain everything that moves is Doppler shifted
# as seen from the core: approaching = blue, receding = red, smeared along its motion.
const RED_SHIFT := Color("ff6b55")
const BLUE_SHIFT := Color("6fb8ff")

func doppler_k() -> float:
	if sim == null or sim.ult.is_empty() or str(sim.ult.kind) != "lightspeed":
		return 0.0
	return ultimate_art.doppler_strength(float(sim.ult.age))

func doppler_ghosts(p: Vector2, r: float, motion: Vector2, k: float) -> void:
	# Light lag: a blue image runs ahead of the body and a red one trails behind.
	if k <= .01 or motion == Vector2.ZERO:
		return
	var dir: Vector2 = motion.normalized()
	var lag: float = minf(r, 30.0) * (.5 + 1.8 * k)
	var segs: int = clampi(int(r), 16, 72)
	draw_arc(p + dir * lag, r, 0, TAU, segs, Color(BLUE_SHIFT, .15 * k), maxf(3.0, r * .12), true)
	draw_arc(p + dir * lag, r, 0, TAU, segs, Color(BLUE_SHIFT, .6 * k), 1.6, true)
	draw_arc(p - dir * lag, r, 0, TAU, segs, Color(RED_SHIFT, .15 * k), maxf(3.0, r * .12), true)
	draw_arc(p - dir * lag, r, 0, TAU, segs, Color(RED_SHIFT, .6 * k), 1.6, true)

func doppler_tint(base: Color, at: Vector2, motion: Vector2, k: float) -> Color:
	if k <= 0.0 or motion == Vector2.ZERO:
		return base
	var toward: float = motion.normalized().dot((sim.defense_position() - at).normalized())
	var shift: Color = BLUE_SHIFT if toward > 0 else RED_SHIFT
	return Color(base.lerp(shift, clampf(absf(toward) * 1.3, 0, 1) * k * .95), base.a)

func draw_bullets() -> void:
	# All rounds go out in three batched calls: white trails, amber trails, heads.
	var trails := PackedVector2Array()
	var hot := PackedVector2Array()
	var heads := PackedVector2Array()
	var needles := PackedVector2Array()
	var round_look: int = sim.stage if sim != null else 0
	sr_trails.clear()
	sr_hot.clear()
	sr_heads.clear()
	sr_needles.clear()
	sr_bright.clear()
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
		var back: Vector2 = pos - dir * 14.0 * grow
		var crit: bool = b_crit[i] & 1 == 1
		if round_look > 0:
			scale_round(round_look, pos, dir, grow, t, i, style == TURRET_STYLE, crit)
			continue
		# Only the silo and the turret ring fire cosmetic rounds; chapter weapons
		# draw their own attacks (draw_weapon_rounds / draw_sweeps / strikes).
		if style == TURRET_STYLE:
			if crit:
				hot.append(pos - dir * 10.0 * grow)
				hot.append(pos)
			else:
				needles.append(pos - dir * 10.0 * grow)
				needles.append(pos)
			continue
		if crit:
			hot.append(back)
			hot.append(pos)
		else:
			trails.append(back)
			trails.append(pos)
		heads.append(pos)
		heads.append(pos + dir * 2.5)
	# Scale rounds were collected in `sr` (packed arrays are passed by value).
	trails.append_array(sr_trails)
	hot.append_array(sr_hot)
	heads.append_array(sr_heads)
	needles.append_array(sr_needles)
	var bright: PackedVector2Array = sr_bright
	glow_trails = trails
	glow_heads = heads
	# Rounds fly away from the core: in the slow-light domain they burn red.
	var dk: float = doppler_k()
	var red_k: float = dk * .9
	if trails.size() > 1:
		draw_multiline(trails, Color(INK.lerp(RED_SHIFT, red_k), .45 + .35 * dk), 1.4 + 1.2 * dk)
	if hot.size() > 1:
		draw_multiline(hot, Color(ACCENT.lerp(RED_SHIFT, red_k), .75), 1.6)
	if heads.size() > 1:
		draw_multiline(heads, INK.lerp(Color(1, .72, .66), red_k), 3.0)
	if needles.size() > 1:
		draw_multiline(needles, Color(GREY.lerp(RED_SHIFT, red_k), .95), 1.3)
	if bright.size() > 1:
		draw_multiline(bright, Color(1, 1, 1, .95).lerp(RED_SHIFT, red_k), 2.0)

# Scale-round segments, appended in place (members, so no copies per append).
var sr_trails := PackedVector2Array()
var sr_hot := PackedVector2Array()
var sr_heads := PackedVector2Array()
var sr_needles := PackedVector2Array()
var sr_bright := PackedVector2Array()

func seg(key: String, a: Vector2, b: Vector2) -> void:
	match key:
		"trails":
			sr_trails.append(a)
			sr_trails.append(b)
		"hot":
			sr_hot.append(a)
			sr_hot.append(b)
		"heads":
			sr_heads.append(a)
			sr_heads.append(b)
		"needles":
			sr_needles.append(a)
			sr_needles.append(b)
		_:
			sr_bright.append(a)
			sr_bright.append(b)

func scale_round(look: int, pos: Vector2, dir: Vector2, grow: float, t: float, i: int, small: bool, crit: bool) -> void:
	# One projectile per scale (chapter 1 keeps the classic tracer in draw_bullets).
	var k: float = .7 if small else 1.0
	var nrm: Vector2 = dir.orthogonal()
	var lines: String = "hot" if crit else ("needles" if small else "trails")
	var core: String = "hot" if crit else "bright"
	match look:
		1:
			# Earth orbit - rail slug: a hard bright head with crackling sparks along it.
			seg(core, pos - dir * 4.0 * k, pos)
			var flick: float = 1.0 if (i + int(clock * 30.0)) % 2 == 0 else -1.0
			seg("hot", pos - dir * 6.0 * k, pos - dir * 9.0 * k + nrm * 3.0 * flick * k)
			seg(lines, pos - dir * 14.0 * grow * k, pos - dir * 5.0 * k)
		2:
			# Inner system - plasma: a soft ball (a cross of short strokes) with a short wake.
			for a in [0.0, PI * .5, PI * .25, -PI * .25]:
				var d: Vector2 = dir.rotated(a) * 2.6 * k
				seg("hot" if crit else "heads", pos - d, pos + d)
			seg(lines, pos - dir * 10.0 * grow * k, pos - dir * 3.0 * k)
		3:
			# Outer system - rail needle: long, thin, bright-tipped.
			seg(lines, pos - dir * 28.0 * grow * k, pos)
			seg(core, pos - dir * 3.0, pos)
		4:
			# Oort cloud - ice shard: a spinning diamond.
			var spin_dir: Vector2 = dir.rotated(t * 14.0 + i)
			var side: Vector2 = spin_dir.orthogonal()
			var tip: Vector2 = pos + spin_dir * 5.0 * k
			var tail: Vector2 = pos - spin_dir * 5.0 * k
			var l: Vector2 = pos + side * 2.2 * k
			var r: Vector2 = pos - side * 2.2 * k
			seg(core, tip, l)
			seg(core, l, tail)
			seg(core, tail, r)
			seg(core, r, tip)
		5:
			# Stellar neighbourhood - photon: a short, bright dash.
			seg(core, pos - dir * 9.0 * grow * k, pos)
			seg(lines, pos - dir * 18.0 * grow * k, pos - dir * 9.0 * k)
		6:
			# Milky Way - pulse: a small breathing hexagon.
			var r: float = (2.6 + 1.4 * sin(t * 24.0 + i)) * k
			var ring_key: String = "hot" if crit or i % 2 == 0 else "needles"
			for j in range(6):
				seg(ring_key, pos + Vector2.from_angle(j * TAU / 6) * r, pos + Vector2.from_angle((j + 1) * TAU / 6) * r)
		7:
			# Supercluster - graviton: a lensing ring around a pin-point core.
			for j in range(6):
				seg("hot", pos + Vector2.from_angle(j * TAU / 6 + t * 6.0) * 4.0 * k, pos + Vector2.from_angle((j + 1) * TAU / 6 + t * 6.0) * 4.0 * k)
			seg("bright", pos - dir * 1.0, pos + dir * 1.0)
		8:
			# Observable universe - cosmic ray: a zig-zag streak.
			var p0: Vector2 = pos - dir * 16.0 * grow * k
			var pts: Array[Vector2] = []
			for j in range(5):
				var wiggle: float = 0.0 if j == 0 or j == 4 else (2.5 if j % 2 else -2.5)
				pts.append(p0.lerp(pos, j / 4.0) + nrm * wiggle * k)
			for j in range(4):
				seg(core, pts[j], pts[j + 1])
		9:
			# The brane - string: a short vibrating sine segment.
			var p0: Vector2 = pos - dir * 14.0 * grow * k
			var phase: float = clock * 30.0 + i
			for j in range(5):
				seg("hot", p0.lerp(pos, j / 5.0) + nrm * sin(phase + j * 1.3) * 2.4 * k, p0.lerp(pos, (j + 1) / 5.0) + nrm * sin(phase + (j + 1) * 1.3) * 2.4 * k)

func scale_spark(look: int, p: Vector2, r: float, t: float, fade: float, col: Color, seed_value: float) -> void:
	var ease: float = 1.0 - pow(1.0 - t, 3)
	match look:
		1:
			# Electric: three jagged little arcs.
			for j in range(3):
				var a: float = j * TAU / 3 + seed_value
				var mid: Vector2 = p + Vector2.from_angle(a + .4) * r * .5 * ease
				stroke(p, mid, Color(col, fade))
				stroke(mid, p + Vector2.from_angle(a) * r * (.7 + ease * .5), Color(ACCENT, fade))
		2:
			# Plasma splash: a hot disc and a soft ring.
			draw_circle(p, r * .45 * (1.0 - t), Color(col, fade * .6))
			ring(p, r * (.5 + ease * .8), Color(col, fade), 1.2)
		3:
			# Pierce: one long bright line straight through the point.
			var d: Vector2 = Vector2.from_angle(seed_value)
			stroke(p - d * r * (.4 + ease * 1.4), p + d * r * (.4 + ease * 1.4), Color(col, fade))
		4:
			# Ice: little diamonds flung out.
			for j in range(5):
				var a: float = j * TAU / 5 + seed_value
				shape(p + Vector2.from_angle(a) * r * (.3 + ease * 1.1), 2.2 * (1.0 - t) + .5, 4, a, Color(col, fade))
		5:
			# Photon: a clean expanding halo.
			ring(p, r * (.3 + ease * 1.5), Color(col, fade), 1.6)
		6:
			# Pulse: two ripples.
			ring(p, r * (.3 + ease), Color(col, fade), 1.2)
			ring(p, r * (.1 + ease * .6), Color(ACCENT, fade * .7), 1.0)
		7:
			# Graviton: space pinching in - a ring that contracts.
			ring(p, r * (1.4 - ease * 1.1), Color(ACCENT, fade), 1.4)
			ring(p, r * .25, Color(col, fade), 1.0)
		8:
			# Cosmic ray: forked lightning.
			for j in range(3):
				var a: float = seed_value + j * 2.1
				var mid: Vector2 = p + Vector2.from_angle(a) * r * .6 * ease
				stroke(p, mid, Color(col, fade))
				stroke(mid, mid + Vector2.from_angle(a + .7) * r * .5 * ease, Color(col, fade * .8))
				stroke(mid, mid + Vector2.from_angle(a - .7) * r * .5 * ease, Color(col, fade * .8))
		9:
			# String: a wavy ring still ringing.
			var last: Vector2 = Vector2.ZERO
			for j in range(25):
				var a: float = j * TAU / 24
				var q: Vector2 = p + Vector2.from_angle(a) * r * (.5 + ease * .8) * (1.0 + .12 * sin(a * 6.0 + t * 20.0) * (1.0 - t))
				if j > 0:
					stroke(last, q, Color(ACCENT, fade))
				last = q
		_:
			ring(p, r * (.4 + t), Color(col, fade), 1.5)
			for j in range(4):
				var a: float = j * TAU / 4 + seed_value
				var dir := Vector2(cos(a), sin(a))
				stroke(p + dir * r * t, p + dir * r * (t + .35), Color(col, fade))

func coin_position(c: Dictionary, age_offset: float = 0.0) -> Vector2:
	var t: float = clampf((float(c.age) + age_offset) / float(c.dur), 0, 1)
	var e: float = t * t
	var from: Vector2 = c.from
	var ctrl: Vector2 = c.ctrl
	if bool(c.get("ultimate", false)):
		# One cubic path and one smooth clock: no stop/jump between scatter
		# and suction, and no velocity snap when the stream reaches the HUD.
		var u: float = t * t * (3.0 - 2.0 * t)
		var inlet: Vector2 = money_anchor + Vector2(float(c.get("lane", 0.0)), 85.0)
		var a: Vector2 = from.lerp(ctrl, u)
		var b: Vector2 = ctrl.lerp(inlet, u)
		var d: Vector2 = inlet.lerp(money_anchor, u)
		var point: Vector2 = a.lerp(b, u).lerp(b.lerp(d, u), u)
		var side: Vector2 = (money_anchor - from).normalized().orthogonal()
		return point + side * sin(u * TAU + float(c.get("phase", 0.0))) * sin(PI * t) * sin(PI * t) * 10.0
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
	if not show_reticle or unified_cursor:
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
			combo_line.add_string(TranslationServer.translate("连击 ×") + sim.Catalog.number(combo), font, 26)
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
	var prof: int = Time.get_ticks_usec()
	draw_glow_layer()
	profile_add("glow", prof)

func draw_glow_layer() -> void:
	# Everything here is additive: overlaps brighten instead of covering.
	if sim == null or reduced_effects:
		return
	if sim.mode == "transition":
		var reveal: float = smoothstep(4.2,6.2,sim.mode_time)
		var center: Vector2 = sim.defense_position_at(sim.stage+1)
		var halo: float = core_outer*(2.2+core_pulse*.6)
		glow.draw_texture_rect(GlowTexture,Rect2(center-Vector2.ONE*halo,Vector2.ONE*halo*2),false,Color(1,1,1,(.16+core_pulse*.12)*reveal))
		for s in range(sim.stage+1):
			for k in range(sim.BODIES[s].size()):
				if not sim.body_converted_at(s,k): continue
				var index: int = k
				for previous in range(s): index += sim.BODIES[previous].size()
				var at: Vector2 = center+Vector2.from_angle(index*.71+sim.elapsed*.25)*(150.0+index%3*14.0)
				var r: float = (float(sim.BODIES[s][k].size)*3.2+26.0)*.4
				glow.draw_texture_rect(GlowTexture,Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2),false,Color(1,1,1,.18*reveal))
		for i in range(DUST):
			var r: float = dust_radius[i]
			var spot: Vector2 = center+Vector2.from_angle(dust_angle[i])*r
			var near: float = clampf(1.0-r/600.0,0,1)
			var radius: float = 2.5+near*2.5
			glow.draw_texture_rect(GlowTexture,Rect2(spot-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(1,1,1,(.1+near*.25)*reveal))
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
				for w in range(WEAPONS):
					if sim.owned[w]:
						origins.append(sim.weapon_origin(w))
				for o in origins:
					stroke(o, o.lerp(p, reach), Color(ACCENT, fade * .55), 1.2)
				ring(p, r + 14 + (1 - fade) * 26, Color(ACCENT, fade), 1.6)
			"mandel":
				# The threat hops along its own orbit of z -> z^2 + c: escapers leap
				# off the screen and burst, prisoners spiral into the set and vanish.
				var orbit: PackedVector2Array = fx.get("orbit", PackedVector2Array([p]))
				var escaped: bool = bool(fx.get("escaped", true))
				var last: int = orbit.size() - 1
				var hop: float = clampf(t * 1.15, 0, 1) * last
				var reached: int = int(hop)
				var ghost: Vector2 = orbit[mini(reached, last)].lerp(orbit[mini(reached + 1, last)], hop - reached)
				for j in range(mini(reached + 1, last)):
					if escaped and j == last - 1:
						break
					draw_line(orbit[j], orbit[j + 1], Color(ACCENT, fade * .22), 5.0, true)
					draw_line(orbit[j], orbit[j + 1], Color(ACCENT, fade), 1.6, true)
					draw_circle(orbit[j + 1], 2.6, Color(1, 1, 1, fade))
				if escaped and reached >= last - 1:
					# The leap to infinity: a streak and a burst where it left.
					var leave: Vector2 = orbit[last - 1]
					stroke(leave, ghost, Color(INK, fade * .8))
					ring(leave, 6.0 + (hop - (last - 1)) * 30.0, Color(ACCENT, fade), 1.4)
				elif not escaped and t > .75:
					ring(ghost, r * (1.0 - (t - .75) / .25) + 1.0, Color(INK, fade), 1.2)
				draw_circle(ghost, r * .9 * (1.0 - t * .5) + 2.0, Color(1, .85, .5, .2 * fade))
				shape(ghost, r * .5 * (1.0 - t * .5) + 1.5, 4, t * 9.0 + seed_value, Color(Color.WHITE, fade))
			"click":
				var ease: float = 1 - pow(1 - t, 3)
				ring(p, r * (.3 + ease), Color(INK, fade * .8), 1.4)
				for j in range(6):
					var dir := Vector2.from_angle(j * TAU / 6 + .3)
					stroke(p + dir * r * (.4 + ease * .7), p + dir * r * (.6 + ease * .9), Color(INK, fade))
			"spark", "critical":
				var col: Color = ACCENT if fx.kind == "critical" else INK
				scale_spark(sim.stage if sim != null else 0, p, r, t, fade, col, seed_value)
				if fx.kind == "critical":
					ink(TranslationServer.translate("暴击"), p + Vector2(14, -16 - t * 12), Color(ACCENT, fade), 12)
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

func core(center: Vector2, layers: int, live: bool = false, view_stage: int = -1, reveal: float = 1.0) -> void:
	var stage_now: int = sim.stage if view_stage < 0 else view_stage
	# One hexagonal shell per scale reached; the live core also shows upgrades:
	# damage grows the heart and adds a shell per doubling milestone, launcher
	# tiers orbit as nodes, crit lights amber sparks, pierce/lock links the nodes.
	var swell: float = 1 + core_pulse * .08 + (growth_bounce * .22 if live else 0.0)
	var inner: float = 9.0
	var shells: int = layers
	if live:
		var damage: int = int(sim.levels.damage)
		inner += minf(10.0, damage * .06) * reveal
		for threshold in [10, 25, 50, 75, 100, 125, 150]:
			if damage >= threshold:
				shells += 1
		shells = mini(shells, 10)
	inner *= swell
	var gap: float = 5.0 * swell
	for i in range(shells, 0, -1):
		var spin: float = clock * (.25 if i % 2 else -.18) + i * .3
		shape(center, inner + i * gap, 6, spin, Color(0, 0, 0, 0), Color(GREY if i == 1 else DIM, .9 * (reveal if i > layers else 1.0)), 1.4 if i <= layers else 1.0)
	shape(center, inner, 6, clock * .4, INK)
	var outer: float = inner + shells * gap
	if not live:
		return
	var sparks: int = mini(16, int(sim.levels.crit) / 3)
	for j in range(sparks):
		var a: float = j * TAU / maxi(1, sparks) - clock * .3
		draw_circle(center + Vector2(cos(a), sin(a)) * (outer + 4), 1.6, Color(ACCENT, reveal))
	# Turrets bought with the turret upgrade: each one is a real shooter in the
	# sim and flashes and recoils on its own staggered beat.
	var count: int = sim.turret_count()
	ensure_turret_visuals()
	var city: bool = stage_now == 0
	if count >= 3 and not city and (int(sim.levels.pierce) > 0 or int(sim.levels.targets) > 0):
		var loop := PackedVector2Array()
		for j in range(mini(sim.TURRET_RINGS[0], count)):
			loop.append(sim.turret_position_at(j, stage_now))
		loop.append(loop[0])
		draw_polyline(loop, Color(GREY, .3 * reveal), 1.0, true)
	begin_batch()
	var far: float = outer
	for j in range(count):
		var lit: float = clampf(turret_flash[j] / .12, 0, 1)
		var home: Vector2 = sim.turret_position_at(j, stage_now)
		var arrive: float = smoothstep(float(j) / maxi(1,count) * .25, .7 + float(j) / maxi(1,count) * .25, reveal)
		far = maxf(far, home.distance_to(center))
		var aim: float = turret_aim[j]
		var barrel := Vector2.from_angle(aim)
		var spot: Vector2 = center.lerp(home, arrive) - barrel * 3.0 * lit
		var size: float = (4.6 + 1.2 * lit) * swell * (1.4 if city else 1.0)
		shape(spot, size, 3, aim, Color(GREY.lerp(INK, lit), arrive))
		stroke(spot, spot + barrel * (size + 6), Color(GREY.lerp(INK, lit), .9 * arrive))
	flush_batch()
	var owned_turrets: int = int(sim.levels.get("turrets", 0))
	if owned_turrets > count and count > 0:
		ink("×" + str(owned_turrets), sim.turret_position_at(count - 1,stage_now) + Vector2(16, 6), Color(GREY,reveal), 12)
	core_outer = outer + 16 if city or count == 0 else far + 6

func ensure_turret_visuals() -> void:
	var previous: int = turret_aim.size()
	var count: int = sim.turret_count()
	turret_flash.resize(count)
	turret_aim.resize(count)
	for j in range(previous, count):
		turret_aim[j] = -PI * .5

# Inner solar system: Earth's place on its orbit (the planetary defense shrinks into it).
const EARTH_ANGLE: float = 2.3
const EARTH_ORBIT: float = 165.0

func stage_scene(index: int, preview_reveal: float = -1.0) -> void:
	var c := Vector2(500, 325)
	var time: float = 0.0 if reduced_effects else clock
	match index:
		0:
			for i in range(30):
				var x: float = -150 + i * 44
				var height: float = 26 + fmod(i * 37.3, 96) + (34 if i % 7 == 0 else 0)
				draw_rect(Rect2(x, 600 - height, 34, height), SHADE if i % 2 else Color("191919"))
			draw_line(Vector2(-150, 600), Vector2(1150, 600), DIM, 1.5)
			ink(TranslationServer.translate("01  /  防御控制中心"), Vector2(540, 624), DIM, 12)
		1:
			ring(c, 190, DARK)
			ring(c, 247, DARK)
			draw_circle(c, 81, SHADE)
			ring(c, 81, DIM, 2)
			if index != sim.stage or sim.mode == "transition":
				draw_circle(c + Vector2(247, -33), 9, DARK)
			ink(TranslationServer.translate("地球"), c + Vector2(-15, 106), DIM, 13)
		2:
			# Terrestrial planets inside the main asteroid belt.
			for r in [70.0, 118.0, EARTH_ORBIT, 215.0]:
				ring(c, r, DARK)
			atlas.points_at(self, atlas.belt, c, time * .01)
			var home: Vector2 = c + Vector2.from_angle(EARTH_ANGLE) * EARTH_ORBIT
			draw_circle(home, 6.0, Color("2c2c2c"))
			ring(home, 6.0, GREY, 1.4)
			ring(home, 13.0 + sin(time * 2.0) * 1.5, Color(ACCENT, .35))
			ink(TranslationServer.translate("地球"), home + Vector2(-34, 24), GREY, 12)
			draw_circle(c, 42, SHADE)
			ring(c, 42, GREY, 2)
			ink(TranslationServer.translate("太阳"), c + Vector2(-15, 62), DIM, 13)
			ink(TranslationServer.translate("主小行星带 / MAIN BELT"), Vector2(170, 590), Color(GREY, .8), 12)
		3:
			# Giant planets, with the whole inner system shrunk to a speck at the centre.
			for r in [92.0, 148.0, 205.0, 255.0]:
				ring(c, r, DARK)
			atlas.dashed_ring(self, c, 296.0, Color(DIM, .7), 1.0, 96)
			atlas.points_at(self, atlas.kuiper, c, time * .006)
			for r in [16.0, 22.0, 28.0]:
				ring(c, r, Color(DARK, .9))
			draw_circle(c, 9, Color("3a3a3a"))
			ring(c, 9, GREY, 1.4)
			ink(TranslationServer.translate("太阳"), c + Vector2(-15, 50), DIM, 12)
			ink(TranslationServer.translate("柯伊伯带 / KUIPER BELT"), Vector2(170, 590), Color(GREY, .8), 12)
		_:
			begin_batch()
			atlas.draw(self, index)
			flush_batch()
	core(Vector2(500, 572) if index == 0 else c, index + 1, preview_reveal >= 0.0 or (index == sim.stage and sim.mode != "transition"), index, maxf(0.0,preview_reveal) if preview_reveal >= 0.0 else 1.0)

func body_pick_radius(body_stage: int, slot: int) -> float:
	return 44.0 if body_stage == 7 else 32.0 if body_stage == 8 else float(sim.BODIES[body_stage][slot].size) + 16.0

func body_has_disc(body_stage: int, slot: int) -> bool:
	return bool(sim.BODIES[body_stage][slot].get("disc", true))

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
		if d < body_pick_radius(sim.stage, k) and d < nearest:
			nearest = d
			best = k
	return best

func on_body_fired(body_stage: int, slot: int, origin: Vector2, destination: Vector2, critical: bool) -> void:
	var key: int = body_stage * 16 + slot
	body_flash[key] = BODY_KICK_TIME
	body_aim[key] = (destination - origin).angle()
	var style: int = int(sim.BODIES[body_stage][slot].get("style", body_stage % 6))
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
	begin_batch()
	draw_shells_batched()
	flush_batch()

func draw_shells_batched() -> void:
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
		if bs != sim.stage:
			# Earlier chapters' cannons: a bright pellet with a short tail.
			shape(at, 2.6, 4, clock * 5.0 + slot, col)
			stroke(at, at - dir * 12.0, Color(col, .45))
			continue
		var r: float = 6.5 if bs == sim.stage else 5.0
		var spin: float = clock * 5.0 + slot
		for g in range(3, 0, -1):
			var ghost: Vector2 = at - dir * g * (r * 1.6)
			shell_shape(form, ghost, r * (1.0 - g * .17), spin - g * .35, Color(col, .3 - g * .07), 1.0)
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
			arc_segments(at, r * 1.3, spin, spin + TAU * .8, col)
		"hole":
			for j in range(3):
				arc_segments(at, r * (.45 + j * .3), spin * (1.0 + j * .3) + j, spin * (1.0 + j * .3) + j + 4.0, Color(col, col.a * (1.0 - j * .25)))
		"spiral":
			for j in range(3):
				var a: float = spin + j * TAU / 3
				stroke(at, at + Vector2.from_angle(a) * r * 1.2, col)
				stroke(at + Vector2.from_angle(a) * r * 1.2, at + Vector2.from_angle(a + .7) * r * 1.6, col)
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
	show_banner(TranslationServer.translate(str(sim.BODIES[body_stage][slot].weapon)) + TranslationServer.translate("上线"), TranslationServer.translate(str(sim.BODIES[body_stage][slot].name)) + TranslationServer.translate("  ·  天体改造完成"), 1.9)

func draw_bodies() -> void:
	if sim.mode == "transition":
		return
	var stage_now: int = sim.stage
	body_hover = body_at(hover)
	# Bodies from earlier chapters orbit the core as small trophies: one batched
	# glyph each (silhouette by form, a barrel along their aim, a flash on fire).
	begin_batch()
	for s in range(stage_now):
		for k in range(sim.BODIES[s].size()):
			if not sim.body_converted_at(s, k):
				continue
			var key_small: int = s * 16 + k
			var lit_small: float = pow(clampf(float(body_flash.get(key_small, 0.0)) / BODY_KICK_TIME, 0, 1), 3.0)
			var at_small: Vector2 = sim.body_position(s, k)
			var aim_small: float = float(body_aim.get(key_small, -PI * .5))
			var sides: int = int(SHELL_SIDES.get(str(sim.BODIES[s][k].get("form", "node")), 3 + (k + s) % 5))
			shape(at_small, 4.2 + lit_small * 1.6, sides, aim_small, Color(INK.lerp(Color.WHITE, lit_small), .2 + lit_small * .5), Color(INK, .9), 1.0)
			stroke(at_small, at_small + Vector2.from_angle(aim_small) * (8.0 + lit_small * 4.0), Color(INK, .8))
	flush_batch()
	for s in range(stage_now, stage_now + 1):
		for k in range(sim.BODIES[s].size()):
			var converted: bool = sim.body_converted_at(s, k)
			var at: Vector2 = sim.body_position(s, k)
			var size: float = float(sim.BODIES[s][k].size) if s == stage_now else 5.0
			var key: int = s * 16 + k
			var kick_t: float = 1.0 - clampf(float(body_flash.get(key, 0.0)) / BODY_KICK_TIME, 0, 1)
			var lit: float = pow(1.0 - kick_t, 3.0)
			if s == stage_now:
				# The body itself: rooftops are blocks, the rest their own natural shape.
				if s == 0:
					draw_rect(Rect2(at - Vector2(size, size * .5), Vector2(size * 2, size)), Color("2a2a2a"))
				elif body_has_disc(s, k):
					draw_circle(at, size, Color("2c2c2c").lerp(GREY, .25 if converted else 0.0))
				if not converted and s >= 2 and s != 7:
					natural_glyph(str(sim.BODIES[s][k].get("form", "node")), at, size, k)
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
				if s == stage_now and s not in atlas.MAPPED and hover.distance_to(at) < size + 16:
					ink(TranslationServer.translate(str(sim.BODIES[s][k].weapon)), at + Vector2(-24, -size - 22), INK, 12)
			elif s == stage_now:
				var hovered: bool = k == body_hover
				var dash_r: float = size + 9 + sin(clock * 3 + k) * 1.5
				for j in range(0, 16, 2):
					var a0: float = clock * .4 + j * TAU / 16
					draw_arc(at, dash_r, a0, a0 + TAU / 16, 4, Color(ACCENT if hovered else GREY, .9 if hovered else .45), 1.4, true)
				if hovered and s not in atlas.MAPPED:
					ink(TranslationServer.translate("改造 ") + TranslationServer.translate(str(sim.BODIES[s][k].name)) + "  $" + sim.Catalog.number(sim.body_cost()), at + Vector2(-40, -dash_r - 10), ACCENT, 12)

func draw_form(form: String, at: Vector2, r: float, lit: float, k: int, big: bool, aim: Vector2 = Vector2.UP, build: float = 1.0) -> void:
	# All geometry shares the same local firing axis; only interior rotors spin.
	glyph_base = scene_transform * Transform2D(aim.angle(), at)
	draw_set_transform_matrix(glyph_base)
	at = Vector2.ZERO
	aim = Vector2.RIGHT
	# Each converted body gets its own silhouette so the player can tell them apart.
	var col: Color = Color(INK.lerp(Color.WHITE, lit), .2 + .8 * smoothstep(.1, .65, build))
	var w: float = 1.6 if big else 1.1
	var spin: float = clock * .28 if form == "spiral" and not reduced_effects else 0.0
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
		"potato", "tilted", "trident", "binary", "probe", "sedna", "comet", "lens", "ice", "trinary", "pulsar", "globular", "cluster", "attractor", "wall", "quasar", "cmb", "void", "calabi":
			glyph(form, at, r, col, w, k)
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

func natural_glyph(form: String, at: Vector2, size: float, k: int, alpha: float = 1.0) -> void:
	# Unconverted bodies look like themselves, in quiet grey; conversion turns them white.
	glyph_base = scene_transform
	glyph(form, at, size, Color(GREY, .75 * alpha), 1.1, k, true)

# Transform the glyph's own sub-transforms compose with (draw_form rotates to its aim).
var glyph_base := Transform2D.IDENTITY

func glyph(form: String, at: Vector2, r: float, col: Color, w: float, k: int, natural: bool = false) -> void:
	var t: float = 0.0 if reduced_effects else clock
	var none := Color(0, 0, 0, 0)
	var dim := Color(col, col.a * .45)
	match form:
		"tri":
			shape(at, r, 3, 0, none, col, w)
		"penta":
			shape(at, r, 5, 0, none, col, w)
		"star4", "star5", "star6", "star7", "star8":
			# A star: core dot and diffraction spikes.
			var points: int = int(form.substr(4))
			for j in range(points):
				var dir := Vector2.from_angle(j * TAU / points - PI * .5)
				draw_line(at + dir * r * .25, at + dir * r * (1.25 if j % 2 == 0 else .8), col, w, true)
			draw_circle(at, r * .3, col)
		"octa":
			ring(at, r, col, w)
			for y in [-.35, 0.0, .35]:
				var half: float = sqrt(1.0 - y * y) * r
				draw_line(at + Vector2(-half, y * r), at + Vector2(half, y * r), dim, 1.0, true)
			draw_circle(at + Vector2(r * .35, r * .3), r * .14, col)
		"ringed":
			ring(at, r * .7, col, w)
			draw_set_transform_matrix(glyph_base * Transform2D(-.25, Vector2(1.0, .32), 0, at))
			draw_arc(Vector2.ZERO, r * 1.35, 0, TAU, 40, col, w, true)
			draw_set_transform_matrix(glyph_base)
		"potato":
			var lump := PackedVector2Array()
			for j in range(10):
				var a: float = j * TAU / 10
				lump.append(at + Vector2.from_angle(a) * r * (.8 + .25 * sin(a * 3 + k) + .1 * cos(a * 5)))
			lump.append(lump[0])
			draw_polyline(lump, col, w, true)
			draw_circle(at + Vector2(-r * .2, r * .1), r * .18, dim)
		"tilted":
			# Uranus rolls on its side: the ring stands upright.
			ring(at, r * .7, col, w)
			draw_set_transform_matrix(glyph_base * Transform2D(1.45, Vector2(1.0, .28), 0, at))
			draw_arc(Vector2.ZERO, r * 1.3, 0, TAU, 40, col, w * .9, true)
			draw_set_transform_matrix(glyph_base)
		"trident":
			ring(at, r * .75, col, w)
			draw_circle(at + Vector2(-r * .2, -r * .15), r * .16, dim)
			var moon: Vector2 = at + Vector2.from_angle(-t * .8 + k) * r * 1.6
			draw_arc(at, r * 1.6, 0, TAU, 32, Color(col, col.a * .25), 1.0, true)
			draw_circle(moon, 2.0, col)
		"binary":
			var a: float = t * .9 + k
			for side in [-1.0, 1.0]:
				var q: Vector2 = at + Vector2.from_angle(a) * side * r * (.55 if side < 0 else .9)
				draw_circle(q, r * (.5 if side < 0 else .32), col)
			ring(at, r * .9, Color(col, col.a * .3), 1.0)
		"probe":
			# Voyager: a dish, a magnetometer boom and the thread of its long path home.
			draw_arc(at, r * .7, PI * .6, PI * 1.4, 12, col, w * 1.4, true)
			draw_line(at, at + Vector2(r * 1.6, 0), col, w, true)
			draw_line(at + Vector2(-r * .2, 0), at + Vector2(-r * .2, r * 1.1), dim, 1.0, true)
			draw_circle(at + Vector2(r * .1, 0), 1.8, col)
			if natural:
				var home: Vector2 = Vector2(500, 325)
				var j: float = 0.0
				while j < 1.0:
					draw_line(at.lerp(home, j), at.lerp(home, j + .03), Color(col, col.a * .25), 1.0, true)
					j += .07
		"sedna":
			draw_circle(at, r * .5, col)
			draw_set_transform_matrix(glyph_base * Transform2D(.6, Vector2(1.0, .35), 0, at + Vector2(-r * 3, r)))
			draw_arc(Vector2.ZERO, r * 3.3, -.4, 1.6, 24, Color(col, col.a * .35), 1.0, true)
			draw_set_transform_matrix(glyph_base)
		"comet":
			# Nucleus, coma, and two tails pointing away from the Sun.
			var away: Vector2 = (at - Vector2(500, 325)).normalized() if natural else Vector2.LEFT
			draw_circle(at, r * .3, col)
			ring(at, r * .65, dim, 1.0)
			draw_line(at, at + away * r * 4.2, Color(col, col.a * .6), w, true)
			var bend: Vector2 = (away + away.orthogonal() * .35).normalized()
			draw_line(at, at + bend * r * 3.0, Color(col, col.a * .35), w * 1.6, true)
		"lens":
			# The Sun's gravitational focus: nested Einstein-ring arcs.
			for j in range(3):
				var rr: float = r * (.45 + j * .3)
				draw_arc(at, rr, -1.0 + j * .2, 1.0 - j * .2, 16, col, w, true)
				draw_arc(at, rr, PI - 1.0 + j * .2, PI + 1.0 - j * .2, 16, col, w, true)
			draw_circle(at, 1.8, col)
		"ice":
			for j in range(7):
				var q: Vector2 = at + Vector2.from_angle(j * 2.399 + k) * r * (.25 + (j % 3) * .3)
				shape(q, 2.0 + (j % 2), 4 + j % 3, j + t * .2, col)
		"trinary":
			# Alpha Centauri A and B in a tight orbit, Proxima far out.
			var a: float = t * .6
			draw_circle(at + Vector2.from_angle(a) * r * .45, r * .35, col)
			draw_circle(at - Vector2.from_angle(a) * r * .55, r * .28, col)
			draw_circle(at + Vector2(r * 1.5, -r * 1.1), 1.8, col)
			draw_line(at, at + Vector2(r * 1.5, -r * 1.1), Color(col, col.a * .25), 1.0, true)
		"pulsar":
			var a: float = t * 6.0 + k
			draw_circle(at, r * .3, col)
			for side in [-1.0, 1.0]:
				var dir: Vector2 = Vector2.from_angle(a) * side
				draw_colored_polygon(PackedVector2Array([at + dir * r * .3, at + dir * r * 1.7 + dir.orthogonal() * r * .35, at + dir * r * 1.7 - dir.orthogonal() * r * .35]), Color(col, col.a * .45))
			ring(at, r * .65, dim, 1.0)
		"globular":
			for j in range(18):
				var q: Vector2 = at + Vector2.from_angle(j * 2.399) * r * sqrt((j + .5) / 18.0)
				draw_circle(q, 1.1, col)
			ring(at, r, Color(col, col.a * .25), 1.0)
		"cluster":
			for j in range(7):
				var q: Vector2 = at + Vector2.from_angle(j * 2.1 + k) * r * (.2 + (j % 3) * .32)
				draw_set_transform_matrix(glyph_base * Transform2D(j * .7, Vector2(1.0, .5), 0, q))
				draw_arc(Vector2.ZERO, 3.0 + (j % 2) * 2.0, 0, TAU, 12, col, 1.0, true)
				draw_set_transform_matrix(glyph_base)
		"attractor":
			for j in range(6):
				var dir := Vector2.from_angle(j * TAU / 6 + t * .1)
				draw_line(at + dir * r * 1.4, at + dir * r * .45, Color(col, col.a * .6), w, true)
				draw_line(at + dir * r * .45, at + dir * r * .45 + (dir.rotated(2.5)) * 4.0, col, w, true)
			draw_circle(at, r * .25, col)
		"wall":
			for j in range(6):
				var q: Vector2 = at + Vector2(-r * 1.2 + j * r * .48, sin(j * 1.3 + k) * r * .25)
				draw_circle(q, 1.7, col)
				if j > 0:
					draw_line(q, at + Vector2(-r * 1.2 + (j - 1) * r * .48, sin((j - 1) * 1.3 + k) * r * .25), dim, 1.0, true)
		"quasar":
			draw_circle(at, r * .3, col)
			for side in [-1.0, 1.0]:
				draw_line(at, at + Vector2(0, side * r * 1.8), col, w, true)
				draw_arc(at + Vector2(0, side * r * 1.8), r * .3, 0, TAU, 12, dim, 1.0, true)
		"cmb":
			for j in range(16):
				var a: float = j * TAU / 16
				var rr: float = r * (.85 + .2 * sin(j * 2.7 + k))
				draw_line(at + Vector2.from_angle(a) * rr, at + Vector2.from_angle(a + TAU / 16) * (r * (.85 + .2 * sin((j + 1) * 2.7 + k))), col, w, true)
		"void":
			for j in range(0, 16, 2):
				draw_arc(at, r, j * TAU / 16, (j + 1) * TAU / 16, 4, col, w, true)
			draw_circle(at, 1.2, dim)
		"calabi":
			# A curled-up dimension: every point hides a tiny circle; a bead runs round it.
			var a: float = t * (1.2 + k * .25) + k
			ring(at, r * .62, col, w)
			ring(at, r * .2, Color(col, col.a * .5), 1.0)
			var bead: Vector2 = at + Vector2.from_angle(a) * r * .62
			draw_circle(bead, maxf(1.6, r * .14), col)
			draw_line(bead, bead + Vector2.from_angle(a + PI * .5) * r * .35, Color(col, col.a * .5), 1.0, true)
		_:
			ring(at, r * .7, col, w)

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

func transition_weapon_pose(index: int, outgoing: Transform2D, t: float) -> Dictionary:
	var gather: float = smoothstep(.32, .84, t)
	var old_size: float = .7 if sim.stage > 0 and index < sim.stage else 1.0
	var new_size: float = .7 if index < sim.stage + 1 else 1.0
	return {"point": (outgoing * sim.weapon_origin(index)).lerp(sim.weapon_origin_at(index,sim.stage+1),gather), "scale": lerpf(old_size*pow(.04,t),new_size,gather)}

func draw_incoming_bodies(view_stage: int, reveal: float) -> void:
	if reveal <= .001:
		return
	for k in range(sim.BODIES[view_stage].size()):
		var spec: Dictionary = sim.BODIES[view_stage][k]
		var at: Vector2 = sim.scene_body_position(view_stage,k)
		var size: float = float(spec.size)
		if sim.body_converted_at(view_stage,k):
			if reveal > .1:
				draw_form(str(spec.get("form","node")),at,(size+7.0)*1.5*reveal,0,k,true,Vector2.UP)
			continue
		if body_has_disc(view_stage,k):
			draw_circle(at,size,Color(Color("2c2c2c"),reveal))
		if view_stage >= 2 and view_stage != 7:
			natural_glyph(str(spec.get("form","node")),at,size,k,reveal)
		var dash_r: float = size+9+sin(clock*3+k)*1.5
		for j in range(0,16,2):
			var a0: float = clock*.4+j*TAU/16
			draw_arc(at,dash_r,a0,a0+TAU/16,4,Color(GREY,.45*reveal),1.4,true)

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

func weapon(index: int, point: Vector2, small: bool = false, visual_scale: float = 1.0) -> void:
	# Turret i is a (3+i)-gon, so older weapons stay recognisable at larger scales.
	var s: float = (.7 if small else 1.0) * visual_scale
	if dock_age[index] >= 0 and not small and sim.mode != "transition":
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
	if sim.mode != "transition" and not small and (index == sim.stage or hover.distance_to(point) < 48):
		ink(TranslationServer.translate(sim.catalog.weapons[index].title), point + Vector2(-26, radius + 24), DIM, 10)
	if sim.mode != "transition" and hover.distance_to(point) < 30 and body_at(hover) < 0:
		var panel: Vector2 = point + Vector2(-115, -96)
		draw_rect(Rect2(panel, Vector2(230, 65)), Color("1a1a1a"))
		draw_rect(Rect2(panel, Vector2(230, 65)), DARK, false, 1)
		ink(TranslationServer.translate(sim.catalog.weapons[index].title) + TranslationServer.translate(" · 在役"), panel + Vector2(10, 19), INK, 13)
		ink(TranslationServer.translate("齐射 ") + sim.Catalog.number(sim.shot_damage(index)) + " / " + ("%.2f s" % sim.shot_interval(index)), panel + Vector2(10, 38), GREY, 11)
		ink(TranslationServer.translate("每次覆盖 ") + sim.Catalog.number(sim.coverage(index)) + TranslationServer.translate(" 成员"), panel + Vector2(10, 55), DIM, 11)

func boss_silhouette(p: Vector2, radius: float, kind: String, flash: float) -> void:
	# The shader paints the light; underneath sits only a dark body in the boss's
	# exact outline, so background never shows through, plus one clean edge.
	var edge := Color(1, .92, .75, .45 + flash * .35)
	match kind:
		"star":
			draw_arc(p, radius * 1.1, 0, TAU, 96, edge, 1.6, true)
		"magnetar":
			draw_circle(p, radius * .36, BG)
			draw_arc(p, radius * .36, 0, TAU, 64, edge, 1.6, true)
		"asteroid":
			var rock := PackedVector2Array()
			for j in range(64):
				var a: float = j * TAU / 64
				var la: float = a - clock * .3
				rock.append(p + Vector2.from_angle(a) * radius * (1.0 + .08 * sin(la * 3.0 + 1.3) + .05 * sin(la * 7.0 + .4)))
			draw_colored_polygon(rock, BG)
			rock.append(rock[0])
			draw_polyline(rock, Color(edge, .3), 1.2, true)
		"planet", "dwarf":
			draw_circle(p, radius, BG)
			draw_arc(p, radius, 0, TAU, 96, Color(edge, .35), 1.2, true)
			if kind == "dwarf":
				for j in range(3):
					var a: float = -PI * .5 + (j - 1) * .62
					var root: Vector2 = p + Vector2.from_angle(a) * radius
					var tip: Vector2 = p + Vector2.from_angle(a) * radius * 1.42
					var side: Vector2 = Vector2.from_angle(a).orthogonal() * radius * .12
					var rig := PackedVector2Array([root + side, tip + side * .6, tip - side * .6, root - side])
					draw_colored_polygon(rig, BG)
					draw_polyline(rig, edge, 1.6, true)
		"mothership", "cathedral":
			shape(p, radius, 5, -PI * .5, BG, edge, 2)
			shape(p, radius * .55, 5, PI * .5 + clock * .4, Color(0, 0, 0, 0), Color(edge, .35), 1.2)
		"cigar":
			var axis := Vector2.from_angle(clock * .55)
			var side: Vector2 = axis.orthogonal()
			var hull := PackedVector2Array()
			for j in range(40):
				var a: float = j * TAU / 40
				hull.append(p + axis * cos(a) * radius * 1.55 + side * sin(a) * radius * .3)
			draw_colored_polygon(hull, BG)
			hull.append(hull[0])
			draw_polyline(hull, Color(edge, .4), 1.2, true)
		"rift":
			draw_circle(p, radius * .45, Color(0, 0, 0))
		"brane":
			var skin := PackedVector2Array()
			for j in range(96):
				var a: float = j * TAU / 96
				skin.append(p + Vector2.from_angle(a) * radius * 1.25 * (1.0 + .035 * sin(4.0 * a) * cos(clock * 1.7) + .02 * sin(7.0 * a + 1.0) * cos(clock * 1.1)))
			draw_colored_polygon(skin, BG)
			skin.append(skin[0])
			draw_polyline(skin, edge, 1.6, true)

func boss_shape(p: Vector2, radius: float, kind: String, flash: float, live: bool = false) -> void:
	var boss_dk: float = doppler_k() if live else 0.0
	if boss_dk > .01:
		var actor: Dictionary = sim.boss_actor()
		if not actor.is_empty():
			doppler_ghosts(p, radius * float({"star": 1.1, "magnetar": .55, "brane": 1.25, "rift": .7}.get(kind, 1.0)), Vector2(actor.end) - Vector2(actor.start), boss_dk)
	if live and BOSS_FX_KIND.has(kind) and not reduced_effects and scene_transform.is_equal_approx(Transform2D.IDENTITY) and sim.mode == "boss":
		boss_silhouette(p, radius, kind, flash)
		return
	boss_aura(p, radius, sim.stage, flash)
	# Hits brighten the body only a little: under constant fire it must not turn white.
	var fill: Color = SHADE.lerp(INK, flash * .3)
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
		"mothership", "cathedral":
			shape(p, radius, 5, -PI * .5, fill, INK, 3)
			shape(p, radius * .55, 5, PI * .5 + clock * .4, Color(0, 0, 0, 0), GREY, 2)
		"dwarf":
			# CERES: a cratered dwarf planet strapped with alien thruster rigs.
			draw_circle(p, radius, fill)
			ring(p, radius, INK, 3)
			for j in range(7):
				var a: float = j * 2.399 + .4
				var q: Vector2 = p + Vector2.from_angle(a) * radius * (.25 + (j % 3) * .22)
				draw_arc(q, radius * (.09 + (j % 2) * .05), 0, TAU, 16, Color(GREY, .8), 1.2, true)
			draw_circle(p + Vector2(radius * .1, -radius * .2), radius * .12, Color(INK, .55))
			for j in range(3):
				var a: float = -PI * .5 + (j - 1) * .62
				var root: Vector2 = p + Vector2.from_angle(a) * radius
				var tip: Vector2 = p + Vector2.from_angle(a) * radius * 1.42
				var side: Vector2 = Vector2.from_angle(a).orthogonal() * radius * .12
				draw_polyline(PackedVector2Array([root + side, tip + side * .6, tip - side * .6, root - side]), INK, 2.0, true)
				draw_line(root + side, tip - side * .6, Color(GREY, .7), 1.0, true)
				draw_line(root - side, tip + side * .6, Color(GREY, .7), 1.0, true)
		"cigar":
			# 'OUMUAMUA: a ten-to-one shard tumbling end over end, catching the light.
			var spin: float = clock * .55
			var axis := Vector2.from_angle(spin)
			var side: Vector2 = axis.orthogonal()
			var hull := PackedVector2Array()
			for j in range(24):
				var a: float = j * TAU / 24
				hull.append(p + axis * cos(a) * radius * 1.55 + side * sin(a) * radius * .3 * (1.0 + .15 * sin(a * 3)))
			draw_colored_polygon(hull, fill)
			hull.append(hull[0])
			draw_polyline(hull, INK, 2.5, true)
			for j in range(5):
				var x: float = (j - 2) * .28
				draw_line(p + axis * radius * 1.55 * x + side * radius * .26, p + axis * radius * 1.55 * (x + .1) - side * radius * .26, Color(GREY, .6), 1.0, true)
			var glint: float = pow(maxf(0.0, sin(clock * 1.1)), 12.0)
			draw_circle(p + axis * radius * 1.1, 3.0 + glint * 9.0, Color(1, 1, 1, .4 + glint * .6))
		"magnetar":
			# MAGNETAR: a city-sized neutron star inside a dipole field cage.
			var tilt: float = clock * .9
			var axis := Vector2.from_angle(tilt)
			for j in range(5):
				var l: float = radius * (.75 + j * .32)
				for side in [-1.0, 1.0]:
					var loop := PackedVector2Array()
					for q in range(33):
						var th: float = .12 + (PI - .24) * q / 32.0
						var rr: float = l * sin(th) * sin(th)
						var local := Vector2(cos(th) * rr, sin(th) * rr * side)
						loop.append(p + axis * local.x + axis.orthogonal() * local.y)
					draw_polyline(loop, Color(INK, .5 - j * .07 + flash * .3), 1.3, true)
			for side in [-1.0, 1.0]:
				var beam: Vector2 = axis * side
				draw_line(p + beam * radius * .3, p + beam * radius * 3.6, Color(1, 1, 1, .2), 10.0, true)
				draw_line(p + beam * radius * .3, p + beam * radius * 3.6, Color(1, 1, 1, .85), 1.6, true)
			draw_circle(p, radius * .34, fill.lerp(INK, .6))
			ring(p, radius * .34, Color.WHITE, 2.5)
			for j in range(4):
				var a: float = j * 1.7 + 1.0
				draw_line(p + Vector2.from_angle(a) * radius * .08, p + Vector2.from_angle(a + .3) * radius * .3, Color(BG, .8), 1.2, true)
		"brane":
			# THE OTHER BRANE: a whole universe in its own bubble, its skin ringing.
			var skin := PackedVector2Array()
			for j in range(96):
				var a: float = j * TAU / 96
				skin.append(p + Vector2.from_angle(a) * radius * 1.25 * (1.0 + .035 * sin(4.0 * a) * cos(clock * 1.7) + .02 * sin(7.0 * a + 1.0) * cos(clock * 1.1)))
			draw_colored_polygon(skin, Color(BG, .92))
			skin.append(skin[0])
			draw_polyline(skin, INK.lerp(Color.WHITE, flash), 3.0, true)
			var back := PackedVector2Array()
			for j in range(73):
				var a: float = j * TAU / 72
				back.append(p + Vector2.from_angle(a) * radius * 1.17 * (1.0 + .03 * sin(4.0 * a + .6) * cos(clock * 1.7)))
			draw_polyline(back, Color(INK, .25), 1.0, true)
			# Its own cosmic web, turning slowly the other way.
			for j in range(26):
				var q: Vector2 = p + Vector2.from_angle(j * 2.399 - clock * .08) * radius * 1.05 * sqrt((j + .5) / 26.0)
				draw_circle(q, 1.3 + (j % 3) * .5, Color(GREY, .7))
				if j > 2:
					var o: Vector2 = p + Vector2.from_angle((j - 3) * 2.399 - clock * .08) * radius * 1.05 * sqrt((j - 2.5) / 26.0)
					draw_line(q, o, Color(GREY, .18), 1.0, true)
			draw_circle(p, radius * .14, Color(ACCENT, .85))
		_:
			shape(p, radius, 7, clock * .15, fill, INK, 3)
			shape(p, radius * .5, 4, -clock * .5, Color(0, 0, 0, 0), GREY, 2)

# How big each archetype is drawn relative to its group radius: size alone tells them apart.
const ARCH_SIZE: Dictionary = {"swarm": .75, "dart": 1.05, "armored": 1.3, "splitter": 1.1, "shielded": 1.1, "mother": 2.3}
const MonsterArt = preload("res://scripts/monster_art.gd")
const MonsterArtFine = preload("res://scripts/monster_art_fine.gd")
const MonsterArtV3 = preload("res://scripts/monster_art_v3.gd")
# Dark body tone for the large archetypes: they read by line work, not by a flat slab.
const DEEP := Color("161616")
const MAT_FILL: Dictionary = {"rock": Color("b4b4b4"), "metal": Color("ededed"), "energy": Color("f6f1e6"), "exotic": Color("1a1a1a")}
# Capture-only: draw threats on an empty field (no scenery, weapons or bodies).
var bare: bool = false
var intro_id: int = -1
var intro_t: float = 0.0

func hit_burst(e: Dictionary, q: Vector2, size: float, flash: float, a: float) -> void:
	# Impact: a white bloom on the body, a shock ring snapping outward, sparks thrown off it.
	# Each hit (new hp) picks its own spark angles.
	var k: float = 1.0 - flash
	draw_circle(q, size * (.5 + .3 * k), Color(1, 1, 1, .3 * flash * flash * a))
	draw_arc(q, size * (1.0 + 1.1 * k), 0, TAU, 40, Color(1, .95, .82, .9 * flash * a), .8 + 2.2 * flash, true)
	var hit_seed: int = int(e.seed) + int(float(e.get("hp", 0.0))) % 97
	for j in range(5):
		var u := Vector2.from_angle(hit_seed * 1.37 + j * 1.26 + .4 * sin(hit_seed + j * 3.0))
		var r0: float = size * (.85 + 1.2 * k)
		stroke(q + u * r0, q + u * (r0 + size * (.2 + .5 * flash)), Color(ACCENT.lerp(Color.WHITE, flash), flash * a), .8 + flash)


func shield_bubble(e: Dictionary, q: Vector2, size: float, flash: float, a: float) -> void:
	# Shield: a faint hex bubble with two light pulses running round its edge in opposite
	# directions, rippling inward when struck and thinning as it is worn down.
	var held: float = float(e.get("shield", 0.0)) / maxf(1.0, float(e.get("shield_max", 1.0)))
	if held <= 0.0:
		return
	var r: float = size * 1.75 * (1.0 + flash * .08 + .02 * sin(clock * 2.4 + int(e.seed)))
	var rot: float = clock * .35 + int(e.seed)
	var hex := ngon(6, r, rot, q)
	draw_colored_polygon(hex, Color(ACCENT, (.04 + .08 * flash) * held * a))
	hex.append(hex[0])
	draw_polyline(hex, Color(ACCENT.lerp(Color.WHITE, flash), (.22 + .35 * held) * a), 1.0, true)
	for dir_sign in [1.0, -1.0]:
		var u: float = fposmod(clock * .45 * dir_sign + (.5 if dir_sign < 0 else 0.0), 1.0) * 6.0
		var i: int = int(u)
		var a0: Vector2 = hex[i].lerp(hex[i + 1], u - i)
		var a1: Vector2 = hex[i].lerp(hex[i + 1], minf(1.0, u - i + .35))
		draw_line(a0, a1, Color(ACCENT.lerp(Color.WHITE, .5), (.5 + .5 * held) * a), 2.0, true)
		draw_circle(a0, 1.6, Color(1, 1, 1, .9 * held * a))
	if flash > 0.0:
		var inner := ngon(6, r * (1.0 - .35 * (1.0 - flash)), rot, q)
		inner.append(inner[0])
		draw_polyline(inner, Color(ACCENT, .7 * flash * a), 1.5, true)


func arch_body(e: Dictionary, p: Vector2, size: float, heading: float, spin: float, fill: Color, along: float, across: float, flash: float, mat: String, quiet: bool) -> void:
	# Every named threat has its own drawing (monster_art.gd); archetype cues go on top.
	var arch: String = str(e.get("arch", "swarm"))
	var launch_open: float = clampf(1.0 - float(e.get("launch_t", 3.0)), 0.0, 1.0) if arch == "mother" and int(e.get("launched", 0)) < sim.MOTHER_LAUNCHES else 0.0
	var key: String = str(e.get("art", ""))
	if key != "":
		var head_dir := Vector2.from_angle(heading)
		if arch == "dart":
			stroke(p - head_dir * size * .6, p - head_dir * size * 5.5, Color(INK, .3 * fill.a))
		# Hit: the body is knocked back along its path, squashed against the blow and bulging
		# sideways, then springs back; newborn threats stay stretched by their entry speed.
		var kick: float = flash * flash
		var q: Vector2 = p - head_dir * size * .22 * kick
		var axis := Transform2D(heading, Vector2.ZERO)
		var squash: Transform2D = axis * Transform2D.IDENTITY.scaled(Vector2(along, across)) * axis.affine_inverse()
		draw_set_transform_matrix(Transform2D(0.0, q) * squash * Transform2D(0.0, -p))
		var drawn: bool = MonsterArtV3.draw(self, key, e, p, size, heading, spin, fill.a, flash, launch_open) or MonsterArtFine.draw(self, key, e, p, size, heading, spin, fill.a, flash, launch_open) or MonsterArt.draw(self, key, e, p, size, heading, spin, fill.a, flash, launch_open)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if drawn:
			if arch == "shielded":
				shield_bubble(e, q, size, flash, fill.a)
			if flash > 0.0:
				hit_burst(e, q, size, flash, fill.a)
			return
	# Fallback: one silhouette family per archetype, dressed in the chapter's material.
	var edge := Color(INK, fill.a)
	var dir := Vector2.from_angle(heading)
	var nrm: Vector2 = dir.orthogonal()
	if mat == "energy" and not quiet and arch != "swarm":
		# Stars, plasma and galaxies burn: a thin amber corona around the body.
		ring(p, size * 1.55, Color(ACCENT, .35 * fill.a), 1.0)
	var hollow: bool = mat == "exotic"
	match arch:
		"dart":
			# A thin chevron down its curving path, trailing a long speed line.
			var tip: Vector2 = p + dir * size * 1.7
			var dart := PackedVector2Array([tip, p - dir * size * .8 + nrm * size * .72, p - dir * size * .3, p - dir * size * .8 - nrm * size * .72])
			draw_colored_polygon(dart, Color(BG, fill.a) if hollow else fill)
			if hollow:
				dart.append(dart[0])
				draw_polyline(dart, edge, 1.2, true)
			stroke(p - dir * size * .5, p - dir * size * 7.0, Color(fill if not hollow else INK, .4 * fill.a))
			stroke(p - dir * size * .5, p - dir * size * 3.0, Color(ACCENT, .55 * fill.a))
			draw_circle(tip, 1.8, Color(ACCENT, fill.a))
		"armored":
			# A faceted dark gem: crisp rim, inner facets, a pulsing amber core, and six
			# separate armour plates with rivets that fall away as it loses health.
			var sides: int = 6 if mat == "metal" else 7
			var rot: float = spin * .35
			var rim := PackedVector2Array()
			for j in range(sides):
				var jitter: float = 1.0 + (.09 * sin(j * 2.7 + float(e.seed)) if mat == "rock" else 0.0)
				rim.append(p + Vector2.from_angle(rot + j * TAU / sides) * size * jitter)
			draw_colored_polygon(rim, Color(DEEP, fill.a))
			var outline := rim.duplicate()
			outline.append(rim[0])
			draw_polyline(outline, Color(edge if mat != "rock" else GREY, fill.a), 1.6, true)
			for j in range(0, sides, 2):
				stroke(p, rim[j], Color(edge, .28 * fill.a))
			match mat:
				"rock":
					stroke(rim[1].lerp(p, .2), p + (rim[3] - p) * .35, Color(GREY, .5 * fill.a))
				"metal":
					shape(p, size * .62, sides, rot, Color(0, 0, 0, 0), Color(edge, .35 * fill.a), 1.0)
				"energy":
					ring(p, size * .62, Color(ACCENT, .45 * fill.a), 1.0)
				_:
					shape(p, size * .82, sides, -rot, Color(0, 0, 0, 0), Color(INK, .5 * fill.a), 1.0)
			var pulse: float = .55 + .45 * sin(clock * 3.0 + float(e.seed))
			draw_circle(p, size * .16 * (1.0 + flash * .5), Color(ACCENT.lerp(Color.WHITE, flash), (.5 + .5 * pulse) * fill.a))
			var health: float = float(e.members) / maxf(1.0, float(e.initial_members)) if int(e.initial_members) > 1 else float(e.hp) / maxf(1.0, float(e.unit_hp))
			var plates: int = ceili(6.0 * clampf(health, 0.0, 1.0))
			for j in range(plates):
				var mid: float = rot + j * TAU / 6 + TAU / 12
				var span: float = TAU / 6 * .32
				var r0: float = size * 1.22
				var r1: float = size * 1.42
				var plate := PackedVector2Array([p + Vector2.from_angle(mid - span) * r0, p + Vector2.from_angle(mid - span * .8) * r1,
					p + Vector2.from_angle(mid + span * .8) * r1, p + Vector2.from_angle(mid + span) * r0])
				draw_colored_polygon(plate, Color(DEEP, fill.a))
				plate.append(plate[0])
				draw_polyline(plate, Color(edge, .85 * fill.a), 1.1, true)
				draw_circle(p + Vector2.from_angle(mid) * size * 1.32, 1.3, Color(ACCENT, .8 * fill.a))
		"splitter":
			# Three dark shards held together by glowing amber seams.
			var seam: float = .6 + .35 * sin(clock * 6.0 + float(e.seed))
			for j in range(3):
				var a: float = spin * .6 + j * TAU / 3
				var c: Vector2 = p + Vector2.from_angle(a) * size * .45
				var shard := PackedVector2Array()
				for k in range(5):
					shard.append(c + Vector2.from_angle(a + spin * .2 + k * TAU / 5) * size * (.5 if k % 2 == 0 else .38))
				draw_colored_polygon(shard, Color(DEEP, fill.a))
				shard.append(shard[0])
				draw_polyline(shard, Color(edge if mat != "rock" else GREY, fill.a), 1.2, true)
			for j in range(3):
				var a: float = spin * .6 + j * TAU / 3 + PI / 3
				stroke(p, p + Vector2.from_angle(a) * size * .9, Color(ACCENT, seam * fill.a))
			draw_circle(p, 2.0, Color(ACCENT, seam * fill.a))
		"shielded":
			if hollow:
				shape(p, size * .85, 5, spin, Color(BG, fill.a), edge, 1.2)
			else:
				shape_squash(p, size * .85, 3 if mat == "metal" else 5, heading if mat == "metal" else spin, fill, along, across, heading)
			var held: float = float(e.get("shield", 0.0)) / maxf(1.0, float(e.get("shield_max", 1.0)))
			if held > 0.0:
				var hex := ngon(6, size * 1.8 * (1.0 + flash * .1), clock * .8, p)
				hex.append(hex[0])
				draw_polyline(hex, Color(ACCENT.lerp(Color.WHITE, flash), (.35 + .6 * held) * fill.a), 1.2 + 1.4 * held, true)
				var inner := ngon(6, size * 1.45, -clock * .5, p)
				inner.append(inner[0])
				draw_polyline(inner, Color(ACCENT, .25 * held * fill.a), 1.0, true)
		"mother":
			# A slim dark carrier: keel, ribs, twin engines, running lights, and a hangar
			# that only glows as it opens to launch.
			var hull := PackedVector2Array([p + dir * size * 1.5, p + dir * size * .9 + nrm * size * .42, p + dir * size * .1 + nrm * size * .62,
				p - dir * size * 1.1 + nrm * size * .55, p - dir * size * 1.3 + nrm * size * .25, p - dir * size * 1.3 - nrm * size * .25,
				p - dir * size * 1.1 - nrm * size * .55, p + dir * size * .1 - nrm * size * .62, p + dir * size * .9 - nrm * size * .42])
			draw_colored_polygon(hull, Color(DEEP, fill.a))
			var outline := hull.duplicate()
			outline.append(hull[0])
			draw_polyline(outline, Color(edge, fill.a), 1.4, true)
			stroke(p + dir * size * 1.35, p - dir * size * 1.2, Color(edge, .35 * fill.a))
			for j in range(4):
				var x: float = .7 - j * .45
				stroke(p + dir * size * x + nrm * size * .45, p + dir * size * x - nrm * size * .45, Color(edge, .22 * fill.a))
			var open: float = clampf(1.0 - float(e.get("launch_t", 3.0)), 0.0, 1.0) if int(e.get("launched", 0)) < sim.MOTHER_LAUNCHES else 0.0
			var bay := PackedVector2Array([p - dir * size * .15 + nrm * size * .26, p - dir * size * .85 + nrm * size * .26,
				p - dir * size * .85 - nrm * size * .26, p - dir * size * .15 - nrm * size * .26])
			if open > 0.0:
				draw_colored_polygon(bay, Color(ACCENT, open * .55 * fill.a))
			bay.append(bay[0])
			draw_polyline(bay, Color(ACCENT if open > 0.0 else edge, (.5 + .5 * open) * fill.a), 1.0, true)
			for side in [1.0, -1.0]:
				var engine: Vector2 = p - dir * size * 1.3 + nrm * size * .16 * side
				draw_circle(engine, 1.8, Color(ACCENT, fill.a))
				stroke(engine, engine - dir * size * (.35 + .15 * sin(clock * 20.0 + side)), Color(ACCENT, .5 * fill.a))
			for j in range(5):
				var lit: bool = int(clock * 4.0) % 5 == j
				var x: float = 1.0 - j * .48
				var w: float = .48 if j < 2 else .58
				draw_circle(p + dir * size * x + nrm * size * w, 1.2, Color(ACCENT if lit else DIM, fill.a))
				draw_circle(p + dir * size * x - nrm * size * w, 1.2, Color(ACCENT if lit else DIM, fill.a))
		_:
			# Swarm: rock chips, metal darts, star sparks or exotic rings.
			match mat:
				"metal":
					shape_squash(p, size, 3, heading, fill, along, across, heading)
				"energy":
					shape_squash(p, size * .75, 4, spin, fill, along, across, heading)
					if not quiet:
						for j in range(4):
							var a: float = spin + j * PI * .5 + PI * .25
							stroke(p + Vector2.from_angle(a) * size * .6, p + Vector2.from_angle(a) * size * 1.35, Color(ACCENT, .7 * fill.a))
				"exotic":
					ring(p, size * .95, Color(INK, .9 * fill.a), 1.2)
					draw_circle(p, size * .3, Color(ACCENT, fill.a))
				_:
					shape_squash(p, size, 4 if int(e.seed) % 2 == 0 else 5, spin, fill, along, across, heading)

func enemy(e: Dictionary) -> void:
	var lead_ratio: float = clampf((float(e.age) + render_lead * sim.enemy_time_rate()) / float(e.lifetime), 0.0, 1.0)
	var p: Vector2 = sim.enemy_point(e, lead_ratio) if not sim.paused else Vector2(e.pos)
	var radius: float = float(e.radius)
	var boss: bool = bool(e.boss)
	var focused: bool = int(e.id) == sim.priority_id or hover.distance_to(p) < radius + 13
	var dense: bool = sim.enemies.size() > 70
	var arch_name: String = str(e.get("arch", "swarm"))
	if dense and not boss and not focused and arch_name == "swarm":
		radius *= .75
	var flash: float = clampf(float(e.get("flash", 0)) / .12, 0, 1)
	if e.has("escort"):
		draw_escort(e, p, flash)
		return
	var appear: float = pop(float(e.age)) if not boss else 1.0
	var danger: float = float(e.age) / float(e.lifetime)
	var heading: float = (Vector2(e.end) - Vector2(e.start)).angle()
	if str(e.get("arch", "")) == "dart" and lead_ratio < .995:
		# Darts face along their curve, not the straight line.
		heading = (sim.enemy_point(e, minf(1.0, lead_ratio + .01)) - p).angle()
	var trail: Vector2 = -Vector2(cos(heading), sin(heading))
	if not boss:
		if batching:
			trail_lines.append(p)
			trail_lines.append(p + trail * radius * 2.6)
		else:
			draw_line(p, p + trail * radius * 2.6, Color(GREY, .14), maxf(1.0, radius * .35), true)
	var string_u: float = float(sim.ult.age) if not sim.ult.is_empty() and str(sim.ult.kind) == "strings" else -1.0
	if string_u >= 0.0 and ultimate_art.string_level(string_u) > .02 and not boss:
		# Under the doomsday weapon a threat shows what it is made of: a ringing string.
		var level: float = ultimate_art.string_level(string_u)
		if level < .98:
			shape(p, radius * .78 * (1.0 - level), 3 if str(e.kind).contains("ship") else 4, heading, Color(INK, 1.0 - level))
		ultimate_art.draw_string_threat(self, p, radius, int(e.seed), string_u, int(e.members))
	elif boss:
		boss_shape(p, radius * (1 + flash * .04), str(e.kind), flash, true)
	elif bool(e.get("fragment", false)):
		# A small body thrown off by the droplet: a tumbling shard with a hot edge.
		var spin_f: float = clock * (2.0 + float(int(e.seed) % 5)) + int(e.seed)
		var shard := PackedVector2Array()
		for j in range(4):
			var a: float = spin_f + j * TAU / 4 + (.5 if j % 2 else 0.0)
			shard.append(p + Vector2.from_angle(a) * radius * (1.0 if j % 2 == 0 else .45))
		var shard_motion: Vector2 = Vector2(e.end) - Vector2(e.start)
		var shard_dk: float = doppler_k()
		if shard_dk > .01:
			doppler_ghosts(p, radius, shard_motion, shard_dk)
		draw_colored_polygon(shard, doppler_tint(GREY.lerp(Color.WHITE, flash), p, shard_motion, shard_dk))
		shard.append(shard[0])
		draw_polyline(shard, Color(INK, .9), 1.0, true)
		if float(e.age) < .6:
			stroke(p, p - (Vector2(e.end) - Vector2(e.start)).normalized() * radius * 3.0 * (1.0 - float(e.age) / .6), Color(1, 1, 1, .6))
	else:
		var size: float = radius * .78 * appear * (1 + flash * .18)
		var spin: float = clock * (.6 + float(int(e.seed) % 7) * .15) + int(e.seed)
		var ship: bool = str(e.kind).contains("ship")
		var mat: String = str(e.get("mat", "metal" if ship else "rock"))
		var fill: Color = MAT_FILL.get(mat, GREY).lerp(Color.WHITE, flash)
		var dk: float = doppler_k()
		var motion: Vector2 = Vector2(e.end) - Vector2(e.start)
		if dk > 0.01:
			fill = doppler_tint(fill, p, motion, dk)
			# Light lag: a blue image runs ahead and a red one trails behind.
			var dir: Vector2 = motion.normalized()
			var lag: float = radius * (.5 + 1.8 * dk)
			shape_squash(p + dir * lag, size * .9, 3 if ship else 4, heading if ship else spin, Color(BLUE_SHIFT, .45 * dk), 1.4, .8, heading)
			shape_squash(p - dir * lag, size * .9, 3 if ship else 4, heading if ship else spin, Color(RED_SHIFT, .45 * dk), 1.4, .8, heading)
		# Threats materialise at the screen edge: they fade up behind their warp-in streak.
		fill.a *= smoothstep(0.0, 1.0, float(e.age) / .45)
		if dense and not focused:
			fill.a = clampf(.5 + danger * .5 + flash, .5, 1)
		# Hit: squashed along the flight line and bulging sideways; newborn
		# threats are stretched along it, carrying their entry speed.
		var young: float = clampf(1.0 - float(e.age) / .4, 0, 1)
		var along: float = 1.0 - .26 * flash + .55 * young
		var across: float = 1.0 + .22 * flash - .2 * young
		arch_body(e, p, size * float(ARCH_SIZE.get(arch_name, 1.0)), heading, spin, fill, along, across, flash, mat, dense and not focused)
		if bool(e.elite):
			# Elite: the game's own four-segment reticle in amber, turning and breathing.
			var er: float = size * (1.95 + .08 * sin(clock * 3.0 + int(e.seed)))
			for j in range(4):
				var a0: float = clock * 1.1 + j * PI * .5
				draw_arc(p, er, a0, a0 + .75, 8, Color(ACCENT, .85 * fill.a), 1.6, true)
				draw_circle(p + Vector2.from_angle(a0 + .375) * (er + 4.0), 1.2, Color(ACCENT, .7 * fill.a))
		if int(e.id) == intro_id and intro_t > 0.0:
			# First of a new archetype: a pulsing ring and its name.
			var k: float = fposmod(clock * 1.6, 1.0)
			ring(p, size * (2.2 + k * 1.6), Color(ACCENT, (1.0 - k) * .9 * minf(1.0, intro_t)), 1.5)
			ink(str(e.get("title", "")), p + Vector2(-20, -size * 2.6 - 6), Color(ACCENT, minf(1.0, intro_t)), 12)
		if int(e.members) > 1:
			var companions: int = 0 if arch_name != "swarm" else 5 if not dense else 2 if focused or danger > .8 else 0
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
	var title: String = TranslationServer.translate(sim.stage_data().boss_title).split(" · ")[0] if boss else TranslationServer.translate("精英 · ") + TranslationServer.translate(str(selected.get("title", "重甲"))) if selected.elite else TranslationServer.translate(str(selected.title)) if selected.has("title") else TranslationServer.translate("外星舰群") if kind == "ship" else TranslationServer.translate("自然威胁群") if int(selected.members) > 1 else TranslationServer.translate("来袭天体")
	ink(title, p + Vector2(14, 26), INK, 15)
	var icon: Vector2 = p + Vector2(55, 92)
	if boss:
		boss_shape(icon, 34, kind, 0)
	else:
		shape(icon, 30, 3 if kind.contains("ship") else 4, clock * .5, INK if kind.contains("ship") else GREY)
	ink(TranslationServer.translate("成员 ") + sim.Catalog.number(selected.members), p + Vector2(110, 62), GREY, 12)
	ink(TranslationServer.translate("总生命"), p + Vector2(110, 84), DIM, 11)
	var hp: float = float(selected.hp) + (int(selected.members) - 1) * float(selected.unit_hp)
	ink(sim.Catalog.number(hp), p + Vector2(110, 106), INK, 14)
	var remaining: float = maxf(0, float(selected.lifetime) - float(selected.age))
	ink(TranslationServer.translate("撞击 %.1f 秒") % remaining, p + Vector2(14, 146), ACCENT if remaining < 10 else GREY, 12)
	ink(TranslationServer.translate("在途伤害 ") + sim.Catalog.number(selected.reserved), p + Vector2(14, 165), DIM, 11)
	ink(TranslationServer.translate("点击指定全体系优先目标") if sim.automation else TranslationServer.translate("点击 / 按住目标发射"), p + Vector2(14, 182), DIM, 11)

# Per-section draw cost (microseconds, accumulated) for performance tests.
var profile: Dictionary = {}

func profile_add(key: String, since: int) -> void:
	profile[key] = int(profile.get(key, 0)) + Time.get_ticks_usec() - since

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_field()
	profile_add("field_total", started)

func _draw_field() -> void:
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
		stage_scene(idx + 1, smoothstep(2.8, 5.8, sim.mode_time))
		draw_incoming_bodies(idx+1,smoothstep(3.1,5.5,sim.mode_time))
		var scale_value: float = pow(0.04, t)
		var previous_center: Vector2 = Vector2(500, 570) if idx == 0 else Vector2(500, 325)
		var anchors: Array[Vector2] = [Vector2(547, 356), Vector2(500, 325) + Vector2.from_angle(EARTH_ANGLE) * EARTH_ORBIT, Vector2(500, 325), Vector2(500, 325), Vector2(500, 325), atlas.SUN_IN_GALAXY, Vector2(500, 325), Vector2(500, 325), Vector2(500, 325)]
		var anchor: Vector2 = Vector2(500, 325) + (anchors[idx] - Vector2(500, 325)) * future_scale
		scene_transform = Transform2D(0, Vector2.ONE * scale_value, 0, anchor - previous_center * scale_value)
		draw_set_transform_matrix(scene_transform)
		stage_scene(idx)
		var outgoing: Transform2D = scene_transform
		scene_transform = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO)
		for i in range(WEAPONS):
			if sim.owned[i]:
				var pose: Dictionary = transition_weapon_pose(i, outgoing, t)
				weapon(i, pose.point, false, pose.scale)
		draw_transition_bodies(outgoing, t)
	else:
		var prof: int = Time.get_ticks_usec()
		if not bare:
			stage_scene(idx)
		profile_add("scene", prof)
		ultimate_art.domain_background(self)
		prof = Time.get_ticks_usec()
		if not bare:
			for i in range(WEAPONS):
				if sim.owned[i]:
					weapon(i, sim.weapon_origin(i), idx > 0 and i < idx)
			draw_bodies()
		profile_add("bodies", prof)
		prof = Time.get_ticks_usec()
		begin_batch()
		for e in sim.enemies:
			if not bool(e.dead):
				enemy(e)
		flush_batch()
		profile_add("enemies", prof)
		prof = Time.get_ticks_usec()
		for p in sim.shots:
			if bool(p.beam) and not p.has("mode"):
				draw_line(p.from, p.end, Color(INK, .06), 9 + int(p.weapon) * 1.5, true)
				draw_line(p.from, p.end, Color(INK, .85), 1.2 + int(p.weapon) * .2, true)
		draw_bullets()
		draw_weapon_rounds()
		profile_add("rounds", prof)
		prof = Time.get_ticks_usec()
		draw_sweeps()
		profile_add("sweeps", prof)
		prof = Time.get_ticks_usec()
		draw_shells()
		draw_swarm()
		profile_add("shells", prof)
		prof = Time.get_ticks_usec()
		draw_strikes()
		profile_add("strikes", prof)
		prof = Time.get_ticks_usec()
		draw_boss_skill()
		draw_ultimate()
		profile_add("ultimate", prof)
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
			var point: Vector2 = coin_position(c)
			if bool(c.get("ultimate", false)):
				var previous: Vector2 = coin_position(c, -.12)
				for segment in range(4):
					var next: Vector2 = coin_position(c, -.09 + segment * .03)
					stroke(previous, next, Color(ACCENT, .12 + segment * .14), .7 + segment * .4)
					previous = next
				var direction: Vector2 = (point - coin_position(c, -.015)).normalized()
				# Gold coins: an amber diamond with a white glint that winks as it tumbles.
				shape(point, 4.4, 4, direction.angle(), ACCENT.lerp(Color.WHITE, .25))
				if sin(clock * 14.0 + float(c.get("phase", 0.0)) * 3.0) > .6:
					shape(point, 1.8, 4, direction.angle() + PI * .25, Color.WHITE)
			else:
				shape(point, 3.2, 4, clock * 6, INK)
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
var prime_marks: Array[Dictionary] = []
var ulam: PackedVector2Array = PackedVector2Array()
const STRIKE_TIME: Dictionary = {"beam": .34, "rail": .42, "chain": .32, "ring": .6, "gravity": .3, "wave": .7, "quake": .3, "meteor": .2, "prism": .4, "w_rod": .7, "w_well": .75, "w_jets": .65, "w_lance": .45, "w_web": .55, "w_standing": .45, "w_pulse": .3}

func on_weapon_strike(kind: String, index: int, origin: Vector2, destination: Vector2, points: PackedVector2Array, critical: bool) -> void:
	if strikes.size() > 90:
		strikes.pop_front()
	strikes.append({"kind": "w_" + kind, "age": 0.0, "dur": float(STRIKE_TIME.get("w_" + kind, .5)), "from": origin, "to": destination, "points": points, "crit": critical, "seed": randi() % 1000, "big": true, "weapon": index})
	match kind:
		"rod":
			add_wave(destination, 26.0, 1.0)
			add_feedback("flash", destination, index, 60.0, .3)
			trauma = maxf(trauma, .12)
		"well":
			add_wave(destination, 30.0, 1.2)
		"jets", "lance":
			add_feedback("flash", destination if kind == "jets" else origin, index, 40.0, .25)
		"web":
			add_wave(destination, 16.0, .9)
		"standing":
			add_wave(sim.defense_position(), 12.0, .8)

func draw_weapon_rounds() -> void:
	# Projectiles of the chapter weapons, each with its own body.
	for p in sim.shots:
		if not p.has("mode"):
			continue
		var at: Vector2 = p.pos
		var travel: Vector2 = Vector2(p.end) - Vector2(p.from)
		var dir: Vector2 = travel.normalized() if travel.length() > .01 else Vector2.DOWN
		var crit: bool = bool(p.crit)
		var col: Color = ACCENT if crit else INK
		var t: float = clampf(float(p.age) / float(p.duration), 0, 1)
		match str(p.mode):
			"rod":
				# Re-entry: a white-hot rod with a plasma sheath and a long ionised trail.
				var tail: Vector2 = at - dir * (60.0 + t * 90.0)
				draw_line(tail, at, Color(INK, .12), 9.0, true)
				draw_line(at - dir * 50.0, at, Color(col, .8), 2.6, true)
				draw_line(at - dir * 16.0, at, Color.WHITE, 3.4, true)
				draw_colored_polygon(PackedVector2Array([at + dir * 6.0, at - dir * 4.0 + dir.orthogonal() * 4.5, at - dir * 4.0 - dir.orthogonal() * 4.5]), Color(ACCENT, .85))
				for k in range(3):
					var side: Vector2 = dir.orthogonal() * (k - 1) * 7.0
					draw_line(at - dir * 6.0 + side, at - dir * (22.0 + k * 6.0) + side * 1.6, Color(ACCENT, .35), 1.0, true)
			"well":
				# A dense slug bending light round itself: dark core, lensing rings.
				for k in range(3):
					var rr: float = 6.0 + k * 5.0 + sin(clock * 9.0 + k) * 1.2
					draw_arc(at, rr, clock * (3.0 - k) + k, clock * (3.0 - k) + k + 4.4, 20, Color(col, .7 - k * .18), 1.4, true)
				draw_circle(at, 4.5, BG)
				ring(at, 4.5, Color.WHITE, 1.4)
				for k in range(1, 5):
					draw_circle(at - dir * k * 9.0, 2.6 - k * .45, Color(GREY, .5 - k * .1))
			"shard":
				# Comet shard: an icy diamond with an ion tail and a curving dust tail.
				var n: Vector2 = dir.orthogonal()
				draw_line(at, at - dir * 30.0, Color(INK, .55), 1.4, true)
				draw_line(at, at - (dir + n * .28).normalized() * 22.0, Color(INK, .25), 2.4, true)
				draw_colored_polygon(PackedVector2Array([at + dir * 5.0, at + n * 2.4, at - dir * 3.0, at - n * 2.4]), col)
			"pulse":
				# A pulsar tick: a short white-hot dash with a faint halo, nothing more.
				if float(p.age) < 0.0:
					continue
				draw_line(at - dir * 18.0, at, Color(col, .25), 6.0, true)
				draw_line(at - dir * 14.0, at, Color(1, 1, 1, .95), 2.0, true)
				draw_circle(at, 2.4, Color.WHITE)
			"jets":
				# Accretion knot: a bright core in a tilted disc.
				draw_set_transform(at, dir.angle(), Vector2(1.0, .35))
				draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color(col, .8), 1.4, true)
				draw_set_transform(Vector2.ZERO)
				draw_circle(at, 3.0, Color.WHITE)
				draw_line(at, at - dir * 24.0, Color(INK, .35), 2.0, true)

func draw_sweeps() -> void:
	# Fan beams and pulsar beacons drawn straight from the sim's sweep state.
	for sw in sim.sweeps:
		var k: float = clampf(float(sw.age) / float(sw.dur), 0, 1)
		var at: Vector2 = sw.origin
		var reach: float = float(sw.reach)
		var crit: bool = bool(sw.crit)
		var lighthouse: bool = str(sw.kind) == "lighthouse"
		for offset in sw.beams:
			var a: float = lerpf(float(sw.from), float(sw.to), k) + float(offset)
			# Afterglow: the swept sector stays faintly lit behind the beam.
			var trail := PackedVector2Array([at])
			var back: float = minf(k, .35)
			for j in range(9):
				var aj: float = lerpf(float(sw.from), float(sw.to), maxf(0.0, k - back * j / 8.0)) + float(offset)
				trail.append(at + Vector2.from_angle(aj) * reach)
			draw_colored_polygon(trail, Color(1, 1, 1, .025))
			var tip: Vector2 = at + Vector2.from_angle(a) * reach
			# Bright near the source, thinning out toward the edge of its reach.
			var mid: Vector2 = at.lerp(tip, .55)
			draw_line(at, mid, Color(ACCENT if crit else INK, .1), 8.0, true)
			draw_line(at, mid, Color(1, 1, 1, .85), 1.5, true)
			draw_line(mid, tip, Color(1, 1, 1, .3), 1.0, true)
			if lighthouse:
				# Pulse knots race outward along the beam.
				for j in range(6):
					var q: float = fposmod(clock * 3.0 + j / 6.0, 1.0)
					draw_circle(at.lerp(tip, q), 2.4, Color(1, 1, 1, .8 * (1.0 - q)))
		if lighthouse:
			var spin: float = lerpf(float(sw.from), float(sw.to), k)
			draw_circle(at, 7.0, Color.WHITE)
			ring(at, 12.0 + sin(clock * 30.0) * 2.0, Color(INK, .6), 1.4)
			for side in [-1.0, 1.0]:
				draw_line(at, at + Vector2.from_angle(spin + PI * .5) * side * 18.0, Color(INK, .35), 1.0, true)

func draw_weapon_strike(st: Dictionary, t: float) -> void:
	var a: Vector2 = st.from
	var b: Vector2 = st.to
	var col: Color = ACCENT if bool(st.crit) else INK
	var fade: float = 1.0 - t
	var pts: PackedVector2Array = st.points
	match str(st.kind):
		"w_rod":
			# Kinetic impact: a crater flash, a hard shock ring and a dust skirt.
			var ease_t: float = 1.0 - pow(1.0 - t, 3)
			draw_arc(b, 10.0 + ease_t * 80.0, 0, TAU, 48, Color(1, 1, 1, fade), 3.0 * fade + .5, true)
			draw_arc(b, 6.0 + ease_t * 50.0, 0, TAU, 40, Color(col, fade * .6), 1.2, true)
			for j in range(12):
				var ang: float = j * TAU / 12 + int(st.seed) * .1
				var r0: float = 8.0 + ease_t * 30.0
				draw_line(b + Vector2.from_angle(ang) * r0, b + Vector2.from_angle(ang) * (r0 + 14.0 * fade), Color(GREY, fade * .7), 1.2, true)
			if t < .25:
				draw_line(b + Vector2(0, -900), b, Color(1, 1, 1, (1.0 - t / .25) * .5), 4.0, true)
		"w_well":
			# The swarm is dragged in along curving streaks, then thrown back out.
			var pull: float = 1.0 - smoothstep(0.0, .45, t)
			for q in pts:
				var mid: Vector2 = q.lerp(b, .5 * pull)
				draw_line(q, mid, Color(INK, fade * .55), 1.2, true)
				draw_circle(q, 2.0 * fade, Color(1, 1, 1, fade))
			for k in range(3):
				var rr: float = lerpf(105.0 - k * 20.0, 8.0, smoothstep(0.0, .5, t)) + smoothstep(.5, 1.0, t) * 140.0
				draw_arc(b, rr, 0, TAU, 56, Color(col if k == 0 else INK, fade * (.8 - k * .2)), 1.6 - k * .3, true)
			draw_circle(b, 9.0 * (1.0 - smoothstep(.4, .6, t)), Color(0, 0, 0, .8))
		"w_jets":
			# Twin relativistic jets with travelling knots, sharp at birth, then fraying.
			var mid: Vector2 = a.lerp(b, .5)
			var grow: float = 1.0 - pow(1.0 - minf(1.0, t * 4.0), 3)
			var e0: Vector2 = mid.lerp(a, grow)
			var e1: Vector2 = mid.lerp(b, grow)
			draw_line(e0, e1, Color(col, .18 * fade), 12.0 * fade + 2.0, true)
			draw_line(e0, e1, Color(1, 1, 1, fade), 2.0, true)
			for j in range(6):
				var q: float = fposmod(t * 2.2 + j / 6.0, 1.0)
				draw_circle(mid.lerp(a, q * grow), 2.6 * fade, Color(1, 1, 1, fade))
				draw_circle(mid.lerp(b, q * grow), 2.6 * fade, Color(1, 1, 1, fade))
			draw_set_transform(mid, (b - a).angle() + PI * .5, Vector2(1.0, .3))
			draw_arc(Vector2.ZERO, 14.0 + t * 10.0, 0, TAU, 32, Color(col, fade), 2.0, true)
			draw_arc(Vector2.ZERO, 26.0 + t * 30.0, 0, TAU, 40, Color(INK, fade * .4), 1.0, true)
			draw_set_transform(Vector2.ZERO)
			# Central flare and the radio lobes that billow where each jet stops.
			draw_circle(mid, 10.0 * fade, Color(1, 1, 1, fade))
			for k in range(4):
				var ang: float = k * PI * .5 + PI * .25
				draw_line(mid + Vector2.from_angle(ang) * 4.0, mid + Vector2.from_angle(ang) * 30.0 * fade, Color(1, 1, 1, fade * .7), 1.0, true)
			if grow >= 1.0:
				var lobe: float = smoothstep(.2, 1.0, t)
				for end in [a, b]:
					var out: Vector2 = (end - mid).normalized()
					draw_set_transform(end + out * 14.0 * lobe, out.angle(), Vector2(1.0, .62))
					for k in range(3):
						draw_arc(Vector2.ZERO, 10.0 + lobe * (22.0 + k * 10.0), 0, TAU, 32, Color(col if k == 0 else INK, fade * (.75 - k * .2)), 1.4, true)
					draw_set_transform(Vector2.ZERO)
		"w_lance":
			var w: float = 6.0 * sqrt(fade) + 1.0
			draw_line(a, b, Color(col, .07 * fade), w * 4.0, true)
			draw_line(a, b, Color(1, 1, 1, .85 * fade), w * .4, true)
			for q in pts:
				draw_arc(q, 5.0 + t * 18.0, 0, TAU, 20, Color(col, fade), 1.4, true)
		"w_web":
			# Filaments light up generation by generation.
			for i in range(0, pts.size() - 1, 2):
				var gen: float = 0.0 if pts[i].distance_to(b) < 1.0 else .35
				var grow: float = clampf((t - gen * .5) / .3, 0, 1)
				if grow <= 0.0:
					continue
				# A filament: a soft glow under a thin line that wavers like plasma.
				var q: Vector2 = pts[i].lerp(pts[i + 1], grow)
				draw_line(pts[i], q, Color(col, .12 * fade), 9.0, true)
				var n: Vector2 = (q - pts[i]).orthogonal().normalized()
				var prev: Vector2 = pts[i]
				for j in range(1, 9):
					var u: float = j / 8.0
					var w: Vector2 = pts[i].lerp(q, u) + n * sin(u * PI * 3.0 + clock * 30.0 + i) * 3.5 * sin(u * PI)
					draw_line(prev, w, Color(1, 1, 1, fade * .95), 1.4, true)
					prev = w
				if grow >= 1.0:
					var bloom: float = clampf((t - gen * .5 - .3) / .25, 0, 1)
					draw_circle(pts[i + 1], 4.0 * fade + .5, Color(1, 1, 1, fade))
					draw_arc(pts[i + 1], 6.0 + bloom * 16.0, 0, TAU, 20, Color(col if gen == 0.0 else INK, fade * (1.0 - bloom * .6)), 1.4, true)
			draw_arc(b, 10.0 + t * 30.0, 0, TAU, 32, Color(col, fade), 2.0, true)
		"w_pulse":
			# Each tick lands as a small sharp ring.
			draw_arc(b, 4.0 + t * 22.0, 0, TAU, 20, Color(col, fade), 1.6 * fade + .4, true)
			for q in pts:
				draw_circle(q, 2.0 * fade + .4, Color(1, 1, 1, fade))
		"w_standing":
			# The resonance shows only where it bites: each struck threat rings as a
			# short vertical string (nodes at both ends), the target brightest.
			if pts.is_empty():
				return
			var osc: float = cos(t * TAU * 3.0) * fade
			for j in range(0, pts.size()):
				var q: Vector2 = b if j == 0 else pts[j]
				var half: float = 34.0 if j == 0 else 20.0
				var prev: Vector2 = q + Vector2(0, -half)
				for k in range(1, 9):
					var u: float = k / 8.0
					var w: Vector2 = q + Vector2(sin(u * PI) * 7.0 * osc, -half + u * half * 2.0)
					draw_line(prev, w, Color(col if j == 0 else INK, fade * (.95 if j == 0 else .6)), 1.4, true)
					prev = w
				draw_circle(q + Vector2(0, -half), 1.6, Color(ACCENT, fade))
				draw_circle(q + Vector2(0, half), 1.6, Color(ACCENT, fade))

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
	begin_batch()
	draw_strikes_batched()
	flush_batch()

func draw_strikes_batched() -> void:
	for st in strikes:
		var t: float = float(st.age) / float(st.dur)
		if t < 0 or t > 1:
			continue
		if not bool(st.big):
			# Earlier chapters' bodies strike in shorthand: a short streak into the
			# target and the hits, never a line across the whole field.
			var c_small: Color = ACCENT if bool(st.crit) else INK
			var into: Vector2 = (Vector2(st.to) - Vector2(st.from)).normalized()
			stroke(Vector2(st.to) - into * 34.0, st.to, Color(c_small, .6 * (1.0 - t)))
			for q in st.points:
				shape(q, 2.2 * (1.0 - t) + .6, 4, .785, Color(c_small, 1.0 - t))
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
				stroke(a, b, Color(col, .9 * fade))
				draw_line(a, b, Color(1, 1, 1, fade), maxf(1.0, w * .3), true)
				draw_circle(b, w * 1.6, Color(1, 1, 1, fade))
				for q in st.points:
					ring(q, 6 + t * 14, Color(col, fade * .8), 1.2)
			"rail":
				# Instant slug: the hairline stops just past the last threat it went through.
				var axis_r: Vector2 = (b - a).normalized()
				var reach_r: float = 420.0
				for q in st.points:
					reach_r = maxf(reach_r, (q - a).dot(axis_r) + 60.0)
				b = a + axis_r * minf(reach_r, a.distance_to(b))
				draw_line(a, b, Color(1, 1, 1, fade), 2.2 * fade + .6, true)
				var dir: Vector2 = (b - a).normalized()
				var n: Vector2 = dir.orthogonal()
				var length: float = a.distance_to(b)
				var d: float = 30.0
				while d < length:
					var c: Vector2 = a + dir * d
					var spread: float = 4.0 + t * 16.0
					stroke(c - n * spread, c + n * spread, Color(col, fade * .35))
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
				arc_segments(a, r * .82, 0, TAU, Color(col, .35 * fade))
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
							stroke(pts[0], pts[j] + off, Color(col, fade * (.85 - k * .25)))
					shape(pts[0], 8 * (1.0 - t * .5), 3, clock * 6.0, Color(0, 0, 0, 0), Color(1, 1, 1, fade), 1.4)
			"quake":
				var bolt: PackedVector2Array = jagged(a, b, int(st.seed), 3.0)
				draw_polyline(bolt, Color(col, .5 * fade), 1.2, true)
			_:
				if str(st.kind).begins_with("w_"):
					draw_weapon_strike(st, t)
	# Gravity wells, quakes and meteors are owned by the sim; draw them from it.
	for w in sim.wells:
		var age: float = float(w.age)
		var at: Vector2 = w.pos
		if int(w.get("slot", -1)) >= 0 and int(w.get("stage", sim.stage)) != sim.stage:
			# Earlier chapters' bodies: just a small flash where the effect lands.
			var k_small: float = clampf(age / maxf(.01, float(w.dur)), 0, 1)
			if age >= 0.0:
				shape(at, 2.6 * (1.0 - k_small) + .6, 4, .785, Color(INK, .7 * (1.0 - k_small)))
			continue
		match str(w.get("kind", "gravity")):
			"burn":
				# The lance's track keeps burning: a heat shimmer along the line.
				var k: float = clampf(age / float(w.dur), 0, 1)
				var to: Vector2 = w.to
				var n: Vector2 = (to - at).normalized().orthogonal()
				draw_line(at, to, Color(ACCENT, .05 * (1.0 - k)), 12.0, true)
				var segs: int = 28
				var prev: Vector2 = at
				for j in range(1, segs + 1):
					var q: Vector2 = at.lerp(to, float(j) / segs) + n * sin(j * 1.9 + clock * 26.0) * 3.0 * (1.0 - k)
					stroke(prev, q, Color(ACCENT if j % 3 else INK, .32 * (1.0 - k)))
					prev = q
			"gravity":
				var k: float = clampf(age / float(w.dur), 0, 1)
				var open: float = minf(1.0, age / .25) * (1.0 - pow(k, 6))
				var r: float = float(w.radius) * open
				draw_circle(at, r, Color(0, 0, 0, .45 * open))
				arc_segments(at, r, clock * 2.0, clock * 2.0 + TAU * .8, Color(INK, .7 * open))
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
				arc_segments(at, 10 + (1.0 - q) * 26, 0, TAU, Color(INK, .25 + q * .4))

func draw_swarm() -> void:
	begin_batch()
	draw_swarm_batched()
	flush_batch()

func draw_swarm_batched() -> void:
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
		var legacy: bool = int(p.get("body_stage", sim.stage)) != sim.stage
		for k in range(1, 3 if legacy else 6):
			var puff: Vector2 = curve.call(maxf(0, t - k * .035))
			shape(puff, 1.6 + k * .35, 5, k, Color(GREY, .28 - k * .045))
		var heading: Vector2 = (head - back).normalized() if head != back else dir
		var col: Color = ACCENT if bool(p.crit) else INK
		shape_squash(head, 3.4, 3, 0.0, col, 1.5, .8, heading.angle())

# ================= Doomsday weapons =================

func on_ultimate_fired(kind: String, point: Vector2) -> void:
	ultimate_art.fired(kind, sim.enemies, sim.defense_position())
	var subtitles: Dictionary = {"nuke": TranslationServer.translate("半径 300 · 一切蒸发"), "photoid": TranslationServer.translate("一颗以光速飞行的粒子"), "droplet": TranslationServer.translate("一瞬间，贯穿一切"), "foil": TranslationServer.translate("空间维度 2 → 1"), "fourier": "f(θ) = Σ c · e^(inθ)", "prime": "2 · 3 · 5 · 7 · 11 · 13 · 17 · 19 · 23 · 29", "mandelbrot": "z → z² + c", "lightspeed": "c = 299,792 km/s → 16.7 km/s", "pi": "π = 3.14159265… → 3", "strings": "11D → 4D"}
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
	if kind == "lightspeed":
		var spots: Array = []
		for e in sim.enemies:
			spots.append(Vector2(e.pos))
		ultimate_art.spectral_burst(spots)
	trauma = 1.0
	punch = 1.2
	slowmo_request = true
	add_wave(point, 60.0, 1.6)
	add_wave(point, 40.0, 2.2)
	if kind == "nuke":
		add_feedback("flash", point, 0, 420.0, .9)

func on_prime_strike(prime: int, points: PackedVector2Array) -> void:
	prime_marks.append({"p": prime, "points": points, "age": 0.0})
	trauma = maxf(trauma, .25 + prime / 29.0 * .4)
	punch = maxf(punch, .2 + prime / 29.0 * .6)
	for q in points:
		add_wave(q, 10.0, .7)

func on_flattened(point: Vector2, radius: float, sides: int, heading: float, members: int) -> void:
	ultimate_art.flattened(point, radius, sides, heading, members)

func on_droplet_pass(points: PackedVector2Array) -> void:
	ultimate_art.droplet_passed(points)
	trauma = .8
	punch = 1.1
	add_wave(sim.defense_position(), 55.0, 1.2)
	add_feedback("flash", sim.defense_position(), 0, 160.0, .35)
	for i in range(0, points.size(), maxi(1, points.size() / 10)):
		add_wave(points[i], 16.0, .9)

func on_droplet_shatter(point: Vector2, radius: float, pieces: int, boss: bool) -> void:
	ultimate_art.droplet_shattered(point, radius, pieces, boss)
	# Every detonation lands: a ripple and a kick, stacking into a barrage.
	add_wave(point, 60.0 if boss else 20.0, 1.6 if boss else .8)
	trauma = minf(1.0, maxf(trauma, .45) + (.25 if boss else .03))
	punch = maxf(punch, .55 if boss else .3)

func on_droplet_arrive(point: Vector2) -> void:
	# The instant it is already there: white-out, a hard shake and a held frame.
	trauma = 1.0
	punch = 1.6
	add_wave(point, 70.0, 1.6)
	add_wave(sim.defense_position(), 45.0, 1.4)
	add_feedback("flash", point, 0, 220.0, .5)

func on_fourier_tour(points: PackedVector2Array, fractions: PackedFloat32Array) -> void:
	ultimate_art.fourier_tour_set(points, fractions, sim.defense_position())

func on_fourier_hit(point: Vector2, index: int, total: int) -> void:
	ultimate_art.fourier_struck(point, index, total)
	add_wave(point, 16.0, .8)
	punch = maxf(punch, .28)
	trauma = maxf(trauma, .16)

func on_string_snap(points: PackedVector2Array) -> void:
	ultimate_art.strings_snapped(points)

func animate_ultimates(delta: float) -> void:
	var presentation_delta: float = 0.0 if sim != null and sim.paused else delta
	ultimate_art.animate(presentation_delta, sim)
	# Dimensional resonance: the shaking extra dimensions ripple the whole grid.
	if sim != null and not sim.ult.is_empty() and str(sim.ult.kind) == "strings":
		var su: float = float(sim.ult.age)
		if su > sim.STRINGS_REVEAL * .6 and su < sim.STRINGS_IMPACT:
			string_pulse -= delta
			var res: float = ultimate_art.string_resonance(su)
			if string_pulse <= 0:
				string_pulse = .42 - res * .3
				add_wave(sim.defense_position(), 10.0 + res * 30.0, 1.2)
			trauma = maxf(trauma, .12 + res * .45)
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
	for i in range(prime_marks.size() - 1, -1, -1):
		prime_marks[i].age = float(prime_marks[i].age) + presentation_delta
		if float(prime_marks[i].age) > .9:
			prime_marks.remove_at(i)

const PHOTOID_START := Vector2(70, 40)
var photoid_ripple: float = 0.0
var string_pulse: float = 0.0

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
	ultimate_art.draw_remnants(self)
	if sim.ult.is_empty():
		if sim.grace > 0 and sim.mode == "wave":
			var g: float = clampf(sim.grace / sim.STAGE_GRACE, 0, 1)
			draw_arc(core_at, 96, -PI / 2, -PI / 2 + TAU * g, 64, Color(INK, .6), 2.0, true)
			centered(TranslationServer.translate("新防线部署中  %.1f s") % sim.grace, core_at + Vector2(0, 122), 13, Color(GREY, .9))
		if sim.spawn_hold > 0 and sim.mode in ["wave", "boss"]:
			var k: float = clampf(sim.spawn_hold / 5.0, 0, 1)
			draw_arc(core_at, 96, -PI / 2, -PI / 2 + TAU * k, 64, Color(INK, .7), 2.0, true)
			centered(TranslationServer.translate("敌踪消失  %.1f s") % sim.spawn_hold, core_at + Vector2(0, 122), 13, Color(GREY, .9))
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
				ink_outlined(TranslationServer.translate("光粒  PHOTOID"), head + Vector2(18, -22), Color(1, 1, 1, appear), 13)
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
		"foil", "prime", "lightspeed", "pi", "droplet", "fourier", "mandelbrot", "strings":
			ultimate_art.draw(self, kind, u, at)

# ================= Boss presence and escorts =================

func on_boss_launched(point: Vector2, count: int) -> void:
	add_wave(point, 18.0 + count, 1.1)
	add_feedback("burst", point, 1, 140.0, .6)
	trauma = maxf(trauma, .18)

func boss_aura(p: Vector2, r: float, stage: int, flash: float) -> void:
	# Every boss carries its scale's own signature, so it never reads as just a bigger star.
	var t: float = clock
	var kind: String = str(sim.catalog.stages[stage].boss_kind)
	var none := Color(0, 0, 0, 0)
	# Shared: a slow pressure pulse that radiates from every boss.
	for j in range(3):
		var k: float = fposmod(t * .45 + j / 3.0, 1.0)
		draw_arc(p, r * (1.1 + k * 1.9), 0, TAU, 72, Color(WARN if sim.enraged else INK, (1.0 - k) * (.4 if sim.enraged else .22)), 1.5, true)
	match kind:
		"asteroid":
			# CHIRON: burning entry, a fire cone streaming behind and debris tumbling round it.
			for j in range(14):
				var w: float = (j - 6.5) / 6.5
				var reach: float = r * (2.2 + .9 * sin(t * 7.0 + j * 1.7))
				var base: Vector2 = p + Vector2(w * r * .8, -r * .4)
				draw_line(base, base + Vector2(w * r * .4, -reach), Color(ACCENT.lerp(INK, absf(w)), .35 * (1.0 - absf(w))), 3.0, true)
			for j in range(9):
				var a: float = t * (.9 + j * .07) + j * 2.1
				var q: Vector2 = p + Vector2(cos(a) * r * 1.5, sin(a) * r * .7)
				shape(q, 4.0 + (j % 3) * 2.0, 4 + j % 3, t * 2.0 + j, GREY)
			for j in range(5):
				var a: float = j * 1.3 + .4
				stroke(p + Vector2.from_angle(a) * r * .2, p + Vector2.from_angle(a + .3) * r * .85, Color(ACCENT, .55 + .3 * sin(t * 5.0 + j)))
		"planet":
			# NOMAD: an atmosphere halo, tidal ripples and a ring of captured moonlets.
			draw_circle(p, r * 1.18, Color(INK, .06))
			draw_arc(p, r * 1.18, 0, TAU, 72, Color(INK, .35), 2.0, true)
			for j in range(6):
				var a: float = t * .35 + j * TAU / 6
				var q: Vector2 = p + Vector2(cos(a) * r * 1.9, sin(a) * r * .9)
				draw_circle(q, 7.0, SHADE)
				draw_arc(q, 7.0, 0, TAU, 20, INK, 1.5, true)
				draw_circle(q + Vector2(2, -2), 1.6, GREY)
			draw_arc(p, r * 1.9, 0, TAU, 96, Color(INK, .12), 1.0, true)
		"mothership":
			# LEVIATHAN: a flickering hex shield, three engine plumes and hangar lights.
			var shield := ngon(6, r * 1.45, t * .1, p)
			shield.append(shield[0])
			draw_polyline(shield, Color(INK, .25 + .2 * absf(sin(t * 6.0)) + flash * .5), 2.0, true)
			for i in range(6):
				draw_line(p, shield[i], Color(INK, .06), 1.0, true)
			for j in range(3):
				var x: float = (j - 1) * r * .45
				var reach: float = r * (1.0 + .3 * sin(t * 12.0 + j))
				draw_line(p + Vector2(x, -r * .7), p + Vector2(x, -r * .7 - reach), Color(ACCENT, .5), 6.0, true)
				draw_line(p + Vector2(x, -r * .7), p + Vector2(x, -r * .7 - reach * .6), Color.WHITE, 2.0, true)
			for j in range(8):
				var on: bool = fposmod(t * 3.0 + j * .37, 1.0) < .5
				draw_circle(p + Vector2((j - 3.5) * r * .2, r * .62), 2.6, ACCENT if on else DIM)
		"star":
			# VESPER: an unstable corona, looping flares and a heat shimmer.
			for j in range(24):
				var a: float = j * TAU / 24 + t * .2
				var reach: float = r * (.35 + .3 * absf(sin(t * 3.0 + j * 1.9)))
				draw_line(p + Vector2.from_angle(a) * r * 1.05, p + Vector2.from_angle(a) * (r * 1.05 + reach), Color(ACCENT, .55), 2.0, true)
			for j in range(3):
				var a0: float = t * (.5 + j * .2) + j * 2.1
				var arc_r: float = r * (1.3 + .15 * j)
				draw_arc(p + Vector2.from_angle(a0) * r * .9, arc_r * .5, a0 - 1.2, a0 + 1.2, 24, Color(ACCENT, .7), 2.5, true)
			draw_circle(p, r * 1.6, Color(ACCENT, .05 + .03 * sin(t * 4.0)))
		"cathedral":
			# CATHEDRAL: counter-rotating arches, spires casting beams, a drone halo.
			for j in range(4):
				var rr: float = r * (1.25 + j * .28)
				var spin: float = t * (.3 if j % 2 == 0 else -.25) + j
				for k in range(3):
					var a: float = spin + k * TAU / 3
					draw_arc(p, rr, a, a + 1.4, 32, Color(INK, .45 - j * .08), 2.0, true)
			for j in range(5):
				var a: float = -PI / 2 + (j - 2) * .45
				var top: Vector2 = p + Vector2.from_angle(a) * r * 1.4
				draw_line(p + Vector2.from_angle(a) * r * .8, top, INK, 2.5, true)
				draw_line(top, top + Vector2.from_angle(a) * 220.0, Color(INK, .08 + .06 * sin(t * 4.0 + j)), 6.0, true)
			for j in range(12):
				var a: float = t * .6 + j * TAU / 12
				shape(p + Vector2.from_angle(a) * r * 2.3, 3.5, 4, a, Color(INK, .7))
		"dwarf":
			# CERES: three thruster plumes shove it forward; alien tugs ride alongside.
			for j in range(3):
				var a: float = -PI * .5 + (j - 1) * .62
				var tip: Vector2 = p + Vector2.from_angle(a) * r * 1.42
				var reach: float = r * (1.0 + .35 * sin(t * 14.0 + j * 2.0))
				draw_line(tip, tip + Vector2.from_angle(a) * reach, Color(ACCENT, .45), 7.0, true)
				draw_line(tip, tip + Vector2.from_angle(a) * reach * .6, Color.WHITE, 2.0, true)
				for k in range(4):
					var puff: float = fposmod(t * 1.6 + k * .25 + j * .1, 1.0)
					draw_circle(tip + Vector2.from_angle(a) * reach * (.6 + puff * 1.2), 2.0 + puff * 5.0, Color(GREY, .3 * (1.0 - puff)))
			for j in range(5):
				var a: float = t * .5 + j * TAU / 5
				var q: Vector2 = p + Vector2(cos(a) * r * 1.8, sin(a) * r * .8)
				shape(q, 4.5, 3, a + PI * .5, INK)
				draw_line(q, p + (q - p) * .62, Color(INK, .12), 1.0, true)
		"cigar":
			# 'OUMUAMUA: silent probe sweeps, and data glyphs orbiting in rings.
			for j in range(2):
				var a: float = t * (.7 + j * .4) + j * PI
				var dir := Vector2.from_angle(a)
				draw_line(p, p + dir * r * 4.5, Color(INK, .07), 26.0, true)
				draw_line(p, p + dir * r * 4.5, Color(INK, .35), 1.0, true)
			for j in range(3):
				var rr: float = r * (1.9 + j * .45)
				for k in range(10 + j * 4):
					var a: float = k * TAU / (10 + j * 4) + t * (.3 - j * .12)
					var q: Vector2 = p + Vector2(cos(a) * rr, sin(a) * rr * .55)
					if (k + j) % 3 == 0:
						draw_line(q - Vector2(3, 0), q + Vector2(3, 0), Color(INK, .5), 1.0, true)
					else:
						draw_circle(q, 1.3, Color(INK, .45))
		"magnetar":
			# MAGNETAR: starquake rings and a hard X-ray flicker.
			for j in range(3):
				var k: float = fposmod(t * .8 + j / 3.0, 1.0)
				var quake := PackedVector2Array()
				for q in range(41):
					var a: float = q * TAU / 40
					quake.append(p + Vector2.from_angle(a) * r * (1.0 + k * 2.6) * (1.0 + sin(a * 9.0 + t * 6.0) * .03))
				draw_polyline(quake, Color(INK, (1.0 - k) * .45), 1.4, true)
			var flick: float = pow(absf(sin(t * 7.3)), 18.0)
			draw_circle(p, r * 1.3, Color(1, 1, 1, .05 + flick * .12))
		"brane":
			# Interference: where the two membranes press, fringes race toward us.
			var core: Vector2 = sim.defense_position()
			var toward: float = (core - p).angle()
			var contact: Vector2 = p + Vector2.from_angle(toward) * r * 1.25
			for j in range(7):
				var k: float = fposmod(t * .5 + j / 7.0, 1.0)
				draw_arc(contact, 12.0 + k * r * 2.2, toward - 1.0, toward + 1.0, 40, Color(ACCENT if j % 2 == 0 else INK, (1.0 - k) * .45), 1.4, true)
			draw_circle(contact, 5.0 + sin(t * 6.0) * 1.5, Color(1, 1, 1, .8))
		_:
			# THE SILENCE: cracks in space reaching out, light falling inward.
			for j in range(9):
				var a: float = j * TAU / 9 + sin(t * .3 + j) * .2
				var pts := PackedVector2Array([p + Vector2.from_angle(a) * r * .5])
				var cur: float = r * .5
				for k in range(5):
					cur += r * (.25 + .1 * sin(j * 3.0 + k))
					pts.append(p + Vector2.from_angle(a + sin(j * 7.0 + k * 2.3) * .18) * cur)
				draw_polyline(pts, Color(INK, .55 + .3 * sin(t * 2.0 + j)), 1.5, true)
			for j in range(30):
				var k: float = fposmod(t * .5 + j * .033, 1.0)
				var a: float = j * 2.399
				draw_circle(p + Vector2.from_angle(a + k) * r * (3.0 - 2.5 * k), 1.6, Color(INK, k))
			draw_circle(p, r * .9, Color(0, 0, 0, .5))

func draw_escort(e: Dictionary, p: Vector2, flash: float) -> void:
	var stage: int = int(e.escort)
	var kind: String = str(sim.catalog.stages[clampi(stage, 0, sim.LAST_STAGE)].boss_kind)
	var heading: float = (Vector2(e.end) - Vector2(e.start)).angle()
	var dir := Vector2.from_angle(heading)
	var born: float = float(e.age)
	var appear: float = pop(born)
	var t: float = clock + int(e.seed)
	var col: Color = INK.lerp(Color.WHITE, flash)
	var none := Color(0, 0, 0, 0)
	var s: float = 9.0 * appear
	var dk: float = doppler_k()
	if dk > .01:
		col = doppler_tint(col, p, dir, dk)
		doppler_ghosts(p, s * 1.1, dir, dk)
	match kind:
		"asteroid":
			stroke(p, p - dir * 26.0, Color(ACCENT, .55))
			shape(p, s, 5, t * 2.0, col)
		"planet":
			draw_circle(p, s, SHADE)
			draw_arc(p, s, 0, TAU, 20, col, 1.5, true)
			draw_circle(p + Vector2(2, -2), 2.0, GREY)
		"mothership", "dwarf":
			var nrm := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + dir * s * 1.4, p - dir * s * .8 + nrm * s, p - dir * s * .4, p - dir * s * .8 - nrm * s]), col)
			draw_circle(p - dir * s * .7, 2.2 + sin(t * 20.0), ACCENT)
		"star":
			var glow_col: Color = doppler_tint(ACCENT, p, dir, dk)
			draw_circle(p, s * 1.6, Color(glow_col, .15))
			draw_circle(p, s * .8, glow_col.lerp(Color.WHITE, flash))
			draw_arc(p, s * 1.2, t * 3.0, t * 3.0 + 4.0, 16, Color(ACCENT, .7), 1.5, true)
		"cigar":
			# Comets shed by the visitor: head, coma and a tail streaming behind.
			draw_line(p, p - dir * s * 4.0, Color(INK, .45), 2.0, true)
			draw_line(p, p - (dir + dir.orthogonal() * .3).normalized() * s * 3.0, Color(INK, .25), 3.0, true)
			draw_circle(p, s * .55, col)
			draw_arc(p, s * .95, 0, TAU, 16, Color(INK, .4), 1.0, true)
		"magnetar":
			# Plasma knots threaded on a field line.
			draw_circle(p, s * .6, col)
			draw_arc(p, s * 1.3, t * 4.0, t * 4.0 + 2.2, 14, Color(INK, .7), 1.4, true)
			draw_arc(p, s * 1.3, t * 4.0 + PI, t * 4.0 + PI + 2.2, 14, Color(INK, .7), 1.4, true)
		"brane":
			# Baby universes budding off the other brane.
			draw_circle(p, s * 1.1, Color(BG, .9))
			draw_arc(p, s * 1.1 * (1.0 + .08 * sin(t * 7.0)), 0, TAU, 20, col, 1.6, true)
			draw_circle(p, 1.6, Color(ACCENT, .9))
		"cathedral":
			shape(p, s, 4, PI / 4, none, col, 1.6)
			draw_arc(p, s * 1.5, t * 2.0, t * 2.0 + 3.6, 16, Color(INK, .6), 1.2, true)
			draw_circle(p, 2.0, col)
		_:
			var shard := PackedVector2Array([p + dir * s * 1.6, p + dir.orthogonal() * s * .6, p - dir * s * .9, p - dir.orthogonal() * s * .5])
			draw_colored_polygon(shard, Color(0, 0, 0, .85))
			shard.append(shard[0])
			draw_polyline(shard, col, 1.3, true)
	# A thin tether back toward where its boss launched it, for the first second.
	if born < 1.0:
		stroke(p, Vector2(e.start), Color(INK, .25 * (1.0 - born)))
	var danger: float = float(e.age) / float(e.lifetime)
	if danger > .7:
		draw_arc(p, 16.0, -PI * .5, -PI * .5 + TAU * danger, 24, Color(ACCENT, .85), 1.5, true)

# ================= Boss skills =================
var skill_pop: Dictionary = {}
const WARN := Color("ff5a47")

func on_boss_skill(event: String, kind: String, point: Vector2) -> void:
	var name: String = TranslationServer.translate(str(sim.SKILL_NAMES.get(kind, "")))
	match event:
		"windup":
			skill_pop = {"text": name, "sub": "BOSS SKILL", "age": 0.0, "col": ACCENT}
			trauma = maxf(trauma, .2)
		"fire":
			trauma = maxf(trauma, .55)
			punch = maxf(punch, .5)
			add_wave(point, 40.0, 1.4)
			if kind == "siege_beam":
				add_feedback("flash", sim.defense_position(), 0, 260.0, .5)
		"broken":
			skill_pop = {"text": "打断！", "sub": name + "  ·  INTERRUPTED", "age": 0.0, "col": INK}
			add_feedback("burst", point, 0, 220.0, .7)
			add_wave(point, 30.0, 1.0)
			punch = maxf(punch, .6)
		"enrage":
			skill_pop = {"text": "狂暴", "sub": "BOSS ENRAGED", "age": 0.0, "col": WARN}
			trauma = maxf(trauma, .7)
			add_wave(point, 55.0, 1.6)

func draw_boss_skill() -> void:
	var boss: Dictionary = sim.boss_actor()
	if boss.is_empty():
		skill_pop = {}
		return
	var p: Vector2 = boss.pos
	var r: float = float(boss.radius)
	var core: Vector2 = sim.defense_position()
	var t: float = clock
	if sim.enraged:
		# Enraged: a ragged red-amber corona flickers round the boss.
		for j in range(18):
			var a: float = j * TAU / 18 + t * .6
			var reach: float = r * (1.3 + .35 * absf(sin(t * 9.0 + j * 2.1)))
			draw_line(p + Vector2.from_angle(a) * r * 1.05, p + Vector2.from_angle(a) * reach, Color(WARN, .5), 2.0, true)
	var sk: Dictionary = sim.skill
	if not sk.is_empty():
		var kind: String = sk.kind
		var windup: bool = str(sk.phase) == "windup"
		var dur: float = float(sim.SKILL_WINDUP[kind]) if windup else float(sim.SKILL_ACTIVE[kind])
		var k: float = clampf(float(sk.age) / dur, 0, 1)
		if windup:
			# Charge ring round the boss; breakable skills show how much damage breaks them.
			draw_arc(p, r + 26, -PI / 2, -PI / 2 + TAU * k, 64, Color(WARN if kind in sim.SKILL_BREAKABLE else ACCENT, .9), 3.0, true)
			if kind in sim.SKILL_BREAKABLE:
				var need: float = sim.boss_max_hp() * sim.SKILL_BREAK_SHARE
				var dealt: float = clampf((float(sk.hp) - float(boss.hp)) / need, 0, 1)
				draw_arc(p, r + 34, -PI / 2, -PI / 2 + TAU * dealt, 64, Color(INK, .9), 2.0, true)
				centered("集火打断  %d%%" % int(dealt * 100), p + Vector2(0, r + 58), 12, Color(INK, .9), true)
		match kind:
			"meteor_rain":
				if windup:
					for i in range(10):
						var x: float = lerpf(sim.spawn_rect.position.x + 60, sim.spawn_rect.end.x - 60, (i + .5) / 10.0)
						var target := Vector2(core.x + (x - core.x) * .15, core.y)
						var blink: float = .4 + .6 * absf(sin(t * 10.0 + i))
						draw_line(Vector2(x, sim.spawn_rect.position.y + 10), target, Color(WARN, .12 * k), 1.0, true)
						draw_arc(target, 10 + 6 * (1.0 - k), 0, TAU, 20, Color(WARN, blink * k), 1.5, true)
			"tidal_shield":
				var rings: int = 4
				for j in range(rings):
					var rr: float = r * (1.25 + j * .22)
					if windup:
						rr = lerpf(r * (3.5 + j), rr, k)
					var spin: float = t * (1.2 if j % 2 == 0 else -1.0)
					draw_arc(p, rr, spin, spin + 4.2, 48, Color(INK, (.35 + .15 * j) * (k if windup else 1.0)), 2.0, true)
				if not windup:
					centered("伤害 -70%", p + Vector2(0, -r - 34), 12, Color(INK, .9), true)
			"siege_beam":
				if windup:
					var wobble: float = sin(t * 30.0) * 2.0 * (1.0 - k)
					for side in [-1.0, 1.0]:
						var off: Vector2 = (core - p).normalized().orthogonal() * side * (24.0 * (1.0 - k) + 2.0 + wobble)
						draw_line(p + off, core + off, Color(WARN, .25 + .5 * k), 1.0, true)
					draw_circle(p + (core - p).normalized() * r, 6.0 + 10.0 * k, Color(WARN, .5 + .5 * k))
					draw_arc(core, 70 - 40 * k, 0, TAU, 32, Color(WARN, .8), 2.0, true)
				else:
					var w: float = 26.0 * (1.0 - k)
					draw_line(p, core, Color(WARN, .35 * (1.0 - k)), w * 2.0, true)
					draw_line(p, core, Color(1, 1, 1, 1.0 - k), w * .5 + 1.0, true)
					centered("撞击倒计时 -2.5s", core + Vector2(0, -110), 14, Color(WARN, 1.0 - k), true)
			"corona":
				if windup:
					draw_circle(p, r * (1.2 + .5 * k), Color(ACCENT, .1 + .15 * k))
					for j in range(16):
						var a: float = j * TAU / 16 + t
						draw_line(p + Vector2.from_angle(a) * r, p + Vector2.from_angle(a) * r * (1.4 + k), Color(ACCENT, .6), 2.0, true)
				else:
					var rr: float = 420.0 * ease_out(k)
					draw_arc(p, rr, 0, TAU, 128, Color(ACCENT, (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
					draw_arc(p, rr * .9, 0, TAU, 128, Color(1, 1, 1, (1.0 - k) * .5), 1.0, true)
			"summon":
				var portals: Array = [p + Vector2(-r * 2.6, r * .4), p + Vector2(r * 2.6, r * .4), p + Vector2(0, -r * 1.9)]
				for q in portals:
					var open: float = k if windup else 1.0 - k
					for j in range(3):
						draw_arc(q, (10 + j * 9) * open, t * (2 + j), t * (2 + j) + 4.5, 32, Color(INK, .8 - j * .2), 2.0, true)
					draw_circle(q, 6.0 * open, Color(0, 0, 0, .9))
			"magnetic_field":
				# The dipole field flares out to its edge; rounds inside it bend away.
				var field: float = r * sim.MAGNET_FIELD
				var reach: float = field * (k if windup else 1.0)
				var tilt: float = t * .9
				var axis := Vector2.from_angle(tilt)
				for j in range(4):
					var l: float = reach * (.45 + j * .19)
					for side in [-1.0, 1.0]:
						var loop := PackedVector2Array()
						for q in range(41):
							var th: float = .1 + (PI - .2) * q / 40.0
							var rr: float = l * sin(th) * sin(th)
							var local := Vector2(cos(th) * rr, sin(th) * rr * side)
							loop.append(p + axis * local.x + axis.orthogonal() * local.y)
						draw_polyline(loop, Color(ACCENT if j == 3 else INK, (.18 + .1 * j) * (k if windup else .7 + .3 * sin(t * 8.0))), 1.2, true)
				draw_arc(p, reach, 0, TAU, 96, Color(ACCENT, .55 if not windup else .3 * k), 1.6, true)
				if not windup:
					centered(TranslationServer.translate("磁场偏转 · 弹体偏折"), p + Vector2(0, -r - 34), 12, Color(ACCENT, .95), true)
			"devour":
				for j in range(40):
					var ph: float = fposmod(t * .9 + j * .025, 1.0)
					var a: float = j * 2.399 + t * .3
					var q: Vector2 = p + Vector2.from_angle(a) * r * (5.0 - 4.2 * ph)
					draw_line(q, q + (p - q).normalized() * 12.0, Color(INK, ph * (k if windup else 1.0 - k)), 1.2, true)
				draw_circle(p, r * .5 * (k if windup else 1.0), Color(0, 0, 0, .7))
				if not windup:
					centered("+5% HP", p + Vector2(0, -r - 34), 13, Color(WARN, 1.0 - k), true)
	# Skill name pops in over the boss: overshoot in, hold, rise away.
	if not skill_pop.is_empty():
		var a: float = float(skill_pop.age)
		var inn: float = ease_out_back(clampf(a / .35, 0, 1))
		var out: float = clampf((a - 1.4) / .4, 0, 1)
		if out >= 1.0:
			skill_pop = {}
		else:
			var at: Vector2 = p + Vector2(0, r + 96 - out * 20)
			draw_set_transform(at, 0, Vector2.ONE * (.6 + .4 * inn))
			centered(str(skill_pop.text), Vector2.ZERO, 30, Color(skill_pop.col, 1.0 - out), true)
			centered(str(skill_pop.sub), Vector2(0, 24), 11, Color(GREY, 1.0 - out), true)
			draw_set_transform(Vector2.ZERO)
