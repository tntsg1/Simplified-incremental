extends RefCounted
# Cached stellar geography. Only transforms and a few flow packets animate;
# visual detail never adds simulation entities or changes celestial positions.
const WHITE := Color("d3d3ce")
const AMBER := Color("ffc94d")
const CENTER := Vector2(500, 325)
# Where the Sun sits in the Milky Way map (the solar defense shrinks into it).
const SUN_IN_GALAXY := Vector2(660, 341)
# Laniakea's basins: every streamline drains toward these.
const ATTRACTORS: Array = [[Vector2(205, 470), 1.0], [Vector2(305, 210), .42], [Vector2(-260, 560), .7], [Vector2(735, 170), .22]]
# Chapters whose maps are drawn here (Oort cloud and beyond).
const MAPPED: Array[int] = [4, 5, 6, 7, 8, 9]
var clouds: Array[MultiMesh] = []
var scaled_clouds: Dictionary = {}
var arms: Array[PackedVector2Array] = []
var nodes: PackedVector2Array = []
var filaments: Array[PackedVector2Array] = []
var web_dust: MultiMesh
var hover_strength: Dictionary = {}
var belt: MultiMesh
var kuiper: MultiMesh
var oort_shell: MultiMesh
var hills: MultiMesh
var near_stars: MultiMesh
var bubble := PackedVector2Array()
var flows: Array[PackedVector2Array] = []
var lani_dust: MultiMesh
var lani_edge := PackedVector2Array()
var horizon: MultiMesh
var bulk_dust: MultiMesh

func _init() -> void:
	for profile in range(4):
		clouds.append(make_cloud(profile))
	for spec in [[0, 302.0], [0, 106.0], [0, 76.0], [1, 59.0], [3, 52.0], [3, 40.0], [2, 60.0], [2, 45.0], [1, 49.0], [3, 30.0], [3, 24.0], [0, 46.0], [1, 38.0]]:
		scaled_cloud(int(spec[0]), float(spec[1]))
	for radius in [15.0, 20.0, 25.0, 30.0, 35.0]:
		scaled_cloud(2, radius)
	for arm in range(4):
		var path := PackedVector2Array()
		for step in range(65):
			var t: float = float(step) / 64.0
			var angle: float = arm * TAU / 4.0 + t * 4.7
			path.append(Vector2.from_angle(angle) * (14.0 + t * 252.0))
		arms.append(path)
	for i in range(34):
		var radius: float = sqrt(float(i) / 34.0) * 290.0
		nodes.append(CENTER + Vector2.from_angle(i * 2.399) * radius)
	# Ambient nodes gather around three supercluster basins. The six gameplay
	# nodes keep their exact simulation coordinates and remain selectable.
	var anchors: Array[Vector2] = [nodes[5], nodes[14], nodes[26]]
	for i in range(nodes.size()):
		if i in [5, 9, 14, 20, 26, 31]: continue
		nodes[i] = nodes[i].lerp(anchors[i % 3], .30 + (i % 4) * .08)
		if nodes[i].distance_to(CENTER) < 75:
			nodes[i] = CENTER + (nodes[i] - CENTER).normalized() * 85.0
	var edges: Dictionary = {}
	for i in range(nodes.size()):
		var nearest: Array[int] = []
		for j in range(nodes.size()):
			if j != i: nearest.append(j)
		nearest.sort_custom(func(a: int, b: int): return nodes[i].distance_squared_to(nodes[a]) < nodes[i].distance_squared_to(nodes[b]))
		for j in nearest.slice(0, 2):
			var key: String = "%d:%d" % [mini(i, j), maxi(i, j)]
			if edges.has(key): continue
			edges[key] = true
			var edge: PackedVector2Array = curve(nodes[i], nodes[j], sin(i * 2.7 + j) * 24.0)
			if path_point(edge, .5).distance_to(CENTER) > 70:
				filaments.append(edge)
	for pair in [[5, 14], [14, 26], [26, 9], [9, 31]]:
		filaments.append(curve(nodes[int(pair[0])], nodes[int(pair[1])], 58.0))
	var points := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 81516
	for path in filaments:
		for j in range(48):
			var p: Vector2 = path_point(path, rng.randf())
			p += Vector2(rng.randfn(0, 5.0), rng.randfn(0, 5.0))
			points.append(p)
	web_dust = point_mesh(points, 8116, .14, .32)
	build_solar_belts(rng)
	build_oort(rng)
	build_neighbourhood(rng)
	build_laniakea(rng)
	build_horizon(rng)

