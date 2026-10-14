extends SceneTree

const Combat = preload("res://scripts/combat.gd")
const Art = preload("res://scripts/ultimate_art.gd")
var failures: int = 0
var checks: int = 0

class DomainProbe extends Node2D:
	var sim: RefCounted
	var tri_points := PackedVector2Array()
	var tri_colors := PackedColorArray()
	var tri_indices := PackedInt32Array()
	func begin_batch() -> void:
		tri_points.clear()
		tri_colors.clear()
		tri_indices.clear()
	func flush_batch() -> void:
		pass
	func opaque_at(p: Vector2) -> bool:
		for i in range(0, tri_points.size(), 3):
			var a: Vector2 = tri_points[i]
			var b: Vector2 = tri_points[i + 1]
			var c: Vector2 = tri_points[i + 2]
			var ab: float = (b - a).cross(p - a)
			var bc: float = (c - b).cross(p - b)
			var ca: float = (a - c).cross(p - c)
			if minf(ab, minf(bc, ca)) >= 0 or maxf(ab, maxf(bc, ca)) <= 0:
				if tri_colors[i].a >= .999 and tri_colors[i + 1].a >= .999 and tri_colors[i + 2].a >= .999:
					return true
		return false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var c = Combat.new()
	c.start_new()
	c.ult_override = "foil"
	c.spawn_enemy(12)
	var e: Dictionary = c.enemies[0]
	e.pos = c.defense_position()
	var original: Array = [e.pos, e.radius, e.members]
	var captured: Array = []
	c.flattened.connect(func(p, r, sides, heading, members): captured.append([p, r, sides, heading, members]))
	c.ult_charge = 1.0
	c.fire_ultimate(e.pos)
	for tick in range(360):
		c.update_ultimate(1.0 / 60)
	check(captured.size() == 1, "Foil emits one remnant per struck group")
	check(captured[0][0] == original[0] and captured[0][1] == original[1] and captured[0][4] == original[2], "Remnant captures silhouette before enemy is mutated or pooled")
	var art = Art.new()
	for hit in captured:
		art.flattened(hit[0], hit[1], hit[2], hit[3], hit[4])
	check(art.remnants.size() == 1, "Actual foil event enters renderer")
	art.animate(.65)
	check(art.remnants.size() == 1, "Unfolded net survives front")
	art.animate(6.5)
	check(art.remnants.is_empty(), "Collapsed lines expire")
	for i in range(300):
		art.flattened(Vector2(i, i), 10, 4, 0, 100)
	check(art.remnants.size() == Art.REMNANT_CAP, "Dense foil bounded at 160 nets")
	# Dimensional collapse melts each body into a flat painting many times its size.
	check(art.membrane_extent(15, 2.4, 10).x > art.membrane_extent(15, 0, 10).x * 3, "Flattened footprint spreads wide")
	# Lowered light speed: Doppler colouring ramps in with the domain and out at impact.
	check(art.doppler_strength(0.0) == 0.0 and art.doppler_strength(2.0) < art.doppler_strength(4.0) and art.doppler_strength(5.0) > .99 and art.doppler_strength(6.6) == 0.0, "Doppler shift creeps in with the wakes and lets go at the harvest")
	check(art.wake_halfwidth(0.0) < art.wake_halfwidth(2.0) and art.wake_halfwidth(2.0) < art.wake_halfwidth(4.0), "Ship wakes keep swelling after the ships pass")
	check(art.wake_path(0, 0.0).x < 0.0 and art.wake_path(0, 1.0).x > 1000.0 and art.wake_path(1, 0.0).x > 1000.0, "Ships cross the whole field on different routes")
	art.spectral_burst([Vector2(10, 10), Vector2(20, 20)])
	var reds: int = 0
	var blues: int = 0
	for shard in art.spectral:
		if shard.col == Art.RED:
			reds += 1
		elif shard.col == Art.BLUE:
			blues += 1
	check(reds > 0 and blues > 0, "Erased threats break into red and blue light")
	var held: float = art.spectral[0].age
	art.animate(0)
	check(art.spectral[0].age == held, "Pause freezes spectral shards")
	var tint_field = preload("res://scripts/battlefield.gd").new()
	var tint_sim = Combat.new()
	tint_sim.start_new()
	tint_sim.stage = 3
	tint_field.sim = tint_sim
	tint_sim.ult = {"kind": "lightspeed", "age": 2.0}
	var core: Vector2 = tint_sim.defense_position()
	var toward: Color = tint_field.doppler_tint(Color.WHITE, core + Vector2(300, 0), Vector2(-1, 0), 1.0)
	var away: Color = tint_field.doppler_tint(Color.WHITE, core + Vector2(300, 0), Vector2(1, 0), 1.0)
	check(toward.b > toward.r and away.r > away.b, "Approaching threats shift blue, receding ones red")
	check(tint_field.doppler_tint(Color.WHITE, core + Vector2(300, 0), Vector2.ZERO, 1.0) == Color.WHITE, "Stationary source has no invented shift")
	tint_field.free()
	c.ult = {"kind": "lightspeed", "age": 0.0}
	check(is_equal_approx(c.enemy_time_rate(), 1.0), "Ships begin before slowing")
	c.ult.age = 1.5
	var midway: float = c.enemy_time_rate()
	c.ult.age = Combat.LIGHT_DOMAIN_SEAL
	check(midway < 1.0 and midway > c.enemy_time_rate() and c.enemy_time_rate() > 0, "Sources slow continuously but remain moving")
	c.ult.age = Combat.LIGHTSPEED_IMPACT
	check(c.enemy_time_rate() == 1.0, "Rate recovers at real impact")
	c.ult = {}
	check(c.enemy_time_rate() == 1.0, "No lingering slowdown")
	var field = preload("res://scripts/battlefield.gd").new()
	field.sim = c
	c.paused = true
	field.on_flattened(Vector2(100, 100), 20, 4, 0, 10)
	field.on_prime_strike(2, PackedVector2Array([Vector2(100, 100)]))
	field.animate_ultimates(1.0)
	check(float(field.ultimate_art.remnants[0].age) == 0 and float(field.prime_marks[0].age) == 0, "Pause holds unfolding and prime impact time")
	c.paused = false
	field.animate_ultimates(.2)
	check(is_equal_approx(float(field.ultimate_art.remnants[0].age), .2), "Resume advances remnant smoothly")
	field.free()
	for kind in ["prime", "lightspeed", "pi"]:
		var boss_sim = Combat.new()
		boss_sim.start_new()
		boss_sim.start_boss()
		boss_sim.ult_override = kind
		var boss: Dictionary = boss_sim.enemies[0]
		var hp: float = boss.hp
		boss_sim.ult_charge = 1.0
		boss_sim.fire_ultimate()
		for tick in range(480):
			boss_sim.update_ultimate(1.0 / 60)
		check(is_equal_approx(float(boss.hp), hp * .8), kind + " retains total Boss 20% cap")
	print("ULTIMATE_ART checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
