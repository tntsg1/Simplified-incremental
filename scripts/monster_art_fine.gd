extends RefCounted
# Refined art (round 2) for the threats the developer flagged as too plain.
# Rule from the developer: minimal but never simple - each one gets layered tones,
# a highlight, fine detail and at least one living motion.
const Base = preload("res://scripts/monster_art.gd")
const INK := Color("ededed")
const ACCENT := Color("ffc94d")
const LIGHT := Vector2(-.6, -.8)
# Tone ramps: shadow, body, lit, highlight.
const ROCK := [Color("232323"), Color("4f4f4f"), Color("8c8c8c"), Color("d6d6d6")]
const METAL := [Color("1a1a1a"), Color("363636"), Color("8a8a8a"), Color("f4f4f4")]
const ICEY := [Color("131c25"), Color("2c4253"), Color("86aac0"), Color("eef8ff")]
const WARM := [Color("2e1c0c"), Color("8c5418"), Color("f2b84a"), Color("fff3d2")]
const STAR := Color("f6f1e6")


static func poly(f: Node2D, pts: PackedVector2Array, a: float, fill: Color, line: Color = Color(0, 0, 0, 0), w: float = 1.1) -> void:
	if pts.size() < 3:
		return
	f.draw_colored_polygon(pts, Color(fill, fill.a * a))
	if line.a > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		f.draw_polyline(loop, Color(line, line.a * a), w, true)


static func shaded(f: Node2D, p: Vector2, s: float, n: int, rot: float, jit: float, seed: int, a: float, tones: Array, outline: bool = true) -> PackedVector2Array:
	# Three stacked tones lit from the upper left: a flat 2D illustration, not 3D.
	var rim: PackedVector2Array = Base.ring_pts(p, s, n, rot, jit, seed)
	poly(f, rim, a, tones[0], tones[2] if outline else Color(0, 0, 0, 0), 1.0)
	poly(f, Base.ring_pts(p + LIGHT * s * .13, s * .78, n, rot, jit, seed), a, tones[1])
	poly(f, Base.ring_pts(p + LIGHT * s * .3, s * .42, n, rot + .4, jit, seed + 3), a, Color(tones[2], .55))
	return rim