# ---------- cached geography for the ten-chapter maps ----------

func build_solar_belts(rng: RandomNumberGenerator) -> void:
	# Main asteroid belt (between Mars and Jupiter) and the Kuiper belt.
	var points := PackedVector2Array()
	for i in range(520):
		var r: float = 250.0 + pow(rng.randf(), 1.3) * 44.0 * (1.0 if rng.randf() < .8 else 1.4)
		points.append(Vector2.from_angle(rng.randf() * TAU) * r)
	belt = point_mesh(points, 2271, .14, .42)
	points = PackedVector2Array()
	for i in range(560):
		var r: float = 314.0 + rng.randfn(0.0, 18.0)
		points.append(Vector2.from_angle(rng.randf() * TAU) * r)
	kuiper = point_mesh(points, 3301, .1, .3)

func build_oort(rng: RandomNumberGenerator) -> void:
	# A spherical shell of comet nuclei seen from outside: projected, the limb
	# thickens, which is what gives the cloud its depth.
	var points := PackedVector2Array()
	for i in range(1900):
		var z: float = rng.randf_range(-1.0, 1.0)
		var a: float = rng.randf() * TAU
		var ring: float = sqrt(1.0 - z * z)
		var r: float = 168.0 + pow(rng.randf(), .8) * 175.0
		points.append(Vector2(cos(a) * ring, sin(a) * ring * .92) * r)
	oort_shell = point_mesh(points, 4417, .1, .5)
	points = PackedVector2Array()
	for i in range(650):
		var a: float = rng.randf() * TAU
		var r: float = 72.0 + pow(rng.randf(), .9) * 92.0
		points.append(Vector2(cos(a) * r, sin(a) * r * .34))
	hills = point_mesh(points, 4423, .12, .4)

