extends RefCounted
# Round 3 art. What the developer liked (iron meteorite, contact-binary comet,
# interceptor V, plasma-shield ship) shares one recipe: a clean silhouette, layered
# tones, ONE amber accent, smooth glow or particle motion - never a tangle of hairlines.
# So here tails, jets and arms are tapered glowing ribbons, glows are layered and soft,
# and anything that read as clutter is gone.
const Base = preload("res://scripts/monster_art.gd")
const Fine = preload("res://scripts/monster_art_fine.gd")
const INK := Color("ededed")
const ACCENT := Color("ffc94d")
const LIGHT := Vector2(-.6, -.8)
const METAL := [Color("1a1a1a"), Color("3a3a3a"), Color("8e8e8e"), Color("f4f4f4")]
const ROCK := [Color("232323"), Color("4f4f4f"), Color("8c8c8c"), Color("d6d6d6")]
const ICEY := [Color("131c25"), Color("2c4253"), Color("86aac0"), Color("eef8ff")]
const WARM := [Color("2a190b"), Color("7d4a16"), Color("e6a640"), Color("fff1cc")]
const GAS := Color("cfe4f2")


static func ribbon(f: Node2D, pts: PackedVector2Array, w0: float, w1: float, col: Color, a: float) -> void:
	# A filled band that tapers from w0 to w1 along its points: tails, jets, arms.
	var n: int = pts.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(n):
		var prev: Vector2 = pts[maxi(0, i - 1)]
		var next: Vector2 = pts[mini(n - 1, i + 1)]
		var side: Vector2 = (next - prev).normalized().orthogonal()
		var w: float = lerpf(w0, w1, float(i) / (n - 1)) * .5
		left.append(pts[i] + side * w)
		right.append(pts[i] - side * w)
	right.reverse()
	left.append_array(right)
	f.draw_colored_polygon(left, Color(col, col.a * a))


static func soft(f: Node2D, c: Vector2, r: float, col: Color, a: float, layers: int = 4) -> void:
	# Layered glow: several faint discs stacking into a smooth falloff.
	for k in range(layers):
		var u: float = float(k + 1) / layers
		f.draw_circle(c, r * (1.0 - u * .75), Color(col, .07 * a * (1.0 + u)))


static func sphere(f: Node2D, c: Vector2, r: float, tones: Array, a: float) -> void:
	# Flat two-tone shading: a dark disc, a lit disc nudged toward the light, a highlight.
	f.draw_circle(c, r, Color(tones[0], a))
	f.draw_circle(c + LIGHT * r * .12, r * .86, Color(tones[1], a))
	f.draw_circle(c + LIGHT * r * .38, r * .34, Color(tones[2], .45 * a))


