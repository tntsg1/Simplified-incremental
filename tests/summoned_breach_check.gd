extends SceneTree
const Combat = preload("res://scripts/combat.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func boss_fight(chapter: int):
	var c = Combat.new()
	c.start_new()
	c.stage = chapter
	c.wave = 10
	c.start_boss()
	c.escort_clock = 1000.0
	c.skill_clock = 1000.0
	c.owned.fill(false)
	return c

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for chapter in range(10):
		var c = boss_fight(chapter)
		c.spawn_escorts(1, false)
		var escort: Dictionary = c.enemies.back()
		escort.age = escort.lifetime
		var money: float = c.money
		c.advance(1.0 / 60.0, false)
		check(c.health == 90.0, "chapter %d escort deals normal base damage" % chapter)
		check(is_equal_approx(c.boss_penalty, c.ESCORT_PENALTY), "existing timer penalty retained")
		check(c.money == money and c.kills == 0, "breach does not award kill rewards")
		c.advance(1.0 / 60.0, false)
		check(c.health == 90.0, "escort cannot hit twice")
		c.spawn_fragment(c.boss_actor().pos, 20.0, 0.0)
		c.enemies.back().age = c.enemies.back().lifetime
		c.advance(1.0 / 60.0, false)
		check(c.health == 90.0 and is_equal_approx(c.boss_penalty, c.ESCORT_PENALTY), "spent droplet debris stays harmless during boss fight")
	for kind in ["meteor_rain", "corona", "summon"]:
		var c = boss_fight(0)
		c.fire_boss_skill(kind, c.boss_actor())
		var count: int = c.enemies.size() - 1
		for e in c.enemies:
			if not e.boss:
				e.age = e.lifetime
		c.advance(1.0 / 60.0, false)
		check(c.health == maxf(0.0, 100.0 - count * 10.0), kind + " summons damage the base")
		if count >= 10:
			check(c.mode == "failed" and c.attempts == 1, kind + " lethal breach ends the fight once")
			c.advance(1.0, false)
			check(c.mode == "failed" and c.attempts == 1, "failed fight remains stopped")
	for boss_mode in [false, true]:
		var c = boss_fight(0)
		if not boss_mode:
			c.clear_battle()
			c.mode = "wave"
			c.spawn_left = 1
			c.spawn_hold = 100.0
		c.spawn_child({"left": 10.0, "base_hp": 100.0, "mat": "rock"}, Vector2(400, 200), 1, 0.5, Vector2.ZERO)
		c.enemies.back().age = c.enemies.back().lifetime
		c.advance(1.0 / 60.0, false)
		check(c.health == 90.0, "mother/splitter child damages base in mode " + str(boss_mode))
	var saved = boss_fight(0)
	saved.spawn_escorts(1, false)
	saved.enemies.back().age = saved.enemies.back().lifetime
	var restored = Combat.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved.snapshot()))), "boss save restores")
	restored.owned.fill(false)
	restored.advance(1.0 / 60.0, false)
	check(restored.health == 90.0, "restored arriving summon damages base")
	print("SUMMONED_BREACH checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