func build_neighbourhood(rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	for i in range(700):
		var p := Vector2(rng.randf_range(-260, 1260), rng.randf_range(-60, 700))
		# The galactic plane runs diagonally across the local sky: stars crowd it.
		if i % 3 == 0:
			var u: float = rng.randf_range(-1.0, 1.0)
			p = CENTER + Vector2(u * 760, u * -190) + Vector2(rng.randfn(0, 18), rng.randfn(0, 46))
		points.append(p)
	near_stars = point_mesh(points, 5507, .08, .42)
	for i in range(73):
		var a: float = i * TAU / 72
		var r: float = 128.0 + sin(a * 3 + .4) * 18.0 + sin(a * 5 - 1.1) * 9.0 + sin(a * 2 + 2.0) * 12.0
		bubble.append(CENTER + Vector2(cos(a) * r * 1.18, sin(a) * r * .9) + Vector2(-14, 6))

func flow_field(p: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for item in ATTRACTORS:
		var a: Vector2 = item[0]
		var d: Vector2 = a - p
		v += d.normalized() * float(item[1]) / pow(maxf(40.0, d.length()) / 200.0, 1.15)
	return v

func build_laniakea(rng: RandomNumberGenerator) -> void:
	# Streamlines of galaxy motion: seeded across the field, they braid into rivers
	# that all drain into the Great Attractor basin.
	for gx in range(11):
		for gy in range(7):
			var p := Vector2(-120 + gx * 125 + rng.randf_range(-30, 30), -10 + gy * 105 + rng.randf_range(-30, 30))
			var path := PackedVector2Array([p])
			for k in range(90):
				var v: Vector2 = flow_field(p)
				p += v.normalized() * 7.0
				path.append(p)
				var close: bool = false
				for item in ATTRACTORS:
					if p.distance_to(item[0]) < 22.0:
						close = true
				if close:
					break
			if path.size() > 8:
				flows.append(path)
	var points := PackedVector2Array()
	for path in flows:
		for j in range(18):
			points.append(path_point(path, rng.randf()) + Vector2(rng.randfn(0, 7), rng.randfn(0, 7)))
	for i in range(500):
		points.append(Vector2(rng.randf_range(-250, 1250), rng.randf_range(-40, 680)))
	lani_dust = point_mesh(points, 6611, .1, .38)
	for i in range(97):
		var a: float = i * TAU / 96
		var r: float = 1.0 + sin(a * 3 + 1.3) * .08 + sin(a * 7 - .4) * .04
		lani_edge.append(Vector2(430, 340) + Vector2(cos(a) * 470, sin(a) * 300) * r)

func build_horizon(rng: RandomNumberGenerator) -> void:
	# The particle horizon: the farthest light, mottled like the microwave background.
	var points := PackedVector2Array()
	for i in range(1500):
		var a: float = rng.randf() * TAU
		var r: float = 318.0 + rng.randfn(0.0, 5.0) + sin(a * 23.0) * 3.0
		points.append(Vector2(cos(a) * r * 1.42, sin(a) * r * .99))
	horizon = point_mesh(points, 7723, .08, .55)
	points = PackedVector2Array()
	for i in range(420):
		points.append(Vector2(rng.randf_range(-260, 1260), rng.randf_range(-60, 700)))
	bulk_dust = point_mesh(points, 8819, .05, .22)

func make_cloud(profile: int) -> MultiMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42011 + profile * 143
	var points := PackedVector2Array()
	var count: int = 3600 if profile == 0 else 950
	for i in range(count):
		var t: float = rng.randf()
		var radius: float = pow(t, .7) * 268.0
		var angle: float = t * 4.7 + (i % (3 if profile == 1 else 4)) * TAU / (3.0 if profile == 1 else 4.0)
		angle += rng.randfn(0, .09 + t * .08)
		if profile == 2:
			angle = rng.randf() * TAU
			radius = pow(t, 1.65) * 260.0
		elif profile == 3:
			angle += rng.randfn(0, .4)
		points.append(Vector2.from_angle(angle) * radius + Vector2(rng.randfn(0, 2), rng.randfn(0, 2)))
	return point_mesh(points, 391 + profile, .20, .66)

func point_mesh(points: PackedVector2Array, seed_value: int, low: float, high: float) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	mesh.mesh = quad
	mesh.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(points.size()):
		var width: float = rng.randf_range(.8, 1.8) if i % 13 else 2.5
		mesh.set_instance_transform_2d(i, Transform2D(0, Vector2.ONE * width, 0, points[i]))
		mesh.set_instance_color(i, Color(WHITE, rng.randf_range(low, high)))
	return mesh

func curve(a: Vector2, b: Vector2, bend: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var perpendicular: Vector2 = (b - a).normalized().orthogonal()
	for i in range(25):
		var t: float = float(i) / 24.0
		path.append(a.lerp(b, t) + perpendicular * sin(t * PI) * bend)
	return path

func path_point(path: PackedVector2Array, t: float) -> Vector2:
	var at: float = clampf(t, 0, .99999) * (path.size() - 1)
	var index: int = int(at)
	return path[index].lerp(path[index + 1], at - index)

func advance(delta: float, field: Node2D) -> void:
	var sim: RefCounted = field.sim
	if sim == null: return
	for k in range(sim.BODIES[sim.stage].size()):
		var key: int = sim.stage * 16 + k
		var active: bool = field.hover.distance_to(sim.body_position(sim.stage, k)) < field.body_pick_radius(sim.stage, k)
		hover_strength[key] = move_toward(float(hover_strength.get(key, 0.0)), 1.0 if active else 0.0, delta * 5.5)

func scaled_cloud(profile: int, radius: float) -> MultiMesh:
	var key: String = "%d:%d" % [profile, int(radius)]
	if scaled_clouds.has(key): return scaled_clouds[key]
	var source: MultiMesh = clouds[profile]
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	mesh.mesh = source.mesh
	mesh.instance_count = mini(source.instance_count, 480 if radius < 40 else 950) if radius < 150 else source.instance_count
	for i in range(mesh.instance_count):
		var transform: Transform2D = source.get_instance_transform_2d(i)
		transform.origin *= radius / 268.0
		transform.x *= .65 if radius < 40 else .85
		transform.y *= .65 if radius < 40 else .85
		mesh.set_instance_transform_2d(i, transform)
		var ink: Color = source.get_instance_color(i)
		ink.a *= .65 if radius < 40 else .85
		if transform.origin.length() < radius * .24:
			ink.a *= .42
		mesh.set_instance_color(i, ink)
	scaled_clouds[key] = mesh
	return mesh

func cloud(field: Node2D, at: Vector2, radius: float, profile: int, angle: float, flatten: float = .72) -> void:
	var local := Transform2D(angle, Vector2(1.0, flatten), 0, at)
	field.draw_set_transform_matrix(field.scene_transform * local)
	field.draw_multimesh(scaled_cloud(profile, radius), null)
	# A layered bulge gives the stars depth without a glowing photo backdrop.
	for j in range(5 if radius > 40 else 2, 0, -1):
		field.draw_circle(Vector2.ZERO, (4.0 + j * 4.8) * minf(1.0, radius / 80.0), Color(WHITE, .026))
	field.draw_circle(Vector2.ZERO, 2.2 if radius < 40 else 3.2, Color(WHITE, .24 if radius < 40 else .36))
	field.draw_set_transform_matrix(field.scene_transform)

func points_at(field: Node2D, mesh: MultiMesh, at: Vector2, angle: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	field.draw_set_transform_matrix(field.scene_transform * Transform2D(angle, scale, 0, at))
	field.draw_multimesh(mesh, null)
	field.draw_set_transform_matrix(field.scene_transform)

func path(field: Node2D, points: PackedVector2Array, alpha: float, live: bool, phase: float, highlight: float = 0.0) -> void:
	var ink: Color = WHITE.lerp(AMBER, highlight * .8)
	for i in range(points.size() - 1):
		field.stroke(points[i], points[i + 1], Color(ink, alpha + highlight * .2))
	if field.reduced_effects: return
	for j in range(2 if live else 1):
		var t: float = fposmod(field.clock * (.11 if live else .028) + phase + j * .5, 1.0)
		var p: Vector2 = path_point(points, t)
		field.shape(p, 1.8 if live else 1.0, 4, .785, Color(ink, .75 if live else .32))
		if live:
			field.stroke(path_point(points, maxf(0.0, t - .055)), p, Color(ink, .4))

func dashed_loop(field: Node2D, points: PackedVector2Array, color: Color, every: int = 2) -> void:
	for i in range(points.size() - 1):
		if i % every == 0:
			field.stroke(points[i], points[i + 1], color)

func dashed_ring(field: Node2D, center: Vector2, radius: float, color: Color, squash: float = 1.0, dashes: int = 48) -> void:
	for j in range(0, dashes, 2):
		var a0: float = j * TAU / dashes
		var a1: float = (j + 1) * TAU / dashes
		field.stroke(center + Vector2(cos(a0), sin(a0) * squash) * radius, center + Vector2(cos(a1), sin(a1) * squash) * radius, color)

func draw(field: Node2D, stage: int) -> void:
	if stage not in MAPPED: return
	var time: float = 0.0 if field.reduced_effects else field.clock
	var current: bool = stage == field.sim.stage and field.sim.mode != "transition"
	match stage:
		4: oort(field, time)
		5: neighbourhood(field, time)
		6: galaxy(field, time)
		7: supercluster(field, time, current)
		8: universe(field, time)
		9: brane(field, time)
	# Focus and conversion feed into the actual celestial weapon state.
	if not current: return
	for k in range(field.sim.BODIES[stage].size()):
		var key: int = stage * 16 + k
		var at: Vector2 = field.sim.body_position(stage, k)
		var live: bool = field.sim.body_converted_at(stage, k)
		var focus: float = float(hover_strength.get(key, 0.0))
		var flash: float = clampf(float(field.body_flash.get(key, 0.0)) / field.BODY_KICK_TIME, 0, 1)
		var r: float = field.body_pick_radius(stage, k) + 5.0
		if focus > .01 or live:
			for j in range(4):
				var a: float = j * PI * .5 + time * .15
				field.draw_arc(at, r, a, a + .35 + focus * .2, 8, Color(AMBER if focus > .01 else WHITE, .25 + focus * .65 + flash * .1), 1.2, true)
		if flash > .01:
			field.ring(at, r + (1 - flash) * 32, Color(WHITE, flash * .35), 1.2)
		if stage in [5, 6, 8, 9]:
			path(field, curve(CENTER, at, 22.0 + k * 7.0), .075 if live else .025, live, k * .27, focus)
		var note: String = str(field.sim.BODIES[stage][k].get("note", ""))
		if focus > .1:
			field.ink(str(field.sim.BODIES[stage][k].name), at + Vector2(r + 8, -7), Color(AMBER, focus), 13)
			field.ink(TranslationServer.translate("防御节点已上线") if live else TranslationServer.translate("点击改造  $") + field.sim.Catalog.number(field.sim.body_cost()), at + Vector2(r + 8, 12), Color(WHITE, focus * .7), 11)
		elif note != "":
			field.ink(note, at + Vector2(r + 6, 4), Color(WHITE, .32), 10)

# ---------- maps ----------

func oort(field: Node2D, time: float) -> void:
	# Hills cloud (inner, flattened) and the spherical Oort shell, both turning slowly.
	points_at(field, hills, CENTER, -.35 + time * .012)
	points_at(field, oort_shell, CENTER, time * .006)
	# Heliosphere: a comet-shaped bubble swept back by the interstellar wind.
	var helio := PackedVector2Array()
	for i in range(65):
		var a: float = i * TAU / 64
		var r: float = 34.0 / (1.0 - .58 * cos(a - 2.6))
		helio.append(CENTER + Vector2.from_angle(a) * r)
	dashed_loop(field, helio, Color(WHITE, .22))
	field.ring(CENTER, 22.0, Color(WHITE, .1))
	for r in [5.0, 8.5, 13.0]:
		field.ring(CENTER, r, Color(WHITE, .14))
	# Long-period comets fall in on near-parabolic orbits, tails always anti-sunward.
	if not field.reduced_effects:
		for j in range(5):
			var period: float = 34.0 + j * 7.0
			var u: float = fposmod(time / period + j * .37, 1.0)
			var q: float = (u - .5) * 2.0
			var axis: float = j * 1.31 + .4
			var local := Vector2(q * 330.0, (1.0 - q * q) * 70.0 - 12.0 - j * 6.0).rotated(axis)
			var head: Vector2 = CENTER + local
			var away: Vector2 = (head - CENTER).normalized()
			var near: float = clampf(1.0 - local.length() / 330.0, 0, 1)
			var tail: float = 8.0 + near * near * 70.0
			field.stroke(head, head + away * tail, Color(WHITE, .14 + near * .35))
			field.stroke(head, head + (away + away.orthogonal() * .25).normalized() * tail * .7, Color(WHITE, .08 + near * .18))
			field.shape(head, 1.6 + near * 1.4, 4, .785, Color(WHITE, .5 + near * .4))
	dashed_ring(field, CENTER, 300.0, Color(WHITE, .1), .92, 80)
	field.draw_circle(CENTER, 3.0, Color(WHITE, .95))
	field.ink(TranslationServer.translate("日球层 / HELIOSPHERE"), CENTER + Vector2(-150, 60), Color(WHITE, .5), 11)
	field.stroke(CENTER + Vector2(-82, 52), CENTER + Vector2(-40, 26), Color(WHITE, .22))
	field.ink(TranslationServer.translate("奥尔特云 / OORT CLOUD"), Vector2(170, 590), Color(WHITE, .65), 12)
	field.ink(TranslationServer.translate("希尔斯云"), CENTER + Vector2(120, -40), Color(WHITE, .38), 11)
	field.ink("1.6 ly", CENTER + Vector2(212, -222), Color(WHITE, .32), 10)

func neighbourhood(field: Node2D, time: float) -> void:
	field.draw_multimesh(near_stars, null)
	# The galactic plane: a broad faint band across the local sky.
	for k in range(5):
		var off: float = (k - 2) * 16.0
		field.stroke(CENTER + Vector2(-780, 195 + off), CENTER + Vector2(780, -195 + off), Color(WHITE, .022))
	dashed_loop(field, bubble, Color(WHITE, .16))
	field.ink(TranslationServer.translate("本地泡 / LOCAL BUBBLE"), CENTER + Vector2(52, 132), Color(WHITE, .42), 11)
	for item in [[70.0, "5 ly"], [140.0, "10 ly"], [220.0, "25 ly"], [300.0, "50 ly"]]:
		dashed_ring(field, CENTER, float(item[0]), Color(WHITE, .09), .86, 96)
		field.ink(str(item[1]), CENTER + Vector2(float(item[0]) * .72, -float(item[0]) * .62), Color(WHITE, .3), 10)
	# The Sun: a small star with four diffraction spikes.
	for j in range(4):
		var dir := Vector2.from_angle(j * PI * .5 + PI * .25)
		field.stroke(CENTER + dir * 4.0, CENTER + dir * 13.0, Color(WHITE, .5))
	field.draw_circle(CENTER, 3.2, Color(WHITE, .95))
	field.ink(TranslationServer.translate("太阳"), CENTER + Vector2(10, 26), Color(WHITE, .5), 11)
	field.ink(TranslationServer.translate("近邻恒星 / SOLAR NEIGHBOURHOOD"), Vector2(170, 590), Color(WHITE, .65), 12)

func galaxy(field: Node2D, time: float) -> void:
	cloud(field, CENTER, 302, 0, -.42 + time * .025, .73)
	# Broad dust ribbons sit below sharp stars and weapons.
	var transform := Transform2D(-.42 + time * .025, Vector2(1.12, .82), 0, CENTER)
	for arm in arms:
		var points: PackedVector2Array = transform * arm
		for i in range(points.size() - 1):
			field.stroke(points[i], points[i + 1], Color(WHITE, .045), 8.0)
		path(field, points, .20, false, float(arms.find(arm)) * .25)
	field.ink(TranslationServer.translate("银河旋臂 / ORION ARM"), Vector2(184, 514), Color(WHITE, .65), 12)
	field.stroke(Vector2(330, 508), Vector2(365, 470), Color(WHITE, .24))
	# You are here: the Sun, on the Orion spur.
	var pulse: float = .5 + .5 * sin(time * 2.0)
	field.ring(SUN_IN_GALAXY, 6.0 + pulse * 3.0, Color(AMBER, .55))
	field.draw_circle(SUN_IN_GALAXY, 1.8, AMBER)
	field.ink(TranslationServer.translate("太阳 / SUN"), SUN_IN_GALAXY + Vector2(10, -10), Color(AMBER, .7), 10)

func supercluster(field: Node2D, time: float, current: bool) -> void:
	field.draw_multimesh(lani_dust, null)
	for i in range(flows.size()):
		path(field, flows[i], .07, false, i * .113)
	dashed_loop(field, lani_edge, Color(WHITE, .14))
	# Galaxies and clusters read as star clouds even before conversion.
	var sim: RefCounted = field.sim
	for k in range(sim.BODIES[7].size()):
		var at: Vector2 = sim.scene_body_position(7, k)
		var form: String = str(sim.BODIES[7][k].form)
		if form == "spiral":
			cloud(field, at, [46.0, 38.0][k % 2], [0, 1][k % 2], k * 1.14 + time * (.05 if k % 2 else -.04), [.5, .78][k % 2])
		elif form == "cluster":
			for j in range(9):
				var a: float = j * 2.399 + k
				var spot: Vector2 = at + Vector2.from_angle(a) * (6.0 + (j % 4) * 7.0)
				cloud(field, spot, [15.0, 20.0, 25.0][j % 3], 2, a + time * .03, .6)
		elif form == "attractor":
			for j in range(3):
				field.ring(at, 10.0 + j * 9.0 + fposmod(time * 6.0, 9.0), Color(WHITE, .18 - j * .05))
	# Local Group: our own little knot, right under the core.
	field.ink(TranslationServer.translate("本星系群 / LOCAL GROUP"), CENTER + Vector2(-70, 124), Color(WHITE, .42), 11)
	field.ink(TranslationServer.translate("拉尼亚凯亚 / LANIAKEA"), Vector2(170, 590), Color(WHITE, .65), 12)
	field.ink(TranslationServer.translate("巨引源"), Vector2(170, 512), Color(AMBER, .5), 11)

func universe(field: Node2D, time: float) -> void:
	points_at(field, horizon, CENTER, time * .004)
	field.draw_multimesh(web_dust, null)
	for i in range(filaments.size()):
		var trunk: bool = i >= filaments.size() - 4
		path(field, filaments[i], .23 if trunk else .075, false, i * .137)
	for i in range(nodes.size()):
		var at: Vector2 = nodes[i]
		cloud(field, at, 15.0 + (i % 5) * 5.0, 2, i * 1.4 + time * .035, .6 + (i % 3) * .12)
		field.shape(at, 1.5 + (i % 3) * .5, 4, .785, Color(WHITE, .22))
	field.ink(TranslationServer.translate("宇宙纤维 / COSMIC WEB"), Vector2(182, 578), Color(WHITE, .65), 12)
	field.ink(TranslationServer.translate("星系际空洞"), Vector2(552, 110), Color(WHITE, .45), 11)
	field.ink(TranslationServer.translate("粒子视界 · 465 亿光年"), Vector2(828, 34), Color(WHITE, .4), 10)

# ---------- the brane: bubble universes in the bulk (pure 2D) ----------
const OUR_RADIUS: float = 262.0
# Neighbouring universes: centre, radius, wobble mode, drift speed.
const BUBBLES: Array = [
	[Vector2(-110, 70), 150.0, 5, .9], [Vector2(1085, 120), 112.0, 4, -.7], [Vector2(935, 590), 70.0, 3, -.8],
	[Vector2(70, 590), 44.0, 6, 1.1], [Vector2(1170, 420), 30.0, 5, -.5],
]

func membrane(center: Vector2, radius: float, time: float, mode: int, amp: float, samples: int = 96) -> PackedVector2Array:
	# A bubble's skin: a closed curve ringing in a standing wave of `mode` lobes,
	# with a slower second mode beating against it.
	var out := PackedVector2Array()
	for i in range(samples + 1):
		var a: float = i * TAU / samples
		var r: float = radius + amp * (sin(mode * a) * cos(time * 1.3) + .45 * sin((mode + 3) * a + 1.1) * cos(time * .7 + .5))
		out.append(center + Vector2.from_angle(a) * r)
	return out

func brane(field: Node2D, time: float) -> void:
	field.draw_multimesh(bulk_dust, null)
	# The other universes: each its own ringing bubble with a faint interior.
	for i in range(BUBBLES.size()):
		var spec: Array = BUBBLES[i]
		var r: float = float(spec[1])
		var c: Vector2 = Vector2(spec[0]) + Vector2(sin(time * .05 * float(spec[3]) + i), cos(time * .04 * float(spec[3]) + i * 2.0)) * 10.0
		# Distant universes: a quiet disc and a clean rim that only breathes.
		var breathe: float = r * (1.0 + .012 * sin(time * .6 + i))
		field.shape(c, breathe, 48, 0.0, Color(WHITE, .025))
		field.arc_segments(c, breathe, 0, TAU, Color(WHITE, .18))
		for k in range(int(r / 18.0)):
			var q: Vector2 = c + Vector2.from_angle(k * 2.399 + i) * r * sqrt((k + .5) / (r / 18.0)) * .8
			field.shape(q, .9, 4, .785, Color(WHITE, .18))
	# Our universe: the cosmic web in miniature, held inside one ringing membrane.
	var inner: float = (OUR_RADIUS - 18.0) / 300.0
	for path in filaments:
		var prev: Vector2 = CENTER + (path[0] - CENTER) * inner
		for k in range(2, path.size(), 2):
			var q: Vector2 = CENTER + (path[k] - CENTER) * inner
			field.stroke(prev, q, Color(WHITE, .07))
			prev = q
	for i in range(nodes.size()):
		field.shape(CENTER + (nodes[i] - CENTER) * inner, 1.3 + (i % 3) * .4, 4, .785, Color(WHITE, .3))
	var skin_ours: PackedVector2Array = membrane(CENTER, OUR_RADIUS, time, 5, 0.0 if field.reduced_effects else 2.5, 160)
	for k in range(skin_ours.size() - 1):
		field.stroke(skin_ours[k], skin_ours[k + 1], Color(WHITE, .62))
	# The standing wave's nodes stay put: amber beads mark them on the membrane.
	for k in range(10):
		var a: float = k * PI / 5.0
		field.shape(CENTER + Vector2.from_angle(a) * OUR_RADIUS, 2.0, 4, .785, Color(AMBER, .75))
	field.ink(TranslationServer.translate("我们的宇宙 / OUR UNIVERSE"), CENTER + Vector2(150, 238), Color(WHITE, .55), 11)
	field.ink(TranslationServer.translate("邻近宇宙泡"), Vector2(-60, 170), Color(WHITE, .32), 11)
	field.ink(TranslationServer.translate("高维体 / THE BULK"), Vector2(170, 590), Color(WHITE, .65), 12)
