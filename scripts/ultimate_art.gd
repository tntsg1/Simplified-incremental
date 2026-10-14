extends RefCounted
# Presentation only: actual hit events supply silhouettes; damage stays in Combat.
const WHITE := Color("ededed")
const AMBER := Color("ffc94d")
const RED := Color("ff785f")
const BLUE := Color("71baff")
const REMNANT_CAP := 160
const SHIP_SAMPLES := 120
var remnants: Array[Dictionary] = []
var routes: Array[PackedVector2Array] = []
var spectral: Array[Dictionary] = []
var membranes: Array[PackedVector2Array] = []
const DOMAIN := Rect2(-460, -280, 1920, 1210)
const LIGHTSPEED_SEAL: float = 4.6
const LIGHTSPEED_IMPACT: float = 6.0

func _init() -> void:
	# Smooth repeated traversals, without polygonal turns.
	for ship in range(4):
		var path := PackedVector2Array()
		for i in range(SHIP_SAMPLES + 1):
			var t: float = float(i) / SHIP_SAMPLES
			var x: float = -140 + (1.0 - cos(t * PI * 3)) * 640
			var y: float = 80 + ship * 160 + sin(t * TAU * 1.5 + ship * .6) * 45
			path.append(Vector2(x, y) - Vector2(500, 325))
		routes.append(path)
	for variant in range(8):
		var contour := PackedVector2Array()
		for i in range(49):
			var a: float = i * TAU / 48
			var edge: float = 1.0 + sin(a * 3 + variant) * .07 + sin(a * 5 - variant * .7) * .035
			contour.append(Vector2(cos(a), sin(a)) * edge)
		membranes.append(contour)

func fired(kind: String, enemies: Array, core: Vector2 = Vector2(500, 325)) -> void:
	spectral.clear()
	match kind:
		"droplet":
			droplet_path = PackedVector2Array()
			droplet_aim = core + Vector2(0, -1)
			var nearest: float = INF
			for e in enemies:
				if bool(e.dead):
					continue
				var d: float = core.distance_to(e.pos)
				if d < nearest:
					nearest = d
					droplet_aim = e.pos
		"fourier":
			prepare_fourier(enemies, core)
			fourier_marks.clear()
		"strings":
			snaps.clear()

func flattened(point: Vector2, radius: float, sides: int, heading: float, members: int) -> void:
	if remnants.size() >= REMNANT_CAP:
		remnants.pop_front()
	remnants.append({"pos": point, "r": radius, "sides": sides, "heading": heading, "members": members, "age": 0.0, "variant": absi(int(point.x * 3 + point.y * 7)) % membranes.size()})

func animate(delta: float, _combat: RefCounted = null) -> void:
	for i in range(remnants.size() - 1, -1, -1):
		remnants[i].age = float(remnants[i].age) + delta
		if float(remnants[i].age) >= 7.0:
			remnants.remove_at(i)
	for i in range(spectral.size() - 1, -1, -1):
		spectral[i].age = float(spectral[i].age) + delta
		if float(spectral[i].age) >= .9:
			spectral.remove_at(i)
	for list in [shatters, fourier_marks, snaps]:
		for i in range(list.size() - 1, -1, -1):
			list[i].age = float(list[i].age) + delta
			if float(list[i].age) >= float(list[i].get("life", 1.2)):
				list.remove_at(i)

func photon_speed(age: float) -> float:
	return .3 + 180.0 * pow(1.0 - smoothstep(.25, 3.1, age), 4)

func spectral_shift(velocity: Vector2, direction: Vector2, light: float) -> float:
	return clampf(velocity.dot(direction) / maxf(.3, light), -.9, .9)

func membrane_extent(radius: float, age: float, members: int) -> Vector2:
	# Visual volume spread: apparent area grows as the third dimension vanishes.
	var spread: float = smoothstep(.12, 1.9, age)
	var footprint: float = clampf(sqrt(pow(maxf(1, radius), 3) * 8.0) * (1 + log(maxi(1, members)) * .13), 58, 220)
	return Vector2(lerpf(radius, footprint, spread), lerpf(radius, footprint * .64, spread))

