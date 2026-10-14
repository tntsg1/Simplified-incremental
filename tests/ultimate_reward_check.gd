extends SceneTree

const Combat = preload("res://scripts/combat.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	for stage in range(6):
		for wave in [1, 5, 10]:
			for damaged in [false, true]:
				var c = Combat.new()
				c.start_new()
				c.stage = stage
				c.wave = wave
				c.start_wave()
				c.spawn_enemy(c.group_size())
				c.serial = 8
				c.spawn_enemy(1)
				var expected: float = 0.0
				var members: int = 0
				for e in c.enemies:
					e.pos = c.defense_position()
					if damaged:
						e.hp *= 0.37
					members += int(e.members)
					expected += int(e.members) * 10.0 * float(c.stage_data().reward_multiplier) / c.wave_density() / (c.WAVE_SCALE if stage > 0 else 1) * (2.0 if bool(e.elite) else 1.0) * c.reward_scale()
				c.ult_charge = 1.0
				check(c.fire_ultimate(), "ultimate fires")
				for tick in range(600):
					c.update_rewards(1.0 / 60.0)
					c.update_ultimate(1.0 / 60.0)
				var label: String = "stage=%d wave=%d damaged=%s" % [stage, wave, damaged]
				check(is_equal_approx(c.money, expected), "reward " + label + " expected=%s actual=%s" % [expected, c.money])
				check(c.kills == members and c.living_count() == 0, "all members killed " + label + " expected=%s actual=%s" % [members, c.kills])
				var paid: float = c.money
				for e in c.enemies:
					c.ult_strike(e, stage)
				check(c.money == paid, "no duplicate reward " + label)
	check_timing_and_save()
	check_boss()
	var ordinary = Combat.new()
	ordinary.start_new()
	ordinary.spawn_enemy(10)
	ordinary.apply_damage(ordinary.enemies[0], 350.0, 4, 0)
	check(ordinary.money == 30 and ordinary.enemies[0].members == 7 and ordinary.enemies[0].hp == 50 and ordinary.reward_batches.is_empty(), "ordinary partial kills still pay immediately")
	ordinary.apply_damage(ordinary.enemies[0], 10000.0, 2, 0)
	check(ordinary.enemies[0].members == 5 and ordinary.money == 50, "ordinary coverage cap remains intact")
	print("ULTIMATE_REWARD checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func check_timing_and_save() -> void:
	var c = Combat.new()
	c.start_new()
	c.spawn_clock = 1000.0
	c.spawn_enemy(10)
	c.ult_charge = 1.0
	c.fire_ultimate()
	c.ult_strike(c.enemies[0], 0)
	var bursts: Array = []
	c.ultimate_loot.connect(func(point, members, flight): bursts.append([point, members, flight]))
	check(c.money == 0 and c.kills == 10, "kills count now; ultimate money waits")
	c.update_rewards(.99)
	check(c.money == 0 and bursts.is_empty(), "one second silent beat before coins")
	c.paused = true
	c.advance(2.0)
	check(c.money == 0 and float(c.reward_batches[0].age) == .99, "pause freezes pending rewards")
	c.paused = false
	c.update_rewards(.02)
	check(c.money == 0 and bursts.size() == 1, "coins erupt together; money still waits")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.snapshot()))
	var restored = Combat.new()
	check(restored.restore(saved), "pending coins survive JSON save and restore")
	restored.mode = "victory"
	restored.advance(Combat.ULT_LOOT_FLIGHT - .02)
	check(restored.money == 0, "money waits for flight even in victory")
	restored.advance(.02)
	check(restored.money == 100 and restored.reward_batches.is_empty(), "arrival pays exact total after restore")
	restored.advance(10.0)
	check(restored.money == 100, "arrival pays once")
	c.update_rewards(Combat.ULT_LOOT_FLIGHT + .01)
	check(c.money == 100, "original branch pays same amount")
	saved.erase("reward_batches")
	saved.erase("boss_reward_queued")
	check(Combat.new().restore(saved), "old saves remain compatible")
	c.queue_ultimate_reward(Vector2.ZERO, 1, 10.0)
	c.start_new()
	check(c.reward_batches.is_empty() and c.money == 0, "new game clears previous pending rewards")

func check_boss() -> void:
	var c = Combat.new()
	c.start_new()
	c.start_boss()
	c.ult_charge = 1.0
	c.fire_ultimate()
	var boss: Dictionary = c.enemies[0]
	var hp: float = float(boss.hp)
	c.ult_strike(boss, 0)
	check(is_equal_approx(float(boss.hp), hp * .8) and c.reward_batches.is_empty(), "nonlethal ultimate keeps Boss 20 percent damage; no bounty")
	boss.hp = hp * .1
	c.ult_strike(boss, 0)
	var reward: float = float(c.stage_data().boss_reward) * c.reward_scale()
	c.finish_boss()
	check(c.money == 0 and c.reward_batches.size() == 1, "ultimate Boss kill queues bounty once across transition")
	c.advance(Combat.ULT_LOOT_DELAY + Combat.ULT_LOOT_FLIGHT + .01)
	check(is_equal_approx(c.money, reward), "Boss bounty arrives once after coins")