static func wobble(c: Vector2, r: float, n: int, amp: float, t: float, seed: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var u: float = i * TAU / n
		var k: float = 1.0 + amp * (sin(u * 3.0 + t * 2.3 + seed) * .6 + sin(u * 5.0 - t * 3.1 + seed * .7) * .4)
		out.append(c + Vector2.from_angle(u) * r * k)
	return out


static func twinkle(f: Node2D, q: Vector2, size: float, phase: float, a: float, col: Color = Color.WHITE) -> void:
	var k: float = pow(.5 + .5 * sin(phase), 3.0)
	if k < .05:
		return
	f.stroke(q - Vector2(size * k, 0), q + Vector2(size * k, 0), Color(col, k * a))
	f.stroke(q - Vector2(0, size * k), q + Vector2(0, size * k), Color(col, k * a))


static func draw(f: Node2D, key: String, e: Dictionary, p: Vector2, s: float, heading: float, spin: float, a: float, flash: float, open: float) -> bool:
	var dir := Vector2.from_angle(heading)
	var nrm: Vector2 = dir.orthogonal()
	var t: float = f.clock
	var sd: int = int(e.seed)
	var hp: float = Base.health_of(e)
	var hot: Color = ACCENT.lerp(Color.WHITE, flash)
	var line: Color = INK.lerp(Color.WHITE, flash)
	match key:
		# ================================================================ 01 city
		"0_armored":
			# Iron meteorite: pitted, sheened; its leading face burns and sheds embers.
			var rim: PackedVector2Array = shaded(f, p, s, 10, spin * .3, .14, sd, a, METAL)
			for j in range(5):
				var q: Vector2 = p + Vector2.from_angle(spin * .3 + j * 1.27 + sd) * s * (.28 + .14 * (j % 3))
				poly(f, Base.oval(q, s * .13, s * .09, spin * .3 + j, 10), a, METAL[0])
				f.draw_arc(q, s * .13, PI * 1.1, PI * 1.7, 6, Color(METAL[3], .5 * a), 1.0, true)
			f.draw_arc(p, s * .82, spin * .3 + 2.6, spin * .3 + 3.4, 10, Color(METAL[3], .7 * a), 1.4, true)
			var burn: float = .6 + .4 * sin(t * 9.0)
			f.draw_arc(p, s * 1.03, heading - 1.0, heading + 1.0, 18, Color(hot, (.55 + .35 * burn) * a), 2.4, true)
			for j in range(7):
				var k: float = fposmod(t * 1.4 + j / 7.0, 1.0)
				var from: Vector2 = p + Vector2.from_angle(heading + (j - 3) * .28) * s
				f.draw_circle(from - dir * s * k * 2.4, 1.6 * (1.0 - k) + .4, Color(ACCENT, (1.0 - k) * a))
			for j in range(int((1.0 - hp) * 5.0)):
				var u := Vector2.from_angle(sd + j * 2.2)
				f.stroke(p + u * s * .1, p + u.rotated(.3) * s * .75, Color(ACCENT, .6 * a))
		# ================================================================ 02 Earth orbit
		"1_swarm":
			# Space junk: a torn panel tumbling, a cable whipping, a glint as it catches the sun.
			var r: float = spin * 1.5
			var u := Vector2.from_angle(r)
			var v: Vector2 = u.orthogonal()
			var torn := PackedVector2Array([p - u * s * .8 - v * s * .5, p + u * s * .55 - v * s * .6, p + u * s * .75 - v * s * .1,
				p + u * s * .5 + v * s * .55, p + u * s * .05 + v * s * .35, p - u * s * .6 + v * s * .6])
			poly(f, torn, a, METAL[1], METAL[2], 1.0)
			f.stroke(p - u * s * .3 - v * s * .4, p - u * s * .1 + v * s * .45, Color(METAL[0], a))
			f.stroke(p + u * s * .2 - v * s * .5, p + u * s * .35 + v * s * .4, Color(METAL[0], a))
			var cable := PackedVector2Array()
			for k in range(8):
				var w: float = k / 7.0
				cable.append(p + u * s * .75 - v * s * .1 + u * s * w * .9 + v * sin(w * 5.0 + t * 7.0) * s * .2 * w)
			f.draw_polyline(cable, Color(METAL[2], a), 1.0, true)
			var glint: float = pow(maxf(0.0, cos(r * 2.0)), 18.0)
			if glint > .05:
				Base.glow(f, p - u * s * .6 - v * s * .4, s * .5 * glint, Color.WHITE, a)
				twinkle(f, p - u * s * .6 - v * s * .4, s * .6, PI * .5, glint * a)
		"1_dart":
			# Recon drone: a lensed hull on four blurred rotors, sweeping a faint scan cone.
			var sweep: float = heading + sin(t * 2.0) * .35
			f.draw_colored_polygon(PackedVector2Array([p, p + Vector2.from_angle(sweep - .25) * s * 3.0, p + Vector2.from_angle(sweep + .25) * s * 3.0]), Color(ACCENT, .07 * a))
			for j in range(4):
				var arm: Vector2 = p + Vector2.from_angle(heading + PI * .25 + j * PI * .5) * s * .85
				f.stroke(p, arm, Color(METAL[2], a), 1.2)
				f.draw_colored_polygon(Base.oval(arm, s * .36, s * .36, 0.0, 14), Color(METAL[2], .12 * a))
				f.draw_arc(arm, s * .36, t * 30.0 + j, t * 30.0 + j + 1.2, 6, Color(INK, .7 * a), 1.0, true)
			poly(f, Base.oval(p, s * .5, s * .38, heading, 14), a, METAL[1], line, 1.2)
			poly(f, Base.oval(p - nrm * s * .05, s * .32, s * .22, heading, 12), a, METAL[2])
			var lens: Vector2 = p + dir * s * .35
			f.draw_circle(lens, s * .17, Color(METAL[0], a))
			f.draw_circle(lens, s * .08 * (1.0 + .3 * sin(t * 6.0)), Color(hot, a))
		"1_armored":
			# Dead satellite: gold-foil bus, gridded wings with a sweeping glint, a dish; it sparks as it breaks.
			var r2: float = spin * .22
			var u := Vector2.from_angle(r2)
			var v: Vector2 = u.orthogonal()
			var bus := PackedVector2Array([p - u * s * .36 - v * s * .32, p + u * s * .36 - v * s * .32, p + u * s * .36 + v * s * .32, p - u * s * .36 + v * s * .32])
			poly(f, bus, a, Color("6b5420"), Color("c9a24a"), 1.2)
			for k in range(3):
				f.stroke(p - u * s * .3 + v * s * (-.2 + k * .2), p + u * s * .3 + v * s * (-.15 + k * .2), Color("c9a24a", .5 * a))
			var cells: int = int(ceil(hp * 8.0))
			var sheen: float = fposmod(t * .4, 1.0)
			for side in [1.0, -1.0]:
				f.stroke(p + u * s * .36 * side, p + u * s * .48 * side, Color(METAL[2], a), 1.4)
				for k in range(4):
					if k + (0 if side > 0 else 4) >= cells:
						continue
					var c0: Vector2 = p + u * side * s * (.5 + k * .31)
					var cell := PackedVector2Array([c0 - v * s * .28, c0 + u * side * s * .28 - v * s * .28, c0 + u * side * s * .28 + v * s * .28, c0 + v * s * .28])
					poly(f, cell, a, Color("1b2633"), METAL[2], .9)
					f.stroke(c0 + u * side * s * .14 - v * s * .28, c0 + u * side * s * .14 + v * s * .28, Color(METAL[1], a))
					if absf(sheen - (k / 4.0)) < .12:
						f.stroke(c0 - v * s * .28, c0 + u * side * s * .28 + v * s * .28, Color(Color.WHITE, .55 * a), 1.2)
				if cells < 8:
					var joint: Vector2 = p + u * side * s * .48
					for j in range(3):
						var spark: Vector2 = joint + Vector2.from_angle(t * 13.0 + j * 2.1) * s * .2 * fposmod(t * 3.0 + j * .3, 1.0)
						f.draw_circle(spark, 1.0, Color(ACCENT, a))
			f.stroke(p + v * s * .32, p + v * s * .62, Color(METAL[2], a))
			f.draw_arc(p + v * s * .74, s * .18, r2 + PI * 1.15, r2 + PI * 1.85, 8, Color(METAL[3], a), 1.4, true)
			f.draw_circle(p, 1.6, Color(ACCENT, (.3 + .7 * float(int(t * 2.0) % 2)) * a))
		# ================================================================ 03 inner Solar System
		"2_swarm":
			# Asteroid chunk: a shaded lump with two rimmed craters.
			shaded(f, p, s * .8, 8, spin, .22, sd, a, ROCK)
			for j in range(2):
				var q: Vector2 = p + Vector2.from_angle(spin + 1.2 + j * 2.4) * s * .32
				f.draw_circle(q, s * (.15 - j * .04), Color(ROCK[0], a))
				f.draw_arc(q, s * (.15 - j * .04), PI * .1, PI * .9, 6, Color(ROCK[3], .6 * a), 1.0, true)
		"2_armored":
			# Metal asteroid: dark polished iron, banded, a specular streak that slides as it turns,
			# inclusions glinting; hits gouge bright scars.
			var rot: float = spin * .25
			poly(f, Base.oval(p, s * 1.05, s * .8, rot, 22), a, METAL[0], METAL[2], 1.2)
			poly(f, Base.oval(p + LIGHT * s * .12, s * .82, s * .6, rot, 20), a, METAL[1])
			for k in range(3):
				f.draw_arc(p, s * (.55 + k * .15), rot + 3.6, rot + 5.3, 12, Color(METAL[2], .4 * a), 1.0, true)
			f.draw_arc(p, s * .75, rot - 2.5 + sin(t * .7) * .3, rot - 1.7 + sin(t * .7) * .3, 10, Color(METAL[3], .9 * a), 2.0, true)
			for j in range(4):
				twinkle(f, p + Vector2.from_angle(rot + j * 1.6 + sd) * s * (.3 + .1 * j), s * .18, t * 3.0 + j * 1.7, a)
			for j in range(int((1.0 - hp) * 5.0)):
				var u := Vector2.from_angle(rot + j * 1.9 + sd)
				f.stroke(p + u * s * .3, p + u * s * .9, Color(METAL[3], .8 * a), 1.6)
		"2_splitter":
			# Rubble pile: seven shaded boulders jostling in a halo of dust, glowing seams between.
			for j in range(7):
				var base_a: float = spin * .4 + j * TAU / 7
				var q: Vector2 = p + Vector2.from_angle(base_a) * s * (.38 if j % 2 == 0 else .58) + Vector2(sin(t * 1.4 + j), cos(t * 1.1 + j * 2.0)) * s * .03
				shaded(f, q, s * (.3 if j % 2 == 0 else .23), 6, spin + j, .2, sd + j, a, ROCK, false)
			shaded(f, p, s * .28, 6, -spin, .2, sd, a, ROCK, false)
			for j in range(10):
				var k: float = t * .5 + j * TAU / 10
				f.draw_circle(p + Vector2.from_angle(k) * s * (.95 + .08 * sin(j * 3.0)), .9, Color(ROCK[2], .55 * a))
			for j in range(3):
				var u := Vector2.from_angle(spin * .4 + j * TAU / 3 + .4)
				f.stroke(p, p + u * s * .75, Color(hot, (.45 + .4 * sin(t * 6.0 + j)) * a), 1.4)
		# ================================================================ 04 outer Solar System
		"3_armored":
			# Alien dreadnought: an arrow hull plated in overlapping chevrons, a reactor spine with a
			# travelling pulse, two tracking turrets and three flickering engines.
			var hull := PackedVector2Array([p + dir * s * 1.55, p + dir * s * .55 + nrm * s * .55, p - dir * s * .2 + nrm * s * .45,
				p - dir * s * 1.1 + nrm * s * .72, p - dir * s * .9, p - dir * s * 1.1 - nrm * s * .72, p - dir * s * .2 - nrm * s * .45, p + dir * s * .55 - nrm * s * .55])
			poly(f, hull, a, METAL[0], line, 1.4)
			var plates: int = int(ceil(hp * 3.0))
			for k in range(3):
				if k >= plates:
					continue
				var x: float = .85 - k * .55
				var chevron := PackedVector2Array([p + dir * s * (x + .25), p + dir * s * (x - .1) + nrm * s * (.4 + k * .08), p + dir * s * (x - .25) + nrm * s * (.4 + k * .08),
					p + dir * s * (x + .05), p + dir * s * (x - .25) - nrm * s * (.4 + k * .08), p + dir * s * (x - .1) - nrm * s * (.4 + k * .08)])
				poly(f, chevron, a, METAL[1], METAL[2], 1.0)
			f.stroke(p - dir * s * .85, p + dir * s * 1.3, Color(ACCENT, .45 * a), 1.2)
			var pulse: float = fposmod(t * .9, 1.0)
			f.draw_circle(p - dir * s * .85 + dir * s * 2.15 * pulse, 2.0, Color(hot, (1.0 - pulse * .6) * a))
			for side in [1.0, -1.0]:
				var mount: Vector2 = p + nrm * s * .3 * side - dir * s * .05
				f.draw_circle(mount, s * .13, Color(METAL[1], a))
				f.draw_arc(mount, s * .13, 0, TAU, 10, Color(METAL[2], a), 1.0, true)
				f.stroke(mount, mount + Vector2.from_angle(heading + sin(t * 1.3 + side) * .5) * s * .38, Color(line, a), 1.4)
			for j in range(3):
				var eng: Vector2 = p - dir * s * 1.0 + nrm * s * (j - 1) * .3
				var flame: float = s * (.3 + .12 * sin(t * 24.0 + j * 2.0))
				f.draw_colored_polygon(PackedVector2Array([eng + nrm * s * .07, eng - nrm * s * .07, eng - dir * flame]), Color(ACCENT, .8 * a))
		# ================================================================ 05 Oort cloud
		"4_swarm":
			# Cometary nucleus: a frosted dark lump venting two flickering sublimation jets.
			shaded(f, p, s * .6, 7, spin, .25, sd, a, ICEY)
			f.draw_circle(p, s * 1.0, Color(ICEY[3], .05 * a))
			for j in range(2):
				var u := Vector2.from_angle(spin + j * 2.6 + 2.2)
				var len: float = s * (.6 + .3 * sin(t * 11.0 + j * 3.0))
				f.stroke(p + u * s * .5, p + u * (s * .5 + len), Color(ICEY[3], .55 * a))
				f.stroke(p + u * s * .5, p + u.rotated(.25) * (s * .5 + len * .7), Color(ICEY[3], .3 * a))
		"4_armored":
			# Giant ice core: faceted crystal with inner refraction, twinkling highlights and venting
			# jets; its fractures glow ice-blue as it breaks.
			var rim: PackedVector2Array = shaded(f, p, s, 9, spin * .15, .12, sd, a, ICEY)
			for j in range(0, 9, 2):
				f.stroke(p + LIGHT * s * .1, rim[j], Color(ICEY[2], .35 * a))
			poly(f, Base.ring_pts(p + LIGHT * s * .2, s * .32, 5, spin * .15 + .5), a, Color(ICEY[3], .22))
			for j in range(4):
				twinkle(f, p + Vector2.from_angle(sd + j * 1.7) * s * (.35 + .12 * j), s * .2, t * 2.5 + j * 2.3, a, ICEY[3])
			for side in [1.0, -1.0]:
				var vent: Vector2 = p + Vector2.from_angle(spin * .15 + side * 1.2) * s * .95
				var out: Vector2 = (vent - p).normalized()
				for k in range(3):
					var len: float = s * (.4 + .25 * fposmod(t * 2.0 + k * .33 + side, 1.0))
					f.stroke(vent, vent + out.rotated((k - 1) * .22) * len, Color(ICEY[3], (.5 - k * .1) * a))
			for j in range(int((1.0 - hp) * 6.0)):
				var u := Vector2.from_angle(sd + j * 1.1)
				f.stroke(p + u * s * .15, p + u.rotated(.2) * s * .9, Color(Color("7fd4ff"), .8 * a), 1.3)
		"4_splitter":
			# Ice-crystal cluster: a branched snowflake turning slowly, light running out along its arms.
			var rot: float = spin * .3
			for j in range(6):
				var u := Vector2.from_angle(rot + j * TAU / 6)
				f.stroke(p, p + u * s * 1.05, Color(ICEY[3], a), 1.8)
				for k in range(2):
					var at: Vector2 = p + u * s * (.4 + k * .3)
					var twig: float = s * (.32 - k * .1)
					f.stroke(at, at + u.rotated(.75) * twig, Color(ICEY[2], a), 1.1)
					f.stroke(at, at + u.rotated(-.75) * twig, Color(ICEY[2], a), 1.1)
				var run: float = fposmod(t * .8 + j * .17, 1.0)
				f.draw_circle(p + u * s * run, 1.4 * (1.0 - run) + .4, Color(Color.WHITE, a))
			poly(f, Base.ring_pts(p, s * .22, 6, rot), a, ICEY[1], ICEY[3], 1.0)
			for j in range(3):
				f.stroke(p, p + Vector2.from_angle(rot + j * TAU / 3 + PI / 6) * s * .75, Color(hot, (.5 + .35 * sin(t * 6.0 + j)) * a), 1.3)
		"4_shielded":
			# Ice-shell ship: a crisp hull inside a faceted translucent carapace, a glint sweeping it.
			var shell: PackedVector2Array = Base.ring_pts(p, s * 1.0, 8, heading + PI / 8)
			poly(f, shell, a, Color(ICEY[2], .12), Color(ICEY[3], .8), 1.1)
			for j in range(0, 8, 2):
				f.stroke(p, shell[j], Color(ICEY[3], .15 * a))
			poly(f, PackedVector2Array([p + dir * s * .62, p + nrm * s * .3 - dir * s * .1, p - dir * s * .5 + nrm * s * .22, p - dir * s * .5 - nrm * s * .22,
				p - nrm * s * .3 - dir * s * .1]), a, METAL[1], line, 1.1)
			f.draw_circle(p - dir * s * .5, 1.6, Color(hot, a))
			var g: float = fposmod(t * .5, 1.0) * 2.0 - 1.0
			if absf(g) < 1.0:
				var c0: Vector2 = p + nrm * s * g
				f.stroke(c0 - dir * s * .7, c0 + dir * s * .7, Color(Color.WHITE, (1.0 - absf(g)) * .5 * a), 1.4)
		"4_mother":
			# Comet nest: a vast pitted nucleus with burrows; jets vent, a wavy ion tail and a dust
			# tail stream behind, and a burrow flares before each brood bursts out.
			var tail := PackedVector2Array()
			for k in range(16):
				var u: float = k / 15.0
				tail.append(p - dir * s * (.8 + u * 3.6) + nrm * sin(u * 6.0 - t * 3.0) * s * .18 * u)
			f.draw_polyline(tail, Color(ICEY[3], .35 * a), 2.2, true)
			var dust := PackedVector2Array()
			for k in range(12):
				var u: float = k / 11.0
				dust.append(p - dir * s * (.8 + u * 2.8) + nrm * s * u * u * 1.4)
			f.draw_polyline(dust, Color(ACCENT, .25 * a), 3.0, true)
			shaded(f, p, s, 12, spin * .08, .15, sd, a, ICEY)
			for j in range(5):
				var q: Vector2 = p + Vector2.from_angle(spin * .08 + j * 1.25 + .7) * s * (.32 + .12 * (j % 3))
				var burst: bool = j == 0 and open > 0.0
				f.draw_circle(q, s * .1, Color(ICEY[0], a))
				f.draw_arc(q, s * .11, PI * .2, PI * 1.1, 8, Color(ICEY[3], .5 * a), 1.0, true)
				if burst:
					Base.glow(f, q, s * .3 * open, ACCENT, a)
					f.draw_arc(q, s * .12, 0, TAU, 10, Color(hot, a), 1.4, true)
			for side in [1.0, -1.0]:
				var vent: Vector2 = p + Vector2.from_angle(spin * .08 + side * 2.0) * s
				f.stroke(vent, vent + (vent - p).normalized() * s * (.45 + .2 * sin(t * 9.0 + side)), Color(ICEY[3], .45 * a), 1.4)
		# ================================================================ 06 stellar neighbourhood
		"5_swarm":
			# Plasma blob: a boiling outline round a white-hot core, tendrils licking off it.
			poly(f, wobble(p, s * .55, 18, .18, t * 2.0, sd), a, Color(WARM[2], .85))
			poly(f, wobble(p, s * .32, 14, .15, t * 3.0, sd + 2), a, WARM[3])
			for j in range(3):
				var u := Vector2.from_angle(spin * 2.0 + j * TAU / 3)
				var curl := PackedVector2Array()
				for k in range(6):
					var w: float = k / 5.0
					curl.append(p + u * s * (.5 + w * .55) + u.orthogonal() * sin(w * 4.0 + t * 8.0 + j) * s * .12)
				f.draw_polyline(curl, Color(WARM[2], .7 * a), 1.2, true)
		"5_dart":
			# Flare bolt: a magnetic loop of plasma with sparks flowing along it, bright at both feet.
			var loop := PackedVector2Array()
			for k in range(17):
				var u: float = k / 16.0
				loop.append(p - dir * s * (1.0 - u * 2.0) * .8 + nrm * sin(u * PI) * s * 1.0)
			f.draw_polyline(loop, Color(WARM[1], .6 * a), 4.0, true)
			f.draw_polyline(loop, Color(WARM[2], a), 2.0, true)
			f.draw_polyline(loop, Color(WARM[3], .8 * a), .8, true)
			for j in range(4):
				var u: float = fposmod(t * 1.6 + j * .25, 1.0)
				f.draw_circle(p - dir * s * (1.0 - u * 2.0) * .8 + nrm * sin(u * PI) * s * 1.0, 1.6, Color(Color.WHITE, a))
			for side in [1.0, -1.0]:
				Base.glow(f, p + dir * s * .8 * side, s * .35, ACCENT, a)
		"5_armored":
			# Brown dwarf: a banded failed star, bands drifting, a storm turning, a warm limb;
			# the bands go dull as it is stripped.
			f.draw_circle(p, s, Color(WARM[0], a))
			var bands: int = int(ceil(hp * 6.0))
			for k in range(6):
				var y: float = -.78 + k * .31 + .05 * sin(t * .4 + k)
				var half: float = sqrt(maxf(0.0, 1.0 - y * y))
				var band := PackedVector2Array()
				for q in range(13):
					var x: float = (q / 12.0 * 2.0 - 1.0) * half
					band.append(p + Vector2(x, y + .04 * sin(x * 3.0 + t * .8 + k)) * s)
				var lit: bool = k < bands
				f.draw_polyline(band, Color(WARM[2] if k % 2 == 0 else WARM[1], (.7 if lit else .2) * a), 2.4 if k % 2 == 0 else 1.6, true)
			var storm: Vector2 = p + Vector2(sin(t * .3 + sd) * .45, .25) * s
			f.draw_arc(storm, s * .16, t * 2.0, t * 2.0 + 4.5, 10, Color(WARM[3], .7 * a), 1.4, true)
			f.draw_arc(p, s, PI * .6, PI * 1.9, 30, Color(WARM[2], .7 * a), 1.6, true)
			f.draw_arc(p, s * .98, PI * 1.9, PI * 2.6, 14, Color(WARM[0], a), 3.0, true)
		"5_splitter":
			# Binary star: two suns circling, a stream of gas spiralling from one onto the other.
			var axis := Vector2.from_angle(t * 1.4 + sd)
			var big: Vector2 = p + axis * s * .42
			var small: Vector2 = p - axis * s * .55
			for j in range(8):
				var u: float = fposmod(t * 1.2 + j / 8.0, 1.0)
				var q: Vector2 = big.lerp(small, u) + axis.orthogonal() * sin(u * PI) * s * .35
				f.draw_circle(q, 1.4 * (1.0 - u * .5), Color(WARM[2], (.4 + .6 * (1.0 - u)) * a))
			for pair in [[big, .34, WARM[3]], [small, .22, STAR]]:
				var c0: Vector2 = pair[0]
				Base.glow(f, c0, s * float(pair[1]) * 2.2, ACCENT, a)
				f.draw_circle(c0, s * float(pair[1]), Color(pair[2], a))
				for k in range(4):
					var u := Vector2.from_angle(t * .8 + k * PI * .5)
					f.stroke(c0 + u * s * float(pair[1]), c0 + u * s * float(pair[1]) * 1.9, Color(WARM[2], .6 * a))
		"5_shielded":
			# Corona-shield ship: a hull behind a parasol; heat shimmer ripples off its face.
			poly(f, PackedVector2Array([p + dir * s * .25, p + nrm * s * .32 - dir * s * .2, p - dir * s * .95 + nrm * s * .18, p - dir * s * .95 - nrm * s * .18,
				p - nrm * s * .32 - dir * s * .2]), a, METAL[1], line, 1.1)
			f.draw_circle(p - dir * s * .9, 1.6, Color(hot, a))
			f.draw_arc(p + dir * s * .1, s * .95, heading - 1.1, heading + 1.1, 20, Color(METAL[3], a), 3.0, true)
			for k in range(3):
				var ph: float = fposmod(t * 1.3 + k / 3.0, 1.0)
				var wave := PackedVector2Array()
				for q in range(11):
					var u: float = (q / 10.0 - .5) * 1.8
					wave.append(p + dir * s * (1.1 + ph * .7) + Vector2.from_angle(heading + u) * 0.0 + nrm * s * u * .6 + dir * sin(u * 6.0 + t * 9.0) * s * .04)
				f.draw_polyline(wave, Color(ACCENT, (1.0 - ph) * .6 * a), 1.0, true)
		"5_mother":
			# Interstellar ark: a spine of three spinning habitat rings, lit windows, an engine plume.
			f.stroke(p + dir * s * 1.4, p - dir * s * 1.5, Color(METAL[2], a), 3.0)
			f.stroke(p + dir * s * 1.4, p - dir * s * 1.5, Color(METAL[1], a), 1.4)
			for k in range(3):
				var c0: Vector2 = p + dir * s * (.85 - k * .85)
				poly(f, Base.oval(c0, s * .24, s * .85, heading, 20), a, METAL[0], line, 1.3)
				for j in range(4):
					var sp: float = t * 1.5 + k + j * PI * .5
					f.stroke(c0, c0 + nrm * s * .82 * cos(sp) + dir * s * .22 * sin(sp), Color(METAL[2], .6 * a))
				for j in range(6):
					var w: float = j * TAU / 6 + t * 1.5
					f.draw_circle(c0 + nrm * s * .83 * cos(w) + dir * s * .23 * sin(w), 1.0, Color(ACCENT if (j + int(t)) % 3 == 0 else STAR, a))
			var bell: Vector2 = p - dir * s * 1.55
			poly(f, PackedVector2Array([bell + nrm * s * .18, bell - nrm * s * .18, bell - dir * s * .35 - nrm * s * .4, bell - dir * s * .35 + nrm * s * .4]), a, METAL[1], line, 1.1)
			var plume: float = s * (.7 + .15 * sin(t * 18.0))
			f.draw_colored_polygon(PackedVector2Array([bell - dir * s * .35 + nrm * s * .3, bell - dir * s * .35 - nrm * s * .3, bell - dir * (s * .35 + plume)]), Color(ACCENT, .55 * a))
			if open > 0.0:
				Base.glow(f, p + dir * s * 1.4, s * .5 * open, ACCENT, a)
		# ================================================================ 07 Milky Way
		"6_armored":
			# Neutron star: a dipole axis turning, field loops wheeling round it, a lighthouse flash
			# each time a pole sweeps past, crust plates that crack off.
			var spin_axis: float = t * 1.2 + sd
			var axis := Vector2.from_angle(spin_axis)
			var loops: int = int(ceil(hp * 3.0))
			for k in range(loops):
				var l: float = s * (.45 + k * .22)
				for side in [1.0, -1.0]:
					var arc := PackedVector2Array()
					for q in range(17):
						var th: float = .15 + (PI - .3) * q / 16.0
						var rr: float = l * 2.0 * sin(th) * sin(th)
						arc.append(p + axis * cos(th) * rr + axis.orthogonal() * sin(th) * rr * side)
					f.draw_polyline(arc, Color(ICEY[3], (.65 - k * .15) * a), 1.0, true)
			var beam: float = pow(absf(cos(spin_axis)), 30.0)
			for side in [1.0, -1.0]:
				f.stroke(p + axis * s * .25 * side, p + axis * s * (1.0 + 1.8 * beam) * side, Color(Color.WHITE, (.25 + .7 * beam) * a), 1.4 + beam * 2.0)
			Base.glow(f, p, s * (.45 + .2 * beam), ICEY[3], a)
			f.draw_circle(p, s * .2, Color(Color.WHITE, a))
		# ================================================================ 08 supercluster
		"7_swarm":
			# Dwarf galaxy: an irregular smudge of twinkling stars round a faint core.
			f.draw_colored_polygon(Base.oval(p, s * .7, s * .45, spin * .2 + sd, 14), Color(ICEY[3], .07 * a))
			for j in range(10):
				var q: Vector2 = p + Vector2.from_angle(sd * 1.3 + j * 2.4) * s * .62 * sqrt(fposmod(j * .37 + .1, 1.0)) * Vector2(1.0, .7)
				f.draw_circle(q, .8 + .6 * pow(.5 + .5 * sin(t * 4.0 + j * 1.9), 4.0), Color(Color.WHITE if j % 3 else ICEY[3], a))
			f.draw_circle(p, 1.5, Color(Color.WHITE, a))
		"7_dart":
			# Relativistic jet blob: a hot knot, precessing jets with blobs riding out along them.
			var jet := Vector2.from_angle(heading + PI * .5 + sin(t * 1.5) * .25)
			Base.glow(f, p, s * .6, ACCENT, a)
			f.draw_circle(p, s * .26, Color(WARM[3], a))
			for side in [1.0, -1.0]:
				f.stroke(p + jet * s * .3 * side, p + jet * s * 1.8 * side, Color(ACCENT, .55 * a), 1.2)
				for j in range(3):
					var u: float = fposmod(t * 1.8 + j / 3.0, 1.0)
					f.draw_circle(p + jet * s * (.35 + u * 1.45) * side, 1.8 * (1.0 - u) + .5, Color(WARM[3], (1.0 - u) * a))
		"7_armored":
			# Elliptical galaxy: smooth nested light with a scatter of twinkling stars; the outer
			# halo is stripped away as it is hit.
			var shells: int = int(ceil(hp * 4.0))
			for k in range(4):
				var r: float = 1.0 - k * .22
				var lit: bool = (3 - k) < shells
				f.draw_colored_polygon(Base.oval(p, s * r, s * r * .68, spin * .1, 24), Color(ICEY[3], (.05 + k * .04) * a * (1.0 if lit else .3)))
			for j in range(12):
				var q: Vector2 = p + Vector2.from_angle(sd + j * 2.4) * s * .85 * sqrt(fposmod(j * .41, 1.0)) * Vector2(1.0, .68).rotated(spin * .1)
				f.draw_circle(q, .7 + .7 * pow(.5 + .5 * sin(t * 3.0 + j * 2.2), 5.0), Color(Color.WHITE, .9 * a))
			Base.glow(f, p, s * .35, Color.WHITE, a)
			f.draw_circle(p, s * .1, Color(Color.WHITE, a))
		"7_splitter":
			# Merging galaxies: two spirals turning into each other, tidal tails flung out, a
			# glowing bridge where they touch.
			for side in [1.0, -1.0]:
				var c0: Vector2 = p + nrm * s * .42 * side
				for k in range(2):
					var arm := PackedVector2Array()
					for q in range(10):
						var u: float = q / 9.0
						arm.append(c0 + Vector2.from_angle(t * .6 * side + k * PI + u * 2.4) * s * (.08 + u * .42))
					f.draw_polyline(arm, Color(ICEY[3], .8 * a), 1.4, true)
				Base.glow(f, c0, s * .2, Color.WHITE, a)
				var tidal := PackedVector2Array()
				for q in range(10):
					var u: float = q / 9.0
					tidal.append(c0 + nrm * side * s * u * .9 + dir * side * s * u * u * .8)
				f.draw_polyline(tidal, Color(ICEY[2], .35 * a), 1.0, true)
			f.stroke(p - nrm * s * .22, p + nrm * s * .22, Color(hot, (.6 + .35 * sin(t * 6.0)) * a), 2.4)
		"7_mother":
			# Cluster core: a giant elliptical in a haze of hot gas, satellites wheeling round it;
			# one is flung out when it launches.
			var haze: float = fposmod(t * .4, 1.0)
			f.draw_arc(p, s * (1.0 + haze * .6), 0, TAU, 40, Color(ACCENT, (1.0 - haze) * .25 * a), 1.2, true)
			for k in range(4):
				var r: float = 1.0 - k * .22
				f.draw_colored_polygon(Base.oval(p, s * r, s * r * .78, spin * .08, 28), Color(ICEY[3], (.05 + k * .05) * a))
			Base.glow(f, p, s * .45, Color.WHITE, a)
			f.draw_circle(p, s * .12, Color(Color.WHITE, a))
			for k in range(6):
				var w: float = t * (.45 + k * .05) + k * TAU / 6
				var q: Vector2 = p + Vector2(cos(w) * s * 1.35, sin(w) * s * 1.05)
				f.draw_colored_polygon(Base.oval(q, s * .14, s * .08, w, 10), Color(ACCENT if k == 0 and open > 0.0 else ICEY[3], .8 * a))
		# ================================================================ 09 observable universe
		"8_swarm":
			# Quasar point: a pin of light in a faint host, diffraction spikes breathing.
			f.draw_circle(p, s * .5, Color(ICEY[3], .07 * a))
			var k: float = .6 + .4 * sin(t * 5.0 + sd)
			for j in range(4):
				var u := Vector2.from_angle(j * PI * .5 + PI * .25)
				f.stroke(p + u * 1.5, p + u * s * (.6 + .5 * k), Color(Color.WHITE, (.4 + .5 * k) * a))
			f.draw_circle(p, 1.8 + k * .6, Color(Color.WHITE, a))
		"8_dart":
			# Gamma-ray burst: twin beams pulsing hard, a shock ring rolling off the source.
			var pulse: float = pow(.5 + .5 * sin(t * 16.0), 2.0)
			for side in [1.0, -1.0]:
				poly(f, PackedVector2Array([p, p + dir * s * 1.6 * side + nrm * s * .32, p + dir * s * 1.6 * side - nrm * s * .32]), a, Color(ACCENT, .15 + .3 * pulse), Color(hot, .6 + .4 * pulse), 1.0)
				f.stroke(p, p + dir * s * 1.7 * side, Color(Color.WHITE, (.5 + .5 * pulse) * a), 1.2)
			var ring_k: float = fposmod(t * 1.2, 1.0)
			f.draw_arc(p, s * (.2 + ring_k * .8), 0, TAU, 20, Color(Color.WHITE, (1.0 - ring_k) * .6 * a), 1.0, true)
			f.draw_circle(p, 2.2, Color(Color.WHITE, a))
		"8_armored":
			# Great-wall segment: galaxy nodes on filaments, light pulses running between them;
			# nodes go dark as it is destroyed.
			var nodes: int = int(ceil(hp * 6.0))
			var pts: Array[Vector2] = []
			for k in range(6):
				pts.append(p + nrm * s * (k - 2.5) * .42 + dir * s * sin(k * 1.7 + sd) * .3)
			for k in range(5):
				f.stroke(pts[k], pts[k + 1], Color(ICEY[2], .5 * a), 1.2)
				var u: float = fposmod(t * .9 + k * .2, 1.0)
				f.draw_circle(pts[k].lerp(pts[k + 1], u), 1.3, Color(Color.WHITE, (1.0 - absf(u - .5) * 1.6) * a))
			for k in range(6):
				var lit: bool = k < nodes
				if lit:
					Base.glow(f, pts[k], s * .18, Color.WHITE, a)
				f.draw_circle(pts[k], 2.2, Color(Color.WHITE if lit else Base.DIM, a))
		"8_splitter":
			# Cosmic-web node: a knot turning slowly, filaments carrying light in, an amber seam.
			for j in range(4):
				var u := Vector2.from_angle(spin * .25 + j * TAU / 4 + .3)
				var far: Vector2 = p + u * s * 1.15
				f.stroke(p, far, Color(ICEY[2], .55 * a), 1.2)
				f.stroke(p + u * s * .6, p + u * s * .6 + u.rotated(.9) * s * .35, Color(ICEY[2], .35 * a))
				var run: float = fposmod(t * .7 + j * .25, 1.0)
				f.draw_circle(far.lerp(p, run), 1.4, Color(Color.WHITE, a))
				f.draw_circle(far, 1.4, Color(ICEY[3], a))
			Base.glow(f, p, s * .4, Color.WHITE, a)
			f.draw_circle(p, s * .22, Color(Color.WHITE, a))
			f.stroke(p - nrm * s * .45, p + nrm * s * .45, Color(hot, (.6 + .3 * sin(t * 6.0)) * a), 1.8)
		"8_mother":
			# Primordial black hole: gas spiralling down an accretion disc, a shimmering photon ring,
			# faint jets; the ring flares before it spits out a brood.
			for j in range(28):
				var u: float = fposmod(t * .35 + j / 28.0, 1.0)
				var r: float = s * (1.35 - u * .85)
				var w: float = j * 2.1 + u * 7.0 + t * .5
				f.draw_circle(p + Vector2(cos(w), sin(w) * .45) * r, 2.2 * (.4 + u), Color(ACCENT if j % 3 == 0 else ICEY[3], (.35 + .6 * u) * a))
			f.draw_colored_polygon(Base.oval(p, s * 1.25, s * .5, 0.0, 28), Color(ACCENT, .06 * a))
			f.draw_circle(p, s * .5, Color(Color.BLACK, a))
			var shimmer: float = .5 + .5 * sin(t * 7.0)
			f.draw_arc(p, s * .53, 0, TAU, 40, Color(Color.WHITE, (.7 + .3 * shimmer) * a), 1.4 + open * 2.0 + shimmer * .6, true)
			f.draw_arc(p, s * .62, PI * 1.05, PI * 1.95, 20, Color(ACCENT, .5 * a), 1.2, true)
		# ================================================================ 10 the brane
		"9_swarm":
			# Quantum foam: bubbles that keep inflating and popping, each pop a tiny spark ring.
			for k in range(5):
				var life: float = fposmod(t * .9 + k * .21 + sd * .07, 1.0)
				var q: Vector2 = p + Vector2.from_angle(k * 1.9 + sd) * s * (.25 + .35 * (k % 3))
				if life < .82:
					var r: float = s * .45 * (life / .82)
					f.draw_arc(q, r, 0, TAU, 14, Color(ICEY[3], (.4 + .5 * life) * a), 1.0, true)
					f.draw_arc(q, r, PI * 1.2, PI * 1.6, 5, Color(Color.WHITE, .8 * a), 1.2, true)
				else:
					var pop: float = (life - .82) / .18
					for j in range(6):
						var u := Vector2.from_angle(j * TAU / 6 + k)
						f.stroke(q + u * s * .45 * (1.0 + pop * .6), q + u * s * .45 * (1.2 + pop * .8), Color(ACCENT, (1.0 - pop) * a))
		"9_dart":
			# Tachyon: arrives before its own light - a needle with ghosts running AHEAD of it and a
			# Cherenkov cone opening forward.
			for k in range(4):
				var g: float = fposmod(t * 2.5 + k * .25, 1.0)
				var ghost: Vector2 = p + dir * s * (.8 + g * 2.2)
				f.stroke(ghost - dir * s * .5, ghost, Color(Color.WHITE, (1.0 - g) * .4 * a), 1.2)
			for side in [1.0, -1.0]:
				f.stroke(p + dir * s * .4, p + dir * s * 2.6 + nrm * s * .9 * side, Color(ICEY[3], .45 * a))
			f.stroke(p - dir * s * 1.0, p + dir * s * .5, Color(Color.WHITE, a), 1.8)
			Base.glow(f, p + dir * s * .5, s * .3, ACCENT, a)
			f.draw_circle(p + dir * s * .5, 1.8, Color(hot, a))
		"9_splitter":
			# Baby universe: a breathing membrane with its own web turning inside, a bud swelling
			# off its side on a glowing stalk.
			var skin: PackedVector2Array = wobble(p, s * .75, 22, .06, t * 1.5, sd)
			poly(f, skin, a, Base.DEEP, line, 1.3)
			var web: Array[Vector2] = []
			for k in range(6):
				web.append(p + Vector2.from_angle(t * .5 + k * 1.05 + sd) * s * (.2 + .3 * fposmod(k * .37, 1.0)))
			for k in range(6):
				f.stroke(web[k], web[(k + 2) % 6], Color(ICEY[2], .45 * a))
				f.draw_circle(web[k], 1.2, Color(Color.WHITE, a))
			var bloom: float = .75 + .25 * sin(t * 1.8)
			var bud: Vector2 = p + nrm * s * (.75 + .25 * bloom)
			f.stroke(p + nrm * s * .7, bud - nrm * s * .25 * bloom, Color(hot, (.6 + .3 * sin(t * 6.0)) * a), 1.8)
			poly(f, wobble(bud, s * .28 * bloom, 14, .08, t * 2.0, sd + 4), a, Base.DEEP, Color(line, .85), 1.0)
		"9_mother":
			# Rift to another universe: a living tear - its jagged edges crawl, it breathes, stars of
			# the other side drift inside, sparks peel off its burning lips; it gapes before a launch.
			var up: Vector2 = nrm
			var right := PackedVector2Array()
			var left := PackedVector2Array()
			var breathe: float = 1.0 + .12 * sin(t * 1.7) + .45 * open
			for k in range(13):
				var u: float = k / 12.0
				var along: Vector2 = p + up * s * (u * 2.6 - 1.3)
				var width: float = s * .62 * sin(u * PI) * breathe
				var zig_r: float = s * .1 * sin(k * 2.3 + t * 3.0 + sd)
				var zig_l: float = s * .1 * sin(k * 1.7 - t * 2.6 + sd * 2)
				right.append(along + dir * maxf(width + zig_r, s * .02))
				left.append(along - dir * maxf(width + zig_l, s * .02))
			var tear: PackedVector2Array = right.duplicate()
			var back: PackedVector2Array = left.duplicate()
			back.reverse()
			tear.append_array(back)
			for edge in [right, left]:
				f.draw_polyline(edge, Color(ACCENT, .12 * a), 12.0, true)
				f.draw_polyline(edge, Color(ACCENT, .25 * a), 5.0, true)
			f.draw_colored_polygon(tear, Color(Color.BLACK, a))
			for j in range(9):
				var u: float = fposmod(j * .37 + t * .08, 1.0)
				var q: Vector2 = p + up * s * (u * 2.0 - 1.0) + dir * s * .22 * sin(j * 2.1 + t * .6) * sin(u * PI)
				f.draw_circle(q, .9 + .6 * pow(.5 + .5 * sin(t * 4.0 + j), 4.0), Color(ICEY[3] if j % 2 else ACCENT, .85 * a))
			for edge in [right, left]:
				f.draw_polyline(edge, Color(hot, a), 1.8, true)
				f.draw_polyline(edge, Color(Color.WHITE, .7 * a), .7, true)
			for j in range(8):
				var k: float = fposmod(t * 1.3 + j * .125, 1.0)
				var src: Vector2 = (right if j % 2 == 0 else left)[2 + (j * 3) % 9]
				var out: Vector2 = (src - (p + up * up.dot(src - p))).normalized()
				f.draw_circle(src + out * s * .5 * k + up * s * .2 * k, 1.3 * (1.0 - k) + .3, Color(ACCENT, (1.0 - k) * a))
		_:
			return false
	return true
