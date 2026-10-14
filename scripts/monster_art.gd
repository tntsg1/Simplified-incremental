extends RefCounted
# Every threat in the campaign drawn as its own thing (key "<stage>_<arch>").
# The archetype keeps one small behaviour cue on top - the shield ring, a crust
# that breaks away, amber seams, a speed streak, a glowing mouth before a launch -
# but the body is designed per name: debris looks like debris, a rift like a tear.
const INK := Color("ededed")
const GREY := Color("b4b4b4")
const DIM := Color("6a6a6a")
const ACCENT := Color("ffc94d")
const DEEP := Color("161616")
const ICE := Color("cfe4f2")


static func body(f: Node2D, pts: PackedVector2Array, a: float, line: Color = INK, fill: Color = DEEP, w: float = 1.3) -> void:
	if pts.size() < 3:
		return
	f.draw_colored_polygon(pts, Color(fill, fill.a * a))
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	f.draw_polyline(loop, Color(line, line.a * a), w, true)


static func ring_pts(c: Vector2, r: float, n: int, rot: float = 0.0, jitter: float = 0.0, seed: int = 0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var k: float = 1.0 + (jitter * sin(i * 2.7 + seed * .37) if jitter > 0.0 else 0.0)
		out.append(c + Vector2.from_angle(rot + i * TAU / n) * r * k)
	return out


static func oval(c: Vector2, rx: float, ry: float, rot: float, n: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a: float = i * TAU / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func star_pts(c: Vector2, r_out: float, r_in: float, n: int, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n * 2):
		out.append(c + Vector2.from_angle(rot + i * PI / n) * (r_out if i % 2 == 0 else r_in))
	return out


static func glow(f: Node2D, c: Vector2, r: float, col: Color, a: float) -> void:
	f.draw_circle(c, r, Color(col, .12 * a))
	f.draw_circle(c, r * .55, Color(col, .22 * a))


static func health_of(e: Dictionary) -> float:
	if int(e.initial_members) > 1:
		return clampf(float(e.members) / float(e.initial_members), 0.0, 1.0)
	return clampf(float(e.hp) / maxf(1.0, float(e.unit_hp)), 0.0, 1.0)


# Returns false when the key has no bespoke art (the generic archetype body is used).
static func draw(f: Node2D, key: String, e: Dictionary, p: Vector2, s: float, heading: float, spin: float, a: float, flash: float, open: float) -> bool:
	var dir := Vector2.from_angle(heading)
	var nrm: Vector2 = dir.orthogonal()
	var t: float = f.clock
	var sd: int = int(e.seed)
	var hp: float = health_of(e)
	var line: Color = INK.lerp(Color.WHITE, flash)
	var hot: Color = ACCENT.lerp(Color.WHITE, flash)
	match key:
		# ---------------------------------------------------------------- 01 city
		"0_swarm":
			# Meteor chip: a jagged grey shard trailing a short ember streak.
			body(f, ring_pts(p, s * .7, 5, spin, .35, sd), a, GREY, Color(GREY, .9))
			f.stroke(p - dir * s * .5, p - dir * s * 2.4, Color(ACCENT, .55 * a))
		"0_armored":
			# Iron meteorite: dense facets pitted with thumbprint dimples, its leading face glowing.
			var rim: PackedVector2Array = ring_pts(p, s, 9, spin * .3, .14, sd)
			body(f, rim, a, GREY)
			for j in range(int(ceil(hp * 5.0))):
				var q: Vector2 = p + Vector2.from_angle(spin * .3 + j * 1.9 + sd) * s * (.3 + .12 * (j % 3))
				f.draw_arc(q, s * (.13 + .04 * (j % 2)), 0, TAU, 12, Color(GREY, .7 * a), 1.0, true)
			f.draw_arc(p, s * 1.02, heading - .9, heading + .9, 16, Color(hot, .85 * a), 2.0, true)
		# ---------------------------------------------------------------- 02 Earth orbit
		"1_swarm":
			# Space junk: a tumbling bent bracket with a bolt.
			var r: float = spin * 1.6
			var u := Vector2.from_angle(r)
			var v: Vector2 = u.orthogonal()
			body(f, PackedVector2Array([p - u * s * .8 - v * s * .25, p + u * s * .5 - v * s * .25, p + u * s * .5 + v * s * .7, p + u * s * .25 + v * s * .7,
				p + u * s * .25 + v * s * .05, p - u * s * .8 + v * s * .05]), a, line, DEEP, 1.1)
			f.draw_circle(p + u * s * .38, 1.4, Color(ACCENT, a))
		"1_dart":
			# Recon drone: a lens body between two rotor arms, its eye tracking forward.
			body(f, oval(p, s * .55, s * .35, heading, 12), a, line)
			for side in [1.0, -1.0]:
				var arm: Vector2 = p + nrm * s * .9 * side
				f.stroke(p + nrm * s * .3 * side, arm, Color(line, a))
				f.draw_arc(arm, s * .35, t * 18.0 * side, t * 18.0 * side + 2.4, 8, Color(line, .7 * a), 1.0, true)
			f.draw_circle(p + dir * s * .35, 2.0, Color(hot, a))
		"1_armored":
			# Dead satellite: a boxy bus with two gridded solar wings; cells fall off as it breaks.
			var r2: float = spin * .25
			var u := Vector2.from_angle(r2)
			var v: Vector2 = u.orthogonal()
			body(f, PackedVector2Array([p - u * s * .35 - v * s * .35, p + u * s * .35 - v * s * .35, p + u * s * .35 + v * s * .35, p - u * s * .35 + v * s * .35]), a, line)
			var cells: int = int(ceil(hp * 8.0))
			for side in [1.0, -1.0]:
				for k in range(4):
					if (k + (0 if side > 0 else 4)) >= cells:
						continue
					var c0: Vector2 = p + u * side * s * (.48 + k * .32)
					body(f, PackedVector2Array([c0 - v * s * .26, c0 + u * side * s * .27 - v * s * .26, c0 + u * side * s * .27 + v * s * .26, c0 + v * s * .26]), a, Color(GREY, .9), Color("1d232b"), 1.0)
			f.stroke(p + v * s * .35, p + v * s * .7, Color(line, a))
			f.draw_arc(p + v * s * .78, s * .14, r2 + PI, r2 + TAU, 8, Color(line, a), 1.0, true)
			f.draw_circle(p, 1.6, Color(ACCENT, (.4 + .6 * float(int(t * 2.0) % 2)) * a))
		# ---------------------------------------------------------------- 03 inner Solar System
		"2_swarm":
			# Asteroid chunk: a lumpy potato with one crater.
			body(f, ring_pts(p, s * .75, 8, spin, .22, sd), a, GREY, Color(GREY, .85))
			f.draw_arc(p + Vector2.from_angle(spin + 1.0) * s * .25, s * .18, 0, TAU, 10, Color(DIM, a), 1.0, true)
		"2_dart":
			# Alien interceptor: a forward-swept X with twin engine glows.
			var nose: Vector2 = p + dir * s * 1.3
			body(f, PackedVector2Array([nose, p + nrm * s * .25, p - dir * s * .9 + nrm * s * 1.0, p - dir * s * .55, p - dir * s * .9 - nrm * s * 1.0, p - nrm * s * .25]), a, line)
			f.stroke(nose, p - dir * s * .55, Color(line, .4 * a))
			for side in [1.0, -1.0]:
				f.draw_circle(p - dir * s * .62 + nrm * s * .3 * side, 1.6, Color(hot, a))
		"2_armored":
			# Metal asteroid: a smooth metallic body with banded sheen; plates of it shear away.
			var rim: PackedVector2Array = oval(p, s * 1.05, s * .8, spin * .2, 18)
			body(f, rim, a, line, Color("202020"))
			for k in range(3):
				var y: float = (k - 1) * .3
				f.draw_arc(p + Vector2(0, y * s).rotated(spin * .2), s * .85, PI * 1.15, PI * 1.85, 12, Color(GREY, .45 * a), 1.0, true)
			f.draw_arc(p, s * .7, spin * .2 - 2.4, spin * .2 - 1.6, 10, Color(Color.WHITE, .8 * a), 1.6, true)
			for j in range(6 - int(ceil(hp * 6.0))):
				var gap: float = spin * .2 + j * TAU / 6
				f.draw_arc(p, s * .98, gap - .2, gap + .2, 6, Color(DEEP, a), 4.0, true)
		"2_splitter":
			# Rubble pile: six loose boulders held by glowing dust.
			for j in range(6):
				var q: Vector2 = p + Vector2.from_angle(spin * .5 + j * TAU / 6) * s * (.45 if j % 2 == 0 else .6)
				body(f, ring_pts(q, s * (.32 if j % 2 == 0 else .25), 6, spin + j, .2, sd + j), a, GREY, Color(GREY, .8), 1.0)
			for j in range(3):
				var q: Vector2 = Vector2.from_angle(spin * .5 + j * TAU / 3)
				f.stroke(p - q * s * .2, p + q * s * .7, Color(hot, (.55 + .3 * sin(t * 6.0 + j)) * a))
		# ---------------------------------------------------------------- 04 outer Solar System
		"3_swarm":
			# Ring ice: a little six-armed crystal glinting.
			for j in range(3):
				var u := Vector2.from_angle(spin + j * PI / 3)
				f.stroke(p - u * s * .7, p + u * s * .7, Color(ICE, a))
			f.draw_circle(p, 1.4, Color(Color.WHITE, a))
		"3_dart":
			# Interceptor formation: three small arrowheads in a tight V.
			for j in range(3):
				var off: Vector2 = Vector2.ZERO if j == 0 else (-dir * s * .8 + nrm * s * .8 * (1.0 if j == 1 else -1.0))
				var q: Vector2 = p + off
				body(f, PackedVector2Array([q + dir * s * .6, q - dir * s * .35 + nrm * s * .35, q - dir * s * .15, q - dir * s * .35 - nrm * s * .35]), a, line, DEEP, 1.0)
				f.draw_circle(q - dir * s * .25, 1.1, Color(hot, a))
		"3_armored":
			# Alien gunship: a hammerhead hull, side armour slabs, a long spinal gun.
			body(f, PackedVector2Array([p + dir * s * .7 + nrm * s * .9, p + dir * s * .9 + nrm * s * .3, p + dir * s * .9 - nrm * s * .3, p + dir * s * .7 - nrm * s * .9,
				p - dir * s * .9 - nrm * s * .45, p - dir * s * 1.1, p - dir * s * .9 + nrm * s * .45]), a, line)
			f.stroke(p + dir * s * .9, p + dir * s * 1.6, Color(line, a), 2.0)
			var slabs: int = int(ceil(hp * 4.0))
			for k in range(4):
				if k >= slabs:
					continue
				var side: float = 1.0 if k % 2 == 0 else -1.0
				var c0: Vector2 = p - dir * s * (.1 + .45 * float(k / 2)) + nrm * s * .78 * side
				body(f, PackedVector2Array([c0 - dir * s * .2, c0 + dir * s * .2, c0 + dir * s * .14 + nrm * s * .14 * side, c0 - dir * s * .14 + nrm * s * .14 * side]), a, GREY, Color("222222"), 1.0)
			f.draw_circle(p - dir * s * 1.0, 1.8, Color(hot, a))
		"3_splitter":
			# Contact-binary comet: two icy lobes joined at a glowing neck, a faint coma round both.
			for side in [1.0, -1.0]:
				body(f, oval(p + nrm * s * .42 * side, s * .5, s * .42, heading + side * .3, 14), a, ICE, Color("1b2128"), 1.2)
			f.stroke(p + nrm * s * .15, p - nrm * s * .15, Color(hot, a), 2.0)
			f.draw_arc(p, s * 1.15, 0, TAU, 24, Color(ICE, .2 * a), 1.0, true)
		"3_shielded":
			# Plasma-shield ship: a slim hull wrapped round a bright plasma globe.
			body(f, PackedVector2Array([p + dir * s * 1.0, p + nrm * s * .55, p - dir * s * .8 + nrm * s * .35, p - dir * s * .8 - nrm * s * .35, p - nrm * s * .55]), a, line)
			glow(f, p, s * .55, ACCENT, a)
			f.draw_circle(p, s * .22, Color(hot, a))
		# ---------------------------------------------------------------- 05 Oort cloud
		"4_swarm":
			# Comet nucleus: a dark lump with a faint short tail.
			body(f, ring_pts(p, s * .55, 6, spin, .25, sd), a, ICE, Color("1b2128"), 1.0)
			f.stroke(p - dir * s * .5, p - dir * s * 1.8, Color(ICE, .35 * a))
		"4_dart":
			# Long-tailed comet: a bright head, a straight ion tail and a curved dust tail.
			glow(f, p, s * .7, ICE, a)
			f.draw_circle(p, s * .3, Color(Color.WHITE, a))
			f.stroke(p - dir * s * .3, p - dir * s * 6.0, Color(ICE, .55 * a))
			var curve := PackedVector2Array()
			for k in range(10):
				var u: float = k / 9.0
				curve.append(p - dir * s * (.3 + u * 4.5) + nrm * s * u * u * 1.6)
			f.draw_polyline(curve, Color(ACCENT, .4 * a), 2.0, true)
		"4_armored":
			# Giant ice core: frost facets, venting jets; its crust cracks away in slabs.
			var rim: PackedVector2Array = ring_pts(p, s, 8, spin * .2, .12, sd)
			body(f, rim, a, ICE, Color("182029"))
			var cracks: int = 6 - int(ceil(hp * 6.0))
			for j in range(8):
				f.stroke(p, rim[j], Color(ICE, (.18 if j >= cracks else .7) * a))
			for side in [1.0, -1.0]:
				var vent: Vector2 = p + Vector2.from_angle(spin * .2 + side) * s
				f.stroke(vent, vent + (vent - p).normalized() * s * (.5 + .2 * sin(t * 8.0 + side)), Color(ICE, .5 * a), 1.5)
		"4_splitter":
			# Ice-crystal cluster: a six-armed snowflake with amber fracture seams.
			for j in range(6):
				var u := Vector2.from_angle(spin * .4 + j * TAU / 6)
				f.stroke(p, p + u * s, Color(ICE, a), 1.6)
				f.stroke(p + u * s * .55, p + u * s * .55 + u.rotated(.7) * s * .3, Color(ICE, .8 * a))
				f.stroke(p + u * s * .55, p + u * s * .55 + u.rotated(-.7) * s * .3, Color(ICE, .8 * a))
			for j in range(3):
				f.stroke(p, p + Vector2.from_angle(spin * .4 + j * TAU / 3 + PI / 6) * s * .7, Color(hot, (.55 + .3 * sin(t * 6.0 + j)) * a))
		"4_shielded":
			# Ice-shell ship: a hull sealed inside a faceted ice carapace.
			body(f, ring_pts(p, s * .95, 6, heading + PI / 6), a, ICE, Color("182029"), 1.0)
			body(f, PackedVector2Array([p + dir * s * .6, p + nrm * s * .3, p - dir * s * .45, p - nrm * s * .3]), a, line)
		"4_mother":
			# Comet nest: a huge pitted nucleus; its burrows glow before a brood bursts out.
			var rim: PackedVector2Array = ring_pts(p, s, 11, spin * .1, .16, sd)
			body(f, rim, a, ICE, Color("161c22"), 1.5)
			for j in range(5):
				var q: Vector2 = p + Vector2.from_angle(spin * .1 + j * 1.3 + 1.0) * s * (.35 + .1 * (j % 3))
				var mouth: Color = ACCENT if j == 0 and open > 0.0 else DIM
				f.draw_circle(q, s * .1, Color(DEEP, a))
				f.draw_arc(q, s * .11, 0, TAU, 10, Color(mouth, (.6 + .4 * open) * a), 1.2, true)
			f.stroke(p - dir * s, p - dir * s * 3.2, Color(ICE, .3 * a), 3.0)
		# ---------------------------------------------------------------- 06 stellar neighbourhood
		"5_swarm":
			# Plasma blob: a hot knot with three flickering tendrils.
			f.draw_circle(p, s * .4, Color(Color("f6f1e6"), a))
			for j in range(3):
				var u := Vector2.from_angle(spin * 2.0 + j * TAU / 3)
				f.stroke(p + u * s * .35, p + u.rotated(.5) * s * (.8 + .2 * sin(t * 9.0 + j)), Color(hot, .8 * a))
		"5_dart":
			# Flare bolt: a magnetic loop of plasma racing forward.
			var loop := PackedVector2Array()
			for k in range(13):
				var u: float = k / 12.0
				loop.append(p - dir * s * (1.0 - u * 2.0) * .8 + nrm * sin(u * PI) * s * .9)
			f.draw_polyline(loop, Color(hot, a), 2.4, true)
			f.draw_polyline(loop, Color(Color.WHITE, .7 * a), 1.0, true)
		"5_armored":
			# Brown dwarf: a banded failed star with a dim warm limb; bands dim as it breaks.
			f.draw_circle(p, s, Color("2a2018", a))
			var bands: int = int(ceil(hp * 5.0))
			for k in range(5):
				var y: float = (k - 2) * .34
				var half: float = sqrt(maxf(0.0, 1.0 - y * y)) * s
				var off := Vector2(0, y * s).rotated(spin * .1)
				var side := Vector2(half, 0).rotated(spin * .1)
				f.stroke(p + off - side, p + off + side, Color(ACCENT if k < bands else DIM, (.55 if k < bands else .25) * a), 2.0)
			f.draw_arc(p, s, 0, TAU, 32, Color(ACCENT, .6 * a), 1.4, true)
		"5_splitter":
			# Binary star: two suns circling a shared centre, a bridge of light between.
			for side in [1.0, -1.0]:
				var q: Vector2 = p + Vector2.from_angle(t * 1.5 + sd) * s * .5 * side
				glow(f, q, s * .55, ACCENT, a)
				f.draw_circle(q, s * .28, Color(Color.WHITE, a))
			f.stroke(p + Vector2.from_angle(t * 1.5 + sd) * s * .5, p - Vector2.from_angle(t * 1.5 + sd) * s * .5, Color(hot, .6 * a))
		"5_shielded":
			# Corona-shield ship: a hull behind a sunshade parasol.
			body(f, PackedVector2Array([p + dir * s * .3, p + nrm * s * .3 - dir * s * .2, p - dir * s * .9, p - nrm * s * .3 - dir * s * .2]), a, line)
			f.draw_arc(p + dir * s * .1, s * .95, heading - 1.1, heading + 1.1, 18, Color(line, a), 2.4, true)
			f.draw_arc(p + dir * s * .1, s * 1.12, heading - .8, heading + .8, 14, Color(hot, .7 * a), 1.2, true)
		"5_mother":
			# Interstellar ark: a long spine with three rotating habitat rings and an engine bell.
			f.stroke(p + dir * s * 1.4, p - dir * s * 1.5, Color(line, a), 2.4)
			for k in range(3):
				var c0: Vector2 = p + dir * s * (.8 - k * .8)
				var tilt: float = t * 1.2 + k
				body(f, oval(c0, s * .22, s * .8, heading, 16), a, line, DEEP, 1.2)
				f.stroke(c0 + nrm * s * .8 * cos(tilt), c0 - nrm * s * .8 * cos(tilt), Color(GREY, .5 * a))
			var bell: Vector2 = p - dir * s * 1.55
			body(f, PackedVector2Array([bell + nrm * s * .2, bell - nrm * s * .2, bell - dir * s * .35 - nrm * s * .42, bell - dir * s * .35 + nrm * s * .42]), a, line)
			f.draw_circle(bell - dir * s * .5, s * (.12 + .25 * open), Color(hot, (.5 + .5 * open) * a))
		# ---------------------------------------------------------------- 07 Milky Way
		"6_swarm":
			# Star stream: five tiny stars strung along a line.
			for k in range(5):
				var q: Vector2 = p - dir * s * (k - 2) * .45 + nrm * sin(k * 1.3 + t * 2.0) * s * .15
				f.draw_circle(q, 1.0 + (2 - absi(k - 2)) * .55, Color(Color.WHITE if k == 2 else ICE, a))
		"6_dart":
			# Pulsar shard: a spinning sliver sweeping two lighthouse beams.
			var u := Vector2.from_angle(t * 14.0 + sd)
			f.stroke(p - u * s * 1.6, p + u * s * 1.6, Color(Color.WHITE, .55 * a), 1.2)
			body(f, star_pts(p, s * .55, s * .2, 4, t * 14.0 + sd), a, line, Color(Color.WHITE, .9))
		"6_armored":
			# Neutron star: a tiny blinding core in a cage of dipole field loops; loops snap off.
			var loops: int = int(ceil(hp * 3.0))
			var axis := Vector2.from_angle(spin * .5)
			for k in range(3):
				if k >= loops:
					continue
				var l: float = s * (.55 + k * .25)
				for side in [1.0, -1.0]:
					var arc := PackedVector2Array()
					for q in range(15):
						var th: float = .15 + (PI - .3) * q / 14.0
						var rr: float = l * 2.0 * sin(th) * sin(th)
						arc.append(p + axis * cos(th) * rr + axis.orthogonal() * sin(th) * rr * side)
					f.draw_polyline(arc, Color(ICE, (.7 - k * .15) * a), 1.0, true)
			glow(f, p, s * .5, ICE, a)
			f.draw_circle(p, s * .2, Color(Color.WHITE, a))
		"6_splitter":
			# Globular cluster: a dense ball of stars thinning outward.
			for k in range(22):
				var r: float = s * pow(float(k) / 22.0, .6)
				var q: Vector2 = p + Vector2.from_angle(k * 2.4 + spin * .3) * r
				f.draw_circle(q, 1.6 - r / s, Color(Color.WHITE if r < s * .4 else ICE, a))
			for j in range(2):
				f.stroke(p - Vector2.from_angle(spin * .3 + j * PI * .5) * s * .9, p + Vector2.from_angle(spin * .3 + j * PI * .5) * s * .9, Color(hot, .4 * a))
		"6_shielded":
			# Magnetosphere ship: a probe sheltering in its own swept-back field lines.
			body(f, PackedVector2Array([p + dir * s * .55, p + nrm * s * .28, p - dir * s * .4, p - nrm * s * .28]), a, line)
			for k in range(2):
				for side in [1.0, -1.0]:
					var arc := PackedVector2Array()
					for q in range(12):
						var u: float = q / 11.0
						arc.append(p + dir * s * (.6 - u * 2.2) + nrm * side * s * (.4 + k * .3) * sin(u * PI * .5 + .4))
					f.draw_polyline(arc, Color(ICE, (.5 - k * .15) * a), 1.0, true)
		"6_mother":
			# Galactic carrier: a disc hull with two swept spiral arms; its core opens to launch.
			var arms: int = 2
			for k in range(arms):
				var arm := PackedVector2Array()
				for q in range(14):
					var u: float = q / 13.0
					arm.append(p + Vector2.from_angle(spin * .3 + k * PI + u * 2.6) * s * (.4 + u * 1.0))
				f.draw_polyline(arm, Color(line, .8 * a), 2.2, true)
			body(f, oval(p, s * .55, s * .55, 0.0, 18), a, line)
			f.draw_circle(p, s * (.18 + .12 * open), Color(hot, (.6 + .4 * open) * a))
		# ---------------------------------------------------------------- 08 supercluster
		"7_swarm":
			# Dwarf galaxy: a small fuzzy oval with a bright core.
			body(f, oval(p, s * .6, s * .35, spin * .2, 14), a, Color(ICE, .6), Color(ICE, .18), 1.0)
			f.draw_circle(p, 1.6, Color(Color.WHITE, a))
		"7_dart":
			# Relativistic jet blob: a knot firing two opposed thin jets.
			f.draw_circle(p, s * .3, Color(Color.WHITE, a))
			f.stroke(p + nrm * s * .35, p + nrm * s * 1.6, Color(hot, .8 * a), 1.4)
			f.stroke(p - nrm * s * .35, p - nrm * s * 1.6, Color(hot, .8 * a), 1.4)
			glow(f, p, s * .6, ACCENT, a)
		"7_armored":
			# Elliptical galaxy: nested isophotes; the outer ones fade as it is stripped.
			var shells: int = int(ceil(hp * 4.0))
			for k in range(4):
				var r: float = 1.0 - k * .22
				f.draw_polyline(oval(p, s * r, s * r * .66, spin * .1, 24) + PackedVector2Array([oval(p, s * r, s * r * .66, spin * .1, 24)[0]]),
					Color(ICE if k < shells else DIM, (.35 + k * .15) * a * (1.0 if k < shells else .4)), 1.0, true)
			glow(f, p, s * .3, Color.WHITE, a)
			f.draw_circle(p, s * .1, Color(Color.WHITE, a))
		"7_splitter":
			# Merging galaxies: two spirals tangled together, tidal tails flung out.
			for side in [1.0, -1.0]:
				var c0: Vector2 = p + nrm * s * .4 * side
				for k in range(2):
					var arm := PackedVector2Array()
					for q in range(8):
						var u: float = q / 7.0
						arm.append(c0 + Vector2.from_angle(spin * .4 * side + k * PI + u * 2.2) * s * (.1 + u * .45))
					f.draw_polyline(arm, Color(ICE, .8 * a), 1.2, true)
				f.draw_circle(c0, 1.8, Color(Color.WHITE, a))
			f.stroke(p - nrm * s * .2, p + nrm * s * .2, Color(hot, a), 2.0)
		"7_shielded":
			# Dark-matter halo: an unseen sphere - only dashed lensing arcs give it away.
			for k in range(8):
				var a0: float = t * .4 + k * TAU / 8
				f.draw_arc(p, s * 1.05, a0, a0 + .45, 6, Color(ICE, .5 * a), 1.0, true)
			body(f, oval(p, s * .45, s * .25, spin * .3, 12), a, Color(ICE, .7), Color(ICE, .15), 1.0)
		"7_mother":
			# Cluster core: a giant elliptical with satellite galaxies orbiting; it throws them out.
			for k in range(3):
				var r: float = 1.0 - k * .28
				var o: PackedVector2Array = oval(p, s * r, s * r * .8, spin * .1, 24)
				o.append(o[0])
				f.draw_polyline(o, Color(ICE, (.3 + k * .2) * a), 1.2, true)
			glow(f, p, s * .5, Color.WHITE, a)
			for k in range(5):
				var q: Vector2 = p + Vector2.from_angle(t * .5 + k * TAU / 5) * s * 1.35
				f.draw_circle(q, 2.0, Color(ACCENT if k == 0 and open > 0.0 else ICE, a))
		# ---------------------------------------------------------------- 09 observable universe
		"8_swarm":
			# Quasar point: a pin of light with four diffraction spikes.
			f.draw_circle(p, 1.8, Color(Color.WHITE, a))
			for j in range(4):
				var u := Vector2.from_angle(j * PI * .5 + PI * .25)
				f.stroke(p + u * 2.0, p + u * s * .9, Color(Color.WHITE, .7 * a))
		"8_dart":
			# Gamma-ray burst: a beamed double cone of light.
			for side in [1.0, -1.0]:
				body(f, PackedVector2Array([p, p + dir * s * 1.4 * side + nrm * s * .35, p + dir * s * 1.4 * side - nrm * s * .35]), a, hot, Color(ACCENT, .25), 1.0)
			f.draw_circle(p, 2.2, Color(Color.WHITE, a))
		"8_armored":
			# Great-wall segment: a chain of galaxy nodes joined by filaments; nodes go dark.
			var nodes: int = int(ceil(hp * 6.0))
			var last := Vector2.ZERO
			for k in range(6):
				var q: Vector2 = p + nrm * s * (k - 2.5) * .42 + dir * s * sin(k * 1.7 + sd) * .3
				if k > 0:
					f.stroke(last, q, Color(ICE, .45 * a), 1.2)
				f.draw_circle(q, 2.4, Color(Color.WHITE if k < nodes else DIM, a))
				last = q
		"8_splitter":
			# Cosmic-web node: a knot where four filaments meet; it parts along the seams.
			for j in range(4):
				var u := Vector2.from_angle(spin * .3 + j * TAU / 4 + .3)
				f.stroke(p, p + u * s * 1.1, Color(ICE, .6 * a), 1.2)
				f.draw_circle(p + u * s * 1.1, 1.4, Color(ICE, a))
			f.draw_circle(p, s * .3, Color(Color.WHITE, a))
			f.stroke(p - nrm * s * .45, p + nrm * s * .45, Color(hot, (.6 + .3 * sin(t * 6.0)) * a), 1.6)
		"8_shielded":
			# Dark-energy bubble: an empty void whose rim keeps swelling outward.
			var k: float = fposmod(t * .6, 1.0)
			f.draw_arc(p, s * (.5 + k * .5), 0, TAU, 24, Color(ICE, (1.0 - k) * .6 * a), 1.0, true)
			f.draw_arc(p, s * .5, 0, TAU, 24, Color(line, a), 1.4, true)
			f.draw_circle(p, 1.4, Color(ACCENT, a))
		"8_mother":
			# Primordial black hole: a black disc, a photon ring, an accretion swirl that sheds.
			for k in range(3):
				var arm := PackedVector2Array()
				for q in range(14):
					var u: float = q / 13.0
					arm.append(p + Vector2.from_angle(t * 1.5 + k * TAU / 3 + u * 3.0) * s * (1.2 - u * .7))
				f.draw_polyline(arm, Color(ACCENT if k == 0 else ICE, .6 * a), 1.4, true)
			f.draw_circle(p, s * .5, Color(Color.BLACK, a))
			f.draw_arc(p, s * .52, 0, TAU, 32, Color(Color.WHITE, (.8 + .2 * open) * a), 1.6 + open * 1.5, true)
		# ---------------------------------------------------------------- 10 the brane
		"9_swarm":
			# Quantum foam: a froth of tiny bubbles flickering in and out.
			for k in range(4):
				var on: float = .5 + .5 * sin(t * 7.0 + k * 1.9 + sd)
				var q: Vector2 = p + Vector2.from_angle(k * 1.7 + sd) * s * .35
				f.draw_arc(q, s * (.18 + .12 * on), 0, TAU, 10, Color(ICE, (.35 + .6 * on) * a), 1.0, true)
		"9_dart":
			# Tachyon: arrives before its own light - a needle with a cone of ripples ahead of it.
			f.stroke(p - dir * s * 1.2, p + dir * s * .6, Color(Color.WHITE, a), 1.6)
			for k in range(3):
				var c0: Vector2 = p + dir * s * (.8 + k * .45)
				f.draw_arc(c0, s * (.3 + k * .2), heading + PI - .8, heading + PI + .8, 10, Color(ICE, (.7 - k * .2) * a), 1.0, true)
			f.draw_circle(p + dir * s * .6, 1.8, Color(hot, a))
		"9_armored":
			# Cosmic-string knot: a trefoil of one thick string; loops slacken as it is cut.
			var lobes: float = 3.0
			var tight: float = .35 + .65 * hp
			var knot := PackedVector2Array()
			for q in range(61):
				var u: float = q / 60.0 * TAU
				var r: float = s * (.55 + .4 * tight * cos(lobes * u))
				knot.append(p + Vector2.from_angle(u + spin * .3) * r)
			f.draw_polyline(knot, Color(line, a), 2.4, true)
			f.draw_polyline(knot, Color(hot, .5 * a), 1.0, true)
		"9_splitter":
			# Baby universe: a small bubble with its own web inside, already budding a twin.
			f.draw_circle(p, s * .75, Color(DEEP, a))
			f.draw_arc(p, s * .75, 0, TAU, 24, Color(line, a), 1.3, true)
			for k in range(4):
				var u := Vector2.from_angle(k * 1.6 + spin * .2)
				f.stroke(p + u * s * .1, p + u * s * .55, Color(ICE, .5 * a))
			var bud: Vector2 = p + nrm * s * .85
			f.draw_arc(bud, s * .3, 0, TAU, 14, Color(line, .8 * a), 1.0, true)
			f.stroke(p + nrm * s * .62, bud - nrm * s * .2, Color(hot, (.6 + .3 * sin(t * 6.0)) * a), 1.6)
		"9_shielded":
			# Brane bubble: a wobbling membrane sack with a core of light.
			var skin := PackedVector2Array()
			for q in range(24):
				var u: float = q * TAU / 24
				skin.append(p + Vector2.from_angle(u) * s * .8 * (1.0 + .08 * sin(u * 3.0 + t * 3.0)))
			body(f, skin, a, line, DEEP, 1.2)
			f.draw_circle(p, s * .18, Color(ACCENT, a))
		"9_mother":
			# Rift to another universe: a jagged tear in space, black inside, burning at the edges.
			var up: Vector2 = nrm
			var tear := PackedVector2Array()
			var left := PackedVector2Array()
			for k in range(9):
				var u: float = k / 8.0
				var along: Vector2 = p + up * s * (u * 2.4 - 1.2)
				var width: float = s * .42 * sin(u * PI) * (1.0 + .5 * open)
				var zig: float = sin(k * 2.3 + sd) * s * .12
				tear.append(along + dir * (width + zig))
				left.append(along - dir * (width - zig))
			left.reverse()
			tear.append_array(left)
			f.draw_colored_polygon(tear, Color(Color.BLACK, a))
			var loop: PackedVector2Array = tear.duplicate()
			loop.append(tear[0])
			f.draw_polyline(loop, Color(hot, a), 2.0, true)
			f.draw_polyline(loop, Color(Color.WHITE, .6 * a), .8, true)
			for k in range(6):
				var q: Vector2 = p + up * s * (k / 5.0 * 2.0 - 1.0) + dir * s * .55 * sin(t * 3.0 + k)
				f.draw_circle(q, 1.2, Color(ACCENT, .6 * a))
		_:
			return false
	return true