func triangle(f: Node2D, a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var base: int = f.tri_points.size()
	f.tri_points.append_array(PackedVector2Array([a, b, c]))
	f.tri_colors.append_array(PackedColorArray([ca, cb, cc]))
	f.tri_indices.append_array(PackedInt32Array([base, base + 1, base + 2]))

func membrane(f: Node2D, p: Vector2, extent: Vector2, variant: int, age: float, alpha: float, detail: bool, edge: bool = true) -> void:
	var contour: PackedVector2Array = membranes[variant % membranes.size()]
	var phase: float = variant * .7
	var points := PackedVector2Array()
	for i in range(contour.size()):
		var v: Vector2 = contour[i] * extent
		v.y += sin(contour[i].x * 4 + phase + age * .4) * extent.y * .075
		points.append(p + v)
	# Soft luminous fill without triangle borders.
	for i in range(1, points.size()):
		triangle(f, p, points[i - 1], points[i], Color(WHITE, alpha * .19), Color(WHITE, 0), Color(WHITE, 0))
	if edge:
		polyline(f, points, Color(WHITE, alpha * .24))
	if not detail:
		return
	for layer in range(2 if f.reduced_effects else 3):
		var line := PackedVector2Array()
		for i in range(25):
			var x: float = (i / 24.0 - .5) * 1.75
			var y: float = sin(x * 3 + phase + layer * .65) * .15 + (layer - 1) * .32
			line.append(p + Vector2(x * extent.x, y * extent.y))
		polyline(f, line, Color(WHITE, alpha * .17))

func route_point(ship: int, t: float, center: Vector2) -> Vector2:
	var index: float = clampf(t, 0, 1) * SHIP_SAMPLES
	var first: int = mini(int(index), SHIP_SAMPLES - 1)
	return center + routes[ship][first].lerp(routes[ship][first + 1], index - first)

func draw_remnants(f: Node2D) -> void:
	draw_shatters(f)
	draw_fourier_marks(f)
	draw_snaps(f)
	draw_flat_remnants(f)

func draw_flat_remnants(f: Node2D) -> void:
	# One-vector foil: a 2D body loses a dimension. Its outline unrolls edge by
	# edge into one straight 1D segment, which then keeps stretching across the
	# plane. Every segment is drawn in its own line style.
	f.begin_batch()
	var start: int = maxi(0, remnants.size() - 60)
	for idx in range(start, remnants.size()):
		var rem: Dictionary = remnants[idx]
		var age: float = float(rem.age)
		var fade: float = 1.0 - smoothstep(4.5, 7.0, age)
		if fade <= 0.0:
			continue
		var sides: int = clampi(int(rem.sides), 3, 8)
		var r: float = maxf(7.0, float(rem.r))
		var p: Vector2 = rem.pos
		var variant: int = int(rem.variant)
		var unroll: float = smoothstep(0.0, 1.3, age)
		var stretch: float = 1.0 + 3.5 * smoothstep(1.0, 4.2, age)
		var edge_len: float = 2.0 * r * sin(PI / sides)
		var total: float = edge_len * sides
		# Each body lies down along its own direction.
		var dir: Vector2 = Vector2.from_angle(float(rem.heading) + variant * .9)
		var origin: Vector2 = p - dir * total * .5 * stretch
		var pts := PackedVector2Array()
		for i in range(sides + 1):
			var on_poly: Vector2 = p + Vector2.from_angle(float(rem.heading) + i * TAU / sides) * r
			var on_line: Vector2 = origin + dir * (i * edge_len * stretch)
			pts.append(on_poly.lerp(on_line, unroll))
		var a: float = (.95 - .45 * smoothstep(2.0, 4.5, age)) * fade
		var nrm: Vector2 = dir.orthogonal()
		match variant % 5:
			0:
				# Solid hairline.
				polyline(f, pts, Color(WHITE, a))
			1:
				# Dashed.
				for i in range(sides):
					for k in range(4):
						var t0: float = k / 4.0
						f.stroke(pts[i].lerp(pts[i + 1], t0), pts[i].lerp(pts[i + 1], t0 + .14), Color(WHITE, a))
			2:
				# Dotted: a string of points.
				for i in range(sides):
					for k in range(6):
						f.shape(pts[i].lerp(pts[i + 1], k / 6.0), 1.4, 4, 0, Color(WHITE, a))
			3:
				# Double rail.
				var shifted := PackedVector2Array()
				for q in pts:
					shifted.append(q + nrm * 3.0 * unroll)
				polyline(f, pts, Color(WHITE, a))
				polyline(f, shifted, Color(WHITE, a * .55))
			_:
				# Ruled: ticks where the old corners were.
				polyline(f, pts, Color(WHITE, a * .85))
				for q in pts:
					f.stroke(q - nrm * 5.0 * unroll, q + nrm * 5.0 * unroll, Color(AMBER, a))
		# The two loose ends glint.
		f.shape(pts[0], 2.0, 4, 0, Color(WHITE, a))
		f.shape(pts[sides], 2.0, 4, 0, Color(WHITE, a))
	f.flush_batch()

func polyline(f: Node2D, points: PackedVector2Array, color: Color) -> void:
	for i in range(1, points.size()):
		f.stroke(points[i - 1], points[i], color)

func draw(f: Node2D, kind: String, age: float, at: Vector2) -> void:
	match kind:
		"droplet": droplet(f, age, at)
		"fourier": fourier(f, age, at)
		"mandelbrot": mandelbrot(f, age, at)
		"strings": strings(f, age, at)
		"foil": foil(f, age, at)
		"prime": prime(f, age, at)
		"lightspeed": lightspeed(f, age, at)
		"pi": rewrite_pi(f, age, at)

var foil_dust: PackedVector2Array = PackedVector2Array()

func foil(f: Node2D, u: float, at: Vector2) -> void:
	if foil_dust.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 2420
		for i in range(320):
			foil_dust.append(Vector2(rng.randf_range(-250, 1250), rng.randf_range(-60, 710)))
	var open_t: float = f.sim.FOIL_OPEN
	var fade: float = 1.0 - smoothstep(6.0, 6.6, u)
	if u < open_t:
		# The foil: a small square card, turning slowly as it settles.
		var arrival: float = f.ease_out(u / open_t, 2)
		var p: Vector2 = (at + Vector2(-260, -230)).lerp(at, arrival)
		var turn: float = (1.0 - arrival) * 3.0
		f.draw_set_transform(p, turn, Vector2(1.0, .2 + .8 * absf(cos(u * 2.0))))
		f.draw_rect(Rect2(-11, -11, 22, 22), Color(WHITE, .85))
		f.draw_rect(Rect2(-11, -11, 22, 22), Color(WHITE, 1), false, 1.0)
		f.draw_set_transform(Vector2.ZERO)
	var half: float = f.sim.foil_half(u)
	f.begin_batch()
	# Dust: pushed straight out by the nearest edge of the square, then stretched into dashes.
	for i in range(foil_dust.size()):
		var q: Vector2 = foil_dust[i]
		var rel: Vector2 = q - at
		var cheb: float = maxf(absf(rel.x), absf(rel.y))
		var push_dir: Vector2 = Vector2(signf(rel.x), 0) if absf(rel.x) >= absf(rel.y) else Vector2(0, signf(rel.y))
		var reach: float = half * (1.0 + .015 * sin(i * 1.7))
		var a: float = (.35 + .25 * fposmod(i * .618, 1.0)) * fade
		if u < open_t or cheb > reach + 4.0:
			f.shape(q, 1.3, 4, 0, Color(WHITE, a * .7))
		elif cheb > reach - 90.0:
			var pushed: Vector2 = q + push_dir * (reach + 3.0 + fposmod(i * .37, 1.0) * 8.0 - cheb)
			f.stroke(pushed, pushed + push_dir * 6.0, Color(WHITE, a * 1.4))
		else:
			var line: float = clampf((reach - 90.0 - cheb) / 160.0, 0, 1)
			f.stroke(q - Vector2(4 + 10 * line, 0), q + Vector2(4 + 10 * line, 0), Color(WHITE, a * .55))
	if half > 0.0:
		# The square sheet: the plane inside collapsed into parallel lines (1D strata).
		var tl: Vector2 = at + Vector2(-half, -half)
		var tr: Vector2 = at + Vector2(half, -half)
		var br: Vector2 = at + Vector2(half, half)
		var bl: Vector2 = at + Vector2(-half, half)
		var film := Color(.88, .92, 1.0, .05 * fade)
		triangle(f, tl, tr, br, film, film, film)
		triangle(f, tl, br, bl, film, film, film)
		var y: float = -half
		while y <= half:
			f.stroke(at + Vector2(-half, y), at + Vector2(half, y), Color(WHITE, .07 * fade))
			y += 5.0
		polyline(f, PackedVector2Array([tl, tr, br, bl, tl]), Color(WHITE, .95 * fade))
		# Corner marks and a glint travelling along the edges.
		for c in [tl, tr, br, bl]:
			f.shape(c, 3.0, 4, PI / 4, Color(WHITE, fade))
		var g: float = fposmod(u * .35, 1.0) * 4.0
		var corners: Array = [tl, tr, br, bl, tl]
		var seg: int = int(g)
		f.shape(Vector2(corners[seg]).lerp(corners[seg + 1], g - seg), 2.5, 4, 0, Color(WHITE, fade))
	f.flush_batch()
	if half > 0.0:
		f.centered(TranslationServer.translate("2D → 1D  ·  低维展开"), Vector2(500, 560), 18, Color(WHITE, fade * .7), true)

func prime_position(f: Node2D, index: int, u: float, at: Vector2) -> Vector2:
	if f.ulam.is_empty():
		return at
	var rotation: float = 0.0 if f.reduced_effects else u * .17
	return at + Vector2(f.ulam[index % f.ulam.size()]).rotated(rotation) * 12.6

func prime(f: Node2D, u: float, at: Vector2) -> void:
	var fade: float = 1.0 - smoothstep(3.6, 4.4, u)
	var reveal: int = int(f.ulam.size() * smoothstep(0, 1.25, u))
	f.begin_batch()
	var previous: Vector2 = at
	for i in range(reveal):
		var p: Vector2 = prime_position(f, i, u, at)
		var fresh: float = clampf(1.0 - (reveal - i) / 24.0, 0, 1)
		if i > 0:
			f.stroke(previous, p, Color(AMBER, (.055 + fresh * .18) * fade))
		f.shape(p, 2.1 + fresh * 1.4, 6, 0, Color(AMBER, (.75 + fresh * .25) * fade))
		previous = p
	for pm in f.prime_marks:
		var age: float = float(pm.age)
		var tail: float = 1.0 - smoothstep(.15, .9, age)
		var points: PackedVector2Array = pm.points
		for j in range(points.size()):
			var src: Vector2 = prime_position(f, int(pm.p) * 5 + j * 11, u, at)
			var target: Vector2 = points[j]
			var travel: float = f.ease_out(age / .14)
			f.stroke(src, src.lerp(target, travel), Color(AMBER, tail * .85), 1.4)
			f.shape(src, 3.4 * tail + 1, 8, 0, Color(AMBER, tail))
			f.ring(target, 24 * (1 - smoothstep(.08, .6, age)) + 1, Color(WHITE, tail * .8))
			f.shape(target, 3.5 * tail, 8, 0, Color(WHITE, tail))
	f.flush_batch()
	f.centered("2 · 3 · 5 · 7 · 11 · 13 · 17 · 19 · 23 · 29", Vector2(500, 82), 17, Color(AMBER, fade), true)
	f.centered("p ∈ P      π(x) ~ x / ln x", Vector2(500, 108), 13, Color(WHITE, fade * .65), true)
	if not f.prime_marks.is_empty():
		var latest: Dictionary = f.prime_marks.back()
		var prime: int = int(latest.p)
		var tail: float = 1.0 - smoothstep(.3, .9, float(latest.age))
		f.centered("p[%d] = %d" % [f.sim.PRIMES.find(prime) + 1, prime], Vector2(500, 565), 24, Color(WHITE, tail), true)

func domain_coverage(age: float) -> float:
	return smoothstep(0, 3.1, age)

func route_progress(age: float, ship: int) -> float:
	var delay: float = ship * .12
	return clampf((age - delay) / (3.1 - delay), 0, 1)

# The black domain is laid by light-speed ships: each streaks across the field
# in a moment, but the wake it leaves (where light itself slows down) swells
# slowly, merges with the others and squeezes the remaining light shut.
const WAKE_LAUNCH: Array[float] = [0.3, 1.0, 1.7, 2.4, 3.1]
const WAKE_PASS: float = 1.3

func wake_path(ship: int, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	match ship:
		0: return Vector2(lerpf(-320, 1320, t), 140 + sin(t * PI * 2.0) * 50)
		1: return Vector2(lerpf(1320, -320, t), 520 - sin(t * PI * 1.5) * 60)
		2: return Vector2(lerpf(-260, 1260, t), lerpf(760, -100, t) + sin(t * PI * 3.0) * 30)
		3:
			var a: float = -PI * .5 + t * TAU * 1.15
			return Vector2(500, 325) + Vector2(cos(a) * 360, sin(a) * 250) * (1.25 - .35 * t)
		_: return Vector2(lerpf(240, 760, t) + sin(t * PI * 2.5) * 70, lerpf(-140, 790, t))

func wake_halfwidth(age_since: float) -> float:
	# Narrow at birth; the slowed light keeps spreading out from the wake.
	return 10.0 + 210.0 * smoothstep(0.0, 4.0, age_since)

func doppler_strength(age: float) -> float:
	# Creeps in with the darkness, then lets go at the harvest.
	return smoothstep(.8, LIGHTSPEED_SEAL, age) * (1.0 - smoothstep(LIGHTSPEED_IMPACT, LIGHTSPEED_IMPACT + .5, age))

func domain_radius(age: float) -> float:
	# Kept for callers that ask "how far has the domain reached": full once sealed.
	return 1500.0 * smoothstep(0.0, LIGHTSPEED_SEAL, age) * (1.0 - smoothstep(LIGHTSPEED_IMPACT, LIGHTSPEED_IMPACT + .45, age))

func domain_background(f: Node2D) -> void:
	if f.sim.ult.is_empty() or str(f.sim.ult.kind) != "lightspeed":
		return
	var age: float = float(f.sim.ult.age)
	var release: float = smoothstep(LIGHTSPEED_IMPACT, LIGHTSPEED_IMPACT + .9, age)
	if release >= 1.0:
		return
	var keep: float = 1.0 - release
	f.begin_batch()
	# Everything darkens a little everywhere as the seal approaches.
	var seal: float = smoothstep(1.5, LIGHTSPEED_SEAL, age)
	var all := Color(0, 0, 0, .5 * seal * keep)
	triangle(f, Vector2(-500, -400), Vector2(1600, -400), Vector2(1600, 1100), all, all, all)
	triangle(f, Vector2(-500, -400), Vector2(1600, 1100), Vector2(-500, 1100), all, all, all)
	for ship in range(WAKE_LAUNCH.size()):
		var t0: float = WAKE_LAUNCH[ship]
		if age < t0:
			continue
		var head: float = clampf((age - t0) / WAKE_PASS, 0.0, 1.0)
		var samples: int = 48
		var last: int = int(head * samples)
		for i in range(last):
			var ta: float = float(i) / samples
			var tb: float = float(i + 1) / samples
			var pa: Vector2 = wake_path(ship, ta)
			var pb: Vector2 = wake_path(ship, tb)
			var n: Vector2 = (pb - pa).normalized().orthogonal()
			var wa: float = wake_halfwidth(age - (t0 + ta * WAKE_PASS))
			var wb: float = wake_halfwidth(age - (t0 + tb * WAKE_PASS))
			var core_col := Color(0, 0, 0, .62 * keep)
			var edge := Color(0, 0, 0, 0)
			# Solid inner wake.
			triangle(f, pa + n * wa * .55, pb + n * wb * .55, pb - n * wb * .55, core_col, core_col, core_col)
			triangle(f, pa + n * wa * .55, pb - n * wb * .55, pa - n * wa * .55, core_col, core_col, core_col)
			# Feathered edges.
			for side in [1.0, -1.0]:
				triangle(f, pa + n * wa * .55 * side, pa + n * wa * side, pb + n * wb * side, core_col, edge, edge)
				triangle(f, pa + n * wa * .55 * side, pb + n * wb * side, pb + n * wb * .55 * side, core_col, edge, core_col)
	f.flush_batch()

func lightspeed(f: Node2D, u: float, at: Vector2) -> void:
	var fade: float = 1.0 - smoothstep(LIGHTSPEED_IMPACT + .6, LIGHTSPEED_IMPACT + 1.2, u)
	var strength: float = doppler_strength(u)
	f.begin_batch()
	for ship in range(WAKE_LAUNCH.size()):
		var t0: float = WAKE_LAUNCH[ship]
		if u < t0:
			continue
		var head: float = clampf((u - t0) / WAKE_PASS, 0.0, 1.0)
		# Dispersion along the wake boundary: red on one side, blue on the other.
		var samples: int = 48
		var last: int = int(head * samples)
		for i in range(0, last, 2):
			var ta: float = float(i) / samples
			var tb: float = float(mini(i + 2, last)) / samples
			var pa: Vector2 = wake_path(ship, ta)
			var pb: Vector2 = wake_path(ship, tb)
			var n: Vector2 = (pb - pa).normalized().orthogonal()
			var wa: float = wake_halfwidth(u - (t0 + ta * WAKE_PASS))
			var wb: float = wake_halfwidth(u - (t0 + tb * WAKE_PASS))
			var a: float = .35 * fade * (1.0 - smoothstep(LIGHTSPEED_SEAL - .6, LIGHTSPEED_SEAL, u))
			f.stroke(pa + n * wa, pb + n * wb, Color(RED, a))
			f.stroke(pa - n * wa, pb - n * wb, Color(BLUE, a))
		if head >= 1.0:
			continue
		# The ship itself: a white-hot needle with a light sail and a flare.
		var p: Vector2 = wake_path(ship, head)
		var dir: Vector2 = (wake_path(ship, head + .01) - p).normalized()
		var nrm: Vector2 = dir.orthogonal()
		for k in range(1, 10):
			var back: Vector2 = wake_path(ship, head - k * .012)
			f.stroke(back, wake_path(ship, head - (k - 1) * .012), Color(WHITE, 1.0 - k / 10.0))
		triangle(f, p + dir * 16.0, p - dir * 8.0 + nrm * 5.0, p - dir * 8.0 - nrm * 5.0, WHITE, Color(WHITE, .6), Color(WHITE, .6))
		f.stroke(p - nrm * 40.0, p + nrm * 40.0, Color(WHITE, .5))
		f.stroke(p - dir * 70.0, p + dir * 30.0, Color(WHITE, .35))
	# The harvest: light snaps back as a spectral ring racing out from the core.
	if u > LIGHTSPEED_IMPACT:
		var k: float = clampf((u - LIGHTSPEED_IMPACT) / .9, 0, 1)
		var rr: float = k * 1300.0
		for band in [[-10.0, BLUE], [0.0, WHITE], [10.0, RED]]:
			var pts := PackedVector2Array()
			for i in range(97):
				pts.append(at + Vector2.from_angle(i * TAU / 96) * (rr + float(band[0])))
			polyline(f, pts, Color(band[1], (1.0 - k) * .9))
	for s in spectral:
		var age: float = float(s.age)
		var q: float = age / .9
		if q >= 1.0:
			continue
		var sp: Vector2 = Vector2(s.pos) + Vector2(s.vel) * age
		f.stroke(sp, sp - Vector2(s.vel).normalized() * 10.0, Color(s.col, 1.0 - q))
	f.flush_batch()
	# Readouts at the bottom: the speed of light ticking down, and the spectrum key.
	var speed: float = lerpf(299792.0, 16.7, pow(smoothstep(0.0, LIGHTSPEED_SEAL, u), 1.6))
	f.centered("c = %s km/s" % (("%.1f" % speed) if speed < 100 else str(int(speed))), Vector2(500, 560), 25, Color(WHITE, fade), true)
	var sealed: bool = u >= LIGHTSPEED_SEAL and u < LIGHTSPEED_IMPACT
	f.centered(TranslationServer.translate("黑域封闭") if sealed else TranslationServer.translate("光速航迹铺设中"), Vector2(500, 536), 13, Color(AMBER, fade * (1.0 if sealed else .7)), true)
	var legend: float = strength * fade
	if legend > .01:
		var x0: float = 380.0
		var x1: float = 620.0
		for i in range(24):
			var k0: float = i / 24.0
			var col: Color = RED.lerp(WHITE, k0 * 2.0) if k0 < .5 else WHITE.lerp(BLUE, (k0 - .5) * 2.0)
			f.draw_line(Vector2(lerpf(x0, x1, k0), 584), Vector2(lerpf(x0, x1, k0 + 1.0 / 24.0), 584), Color(col, legend), 3.0)
		f.ink(TranslationServer.translate("红移 · 远离"), Vector2(x0 - 78, 589), Color(RED, legend), 12)
		f.ink(TranslationServer.translate("接近 · 蓝移"), Vector2(x1 + 10, 589), Color(BLUE, legend), 12)

func spectral_burst(points: Array) -> void:
	# Each erased threat breaks into red and blue light.
	spectral.clear()
	for p in points:
		if spectral.size() > 240:
			break
		for i in range(8):
			var a: float = i * TAU / 8 + randf() * .4
			spectral.append({"pos": p, "vel": Vector2.from_angle(a) * randf_range(60.0, 160.0), "age": 0.0, "col": BLUE if i % 2 == 0 else RED})

func warped(point: Vector2, at: Vector2, amount: float) -> Vector2:
	var local: Vector2 = point - at
	var radius: float = local.length()
	var angle: float = local.angle()
	# A circle's metric is rewritten to a six-sided space, continuously.
	var sector: float = fposmod(angle + PI / 6, PI / 3) - PI / 6
	var hex_radius: float = cos(PI / 6) / maxf(.01, cos(sector))
	return at + Vector2.from_angle(angle + sin(angle * 3) * amount * .13) * radius * lerpf(1, hex_radius, amount)

func rewrite_pi(f: Node2D, u: float, at: Vector2) -> void:
	var rewrite: float = smoothstep(.3, f.sim.PI_IMPACT, u)
	var fade: float = 1.0 - smoothstep(3.3, 4.2, u)
	var release: float = maxf(0, u - f.sim.PI_IMPACT)
	# Visible Cartesian lines shear into a curved, rewritten metric.
	var lines: int = 7 if f.reduced_effects else 12
	f.begin_batch()
	for axis in range(2):
		for line in range(-lines, lines + 1):
			var path := PackedVector2Array()
			for k in range(29):
				var p: Vector2 = Vector2((k - 14) * 48, line * 48)
				if axis == 1:
					p = Vector2(p.y, p.x)
				p += at
				path.append(warped(p, at, rewrite))
			polyline(f, path, Color(WHITE, (.13 if line != 0 else .4) * fade))
	f.flush_batch()
	for j in range(8):
		var radius: float = 38 + j * 64 + release * release * 250
		var shape := PackedVector2Array()
		for i in range(73):
			shape.append(warped(at + Vector2.from_angle(i * TAU / 72) * radius, at, rewrite))
		f.draw_polyline(shape, Color(WHITE, (.65 - j * .065) * fade), 2 if j == 0 else 1, true)
	# A diameter, circumference and severed digits make the physical rewrite legible.
	var rotating: float = u * .32
	var vector: Vector2 = Vector2.from_angle(rotating) * 220
	f.draw_line(warped(at - vector, at, rewrite), warped(at + vector, at, rewrite), Color(AMBER, .6 * fade), 1.5, true)
	var digits: String = "14159265358979323846"
	var keep: int = int(20 * (1 - rewrite))
	f.centered("π = 3" + ("." + digits.substr(0, keep) if keep > 0 else ""), Vector2(500, 84), 32, Color(WHITE, fade), true)
	if not f.reduced_effects:
		for i in range(keep, 20):
			var fall: float = clampf(rewrite - (20 - i) / 20.0, 0, 1)
			if fall <= 0:
				continue
			f.ink(digits[i], Vector2(430 + i * 8, 105 + fall * 190), Color(WHITE, (1 - fall) * .25 * fade), 12)
	if release > 0:
		var flash: float = 1.0 - smoothstep(0, .25, release)
		f.ult_flash = flash * (.1 if f.reduced_effects else .18)
		for j in range(6):
			var direction: Vector2 = Vector2.from_angle(j * TAU / 6)
			var tangent: Vector2 = direction.orthogonal()
			var cut: Vector2 = at + direction * (70 + release * 480)
			f.draw_line(cut - tangent * (30 + release * 100), cut + tangent * (30 + release * 100), Color(WHITE, fade * .8), 2, true)

# =====================================================================
# Droplet: a mirror-smooth drop of strong-interaction matter. It forms at the
# core, then in a single frame threads every threat on the field; time holds,
# and everything it passed through shatters into small bodies.
# =====================================================================
var droplet_path := PackedVector2Array()
var droplet_aim := Vector2(500, 200)
var shatters: Array[Dictionary] = []

var droplet_fracs := PackedFloat32Array()

func droplet_passed(points: PackedVector2Array) -> void:
	droplet_path = points
	# Arc-length fraction of each stop: when the visible drop reaches it.
	droplet_fracs = PackedFloat32Array([0.0])
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		droplet_fracs.append(total)
	for i in range(droplet_fracs.size()):
		droplet_fracs[i] /= maxf(1.0, total)

func droplet_point(t: float) -> Vector2:
	# Position along the threaded path at arc-length fraction t.
	if droplet_path.size() < 2:
		return droplet_path[0] if not droplet_path.is_empty() else Vector2(500, 325)
	t = clampf(t, 0, 1)
	var lo: int = 0
	var hi: int = droplet_fracs.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if droplet_fracs[mid] < t:
			lo = mid
		else:
			hi = mid
	var span: float = maxf(.00001, droplet_fracs[hi] - droplet_fracs[lo])
	return droplet_path[lo].lerp(droplet_path[hi], clampf((t - droplet_fracs[lo]) / span, 0, 1))

func droplet_shattered(point: Vector2, radius: float, pieces: int, boss: bool) -> void:
	if shatters.size() >= 260:
		shatters.pop_front()
	shatters.append({"pos": point, "r": maxf(6.0, radius), "pieces": pieces, "boss": boss, "age": 0.0, "life": 1.6 if boss else 1.1, "seed": absi(int(point.x * 7 + point.y * 13)) % 997})

func drop_outline(center: Vector2, size: float, heading: float, wobble: float = 0.0) -> PackedVector2Array:
	# Teardrop: the round head leads along `heading`, the fine point trails behind.
	var out := PackedVector2Array()
	var rot := Vector2.from_angle(heading)
	for i in range(40):
		var t: float = i * TAU / 40
		var x: float = -cos(t) * 1.45
		var y: float = sin(t) * pow(absf(sin(t * .5)), 1.25) * (1.0 + wobble * sin(t * 5.0))
		var local := Vector2(x, y) * size
		out.append(center + rot * local.x + rot.orthogonal() * local.y)
	return out

func draw_drop(f: Node2D, center: Vector2, size: float, heading: float, alpha: float, wobble: float = 0.0) -> void:
	if size < .5 or alpha <= .01:
		return
	# A mirror reads as layers: a dark rim, a cool body, a hot inner band, a highlight.
	var shell: PackedVector2Array = drop_outline(center, size, heading, wobble)
	f.draw_colored_polygon(shell, Color(.08, .08, .09, alpha))
	var head: Vector2 = center + Vector2.from_angle(heading) * size * .55
	for layer in range(4):
		var k: float = 1.0 - layer * .2
		var inner: PackedVector2Array = drop_outline(center.lerp(head, layer * .12), size * k, heading, wobble)
		f.draw_colored_polygon(inner, Color(.55 + layer * .13, .57 + layer * .13, .6 + layer * .12, alpha * (.35 + layer * .12)))
	shell.append(shell[0])
	f.draw_polyline(shell, Color(1, 1, 1, alpha), 1.4, true)
	var hl: Vector2 = head + Vector2.from_angle(heading - 1.9) * size * .42
	f.draw_arc(hl, size * .32, heading - 2.6, heading - 1.2, 10, Color(1, 1, 1, alpha), 2.0, true)
	f.draw_circle(hl + Vector2.from_angle(heading - 1.6) * size * .18, maxf(1.0, size * .09), Color(1, 1, 1, alpha))
	# The universe slides across its surface: three reflected stars.
	for j in range(3):
		var slide: float = fposmod(f.clock * .35 + j * .33, 1.0)
		var q: Vector2 = center + Vector2.from_angle(heading) * size * lerpf(-.9, .9, slide) + Vector2.from_angle(heading).orthogonal() * size * (.25 - j * .2) * sin(slide * PI)
		f.draw_circle(q, 1.0, Color(1, 1, 1, alpha * .8 * sin(slide * PI)))

func droplet(f: Node2D, u: float, at: Vector2) -> void:
	var pass_t: float = f.sim.DROPLET_PASS
	var aim_heading: float = (droplet_aim - at).angle()
	var ultd: Dictionary = f.sim.ult
	var travel: float = float(ultd.get("travel", .4))
	var arrive: float = pass_t + travel
	var shatter_at: float = float(ultd.get("shatter_at", arrive + .35))
	var cascade: float = f.sim.DROPLET_CASCADE
	if u < pass_t:
		# 1) Charge: dust spirals in and condenses into a mirror drop; lock rings tighten.
		var k: float = f.ease_out(u / .95, 3)
		var center: Vector2 = at + Vector2.from_angle(aim_heading) * 34.0 * k
		var size: float = 4.0 + 17.0 * k
		f.begin_batch()
		for j in range(56):
			var ph: float = fposmod(u * 1.3 + j * .0179, 1.0)
			var a: float = j * 2.399 + u * (2.0 + j % 3)
			var rr: float = (1.0 - ph) * (260.0 + (j % 7) * 30.0) + size * 1.4
			var q: Vector2 = center + Vector2.from_angle(a + ph * 2.5) * rr
			f.stroke(q, q + (center - q).normalized() * (6.0 + ph * 10.0), Color(1, 1, 1, ph * .7))
		f.flush_batch()
		for j in range(3):
			var g: float = fposmod(u * 1.4 + j / 3.0, 1.0)
			f.draw_arc(center, lerpf(180.0, size * 1.7, f.ease_out(g, 2)), 0, TAU, 64, Color(AMBER if j == 0 else WHITE, g * .45), 1.2, true)
		glow_at(f, center, size * 7.0, Color(.8, .86, 1.0, .35 * k))
		glow_at(f, center, size * 2.5, Color(1, 1, 1, .4 * k))
		draw_drop(f, center, size, aim_heading, minf(1.0, u * 4.0), .05 * (1.0 - k))
		# A highlight sweeps across the mirror surface.
		var sweep: float = fposmod(u * .9, 1.0)
		var hl: Vector2 = center + Vector2.from_angle(aim_heading + PI * .5) * size * lerpf(-.9, .9, sweep)
		f.draw_line(hl - Vector2.from_angle(aim_heading) * size * .6, hl + Vector2.from_angle(aim_heading) * size * .6, Color(1, 1, 1, .8 * sin(sweep * PI)), 1.6, true)
		f.centered("T-%.2f" % (pass_t - u), center + Vector2(0, -size * 3.4 - 22), 14, Color(AMBER, .95), true)
		f.centered(TranslationServer.translate("强相互作用力材料  ·  表面绝对光滑"), Vector2(500, 576), 14, Color(WHITE, .65 * k), true)
		return
	var path: PackedVector2Array = droplet_path
	var hits: int = maxi(0, path.size() - 1)
	var end: Vector2 = path[path.size() - 1] if path.size() > 0 else at
	var moving: float = clampf((u - pass_t) / travel, 0, 1)
	var drop_at: Vector2 = droplet_point(moving)
	var heading: float = (droplet_point(minf(1.0, moving + .01)) - droplet_point(maxf(0.0, moving - .01))).angle()
	# Which stops have already blown: the channel crumbles behind the detonations.
	var blown: float = clampf((u - shatter_at) / cascade, 0, 1) if u >= shatter_at else -1.0
	var gone_after: float = 1.0 - smoothstep(shatter_at + cascade, shatter_at + cascade + .6, u)
	# 2) The plasma channel the drop leaves behind.
	if path.size() > 1:
		var channel := PackedVector2Array()
		var samples: int = 160
		for k in range(samples + 1):
			var t: float = moving * k / samples
			channel.append(droplet_point(t))
		var heat: float = 1.0 - smoothstep(arrive, shatter_at + cascade, u) * .6
		f.draw_polyline(channel, Color(.78, .86, 1.0, .14 * gone_after), 22.0, true)
		f.draw_polyline(channel, Color(.85, .92, 1.0, .22 * heat * gone_after), 9.0, true)
		f.draw_polyline(channel, Color(1, 1, 1, .5 * heat * gone_after), 3.5, true)
		f.begin_batch()
		for k in range(samples):
			var t0: float = moving * k / samples
			if blown >= 0.0 and t0 < blown:
				# Already detonated: the channel there breaks into drifting embers.
				var q: Vector2 = channel[k] + Vector2(sin(k * 1.7) * 9.0, cos(k * 2.3) * 9.0) * (u - shatter_at)
				if k % 3 == 0:
					f.shape(q, 1.4, 4, .785, Color(1, 1, 1, .5 * gone_after))
				continue
			f.stroke(channel[k], channel[k + 1], Color(1, 1, 1, .95 * gone_after))
		f.flush_batch()
	# 3) Each stop the drop pierces: a puncture flash and a sonic ring.
	for i in range(1, path.size()):
		var pass_at: float = pass_t + travel * (droplet_fracs[i] if i < droplet_fracs.size() else 1.0)
		var since: float = u - pass_at
		if since < 0.0 or since > .6:
			continue
		var k2: float = since / .6
		if since < .12:
			glow_at(f, path[i], 26.0 * (1.0 - since / .12) + 6.0, Color(1, 1, 1, (1.0 - since / .12)))
		f.draw_arc(path[i], 6.0 + f.ease_out(k2, 2) * 44.0, 0, TAU, 24, Color(1, 1, 1, (1.0 - k2) * .6), 1.4, true)
	if moving < 1.0:
		# 4) The drop in flight: a blinding point with a Mach cone and afterimages.
		var dir: Vector2 = Vector2.from_angle(heading)
		for side in [-1.0, 1.0]:
			f.draw_line(drop_at, drop_at - dir.rotated(side * .32) * 70.0, Color(1, 1, 1, .55), 1.6, true)
			f.draw_line(drop_at, drop_at - dir.rotated(side * .2) * 120.0, Color(.8, .88, 1.0, .25), 1.0, true)
		for j in range(1, 7):
			var ghost: Vector2 = droplet_point(maxf(0.0, moving - j * .012))
			draw_drop(f, ghost, 8.0 - j * .6, heading, .45 - j * .06)
		# Comet tail: the last stretch of the channel, thick and white-hot at the head.
		var tail_n: int = 28
		for j in range(tail_n):
			var t0: float = maxf(0.0, moving - (j + 1) * .006)
			var t1: float = maxf(0.0, moving - j * .006)
			var w: float = 1.0 - float(j) / tail_n
			f.draw_line(droplet_point(t0), droplet_point(t1), Color(Color(.75, .85, 1.0).lerp(Color.WHITE, w), .9 * w), 2.0 + 12.0 * w, true)
		glow_at(f, drop_at, 80.0, Color(.8, .88, 1.0, .55))
		glow_at(f, drop_at, 28.0, Color(1, 1, 1, 1.0))
		draw_drop(f, drop_at, 12.0, heading, 1.0)
		f.trauma = maxf(f.trauma, .6)
		var passed: int = 0
		for i in range(1, droplet_fracs.size()):
			if droplet_fracs[i] <= moving:
				passed += 1
		f.centered(TranslationServer.translate("贯穿 %d 个目标") % passed, Vector2(500, 576), 14, Color(AMBER, .95), true)
		return
	if u < shatter_at:
		# 5) The frozen instant at the far end.
		var since_arrive: float = u - arrive
		if since_arrive < .3:
			f.ult_flash = pow(1.0 - since_arrive / .3, 1.5) * .8
		var heading_end: float = (end - path[path.size() - 2]).angle() if path.size() > 1 else aim_heading
		glow_at(f, end, 40.0, Color(.85, .9, 1.0, .45))
		draw_drop(f, end, 12.0, heading_end, 1.0)
		f.centered("t = 0.000 s", Vector2(500, 546), 30, Color(WHITE, 1.0), true)
		f.centered(TranslationServer.translate("贯穿 %d 个目标") % hits, Vector2(500, 576), 14, Color(AMBER, .9), true)
		return
	# 6) Detonations run down the path (drawn by draw_shatters); the drop goes home.
	var back: float = clampf((u - shatter_at - cascade * .4) / 1.4, 0, 1)
	var e: float = back * back * (3.0 - 2.0 * back)
	var ctrl: Vector2 = end.lerp(at, .5) + (at - end).orthogonal().normalized() * 160.0
	var pos: Vector2 = end.lerp(ctrl, e).lerp(ctrl.lerp(at, e), e)
	var ahead_t: float = minf(1.0, e + .02)
	var ahead: Vector2 = end.lerp(ctrl, ahead_t).lerp(ctrl.lerp(at, ahead_t), ahead_t)
	if back < 1.0:
		for j in range(1, 8):
			var gt: float = maxf(0.0, e - j * .02)
			var gp: Vector2 = end.lerp(ctrl, gt).lerp(ctrl.lerp(at, gt), gt)
			f.draw_circle(gp, 3.0 - j * .3, Color(1, 1, 1, .5 - j * .06))
		draw_drop(f, pos, 12.0 * (1.0 - back * .7), (ahead - pos).angle() if ahead != pos else 0.0, 1.0 - smoothstep(.85, 1.0, back))
	else:
		var settle: float = clampf((u - shatter_at - cascade * .4 - 1.4) / .6, 0, 1)
		f.draw_arc(at, 12.0 + f.ease_out(settle, 2) * 120.0, 0, TAU, 64, Color(1, 1, 1, (1.0 - settle) * .8), 2.4, true)
		if settle < .2:
			glow_at(f, at, 40.0 * (1.0 - settle / .2), Color(1, 1, 1, 1.0 - settle / .2))
	f.centered(TranslationServer.translate("贯穿 %d 个目标") % hits, Vector2(500, 576), 14, Color(AMBER, .9 * (1.0 - smoothstep(.4, 1.0, back))), true)

func draw_shatters(f: Node2D) -> void:
	if shatters.is_empty():
		return
	for sh in shatters:
		var tg: float = float(sh.age) / float(sh.life)
		if tg < .25:
			var r_glow: float = float(sh.r) * (2.2 if bool(sh.boss) else 1.0)
			glow_at(f, sh.pos, r_glow * 2.6 + 14.0, Color(1, .95, .85, (1.0 - tg / .25) * .9))
	f.begin_batch()
	for sh in shatters:
		var t: float = float(sh.age) / float(sh.life)
		var p: Vector2 = sh.pos
		var r: float = float(sh.r) * (2.2 if bool(sh.boss) else 1.0)
		var pieces: int = int(sh.pieces)
		var seed_value: int = int(sh.seed)
		var fly: float = 1.0 - pow(1.0 - t, 3)
		var a: float = 1.0 - t
		# Crack star first, then the body springs apart along those cracks.
		var cracks: int = pieces + 3
		for j in range(cracks):
			var ang: float = j * TAU / cracks + seed_value * .1
			var reach: float = r * (1.1 + .5 * sin(j * 2.3 + seed_value)) * minf(1.0, t * 6.0)
			f.stroke(p, p + Vector2.from_angle(ang) * reach, Color(1, 1, 1, a * (1.0 - smoothstep(.2, .5, t))))
		for j in range(pieces * 3):
			var ang: float = j * 2.399 + seed_value
			var dist: float = r * (.4 + fly * (1.6 + (j % 3) * .5))
			var q: Vector2 = p + Vector2.from_angle(ang) * dist
			f.shape(q, (2.6 + (j % 3)) * (1.0 - t * .6), 3, ang + t * 9.0, Color(1, 1, 1, a * (.9 if j % 2 else .55)))
		f.ring(p, r * (.6 + fly * 1.8), Color(1, 1, 1, a * .5), 1.0)
	f.flush_batch()

# =====================================================================
# Fourier drawing: the frozen swarm is one closed signal through every threat.
# Its DFT becomes a chain of spinning sticks and circles (epicycles); the tip of
# the chain draws the curve, and each threat bursts as the tip passes through it.
# =====================================================================
const FOURIER_TERMS: int = 48
const FOURIER_SAMPLES: int = 512
const FOURIER_CHAIN_DRAWN: int = 34
var tour_points := PackedVector2Array()
var tour_fracs := PackedFloat32Array()
var tour_curve := PackedVector2Array()
var tour_terms: Array[Vector3] = []
var fourier_marks: Array[Dictionary] = []

func prepare_fourier(_enemies: Array, _core: Vector2) -> void:
	tour_points = PackedVector2Array()
	tour_curve = PackedVector2Array()
	tour_terms.clear()

func fourier_tour_set(points: PackedVector2Array, fractions: PackedFloat32Array, core: Vector2) -> void:
	tour_points = points
	tour_fracs = fractions
	# Resample the closed tour by arc length, relative to the core.
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	var total: float = 0.0
	for i in range(1, loop.size()):
		total += loop[i - 1].distance_to(loop[i])
	var samples := PackedVector2Array()
	var seg: int = 1
	var walked: float = 0.0
	for k in range(FOURIER_SAMPLES):
		var want: float = total * k / FOURIER_SAMPLES
		while seg < loop.size() - 1 and walked + loop[seg - 1].distance_to(loop[seg]) < want:
			walked += loop[seg - 1].distance_to(loop[seg])
			seg += 1
		var span: float = maxf(.001, loop[seg - 1].distance_to(loop[seg]))
		samples.append(loop[seg - 1].lerp(loop[seg], clampf((want - walked) / span, 0, 1)) - core)
	# Discrete Fourier transform: one rotating stick per frequency.
	tour_terms.clear()
	for freq in range(-FOURIER_TERMS, FOURIER_TERMS + 1):
		var acc := Vector2.ZERO
		for k in range(FOURIER_SAMPLES):
			var ang: float = -TAU * freq * k / FOURIER_SAMPLES
			var z: Vector2 = samples[k]
			acc += Vector2(z.x * cos(ang) - z.y * sin(ang), z.x * sin(ang) + z.y * cos(ang))
		acc /= FOURIER_SAMPLES
		tour_terms.append(Vector3(freq, acc.x, acc.y))
	tour_terms.sort_custom(func(x: Vector3, y: Vector3) -> bool: return Vector2(x.y, x.z).length() > Vector2(y.y, y.z).length())
	# The curve the chain will draw (precomputed once).
	tour_curve = PackedVector2Array()
	for k in range(FOURIER_SAMPLES + 1):
		tour_curve.append(core + epicycle_tip(TAU * k / FOURIER_SAMPLES))

func epicycle_tip(theta: float) -> Vector2:
	var sum := Vector2.ZERO
	for term in tour_terms:
		var a: float = term.x * theta
		sum += Vector2(term.y * cos(a) - term.z * sin(a), term.y * sin(a) + term.z * cos(a))
	return sum

func fourier_struck(point: Vector2, index: int, total: int) -> void:
	if fourier_marks.size() > 220:
		fourier_marks.pop_front()
	fourier_marks.append({"pos": point, "age": 0.0, "life": .8, "seed": index})

func glow_at(f: Node2D, p: Vector2, radius: float, color: Color) -> void:
	f.draw_texture_rect(f.GlowTexture, Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)

func fourier(f: Node2D, u: float, at: Vector2) -> void:
	var sample_t: float = f.sim.FOURIER_SAMPLE
	var trace_t: float = f.sim.FOURIER_TRACE
	var dur: float = float(f.sim.ult.get("trace_dur", 3.0))
	var end_t: float = trace_t + dur
	var fade: float = 1.0 - smoothstep(end_t + 1.2, end_t + 1.8, u)
	var count: int = maxi(0, tour_points.size() - 1)
	# 1) Lock-on: a radar sweep from the core; brackets snap onto each threat it passes.
	if u < trace_t:
		var sweep: float = u / trace_t * TAU * 1.25 - PI * .5
		var reach: float = 950.0
		var fan := PackedVector2Array([at])
		for j in range(13):
			fan.append(at + Vector2.from_angle(sweep - j * .03) * reach)
		f.draw_colored_polygon(fan, Color(1, .85, .45, .07))
		f.draw_line(at, at + Vector2.from_angle(sweep) * reach, Color(AMBER, .7), 1.6, true)
	f.begin_batch()
	for i in range(1, tour_points.size()):
		var p: Vector2 = tour_points[i]
		var bearing: float = fposmod((p - at).angle() + PI * .5, TAU)
		var locked_at: float = clampf(bearing / (TAU * 1.25), 0, 1) * trace_t
		var appear: float = clampf((u - maxf(sample_t * .5, locked_at)) / .2, 0, 1)
		var hit_at: float = trace_t + dur * (tour_fracs[i] if i < tour_fracs.size() else 1.0)
		if appear <= 0.0 or u > hit_at:
			continue
		var snap: float = f.ease_out_back(appear)
		var r: float = 8.0 + (1.0 - snap) * 18.0
		var waiting: float = clampf((hit_at - u) / .35, 0, 1)
		var col := Color(AMBER, .9 * fade).lerp(Color(1, 1, 1, fade), 1.0 - waiting)
		for j in range(4):
			var c0: Vector2 = p + Vector2.from_angle(j * PI * .5 + PI * .25) * r
			var d1: Vector2 = Vector2.from_angle(j * PI * .5 + PI * .25 + PI * .75) * 5.0
			var d2: Vector2 = Vector2.from_angle(j * PI * .5 + PI * .25 - PI * .75) * 5.0
			f.stroke(c0, c0 + d1, col)
			f.stroke(c0, c0 + d2, col)
	f.flush_batch()
	if tour_curve.is_empty():
		return
	var progress: float = clampf((u - trace_t) / dur, 0, 1)
	var collapse: float = smoothstep(end_t + .25, end_t + .9, u)
	var shown: int = int(progress * FOURIER_SAMPLES)
	# 2) The drawn curve: glow under a crisp line, with light pulses running along it.
	if shown > 1:
		var pts := PackedVector2Array()
		for k in range(shown + 1):
			pts.append(tour_curve[k].lerp(at, collapse))
		var flare: float = 1.0 + 1.6 * (smoothstep(end_t - .05, end_t + .1, u) - smoothstep(end_t + .1, end_t + .5, u))
		f.draw_polyline(pts, Color(1, .88, .62, .09 * flare * fade), 12.0, true)
		f.draw_polyline(pts, Color(1, .92, .75, .2 * flare * fade), 4.0, true)
		f.draw_polyline(pts, Color(1, 1, 1, .9 * fade), 1.5, true)
		for j in range(6):
			var q: float = fposmod(u * .35 + j / 6.0, 1.0) * shown
			var pk: Vector2 = pts[mini(int(q), pts.size() - 1)]
			glow_at(f, pk, 9.0, Color(1, .9, .6, .55 * fade))
			f.draw_circle(pk, 1.8, Color(1, 1, 1, fade))
		# The pen's comet tail: three widths, amber fading into white-hot.
		var tail_len: int = mini(shown, 70)
		for layer in range(3):
			var width: float = [9.0, 4.5, 2.2][layer]
			var alpha: float = [.12, .35, .95][layer]
			for k in range(pts.size() - tail_len, pts.size() - 1):
				var w: float = float(k - (pts.size() - tail_len)) / tail_len
				f.draw_line(pts[k], pts[k + 1], Color(AMBER.lerp(Color.WHITE, w), alpha * w * fade * (1.0 - collapse)), width * (.4 + .6 * w), true)
	# 3) The epicycles: tapering sticks, glowing joints, circles with a soft halo.
	if u >= trace_t - .4 and collapse < 1.0:
		var theta: float = TAU * progress
		var grow: float = smoothstep(trace_t - .4, trace_t, u) * (1.0 - collapse)
		var pos: Vector2 = at
		var drawn: int = 0
		for term in tour_terms:
			var c := Vector2(term.y, term.z)
			var ang: float = term.x * theta
			var arm := Vector2(c.x * cos(ang) - c.y * sin(ang), c.x * sin(ang) + c.y * cos(ang)) * grow
			if drawn < FOURIER_CHAIN_DRAWN:
				var rad: float = c.length() * grow
				var weight: float = 1.0 - float(drawn) / FOURIER_CHAIN_DRAWN
				if term.x != 0.0 and rad > 2.0:
					f.draw_arc(pos, rad, 0, TAU, clampi(int(rad * .5), 16, 96), Color(AMBER, (.06 + .1 * weight) * fade), 4.0, true)
					f.draw_arc(pos, rad, 0, TAU, clampi(int(rad * .5), 16, 96), Color(AMBER if drawn < 8 else WHITE, (.2 + .45 * weight) * fade), 1.0, true)
				f.draw_line(pos, pos + arm, Color(1, 1, 1, (.35 + .6 * weight) * fade), .8 + 2.4 * weight, true)
				if drawn < 10:
					glow_at(f, pos, 6.0 + 6.0 * weight, Color(1, .85, .5, .45 * weight * fade))
				f.draw_circle(pos, .8 + 2.2 * weight, Color(1, 1, 1, fade))
			pos += arm
			drawn += 1
		var tip: Vector2 = tour_curve[shown].lerp(at, collapse) if shown < tour_curve.size() else pos
		glow_at(f, tip, 34.0, Color(1, .82, .45, .55 * fade))
		glow_at(f, tip, 12.0, Color(1, 1, 1, .9 * fade))
		for j in range(4):
			var d := Vector2.from_angle(j * PI * .5 + u * 4.0)
			f.draw_line(tip + d * 5.0, tip + d * 22.0, Color(1, 1, 1, .8 * fade), 1.3, true)
	# 4) Finale: time domain to frequency domain. The curve's own spectrum bursts out.
	if u > end_t + .55 and not tour_terms.is_empty():
		var k: float = clampf((u - end_t - .55) / 1.1, 0, 1)
		var out: float = f.ease_out(k, 3)
		var peak: float = maxf(1.0, Vector2(tour_terms[1].y, tour_terms[1].z).length() if tour_terms.size() > 1 else 1.0)
		var bars: int = mini(tour_terms.size(), 96)
		for j in range(bars):
			var term: Vector3 = tour_terms[j]
			var amp: float = log(1.0 + clampf(Vector2(term.y, term.z).length() / peak, 0, 1) * 60.0) / log(61.0)
			var ang: float = (term.x + FOURIER_TERMS) / (FOURIER_TERMS * 2.0 + 1.0) * TAU - PI * .5
			var r0: float = 40.0 + out * 60.0
			var r1: float = r0 + (18.0 + 270.0 * amp) * out
			var dir := Vector2.from_angle(ang)
			var col := Color(AMBER if term.x == 0.0 or j < 6 else WHITE, (1.0 - k) * (.5 + .5 * amp))
			f.draw_line(at + dir * r0, at + dir * r1, Color(col, col.a * .25), 7.0, true)
			f.draw_line(at + dir * r0, at + dir * r1, col, 2.6, true)
			if j < 12:
				glow_at(f, at + dir * r1, 12.0, Color(1, .88, .55, (1.0 - k) * .6))
		f.draw_arc(at, (40.0 + out * 60.0), 0, TAU, 96, Color(1, 1, 1, (1.0 - k) * .8), 1.4, true)
		if k < .25:
			f.ult_flash = (1.0 - k / .25) * .25
	# 5) Readouts, clear of the title card.
	var top: float = smoothstep(2.1, 2.5, u) * fade
	f.centered("f(t) = Σ  cₙ · e^(i n t)", Vector2(500, 82), 24, Color(WHITE, top), true)
	var done: int = 0
	for i in range(1, tour_fracs.size()):
		if tour_fracs[i] <= progress:
			done += 1
	var line: String = TranslationServer.translate("采样中") if u < trace_t else TranslationServer.translate("傅里叶项 %d  ·  已击穿 %d / %d") % [tour_terms.size(), done, count]
	f.centered(line, Vector2(500, 576), 14, Color(AMBER, .9 * fade), true)

func draw_fourier_marks(f: Node2D) -> void:
	# Each threat the pen passes through: white flash, double ring, radial spikes.
	if fourier_marks.is_empty():
		return
	for m in fourier_marks:
		var t: float = float(m.age) / float(m.life)
		if t < .3:
			glow_at(f, m.pos, 30.0 * (1.0 - t / .3) + 8.0, Color(1, .95, .8, (1.0 - t / .3) * .8))
	f.begin_batch()
	for m in fourier_marks:
		var t: float = float(m.age) / float(m.life)
		var p: Vector2 = m.pos
		var ease_t: float = 1.0 - pow(1.0 - t, 3)
		f.arc_segments(p, 6.0 + ease_t * 30.0, 0, TAU, Color(WHITE, (1.0 - t) * .95))
		f.arc_segments(p, 3.0 + ease_t * 18.0, 0, TAU, Color(AMBER, (1.0 - t) * .8))
		for j in range(10):
			var a: float = j * TAU / 10 + int(m.seed) * .37
			var d := Vector2.from_angle(a)
			var len: float = 10.0 if j % 2 == 0 else 6.0
			f.stroke(p + d * (6.0 + ease_t * 20.0), p + d * (6.0 + ease_t * 20.0 + len * (1.0 - t)), Color(AMBER if j % 2 == 0 else WHITE, (1.0 - t)))
		f.shape(p, 4.5 * (1.0 - t) + .5, 4, t * 6.0, Color(1, 1, 1, 1.0 - t))
	f.flush_batch()

# =====================================================================
# Mandelbrot: the set itself is a shader overlay (main.gd); the field adds the
# iteration orbit, the formula and the zoom readouts.
# =====================================================================
const SEAHORSE := Vector2(-0.743643887, 0.131825904)

func mandel_scale(u: float, disc: float = 1.0) -> float:
	# While it blooms the whole set sits inside the disc; then the dive begins.
	var whole: float = 2.9 / maxf(.06, 2.0 * disc)
	return minf(whole, 3.2) * exp(-log(12000.0) * smoothstep(2.7, 5.4, u))

func mandel_focus(u: float) -> Vector2:
	return Vector2(-0.62, 0.0).lerp(SEAHORSE, smoothstep(2.4, 3.7, u))

func mandel_iterations(u: float) -> int:
	return int(lerpf(48.0, 420.0, smoothstep(1.2, 5.0, u)))

func mandelbrot(f: Node2D, u: float, at: Vector2) -> void:
	var fade: float = 1.0 - smoothstep(4.9, 5.6, u)
	if u < 1.4:
		# The seed: one orbit of z -> z^2 + c spirals out of the core in amber.
		var c := Vector2(-0.12, 0.74)
		var z := Vector2.ZERO
		var shown: int = int(36 * smoothstep(0.0, .9, u))
		var prev: Vector2 = at
		var px: float = 150.0
		var fade_orbit: float = 1.0 - smoothstep(1.0, 1.4, u)
		for i in range(shown):
			z = Vector2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c
			var p: Vector2 = at + Vector2(z.x, -z.y) * px
			f.draw_line(prev, p, Color(AMBER, .55 * fade_orbit), 1.2, true)
			f.draw_circle(p, 2.2, Color(1, 1, 1, fade_orbit))
			prev = p
	var type_in: int = int(clampf(u / .6, 0, 1) * 13)
	f.centered("z  →  z² + c".substr(0, type_in), Vector2(500, 546), 30, Color(WHITE, fade), true)
	if u > MANDEL_TEXT_START:
		var zoom: float = 3.2 / mandel_scale(u)
		var focus: Vector2 = mandel_focus(u)
		f.centered(TranslationServer.translate("放大 ×%s  ·  迭代 %d") % [f.sim.Catalog.number(zoom), mandel_iterations(u)], Vector2(500, 576), 14, Color(AMBER, .9 * fade), true)
		f.centered("c = %.6f %s %.6f i" % [focus.x, "+" if focus.y >= 0 else "−", absf(focus.y)], Vector2(500, 82), 14, Color(WHITE, .6 * fade * smoothstep(2.1, 2.5, u)), true)
const MANDEL_TEXT_START: float = 1.0

# =====================================================================
# Dimensional resonance: concentric closed strings unfurl round the core, each
# ringing in its own harmonic; every threat is revealed as a vibrating string,
# driven to resonance by the shaking dimensions, and all of them snap.
# =====================================================================
var snaps: Array[Dictionary] = []
# The resonance rings: concentric closed strings round the core, each ringing in
# its own harmonic (Fibonacci overtones climb as the field resonates).
const STRING_RINGS: Array = [[96.0, 3], [170.0, 5], [250.0, 8]]

func ring_radius(base: float, n: int, angle: float, amp: float, phase: float) -> float:
	return base + amp * sin(n * angle) * cos(phase)

func string_level(u: float) -> float:
	# 0 = ordinary threats, 1 = fully revealed strings.
	return smoothstep(.7, 1.6, u) * (0.0 if u >= 4.4 else 1.0)

func string_resonance(u: float) -> float:
	return smoothstep(2.6, 4.4, u)

func strings(f: Node2D, u: float, at: Vector2) -> void:
	var impact: float = f.sim.STRINGS_IMPACT
	var res: float = string_resonance(u)
	var fade: float = 1.0 - smoothstep(6.0, 6.6, u)
	f.begin_batch()
	if u < impact:
		# Each ring unfurls in turn, then rings in a standing wave: its nodes stay
		# pinned (amber beads) while the antinodes swing, harder and faster with resonance.
		for i in range(STRING_RINGS.size()):
			var base: float = float(STRING_RINGS[i][0])
			var n: int = int(STRING_RINGS[i][1])
			var grow: float = f.ease_out((u - i * .16) / .9, 3)
			if grow <= 0.0:
				continue
			var radius: float = base * grow
			var amp: float = (2.0 + base * .02) * (.35 + res * 1.1) * grow
			var phase: float = u * (3.0 + n * .6) * (1.0 + res * 2.5)
			var hot: bool = res > .15 and i <= int(res * STRING_RINGS.size())
			var col: Color = Color(AMBER if hot else WHITE, (.55 + .4 * res) * fade)
			var samples: int = 96 + n * 6
			var prev: Vector2 = at + Vector2.from_angle(0.0) * ring_radius(radius, n, 0.0, amp, phase)
			for k in range(1, samples + 1):
				var a: float = k * TAU / samples
				var q: Vector2 = at + Vector2.from_angle(a) * ring_radius(radius, n, a, amp, phase)
				f.stroke(prev, q, col)
				prev = q
			# The still points of the vibration.
			for k in range(2 * n):
				f.shape(at + Vector2.from_angle(k * PI / n) * radius, 1.8, 4, .785, Color(AMBER, .85 * fade * grow))
			# A faint envelope shows the full swing of the antinodes.
			if res > .05:
				for k in range(n):
					var a: float = (k + .5) * TAU / n
					f.stroke(at + Vector2.from_angle(a) * (radius - amp), at + Vector2.from_angle(a) * (radius + amp), Color(WHITE, .25 * res * fade))
	else:
		# The snap: every ring breaks at its nodes and the pieces fly outward.
		var k: float = clampf((u - impact) / 1.4, 0, 1)
		var fly: float = 1.0 - pow(1.0 - k, 3)
		for i in range(STRING_RINGS.size()):
			var base: float = float(STRING_RINGS[i][0])
			var n: int = int(STRING_RINGS[i][1])
			for piece in range(2 * n):
				var a0: float = piece * PI / n
				var mid: float = a0 + PI / (2.0 * n)
				var push: Vector2 = Vector2.from_angle(mid) * fly * (120.0 + base * .8)
				var prev: Vector2 = Vector2.ZERO
				for j in range(9):
					var a: float = a0 + (PI / n) * j / 8.0
					var curl: float = sin(j / 8.0 * PI) * 14.0 * fly * (1.0 if piece % 2 == 0 else -1.0)
					var q: Vector2 = at + push + Vector2.from_angle(a) * (base + curl)
					if j > 0:
						f.stroke(prev, q, Color(AMBER if j % 4 == 0 else WHITE, (1.0 - k) * .9 * fade))
					prev = q
	f.flush_batch()
	var since: float = u - impact
	if since > 0.0 and since < .35:
		f.ult_flash = (1.0 - since / .35) * .5
	if since > 0.0:
		var kk: float = clampf(since / 1.2, 0, 1)
		f.draw_arc(at, f.ease_out(kk, 2) * 1100.0, 0, TAU, 160, Color(1, 1, 1, (1.0 - kk) * .9), 3.0 * (1.0 - kk) + 1.0, true)
	# Readouts: dimensions folding, harmonics climbing.
	f.centered("11D  →  4D", Vector2(500, 546), 28, Color(WHITE, fade * smoothstep(.1, .6, u)), true)
	var harmonics: Array[String] = ["1", "2", "3", "5", "8", "13", "21", "34", "∞"]
	var hn: String = harmonics[clampi(int(res * 8.0 + (1.0 if u > 1.3 else 0.0)), 0, 8)]
	var label: String = TranslationServer.translate("额外维度展开") if u < f.sim.STRINGS_REVEAL else (TranslationServer.translate("弦振动  ·  谐波 n = ") + hn if u < impact else TranslationServer.translate("共振断裂"))
	f.centered(label, Vector2(500, 576), 14, Color(AMBER, .9 * fade), true)

func strings_snapped(points: PackedVector2Array) -> void:
	for p in points:
		if snaps.size() >= 240:
			break
		snaps.append({"pos": p, "age": 0.0, "life": .9, "seed": absi(int(p.x * 3 + p.y * 11)) % 628})

func draw_snaps(f: Node2D) -> void:
	if snaps.is_empty():
		return
	f.begin_batch()
	for sn in snaps:
		var t: float = float(sn.age) / float(sn.life)
		var p: Vector2 = sn.pos
		var ang: float = int(sn.seed) * .01
		var fly: float = 1.0 - pow(1.0 - t, 3)
		# The string snaps in two; both halves whip away and curl as they go.
		for side in [-1.0, 1.0]:
			var dir: Vector2 = Vector2.from_angle(ang) * side
			var prev: Vector2 = p + dir * fly * 6.0
			for k in range(1, 9):
				var q: float = k / 8.0
				var curl: float = sin(q * PI * 2.0 + t * 12.0) * 10.0 * (1.0 - t) * q
				var pt: Vector2 = p + dir * (fly * 34.0 + q * 18.0 * (1.0 - t * .5)) + dir.orthogonal() * curl
				f.stroke(prev, pt, Color(AMBER if k < 3 else WHITE, (1.0 - t) * .9))
				prev = pt
		f.shape(p, 2.5 * (1.0 - t) + .5, 4, ang, Color(1, 1, 1, 1.0 - t))
	f.flush_batch()

func draw_string_threat(f: Node2D, p: Vector2, radius: float, seed_value: int, u: float, members: int) -> void:
	# A threat seen as what it is underneath: a closed string ringing in harmonic n.
	var res: float = string_resonance(u)
	var level: float = string_level(u)
	var n: int = 3 + seed_value % 3
	var amp: float = .05 + res * .14
	var loop := PackedVector2Array()
	var r: float = radius * (.8 + .2 * level)
	for k in range(25):
		var a: float = k * TAU / 24
		var wobble: float = sin(a * n + u * (6.0 + res * 26.0) + seed_value) * amp
		loop.append(p + Vector2.from_angle(a) * r * (1.0 + wobble))
	for k in range(24):
		f.stroke(loop[k], loop[k + 1], Color(AMBER if res > .6 else WHITE, .45 + level * .35))
