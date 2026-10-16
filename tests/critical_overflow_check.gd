extends SceneTree
const Combat = preload("res://scripts/combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var c = Combat.new()
	c.start_new()
	var base_dps: float = c.nominal_dps()
	for sample in [[0,0.0,2.0],[25,0.5,3.0],[26,0.52,3.0],[49,0.98,3.0],[50,1.0,4.0],[51,1.02,4.06],[74,1.48,5.44],[75,1.5,6.5],[100,2.0,9.0],[150,3.0,14.0]]:
		c.levels.crit = sample[0]
		check(is_equal_approx(c.crit_chance(), sample[1]), "uncapped chance at level " + str(sample[0]))
		check(is_equal_approx(c.crit_multiplier(), sample[2]), "3:1 additive overflow at level " + str(sample[0]))
		var expected: float = base_dps * (1.0 + minf(1.0, sample[1]) * (sample[2] - 1.0))
		check(is_equal_approx(c.nominal_dps(), expected), "DPS does not count overflow chance twice")
	for level in [50,51,75,100]:
		c.levels.crit = level
		c.start_boss()
		var target: Dictionary = c.boss_actor()
		var normal: float = c.shot_damage(0)
		for i in range(100):
			c.fire_weapon(0, target)
			var shot: Dictionary = c.shots.back()
			check(shot.crit, "100% or more always crits")
			check(is_equal_approx(shot.damage, normal * c.crit_multiplier()), "actual main shot receives overflow once")
		c.fire_turret(0, target)
		check(c.shots.back().crit, "turrets share guaranteed crit")
		c.fire_body(0, 0, target)
		check(c.shots.back().crit, "converted bodies share guaranteed crit")
	var restored = Combat.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(c.snapshot()))), "existing save format restores")
	check(is_equal_approx(restored.crit_chance(), 2.0) and is_equal_approx(restored.crit_multiplier(), 9.0), "saved level gets new rules without migration")
	print("CRITICAL_OVERFLOW checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
