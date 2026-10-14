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
			# Recon drone: a shaded teardrop hull between two ducted rotors, one amber sensor eye.
			var hull := PackedVector2Array([p + dir * s * .9, p + dir * s * .3 + nrm * s * .38, p - dir * s * .6 + nrm * s * .26, p - dir * s * .75,
				p - dir * s * .6 - nrm * s * .26, p + dir * s * .3 - nrm * s * .38])
			Fine.poly(f, hull, a, METAL[1], line, 1.2)
			Fine.poly(f, PackedVector2Array([p + dir * s * .6, p + dir * s * .2 + nrm * s * .2, p - dir * s * .4 + nrm * s * .12, p - dir * s * .1]), a, Color(METAL[2], .5))
			for side in [1.0, -1.0]:
				var duct: Vector2 = p - dir * s * .15 + nrm * s * .78 * side
				f.draw_circle(duct, s * .3, Color(METAL[0], a))
				f.draw_circle(duct, s * .26, Color(METAL[2], .3 * a))
				f.draw_arc(duct, s * .3, 0, TAU, 18, Color(line, a), 1.2, true)
				f.draw_arc(duct, s * .22, t * 26.0 * side, t * 26.0 * side + PI * .7, 8, Color(METAL[3], .5 * a), 1.6, true)
			var eye: Vector2 = p + dir * s * .52
			soft(f, eye, s * .4, ACCENT, a)
			f.draw_circle(eye, s * .1 * (1.0 + .25 * sin(t * 5.0)), Color(hot, a))
		# ================================================================ inner Solar System
		"2_armored":
			# Metal asteroid: a faceted polished body in three tones, a crisp rim light that slides
			# with its spin, a few glints; hits strip bright gouges.
			var rot: float = spin * .2
			var rim: PackedVector2Array = Fine.shaded(f, p, s, 11, rot, .08, sd, a, METAL)
			f.draw_arc(p, s * .96, rot + 3.5 + sin(t * .6) * .25, rot + 4.6 + sin(t * .6) * .25, 14, Color(METAL[3], .85 * a), 2.0, true)
			for j in range(3):
				var g: float = maxf(0.0, sin(t * 2.2 + j * 2.0))
				var q: Vector2 = p + Vector2.from_angle(rot + j * 2.1 + sd) * s * (.3 + .15 * j)
				soft(f, q, s * .25, Color.WHITE, a * g, 3)
				f.draw_circle(q, .8 + g, Color(METAL[3], (.4 + .6 * g) * a))
			for j in range(int((1.0 - hp) * 5.0)):
				var u := Vector2.from_angle(rot + j * 1.9 + sd)
				f.stroke(p + u * s * .35, p + u * s * .85, Color(METAL[3], .75 * a), 2.0)
		"2_splitter":
			# Rubble pile: four big shaded boulders held by one glowing amber core, a thin dust ring turning.
			for j in range(10):
				var w: float = t * .45 + j * TAU / 10
				f.draw_circle(p + Vector2(cos(w), sin(w) * .55).rotated(.3) * s * 1.05, 1.0, Color(ROCK[2], .5 * a))
			soft(f, p, s * .7, ACCENT, a)
			for j in range(4):
				var q: Vector2 = p + Vector2.from_angle(spin * .35 + j * TAU / 4) * s * .42 + Vector2(sin(t * 1.3 + j), cos(t * 1.1 + j)) * s * .025
				Fine.shaded(f, q, s * .4, 7, spin + j, .18, sd + j, a, ROCK, false)
			f.draw_circle(p, s * .1, Color(hot, (.7 + .3 * sin(t * 5.0)) * a))
		# ================================================================ Oort cloud
		"4_dart":
			# Long-tailed comet: a soft glowing head; a straight blue-white ion tail and a curved
			# warm dust tail, both tapering; motes shed into the tails.
			var ion := PackedVector2Array()
			var dust := PackedVector2Array()
			for k in range(12):
				var u: float = k / 11.0
				ion.append(p - dir * s * (u * 5.5) + nrm * sin(u * 4.0 - t * 3.0) * s * .06 * u)
				dust.append(p - dir * s * (u * 4.2) + nrm * s * u * u * 1.5)
			ribbon(f, dust, s * .9, s * .1, Color(ACCENT, .28), a)
			ribbon(f, ion, s * .55, s * .04, Color(GAS, .45), a)
			ribbon(f, ion, s * .2, s * .02, Color(Color.WHITE, .6), a)
			for j in range(5):
				var k: float = fposmod(t * .8 + j * .2, 1.0)
				f.draw_circle(p - dir * s * k * 4.5 + nrm * s * k * k * .9, 1.2 * (1.0 - k) + .3, Color(Color.WHITE, (1.0 - k) * a))
			soft(f, p, s * 1.1, GAS, a, 5)
			f.draw_circle(p, s * .26, Color(Color.WHITE, a))
		"4_mother":
			# Comet nest: a big shaded icy nucleus with three glowing burrows, one tapered ion tail
			# and a soft dust fan; a burrow blazes before each brood bursts out.
			var tail := PackedVector2Array()
			for k in range(12):
				var u: float = k / 11.0
				tail.append(p - dir * s * (.6 + u * 3.6) + nrm * sin(u * 4.0 - t * 2.2) * s * .12 * u)
			ribbon(f, tail, s * 1.3, s * .08, Color(GAS, .25), a)
			ribbon(f, tail, s * .5, s * .03, Color(Color.WHITE, .35), a)
			soft(f, p, s * 1.6, GAS, a, 4)
			Fine.shaded(f, p, s, 12, spin * .08, .13, sd, a, ICEY)
			for j in range(3):
				var q: Vector2 = p + Vector2.from_angle(spin * .08 + j * 2.1 + .7) * s * .45
				var burst: float = open if j == 0 else 0.0
				f.draw_circle(q, s * .13, Color(ICEY[0], a))
				soft(f, q, s * (.3 + .5 * burst), ACCENT, a * (.6 + .4 * burst))
				f.draw_circle(q, s * .06, Color(hot, (.5 + .5 * burst) * a))
		# ================================================================ stellar neighbourhood
		"5_dart":
			# Flare bolt: a magnetic loop as one tapered glowing ribbon (thick at the crown), plasma
			# beads flowing along it, both feet burning.
			var loop := PackedVector2Array()
			for k in range(17):
				var u: float = k / 16.0
				loop.append(p - dir * s * (1.0 - u * 2.0) * .8 + nrm * sin(u * PI) * s * 1.0)
			for half in [0, 1]:
				var seg := PackedVector2Array()
				for k in range(9):
					seg.append(loop[k + half * 8] if half == 0 else loop[16 - k])
				ribbon(f, seg, s * .12, s * .42, Color(WARM[2], .55), a)
				ribbon(f, seg, s * .05, s * .16, Color(WARM[3], .9), a)
			for j in range(5):
				var u: float = fposmod(t * 1.4 + j * .2, 1.0)
				var q: Vector2 = p - dir * s * (1.0 - u * 2.0) * .8 + nrm * sin(u * PI) * s * 1.0
				f.draw_circle(q, 1.5, Color(Color.WHITE, a))
			for side in [1.0, -1.0]:
				soft(f, p + dir * s * .8 * side, s * .45, ACCENT, a)
		"5_armored":
			# Brown dwarf: a softly shaded sphere crossed by broad muted bands that drift; a warm
			# limb on the lit side. Bands dull as it is stripped.
			var r: float = s
			sphere(f, p, r, WARM, a)
			var bands: int = int(ceil(hp * 4.0))
			for k in range(4):
				var y: float = -.6 + k * .4 + .04 * sin(t * .35 + k)
				var half: float = sqrt(maxf(0.0, 1.0 - y * y)) * .96
				var band := PackedVector2Array()
				for q in range(11):
					var x: float = (q / 10.0 * 2.0 - 1.0) * half
					band.append(p + Vector2(x, y + .03 * sin(x * 2.5 + t * .6 + k)) * r)
				var lit: bool = k < bands
				ribbon(f, band, r * .14, r * .14, Color(WARM[2] if k % 2 == 0 else WARM[1], (.45 if lit else .12)), a)
			f.draw_arc(p, r, PI * .65, PI * 1.85, 30, Color(WARM[3], .55 * a), 1.4, true)
			soft(f, p, r * 1.5, ACCENT, a * .5, 3)
		"5_mother":
			# Interstellar ark, simplified: one clean capsule hull, a single habitat ring turning
			# round its waist, one engine glow. Nothing else.
			var hull := PackedVector2Array()
			for k in range(20):
				var u: float = k * TAU / 20
				hull.append(p + dir * cos(u) * s * 1.45 + nrm * sin(u) * s * .32)
			Fine.poly(f, hull, a, METAL[1], line, 1.4)
			Fine.poly(f, Base.oval(p + nrm * s * -.08 + dir * s * .1, s * 1.2, s * .14, heading, 16), a, Color(METAL[2], .35))
			var ring := Base.oval(p, s * .22, s * .95, heading, 28)
			ring.append(ring[0])
			f.draw_polyline(ring, Color(line, a), 2.0, true)
			var bead: float = t * 1.6
			f.draw_circle(p + nrm * s * .95 * cos(bead) + dir * s * .22 * sin(bead), 2.0, Color(hot, a))
			var engine: Vector2 = p - dir * s * 1.5
			soft(f, engine, s * (.55 + .2 * open), ACCENT, a)
			f.draw_circle(engine, s * .12, Color(hot, a))
		# ================================================================ Milky Way
		"6_mother":
			# Galactic carrier: a shaded disc hull, two tapered glowing spiral arms turning, a core
			# that brightens before it launches.
			for k in range(2):
				var arm := PackedVector2Array()
				for q in range(12):
					var u: float = q / 11.0
					arm.append(p + Vector2.from_angle(t * .3 + k * PI + u * 2.7) * s * (.45 + u * 1.0))
				ribbon(f, arm, s * .32, s * .04, Color(GAS, .35), a)
				ribbon(f, arm, s * .12, s * .02, Color(Color.WHITE, .55), a)
			sphere(f, p, s * .55, METAL, a)
			f.draw_arc(p, s * .55, 0, TAU, 32, Color(line, a), 1.3, true)
			soft(f, p, s * (.5 + .35 * open), ACCENT, a)
			f.draw_circle(p, s * .13, Color(hot, a))
		# ================================================================ supercluster
		"7_splitter":
			# Merging galaxies: two soft galaxies, each with two tapered arms turning, joined by a
			# glowing bridge; tidal tails sweep out as tapered ribbons.
			for side in [1.0, -1.0]:
				var c0: Vector2 = p + nrm * s * .42 * side
				var tail := PackedVector2Array()
				for q in range(10):
					var u: float = q / 9.0
					tail.append(c0 + nrm * side * s * u * .95 + dir * side * s * u * u * .9)
				ribbon(f, tail, s * .2, s * .02, Color(GAS, .3), a)
				soft(f, c0, s * .6, GAS, a, 5)
				for k in range(2):
					var arm := PackedVector2Array()
					for q in range(9):
						var u: float = q / 8.0
						arm.append(c0 + Vector2.from_angle(t * .5 * side + k * PI + u * 2.5) * s * (.06 + u * .4))
					ribbon(f, arm, s * .28, s * .03, Color(GAS, .3), a)
					ribbon(f, arm, s * .12, s * .02, Color(Color.WHITE, .75), a)
				f.draw_circle(c0, s * .07, Color(Color.WHITE, a))
			ribbon(f, PackedVector2Array([p - nrm * s * .3, p, p + nrm * s * .3]), s * .05, s * .05, Color(hot, .7 + .3 * sin(t * 5.0)), a)
		"7_armored":
			# Elliptical galaxy: a smooth eight-step glow falling off from a bright core, a sprinkle
			# of twinkling stars; the outer light fades as it is stripped.
			var keep: float = .45 + .55 * hp
			for k in range(8):
				var r: float = (1.0 - k * .11) * keep + (1.0 - keep) * .3
				f.draw_colored_polygon(Base.oval(p, s * r, s * r * .66, spin * .08, 28), Color(GAS, (.035 + k * .018) * a))
			for j in range(10):
				var q: Vector2 = p + (Vector2.from_angle(sd + j * 2.4) * s * .8 * sqrt(fposmod(j * .41, 1.0)) * Vector2(1.0, .66)).rotated(spin * .08)
				f.draw_circle(q, .7 + .5 * maxf(0.0, sin(t * 2.4 + j * 2.1)), Color(Color.WHITE, (.35 + .5 * maxf(0.0, sin(t * 2.4 + j * 2.1))) * a))
			soft(f, p, s * .35, Color.WHITE, a)
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
			# Great-wall segment: one glowing filament (soft wide band + thin bright core) strung with
			# tiny galaxies; light pulses run along it. Galaxies go dark as it breaks.
			var spine := PackedVector2Array()
			for k in range(13):
				var u: float = k / 12.0
				spine.append(p + nrm * s * (u * 2.4 - 1.2) + dir * s * sin(u * 4.0 + sd) * .25)
			ribbon(f, spine, s * .35, s * .35, Color(GAS, .12), a)
			ribbon(f, spine, s * .07, s * .07, Color(GAS, .55), a)
			var nodes: int = int(ceil(hp * 5.0))
			for k in range(5):
				var q: Vector2 = spine[1 + k * 2 + (1 if k > 2 else 0)]
				var lit: bool = k < nodes
				if lit:
					soft(f, q, s * .22, Color.WHITE, a, 3)
				f.draw_colored_polygon(Base.oval(q, s * .09, s * .05, sd + k, 10), Color(Color.WHITE if lit else Base.DIM, a))
			var run: float = fposmod(t * .5, 1.0)
			f.draw_circle(spine[0].lerp(spine[12], run), 1.8, Color(hot, a))
		# ================================================================ the brane
		"9_dart":
			# Tachyon: a sharp glowing needle; a filled Cherenkov cone opens AHEAD of it, and its
			# own afterimages run out in front - it arrives before its light.
			var tip: Vector2 = p + dir * s * .7
			Fine.poly(f, PackedVector2Array([tip, tip + dir * s * 2.4 + nrm * s * .85, tip + dir * s * 2.4 - nrm * s * .85]), a, Color(GAS, .07))
			for side in [1.0, -1.0]:
				ribbon(f, PackedVector2Array([tip, tip + dir * s * 1.2 + nrm * s * .42 * side, tip + dir * s * 2.4 + nrm * s * .85 * side]), s * .06, s * .01, Color(GAS, .7), a)
			for k in range(3):
				var g: float = fposmod(t * 2.2 + k / 3.0, 1.0)
				var ghost: Vector2 = tip + dir * s * g * 2.0
				ribbon(f, PackedVector2Array([ghost - dir * s * .6, ghost]), s * .02, s * .1, Color(Color.WHITE, (1.0 - g) * .5), a)
			ribbon(f, PackedVector2Array([p - dir * s * 1.0, tip]), s * .02, s * .16, Color(Color.WHITE, 1.0), a)
			soft(f, tip, s * .45, ACCENT, a)
			f.draw_circle(tip, s * .07, Color(hot, a))
		_:
			return false
	return true