static func draw(f: Node2D, key: String, e: Dictionary, p: Vector2, s: float, heading: float, spin: float, a: float, flash: float, open: float) -> bool:
	var dir := Vector2.from_angle(heading)
	var nrm: Vector2 = dir.orthogonal()
	var t: float = f.clock
	var sd: int = int(e.seed)
	var hp: float = Base.health_of(e)
	var hot: Color = ACCENT.lerp(Color.WHITE, flash)
	var line: Color = INK.lerp(Color.WHITE, flash)
	match key:
		# ================================================================ Earth orbit
		"1_swarm":
			# Space junk: one clean broken solar-cell shard, tumbling, a glint riding its edge.
			var r: float = spin * 1.3
			var u := Vector2.from_angle(r)
			var v: Vector2 = u.orthogonal()
			var shard := PackedVector2Array([p - u * s * .75 - v * s * .42, p + u * s * .6 - v * s * .5, p + u * s * .7 + v * s * .2, p + u * s * .1 + v * s * .5, p - u * s * .6 + v * s * .38])
			Fine.poly(f, shard, a, Color("1b2633"), METAL[2], 1.1)
			f.stroke(p - u * s * .05 - v * s * .46, p + u * s * .02 + v * s * .45, Color(METAL[2], .55 * a))
			f.stroke(p - u * s * .68, p + u * s * .65, Color(METAL[2], .3 * a))
			var g: float = fposmod(t * .7 + sd * .1, 1.0)
			var edge: Vector2 = shard[1].lerp(shard[2], g)
			Base.glow(f, edge, s * .3, Color.WHITE, a * (1.0 - absf(g - .5) * 2.0))
		"1_dart":
			# Recon drone: a shaded teardrop hull hovering between two ducted rotors; it bobs and
			# banks, blades whirl as bright arcs over blurred discs, nav lights blink in turn and
			# its amber eye sends a radar ping forward every second and a half.
			var bank: float = sin(t * 1.7 + sd) * .35
			var c: Vector2 = p + nrm * sin(t * 2.3 + sd) * s * .08
			var hull := PackedVector2Array([c + dir * s * .9, c + dir * s * .3 + nrm * s * .38, c - dir * s * .6 + nrm * s * .26, c - dir * s * .75,
				c - dir * s * .6 - nrm * s * .26, c + dir * s * .3 - nrm * s * .38])
			Fine.poly(f, hull, a, METAL[1].lerp(Color.WHITE, flash * .5), line, 1.2)
			Fine.poly(f, PackedVector2Array([c + dir * s * .6, c + dir * s * .2 + nrm * s * .2, c - dir * s * .4 + nrm * s * .12, c - dir * s * .1]), a, Color(METAL[2], .5))
			for side in [1.0, -1.0]:
				var rr: float = s * .3 * (1.0 + bank * side)
				var duct: Vector2 = c - dir * s * .15 + nrm * s * .78 * side
				f.draw_circle(duct, rr, Color(METAL[0], a))
				f.draw_circle(duct, rr * .85, Color(METAL[2], .18 * a))
				for blade in range(2):
					var b0: float = t * 30.0 * side + blade * PI
					f.draw_arc(duct, rr * .72, b0, b0 + .9, 8, Color(METAL[3], .75 * a), 1.6, true)
				f.draw_arc(duct, rr, 0, TAU, 20, Color(line, a), 1.2, true)
				var nav: float = 1.0 if fposmod(t * 1.5 + (0.0 if side > 0.0 else .5), 1.0) < .15 else .25
				f.draw_circle(duct + nrm * side * rr, 1.2, Color(Color.WHITE if side > 0.0 else ACCENT, nav * a))
			var eye: Vector2 = c + dir * s * .52
			var ping: float = fposmod(t / 1.5 + sd * .1, 1.0)
			f.draw_arc(eye, s * (.2 + 2.2 * ping), heading - .9, heading + .9, 14, Color(ACCENT, (1.0 - ping) * .7 * a), 1.2, true)
			soft(f, eye, s * .4, ACCENT, a)
			f.draw_circle(eye, s * .1 * (1.0 + .25 * sin(t * 5.0)), Color(hot, a))
		# ================================================================ inner Solar System
		"2_armored":
			# Metal asteroid: a faceted polished body tumbling visibly; a specular flash sweeps across
			# its facets each half turn, glints wink, three chips orbit it (passing behind and in
			# front) and hits strip bright gouges.
			var rot: float = spin * .55
			for j in range(3):
				var w: float = t * (1.2 + j * .3) + j * 2.1 + sd
				if sin(w) < 0.0:
					f.draw_circle(p + Vector2(cos(w), sin(w) * .45).rotated(.5 + j) * s * (1.3 + j * .15), 1.1, Color(METAL[2], .55 * a))
			Fine.shaded(f, p, s, 11, rot, .08, sd, a, METAL)
			var spec: float = fposmod(rot / TAU * 2.0, 1.0)
			var band_x: float = (spec * 2.0 - 1.0) * .9
			var chord: float = sqrt(maxf(0.0, 1.0 - band_x * band_x)) * .85
			var ax: Vector2 = Vector2.from_angle(-.6)
			f.stroke(p + (ax * band_x + ax.orthogonal() * chord) * s, p + (ax * band_x - ax.orthogonal() * chord) * s, Color(Color.WHITE, .55 * sin(spec * PI) * a), 2.0)
			f.draw_arc(p, s * .96, rot + 3.5, rot + 4.6, 14, Color(METAL[3], .85 * a), 2.0, true)
			for j in range(3):
				var g: float = maxf(0.0, sin(t * 2.2 + j * 2.0))
				var q: Vector2 = p + Vector2.from_angle(rot + j * 2.1 + sd) * s * (.3 + .15 * j)
				soft(f, q, s * .25, Color.WHITE, a * g, 3)
				f.draw_circle(q, .8 + g, Color(METAL[3], (.4 + .6 * g) * a))
			for j in range(int((1.0 - hp) * 5.0)):
				var u := Vector2.from_angle(rot + j * 1.9 + sd)
				f.stroke(p + u * s * .35, p + u * s * .85, Color(METAL[3], .75 * a), 2.0)
			for j in range(3):
				var w: float = t * (1.2 + j * .3) + j * 2.1 + sd
				if sin(w) >= 0.0:
					f.draw_circle(p + Vector2(cos(w), sin(w) * .45).rotated(.5 + j) * s * (1.3 + j * .15), 1.4, Color(METAL[3], .9 * a))
		"2_splitter":
			# Rubble pile: four shaded boulders held by a glowing amber core; its light leaks out in
			# rays through the gaps, the boulders grind and jostle, and a dust ring circles.
			var turn: float = spin * .6
			for j in range(14):
				var w: float = t * .9 + j * TAU / 14
				f.draw_circle(p + Vector2(cos(w), sin(w) * .5).rotated(.3) * s * 1.1, .9 + .5 * maxf(0.0, sin(w)), Color(ROCK[2], (.35 + .4 * maxf(0.0, sin(w))) * a))
			var glow_k: float = .6 + .4 * sin(t * 3.0)
			soft(f, p, s * (.7 + .2 * glow_k), ACCENT, a)
			for j in range(4):
				var ray := Vector2.from_angle(turn + j * TAU / 4 + PI / 4)
				ribbon(f, PackedVector2Array([p, p + ray * s * .9, p + ray * s * (1.5 + .3 * glow_k)]), s * .2, s * .02, Color(ACCENT, .35 * glow_k), a)
			for j in range(4):
				var jostle := Vector2(sin(t * 2.6 + j * 1.7), cos(t * 2.2 + j * 2.3)) * s * .05
				Fine.shaded(f, p + Vector2.from_angle(turn + j * TAU / 4) * s * .42 + jostle, s * .4, 7, spin * .8 + j, .18, sd + j, a, ROCK, false)
			f.draw_circle(p, s * .1, Color(hot, (.6 + .4 * glow_k) * a))
		# ================================================================ Oort cloud
		"4_dart":
			# Long-tailed comet: a breathing coma round a white nucleus; the blue ion tail ripples
			# and every so often a bright knot breaks off and races down it; the curved dust tail sways
			# and motes stream into both.
			var ion := PackedVector2Array()
			var dust := PackedVector2Array()
			for k in range(14):
				var u: float = k / 13.0
				ion.append(p - dir * s * (u * 5.8) + nrm * sin(u * 5.0 - t * 4.0) * s * .18 * u)
				dust.append(p - dir * s * (u * 4.4) + nrm * s * u * u * 1.5 + nrm * sin(u * 3.0 - t * 1.5) * s * .08 * u)
			ribbon(f, dust, s * .9, s * .1, Color(ACCENT, .28), a)
			ribbon(f, ion, s * .6, s * .04, Color(GAS, .45), a)
			ribbon(f, ion, s * .22, s * .02, Color(Color.WHITE, .6), a)
			var g0: float = fposmod(t * .6 + sd * .1, 1.0)
			var knot: Vector2 = p - dir * s * g0 * 5.8 + nrm * sin(g0 * 5.0 - t * 4.0) * s * .18 * g0
			soft(f, knot, s * .5 * (1.0 - g0), Color.WHITE, a, 3)
			f.draw_circle(knot, 1.6 * (1.0 - g0) + .4, Color(Color.WHITE, (1.0 - g0) * a))
			for j in range(10):
				var k: float = fposmod(t * .9 + j * .1, 1.0)
				f.draw_circle(p - dir * s * k * 4.6 + nrm * s * k * k * (.9 if j % 2 else 0.1), 1.2 * (1.0 - k) + .3, Color(Color.WHITE if j % 2 == 0 else WARM[3], (1.0 - k) * a))
			soft(f, p, s * (1.1 + .15 * sin(t * 3.0)), GAS, a, 5)
			f.draw_circle(p, s * .26, Color(Color.WHITE, a))
		"4_mother":
			# Comet nest: a big shaded icy nucleus turning, with three glowing burrows that vent gas
			# jets; larvae crawl over the surface into the burrows, the ion tail ripples and a burrow
			# blazes before each brood bursts out.
			var turn: float = spin * .25
			var tail := PackedVector2Array()
			for k in range(12):
				var u: float = k / 11.0
				tail.append(p - dir * s * (.6 + u * 3.6) + nrm * sin(u * 4.0 - t * 3.0) * s * .18 * u)
			ribbon(f, tail, s * 1.3, s * .08, Color(GAS, .25), a)
			ribbon(f, tail, s * .5, s * .03, Color(Color.WHITE, .35), a)
			soft(f, p, s * (1.6 + .1 * sin(t * 2.0)), GAS, a, 4)
			Fine.shaded(f, p, s, 12, turn, .13, sd, a, ICEY)
			for j in range(3):
				var ang: float = turn + j * 2.1 + .7
				var q: Vector2 = p + Vector2.from_angle(ang) * s * .45
				var burst: float = open if j == 0 else 0.0
				var out := Vector2.from_angle(ang)
				for k in range(4):
					var g: float = fposmod(t * 1.4 + k * .25 + j * .4, 1.0)
					f.draw_circle(q + out.rotated(sin(k * 2.0 + j) * .3) * s * (.2 + g * (.9 + .8 * burst)), (1.0 - g) * 1.3 + .2, Color(ICEY[3], (1.0 - g) * .7 * a))
				f.draw_circle(q, s * .13, Color(ICEY[0], a))
				soft(f, q, s * (.3 + .5 * burst + .08 * sin(t * 3.0 + j)), ACCENT, a * (.6 + .4 * burst))
				f.draw_circle(q, s * .06, Color(hot, (.5 + .5 * burst) * a))
			for j in range(5):
				var crawl: float = fposmod(t * .25 + j * .2, 1.0)
				var home: float = turn + (j % 3) * 2.1 + .7
				var start: float = home + 1.6
				var at: float = lerpf(start, home, crawl)
				var rad: float = s * lerpf(.85, .45, crawl * crawl)
				f.draw_circle(p + Vector2.from_angle(at) * rad, 1.1, Color(ACCENT, (1.0 - crawl * .6) * a))
		# ================================================================ stellar neighbourhood
		"5_dart":
			# Flare bolt: a white-hot plasma knot dragging two magnetic strands that braid round
			# each other as it flies; sparks peel off the braid, and every few seconds the knot
			# flares and throws off a ring.
			var phase: float = fposmod(t * .45 + sd * .13, 1.0)
			var flare: float = 1.0 - smoothstep(0.0, .3, phase)
			soft(f, p - dir * s * .9, s * 1.5, ACCENT, a * .7, 4)
			for strand in range(2):
				var braid := PackedVector2Array()
				for k in range(16):
					var u: float = k / 15.0
					var ph: float = u * 9.0 - t * 15.0 + strand * PI
					braid.append(p - dir * s * (.1 + u * 3.6) + nrm * sin(ph) * s * .4 * (.3 + .7 * u) * (1.0 - .35 * u))
				ribbon(f, braid, s * .3, s * .03, Color(WARM[2], .5), a)
				ribbon(f, braid, s * .11, s * .015, Color(WARM[3], .95), a)
			for j in range(8):
				var g: float = fposmod(t * 1.5 + j * .125 + sd * .1, 1.0)
				var side: float = sin(j * 2.7 + sd)
				var spark: Vector2 = p - dir * s * (.5 + g * 3.8) + nrm * s * side * (.15 + g * 1.2)
				f.draw_circle(spark, (1.0 - g) * 1.5 + .3, Color(Color.WHITE if j % 2 else WARM[3], (1.0 - g) * a))
			if phase < .3:
				var k: float = phase / .3
				f.draw_arc(p, s * (.5 + 2.2 * k), 0, TAU, 28, Color(WARM[3], (1.0 - k) * .8 * a), 1.0 + 1.5 * (1.0 - k), true)
			soft(f, p, s * (1.0 + .7 * flare), ACCENT, a, 5)
			var drop := PackedVector2Array()
			for k in range(14):
				var u: float = k * TAU / 14
				var r: float = s * .34 * (1.0 + .5 * maxf(0.0, -cos(u)))
				drop.append(p + dir * cos(u) * r * (1.25 if cos(u) < 0.0 else .9) + nrm * sin(u) * s * .3)
			f.draw_colored_polygon(drop, Color(WARM[3].lerp(Color.WHITE, flash), a))
			f.draw_circle(p + dir * s * .08, s * (.17 + .1 * flare), Color(Color.WHITE, a))
		"5_armored":
			# Brown dwarf: a lit sphere whose bands are clipped exactly to the globe and bend with
			# latitude; they drift at different speeds, a storm crosses the face foreshortened,
			# the night side is cut by a soft terminator and aurorae flicker at the pole.
			var r: float = s
			var tilt: float = -.35
			var ax := Vector2.from_angle(tilt)
			var ay: Vector2 = ax.orthogonal()
			soft(f, p, r * 1.6, ACCENT, a * .6, 4)
			var moon_w: float = t * .9 + sd
			var moon: Vector2 = p + Vector2(cos(moon_w) * r * 1.55, sin(moon_w) * r * .45).rotated(tilt)
			if sin(moon_w) < 0.0:
				sphere(f, moon, r * .13, ROCK, a * .8)
			f.draw_circle(p, r, Color(WARM[1].lerp(Color.WHITE, flash * .4), a))
			var edges: Array = [-.92, -.62, -.34, -.08, .2, .46, .72, .94]
			var live_bands: int = int(ceil(hp * 7.0))
			for k in range(7):
				var y0: float = edges[k]
				var y1: float = edges[k + 1]
				var band := PackedVector2Array()
				var x0: float = sqrt(maxf(0.0, 1.0 - y0 * y0))
				var x1: float = sqrt(maxf(0.0, 1.0 - y1 * y1))
				for i in range(13):
					var x: float = lerpf(-x0, x0, i / 12.0)
					var y: float = y0 + .05 * sin(x * 5.0 + t * (1.4 + .5 * k) + k) * (1.0 - x * x)
					band.append(p + (ax * x + ay * y) * r)
				var a0: float = atan2(y0, x0)
				var a1: float = atan2(y1, x1)
				for i in range(1, 4):
					var th: float = lerpf(a0, a1, i / 4.0)
					band.append(p + (ax * cos(th) + ay * sin(th)) * r)
				for i in range(13):
					var x: float = lerpf(x1, -x1, i / 12.0)
					var y: float = y1 + .05 * sin(x * 5.0 + t * (1.4 + .5 * (k + 1)) + k + 1) * (1.0 - x * x)
					band.append(p + (ax * x + ay * y) * r)
				for i in range(1, 4):
					var th: float = lerpf(PI - a1, PI - a0, i / 4.0)
					band.append(p + (ax * cos(th) + ay * sin(th)) * r)
				var tone: Color = [WARM[2], WARM[1], Color("c07a2a"), WARM[0], WARM[2], Color("a3621f"), WARM[1]][k]
				f.draw_colored_polygon(band, Color(tone.lerp(Color.WHITE, flash * .5), (.75 if k < live_bands else .3) * a))
			for j in range(6):
				var lane: int = [1, 2, 3, 4, 5, 2][j]
				var yc: float = (edges[lane] + edges[lane + 1]) * .5
				var ex: float = fposmod(t * (.16 + .05 * j) + j * .37 + sd * .1, 1.0) * 2.4 - 1.2
				var limit: float = sqrt(maxf(0.0, 1.0 - yc * yc)) * .92
				if absf(ex) < limit:
					var fade: float = 1.0 - pow(absf(ex) / limit, 4.0)
					var squeeze2: float = sqrt(maxf(0.0, 1.0 - (ex / maxf(limit, .01)) * (ex / maxf(limit, .01))))
					var ec: Vector2 = p + (ax * ex + ay * yc) * r
					f.draw_colored_polygon(Base.oval(ec, r * .1 * squeeze2 + .5, r * .045, tilt, 10), Color(WARM[3] if j % 2 else WARM[0], .55 * fade * a))
			var storm_x: float = fposmod(t * .22 + sd * .3, 1.4) * 2.0 - 1.4
			if absf(storm_x) < .9:
				var squeeze: float = sqrt(1.0 - storm_x * storm_x)
				f.draw_colored_polygon(Base.oval(p + (ax * storm_x + ay * .33) * r, r * .16 * squeeze, r * .09, tilt, 14), Color(WARM[3], .6 * a))
				f.draw_colored_polygon(Base.oval(p + (ax * storm_x + ay * .33) * r, r * .07 * squeeze, r * .04, tilt, 10), Color(WARM[1], .7 * a))
			var lit_dir: Vector2 = LIGHT.normalized()
			var lx: Vector2 = lit_dir
			var ly: Vector2 = lit_dir.orthogonal()
			var night := PackedVector2Array()
			for i in range(17):
				var th: float = PI * .5 + PI * i / 16.0
				night.append(p + (lx * cos(th) + ly * sin(th)) * r)
			for i in range(17):
				var th: float = -PI * .5 + PI * i / 16.0
				night.append(p + (lx * -.35 * cos(th) + ly * sin(th)) * r)
			f.draw_colored_polygon(night, Color(0, 0, 0, .5 * a))
			var lit_angle: float = lit_dir.angle()
			f.draw_arc(p, r * .97, lit_angle - 1.1, lit_angle + 1.1, 24, Color(WARM[3], .7 * a), 1.6, true)
			if sin(moon_w) >= 0.0:
				sphere(f, moon, r * .13, ROCK, a)
			for j in range(3):
				var flick: float = .5 + .5 * sin(t * (5.0 + j) + j * 2.0)
				var pole: Vector2 = p - ay * r * .92
				f.draw_arc(pole, r * (.28 + j * .07), tilt + PI + .5, tilt + TAU - .5, 14, Color(WARM[3], .6 * flick * a), 1.2, true)
		"5_mother":
			# Interstellar ark: a long two-tone spindle hull; a habitat ring turns round its waist
			# with its far half passing behind the hull and lit windows sliding round; running
			# lights chase bow-ward, the bow beacon blinks, the plasma plume flickers, and the
			# hangar slit glows before a launch.
			var lit_side: float = 1.0 if nrm.dot(LIGHT) > 0.0 else -1.0
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for k in range(17):
				var u: float = k / 16.0
				var x: float = lerpf(-1.25, 1.6, u)
				var w: float = s * .3 * pow(sin(PI * clampf(u * .9 + .1, 0.0, 1.0)), .6)
				top.append(p + dir * x * s + nrm * w * lit_side)
				bottom.append(p + dir * x * s - nrm * w * lit_side)
			var nozzle: Vector2 = p - dir * s * 1.3
			var flick: float = .85 + .15 * sin(t * 23.0) + .1 * sin(t * 37.0)
			soft(f, nozzle, s * (.7 + .2 * flick), ACCENT, a, 4)
			for layer in range(2):
				var flame := PackedVector2Array()
				var flame_back := PackedVector2Array()
				var reach: float = s * (1.5 + .5 * open) * flick * (1.0 if layer == 0 else .6)
				for k in range(10):
					var u: float = k / 9.0
					var w: float = s * (.26 if layer == 0 else .12) * pow(sin(PI * (.18 + .82 * u)), .8) * (1.0 - .25 * u) * (1.0 + .12 * sin(t * 19.0 + u * 6.0))
					var c: Vector2 = nozzle - dir * reach * u
					flame.append(c + nrm * w)
					flame_back.append(c - nrm * w)
				flame_back.reverse()
				flame.append_array(flame_back)
				f.draw_colored_polygon(flame, Color(ACCENT, .28 * a) if layer == 0 else Color(ACCENT.lerp(Color.WHITE, .7), .6 * a))
			for j in range(4):
				var g: float = fposmod(t * 2.6 + j * .25, 1.0)
				f.draw_circle(nozzle - dir * s * g * 1.6 * flick + nrm * s * .08 * sin(t * 9.0 + j * 2.0), (1.0 - g) * 1.6 + .3, Color(ACCENT.lerp(Color.WHITE, 1.0 - g), (1.0 - g) * .8 * a))
			var ring_c: Vector2 = p - dir * s * .1
			var rx: float = s * .2
			var ry: float = s * .95
			var ring_w: float = maxf(2.0, s * .1)
			var turn: float = t * .7
			var back := PackedVector2Array()
			var front := PackedVector2Array()
			for k in range(25):
				var th: float = -PI * .5 + PI * k / 24.0
				back.append(ring_c + dir * cos(th) * rx + nrm * sin(th) * ry)
				front.append(ring_c - dir * cos(th) * rx + nrm * sin(th) * ry)
			f.draw_polyline(back, Color(METAL[1], a), ring_w, true)
			for j in range(12):
				var th: float = turn + j * TAU / 12
				if cos(th) > 0.0:
					f.draw_circle(ring_c + dir * cos(th) * rx + nrm * sin(th) * ry, ring_w * .22, Color(ACCENT, .35 * a))
			var hull := top.duplicate()
			var under: PackedVector2Array = bottom.duplicate()
			under.reverse()
			hull.append_array(under)
			f.draw_colored_polygon(hull, Color(METAL[1].lerp(Color.WHITE, flash * .5), a))
			var upper := top.duplicate()
			for k in range(16, -1, -1):
				upper.append(p + dir * lerpf(-1.25, 1.6, k / 16.0) * s)
			f.draw_colored_polygon(upper, Color(METAL[2], .45 * a))
			f.draw_polyline(top, Color(METAL[3].lerp(Color.WHITE, flash), .8 * a), 1.2, true)
			f.draw_polyline(bottom, Color(METAL[0], a), 1.0, true)
			for k in range(3):
				var x: float = -.7 + k * .55
				f.stroke(p + dir * s * x + nrm * s * .26, p + dir * s * x - nrm * s * .26, Color(METAL[0], .7 * a), 1.0)
			var slit: Vector2 = p + dir * s * .55 - nrm * lit_side * s * .12
			f.stroke(slit - dir * s * .25, slit + dir * s * .25, Color(ACCENT.lerp(Color.WHITE, open), (.25 + .75 * open) * a), 1.0 + 2.0 * open)
			if open > 0.0:
				soft(f, slit, s * .5 * open, ACCENT, a, 3)
			f.draw_polyline(front, Color(METAL[2].lerp(Color.WHITE, flash), a), ring_w, true)
			f.draw_polyline(front, Color(METAL[3], .5 * a), ring_w * .35, true)
			for j in range(12):
				var th: float = turn + j * TAU / 12
				if cos(th) <= 0.0:
					f.draw_circle(ring_c + dir * cos(th) * rx + nrm * sin(th) * ry, ring_w * .28, Color(ACCENT.lerp(Color.WHITE, .4), a))
			for k in range(5):
				var chase: float = pow(maxf(0.0, cos(t * 4.0 - k * .9)), 8.0)
				f.draw_circle(p + dir * s * (-.9 + k * .5) + nrm * lit_side * s * .2, 1.0 + chase, Color(Color.WHITE, (.25 + .75 * chase) * a))
			var beacon: float = 1.0 if fposmod(t + sd * .1, 1.2) < .12 else 0.0
			f.draw_circle(p + dir * s * 1.62, 1.4 + 1.6 * beacon, Color(Color.WHITE, (.4 + .6 * beacon) * a))
			if beacon > 0.0:
				soft(f, p + dir * s * 1.62, s * .5, Color.WHITE, a, 3)
		# ================================================================ Milky Way
		"6_mother":
			# Galactic carrier: star-specks stream inward along two spiral arms and vanish into the
			# core; two segmented hull rings turn against each other; the core breathes, and before
			# a launch the ring gaps blaze and a cross-flare opens.
			for k in range(2):
				var lane := PackedVector2Array()
				for q in range(14):
					var u: float = q / 13.0
					lane.append(p + Vector2.from_angle(t * .25 + k * PI + u * 3.0) * s * (.5 + u * 1.15))
				ribbon(f, lane, s * .4, s * .05, Color(GAS, .14), a)
			for j in range(40):
				var arm: int = j % 2
				var u: float = 1.0 - fposmod(t * .18 + j * .0491 + sd * .07, 1.0)
				var ang: float = t * .25 + arm * PI + u * 3.0 + .25 * sin(j * 1.7)
				var dot: Vector2 = p + Vector2.from_angle(ang) * s * (.5 + u * 1.15)
				var tw: float = .5 + .5 * sin(t * 6.0 + j * 2.3)
				f.draw_circle(dot, .6 + .9 * u * tw, Color(Color.WHITE if j % 3 else GAS, minf(1.0, u * 3.0) * (.4 + .6 * tw) * a))
			soft(f, p, s * (.9 + .25 * sin(t * 2.0) + .5 * open), ACCENT, a, 5)
			sphere(f, p, s * .62, METAL, a)
			for ring_i in range(2):
				var rr: float = s * (.62 if ring_i == 0 else .44)
				var segs: int = 3 if ring_i == 0 else 4
				var rot: float = t * (.6 if ring_i == 0 else -.9) + sd
				for g in range(segs):
					var a0: float = rot + g * TAU / segs
					var a1: float = a0 + TAU / segs - .35
					f.draw_arc(p, rr, a0, a1, 12, Color(METAL[3].lerp(Color.WHITE, flash), (.75 - ring_i * .2) * a), maxf(1.5, s * .07), true)
					var gap: Vector2 = p + Vector2.from_angle(a1 + .175) * rr
					f.draw_circle(gap, maxf(1.0, s * .05) * (1.0 + open), Color(ACCENT.lerp(Color.WHITE, open), (.4 + .6 * open) * a))
			var beat: float = .5 + .5 * sin(t * 3.0)
			f.draw_circle(p, s * (.16 + .04 * beat + .06 * open), Color(ACCENT.lerp(Color.WHITE, .5 + .5 * open), a))
			if open > .05:
				for g in range(4):
					var u := Vector2.from_angle(t * .5 + g * PI * .5)
					ribbon(f, PackedVector2Array([p, p + u * s * .8 * open, p + u * s * 1.4 * open]), s * .12, s * .01, Color(Color.WHITE, .8 * open), a)
		"6_shielded":
			# Magnetosphere ship: a shaded arrowhead probe behind a glowing bow shock; stellar-wind
			# specks stream in, swerve round the shock and slide down the swept-back field lines,
			# which ripple backward along their length.
			var shock := PackedVector2Array()
			for k in range(17):
				var y: float = lerpf(-1.3, 1.3, k / 16.0)
				shock.append(p + dir * s * (.95 - y * y * .55) + nrm * s * y)
			ribbon(f, shock, s * .05, s * .05, Color(GAS, .25), a)
			f.draw_polyline(shock, Color(GAS, (.45 + .2 * sin(t * 4.0)) * a), 1.2, true)
			for side in [1.0, -1.0]:
				for k in range(2):
					var line_pts := PackedVector2Array()
					for q in range(12):
						var u: float = q / 11.0
						var wave: float = sin(u * 7.0 - t * 5.0 + k * 1.5) * s * .06 * u
						line_pts.append(p + dir * s * (.7 - u * 2.6) + nrm * side * (s * (.45 + k * .3) * sin(u * PI * .5 + .45) + wave))
					ribbon(f, line_pts, s * .08, s * .015, Color(GAS, .55 - k * .2), a)
			for j in range(14):
				var g: float = fposmod(t * .7 + j * .0714 + sd * .05, 1.0)
				var b: float = (fposmod(j * .618, 1.0) * 2.0 - 1.0) * s * 1.2
				var x: float = s * (2.4 - g * 5.0)
				var wall: float = s * (.95 - (b / s) * (b / s) * .55)
				var push: float = clampf((wall + s * .2 - x) / (s * 1.2), 0.0, 1.0)
				var y: float = b + signf(b if absf(b) > .01 else 1.0) * push * s * .45
				f.draw_circle(p + dir * x + nrm * y, .8, Color(Color.WHITE, (.25 + .6 * (1.0 - absf(g * 2.0 - 1.0))) * a))
			var probe := PackedVector2Array([p + dir * s * .6, p - dir * s * .4 + nrm * s * .32, p - dir * s * .22, p - dir * s * .4 - nrm * s * .32])
			Fine.poly(f, probe, a, METAL[1].lerp(Color.WHITE, flash * .5), line, 1.1)
			Fine.poly(f, PackedVector2Array([p + dir * s * .6, p - dir * s * .4 + nrm * s * .32, p - dir * s * .22]), a, Color(METAL[2], .5))
			soft(f, p - dir * s * .35, s * (.35 + .1 * sin(t * 9.0)), GAS, a, 3)
			f.draw_circle(p + dir * s * .2, s * .07, Color(hot, (.6 + .4 * sin(t * 4.0)) * a))
		"6_armored":
			# Neutron star: a tiny blinding core in layered glow; two lighthouse cones sweep round,
			# the whole star flashes as a beam crosses the line of sight and sends out a pulse ring;
			# faint field loops turn with the axis, and the cracked crust sheds sparks as it weakens.
			var spin_axis: float = t * 1.6 + sd
			var axis := Vector2.from_angle(spin_axis)
			var beam: float = pow(absf(cos(spin_axis * 1.0 - heading)), 24.0)
			var pulse_phase: float = fposmod((spin_axis - heading) / PI, 1.0)
			f.draw_arc(p, s * (.4 + 2.2 * pulse_phase), 0, TAU, 32, Color(ICEY[3], (1.0 - pulse_phase) * .45 * a), 1.2, true)
			for k in range(2):
				var l: float = s * (.5 + k * .25)
				for side in [1.0, -1.0]:
					var arc := PackedVector2Array()
					for q in range(15):
						var th: float = .2 + (PI - .4) * q / 14.0
						var rr: float = l * 2.0 * sin(th) * sin(th)
						arc.append(p + axis * cos(th) * rr + axis.orthogonal() * sin(th) * rr * side)
					f.draw_polyline(arc, Color(ICEY[2], (.3 - k * .1) * a), 1.0, true)
			for side in [1.0, -1.0]:
				var tip: Vector2 = p + axis * s * 2.4 * side
				for layer in range(3):
					var spread: float = [.6, .36, .16][layer]
					var cone := PackedVector2Array([p + axis * s * .12 * side, tip + axis.orthogonal() * s * spread, tip - axis.orthogonal() * s * spread])
					f.draw_colored_polygon(cone, Color(ICEY[3].lerp(Color.WHITE, layer * .5), ([.06, .1, .2][layer] + .2 * beam) * a))
				var drift: float = fposmod(t * 1.8, 1.0)
				f.draw_circle(p + axis * s * (.3 + 2.0 * drift) * side, 1.0 + (1.0 - drift), Color(Color.WHITE, (1.0 - drift) * a))
			soft(f, p, s * (.8 + .9 * beam), ICEY[3], a, 5)
			f.draw_circle(p, s * (.2 + .06 * beam), Color(Color.WHITE, a))
			var cracks: int = int((1.0 - hp) * 6.0)
			for j in range(cracks):
				var g: float = fposmod(t * 1.2 + j * .17, 1.0)
				var u := Vector2.from_angle(sd + j * 1.9 + t * .3)
				f.draw_circle(p + u * s * (.25 + g * 1.2), (1.0 - g) * 1.3, Color(ACCENT, (1.0 - g) * a))
		# ================================================================ supercluster
		"7_splitter":
			# Merging galaxies: two galaxies circle each other with their arms turning; a glowing
			# bridge links the cores and stars stream out along the trailing tidal tails.
			var orbit: float = heading + PI * .5 + t * .35
			var cores: Array = []
			for side in [1.0, -1.0]:
				var c0: Vector2 = p + Vector2.from_angle(orbit) * side * s * .42
				cores.append(c0)
				var tail := PackedVector2Array()
				for q in range(10):
					var u: float = q / 9.0
					tail.append(p + Vector2.from_angle(orbit - u * 1.4) * side * s * (.42 + u * 1.0))
				ribbon(f, tail, s * .22, s * .02, Color(GAS, .3), a)
				for j in range(4):
					var g: float = fposmod(t * .4 + j * .25, 1.0)
					f.draw_circle(p + Vector2.from_angle(orbit - g * 1.4) * side * s * (.42 + g * 1.0), 1.1 * (1.0 - g) + .3, Color(Color.WHITE, (1.0 - g) * a))
				soft(f, c0, s * .6, GAS, a, 5)
				for k in range(2):
					var arm := PackedVector2Array()
					for q in range(9):
						var u: float = q / 8.0
						arm.append(c0 + Vector2.from_angle(t * .8 * side + k * PI + u * 2.5) * s * (.06 + u * .4))
					ribbon(f, arm, s * .28, s * .03, Color(GAS, .3), a)
					ribbon(f, arm, s * .12, s * .02, Color(Color.WHITE, .75), a)
				f.draw_circle(c0, s * .07, Color(Color.WHITE, a))
			var mid: Vector2 = p + Vector2.from_angle(orbit + PI * .5) * s * .12 * sin(t)
			ribbon(f, PackedVector2Array([cores[0], mid, cores[1]]), s * .06, s * .06, Color(hot, .55 + .35 * sin(t * 5.0)), a)
		"7_armored":
			# Elliptical galaxy: a smooth eight-step glow that slowly breathes, with stars wheeling
			# on their own elliptical orbits (some each way) and twinkling as they go; the outer light
			# fades as it is stripped.
			var keep: float = .45 + .55 * hp
			var breath: float = 1.0 + .06 * sin(t * 1.5 + sd)
			for k in range(8):
				var r: float = ((1.0 - k * .11) * keep + (1.0 - keep) * .3) * breath
				f.draw_colored_polygon(Base.oval(p, s * r, s * r * .66, spin * .08, 28), Color(GAS, (.035 + k * .018) * a))
			for j in range(14):
				var w: float = t * (.6 + .5 * fposmod(j * .37, 1.0)) * (1.0 if j % 2 else -1.0) + j * 2.4 + sd
				var rr: float = s * (.25 + .6 * fposmod(j * .61, 1.0)) * keep
				var tw: float = maxf(0.0, sin(t * 3.0 + j))
				f.draw_circle(p + Vector2(cos(w) * rr, sin(w) * rr * .66).rotated(spin * .08), .7 + .5 * tw, Color(Color.WHITE, (.4 + .5 * tw) * a))
			soft(f, p, s * .35 * breath, Color.WHITE, a)
			f.draw_circle(p, s * .08, Color(Color.WHITE, a))
		"7_shielded":
			# Dark-matter halo: invisible itself - background stars around it are bent into short
			# arcs, a faint lensing ring, a small bright galaxy at the centre.
			soft(f, p, s * 1.1, GAS, a * .4, 3)
			for k in range(7):
				var w: float = sd + k * TAU / 7 + t * .15
				var rr: float = s * (.75 + .25 * fposmod(k * .37, 1.0))
				f.draw_arc(p, rr, w, w + .22 + .1 * sin(t + k), 6, Color(Color.WHITE, .75 * a), 1.4, true)
			f.draw_arc(p, s * 1.0, 0, TAU, 40, Color(GAS, (.25 + .1 * sin(t * 2.0)) * a), 1.0, true)
			f.draw_colored_polygon(Base.oval(p, s * .3, s * .16, spin * .3, 14), Color(GAS, .5 * a))
			f.draw_circle(p, s * .06, Color(Color.WHITE, a))
		# ================================================================ observable universe
		"8_armored":
			# Great-wall segment: one glowing filament that undulates as a wave runs along it, strung
			# with tiny galaxies that light up in sequence; light pulses race both ways along it.
			# Galaxies go dark as it breaks.
			var spine := PackedVector2Array()
			for k in range(13):
				var u: float = k / 12.0
				spine.append(p + nrm * s * (u * 2.4 - 1.2) + dir * s * sin(u * 4.0 + sd + t * 1.3) * .25)
			ribbon(f, spine, s * .35, s * .35, Color(GAS, .12), a)
			ribbon(f, spine, s * .07, s * .07, Color(GAS, .55), a)
			var nodes: int = int(ceil(hp * 5.0))
			for k in range(5):
				var q: Vector2 = spine[1 + k * 2 + (1 if k > 2 else 0)]
				if k < nodes:
					var seq: float = pow(maxf(0.0, cos(t * 2.0 - k * 1.2)), 6.0)
					soft(f, q, s * (.22 + .2 * seq), Color.WHITE, a, 3)
					f.draw_colored_polygon(Base.oval(q, s * .09, s * .05, sd + k + t * .5, 10), Color(Color.WHITE, a))
				else:
					f.draw_colored_polygon(Base.oval(q, s * .09, s * .05, sd + k, 10), Color(Base.DIM, a))
			for j in range(4):
				var run: float = fposmod(t * (.45 + .1 * j) + j * .25, 1.0)
				if j % 2:
					run = 1.0 - run
				var i: int = mini(11, int(run * 12.0))
				var q2: Vector2 = spine[i].lerp(spine[i + 1], run * 12.0 - i)
				soft(f, q2, s * .2, ACCENT if j % 2 else Color.WHITE, a, 3)
				f.draw_circle(q2, 1.6, Color(hot if j % 2 else Color.WHITE, a))
		# ================================================================ the brane
		"9_dart":
			# Tachyon: a sharp glowing needle that stutters forward in tiny jumps; a filled Cherenkov
			# cone opens AHEAD of it with light running out along its edges, its own afterimages race
			# in front and sparks burst from the tip - it arrives before its light.
			var stutter: float = floor(fposmod(t * 6.0, 3.0)) * .08
			var tip: Vector2 = p + dir * s * (.7 + stutter)
			Fine.poly(f, PackedVector2Array([tip, tip + dir * s * 2.4 + nrm * s * .85, tip + dir * s * 2.4 - nrm * s * .85]), a, Color(GAS, .07))
			for side in [1.0, -1.0]:
				var edge_end: Vector2 = tip + dir * s * 2.4 + nrm * s * .85 * side
				ribbon(f, PackedVector2Array([tip, tip.lerp(edge_end, .5), edge_end]), s * .06, s * .01, Color(GAS, .7), a)
				for j in range(2):
					var g: float = fposmod(t * 2.0 + j * .5 + (0.0 if side > 0.0 else .25), 1.0)
					f.draw_circle(tip.lerp(edge_end, g), 1.4 * (1.0 - g) + .3, Color(Color.WHITE, (1.0 - g) * a))
			for k in range(3):
				var g: float = fposmod(t * 2.2 + k / 3.0, 1.0)
				var ghost: Vector2 = tip + dir * s * g * 2.0
				ribbon(f, PackedVector2Array([ghost - dir * s * .6, ghost]), s * .02, s * .1, Color(Color.WHITE, (1.0 - g) * .5), a)
			ribbon(f, PackedVector2Array([p - dir * s * 1.0, tip]), s * .02, s * .16, Color(Color.WHITE, 1.0), a)
			for j in range(4):
				var g: float = fposmod(t * 3.0 + j * .25, 1.0)
				f.draw_circle(tip + Vector2.from_angle(heading + PI + (j - 1.5) * .5) * s * g * .8, (1.0 - g) * 1.2, Color(ACCENT, (1.0 - g) * a))
			soft(f, tip, s * .45, ACCENT, a)
			f.draw_circle(tip, s * .07, Color(hot, a))
		"1_armored":
			# Dead satellite (round-2 art) tumbling faster; its dish still beams weak signal rings
			# and loose gold foil flutters off as it drifts.
			var tumble: float = spin * 2.5
			Fine.draw(f, key, e, p, s, heading, tumble, a, flash, open)
			var r2: float = tumble * .22
			var v: Vector2 = Vector2.from_angle(r2).orthogonal()
			var dish: Vector2 = p + v * s * .74
			for j in range(3):
				var g: float = fposmod(t * .8 + j / 3.0, 1.0)
				f.draw_arc(dish + v * s * .1, s * (.2 + g * 1.2), r2 + PI * .5 - .6, r2 + PI * .5 + .6, 10, Color(METAL[3], (1.0 - g) * .5 * a), 1.0, true)
			for j in range(3):
				var g: float = fposmod(t * .45 + j * .33 + sd * .1, 1.0)
				var flake: Vector2 = p + Vector2.from_angle(sd + j * 2.1 + g * 1.5) * s * (.5 + g * 1.6)
				var fr: Vector2 = Vector2.from_angle(t * 6.0 + j) * 1.6
				f.draw_line(flake - fr, flake + fr, Color(Color("c9a24a"), (1.0 - g) * a), 1.2, true)
		"2_dart":
			# Alien interceptor: forward-swept wings that roll as it weaves (each foreshortens in
			# turn), a shaded fuselage, twin engines flickering and shedding sparks, and a sensor slit
			# whose light runs across the nose.
			var roll: float = cos(t * 2.6 + sd)
			var span: float = s * (.65 + .35 * absf(roll))
			var nose: Vector2 = p + dir * s * 1.3
			for side in [1.0, -1.0]:
				var tip: Vector2 = p - dir * s * .9 + nrm * span * side * 1.05
				var wing := PackedVector2Array([p + dir * s * .15 + nrm * s * .2 * side, tip, p - dir * s * .62 + nrm * span * side * .8, p - dir * s * .4 + nrm * s * .15 * side])
				Fine.poly(f, wing, a, (METAL[2] if roll * side > 0.0 else METAL[1]).lerp(Color.WHITE, flash * .5), line, 1.0)
				f.draw_circle(tip, 1.1, Color(ACCENT, (.5 + .5 * sin(t * 6.0 + side)) * a))
			var fuselage := PackedVector2Array([nose, p + dir * s * .2 + nrm * s * .22, p - dir * s * .7 + nrm * s * .16, p - dir * s * .7 - nrm * s * .16, p + dir * s * .2 - nrm * s * .22])
			Fine.poly(f, fuselage, a, METAL[1].lerp(Color.WHITE, flash * .5), line, 1.2)
			Fine.poly(f, PackedVector2Array([nose, p + dir * s * .2 + nrm * s * .22, p - dir * s * .7 + nrm * s * .16, p - dir * s * .2]), a, Color(METAL[2], .45))
			var slit: float = sin(t * 3.5) * .16
			f.stroke(p + dir * s * .8 + nrm * s * (slit - .05), p + dir * s * .8 + nrm * s * (slit + .05), Color(hot, a), 2.0)
			for side in [1.0, -1.0]:
				var eng: Vector2 = p - dir * s * .72 + nrm * s * .1 * side
				var flame: float = s * (.45 + .2 * sin(t * 27.0 + side * 2.0))
				f.draw_colored_polygon(PackedVector2Array([eng + nrm * s * .07, eng - nrm * s * .07, eng - dir * flame]), Color(ACCENT, .85 * a))
				soft(f, eng, s * .3, ACCENT, a, 3)
				for j in range(3):
					var g: float = fposmod(t * 3.0 + j * .33 + side, 1.0)
					f.draw_circle(eng - dir * s * (.3 + g * 1.4) + nrm * s * .1 * sin(j * 3.0 + t * 5.0), (1.0 - g) * 1.1 + .2, Color(ACCENT.lerp(Color.WHITE, 1.0 - g), (1.0 - g) * a))
		"3_dart":
			# Interceptor formation: three shaded arrowheads holding a V; each weaves on its own beat,
			# engines flicker behind short contrails and the formation lights blink down the line.
			for j in range(3):
				var wing_side: float = 0.0 if j == 0 else (1.0 if j == 1 else -1.0)
				var weave: float = sin(t * 3.2 + j * 2.1 + sd)
				var slot: Vector2 = Vector2.ZERO if j == 0 else (-dir * s * .85 + nrm * s * .85 * wing_side)
				var q: Vector2 = p + slot + nrm * weave * s * .12 + dir * cos(t * 2.4 + j) * s * .08
				var hd: Vector2 = dir.rotated(weave * .12)
				var hn: Vector2 = hd.orthogonal()
				ribbon(f, PackedVector2Array([q - hd * s * .2, q - hd * s * .7 - hn * weave * s * .05, q - hd * s * 1.3 - hn * weave * s * .15]), s * .12, s * .01, Color(INK, .35), a)
				var arrow := PackedVector2Array([q + hd * s * .6, q - hd * s * .35 + hn * s * .36, q - hd * s * .15, q - hd * s * .35 - hn * s * .36])
				Fine.poly(f, arrow, a, METAL[1].lerp(Color.WHITE, flash * .5), line, 1.0)
				Fine.poly(f, PackedVector2Array([q + hd * s * .6, q - hd * s * .35 + hn * s * .36, q - hd * s * .15]), a, Color(METAL[2], .5))
				var flame: float = s * (.22 + .1 * sin(t * 25.0 + j * 2.0))
				f.draw_colored_polygon(PackedVector2Array([q - hd * s * .2 + hn * s * .06, q - hd * s * .2 - hn * s * .06, q - hd * (s * .2 + flame)]), Color(ACCENT, .9 * a))
				var blink: float = 1.0 if fposmod(t * 1.2 - j * .15, 1.0) < .1 else .2
				f.draw_circle(q + hd * s * .15, 1.0, Color(Color.WHITE, blink * a))
		"3_splitter":
			# Contact-binary comet (round-1 lobes): the two icy lobes tumble round their glowing neck,
			# the coma breathes, gas jets spray off both lobes and dust drifts away behind.
			var tumble: float = heading + t * .7 + sd
			soft(f, p, s * (1.4 + .12 * sin(t * 1.8)), GAS, a * .6, 4)
			Base.draw(f, key, e, p, s, tumble, spin, a, flash, open)
			var neck: float = .5 + .5 * sin(t * 4.0)
			soft(f, p, s * (.35 + .2 * neck), ACCENT, a, 3)
			for side in [1.0, -1.0]:
				var lobe: Vector2 = p + Vector2.from_angle(tumble).orthogonal() * s * .42 * side
				var out: Vector2 = (lobe - p).normalized().rotated(.4 * side)
				for j in range(4):
					var g: float = fposmod(t * 1.6 + j * .25 + side * .3, 1.0)
					f.draw_circle(lobe + out * s * (.4 + g * 1.0) + out.orthogonal() * s * .15 * sin(j * 2.0 + t * 3.0), (1.0 - g) * 1.2 + .3, Color(ICEY[3], (1.0 - g) * .8 * a))
			for j in range(5):
				var g: float = fposmod(t * .5 + j * .2, 1.0)
				f.draw_circle(p - dir * s * (.6 + g * 2.4) + nrm * s * .3 * sin(j * 1.9), .9, Color(GAS, (1.0 - g) * .6 * a))
		"3_armored":
			# Alien dreadnought (round-2 hull) brought to life: a scan of light sweeps the plating
			# nose to tail, the turrets fire short tracers in turn and the engines shed plasma.
			Fine.draw(f, key, e, p, s, heading, spin, a, flash, open)
			var sweep: float = fposmod(t * .6 + sd * .1, 1.4)
			if sweep < 1.0:
				var x: float = 1.5 - sweep * 2.6
				f.stroke(p + dir * s * x + nrm * s * .62, p + dir * s * x - nrm * s * .62, Color(Color.WHITE, .5 * sin(sweep * PI) * a), 1.5)
			for side in [1.0, -1.0]:
				var shot: float = fposmod(t * .8 + (0.0 if side > 0.0 else .5), 1.0)
				if shot < .25:
					var mount: Vector2 = p + nrm * s * .3 * side - dir * s * .05
					var aim := Vector2.from_angle(heading + sin(t * 1.3 + side) * .5)
					var k: float = shot / .25
					f.stroke(mount + aim * s * (.4 + k * 2.0), mount + aim * s * (.7 + k * 2.4), Color(ACCENT.lerp(Color.WHITE, .5), (1.0 - k) * a), 1.4)
					if k < .3:
						f.draw_circle(mount + aim * s * .4, 2.0 * (1.0 - k / .3), Color(Color.WHITE, a))
			for j in range(3):
				var g: float = fposmod(t * 2.5 + j * .33, 1.0)
				f.draw_circle(p - dir * s * (1.35 + g * 1.0) + nrm * s * (j - 1) * .3, (1.0 - g) * 1.3, Color(ACCENT, (1.0 - g) * .8 * a))
		"4_armored":
			# Giant ice core (round-2 crystal) turning faster, a refracted ray wheeling through it, its
			# vents spraying ice and frost sparkles orbiting (bright where they pass in front).
			var turn: float = spin * 2.6
			soft(f, p, s * 1.4, ICEY[3], a * .5, 3)
			Fine.draw(f, key, e, p, s, heading, turn, a, flash, open)
			var ray := Vector2.from_angle(t * 1.4 + sd)
			f.stroke(p - ray * s * .75, p + ray * s * .75, Color(ICEY[3], .4 * a), 1.4)
			f.draw_circle(p + ray * s * .75 * sin(t * 2.8), 1.6, Color(Color.WHITE, a))
			for side in [1.0, -1.0]:
				var vent: Vector2 = p + Vector2.from_angle(turn * .15 + side * 1.2) * s * .95
				var out: Vector2 = (vent - p).normalized()
				for j in range(5):
					var g: float = fposmod(t * 1.8 + j * .2 + side * .37, 1.0)
					f.draw_circle(vent + out.rotated(sin(j * 2.3) * .35) * s * g * 1.3, (1.0 - g) * 1.4 + .2, Color(ICEY[3], (1.0 - g) * .8 * a))
			for j in range(6):
				var w: float = t * .9 + j * TAU / 6
				var front: float = maxf(0.0, sin(w))
				f.draw_circle(p + Vector2(cos(w), sin(w) * .5).rotated(.4) * s * 1.25, .5 + .9 * front, Color(Color.WHITE, (.3 + .6 * front) * a))
		"8_swarm":
			# Quasar point: a pin of light whose brightness wanders, twin jets pulsing out of it,
			# slowly turning diffraction spikes and a faint host galaxy.
			var vary: float = .6 + .25 * sin(t * 5.0 + sd) + .15 * sin(t * 13.0 + sd * 2.0)
			f.draw_colored_polygon(Base.oval(p, s * .55, s * .35, sd, 14), Color(GAS, .07 * a))
			var jet := Vector2.from_angle(sd * .7)
			for side in [1.0, -1.0]:
				ribbon(f, PackedVector2Array([p, p + jet * s * .6 * side, p + jet * s * 1.2 * side]), s * .1, s * .01, Color(GAS, .5), a)
				var g: float = fposmod(t * 1.5 + (0.0 if side > 0.0 else .5), 1.0)
				f.draw_circle(p + jet * s * 1.2 * g * side, 1.2 * (1.0 - g) + .3, Color(Color.WHITE, (1.0 - g) * a))
			for j in range(4):
				var u := Vector2.from_angle(j * PI * .5 + PI * .25 + t * .3)
				f.draw_line(p + u * 1.5, p + u * s * (.3 + .35 * vary), Color(Color.WHITE, (.2 + .4 * vary) * a), 1.0, true)
			soft(f, p, s * .4 * vary, Color.WHITE, a, 3)
			f.draw_circle(p, 1.1 + .6 * vary, Color(Color.WHITE, a))
		_:
			return false
	return true
