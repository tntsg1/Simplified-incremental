extends SceneTree

const Combat = preload("res://scripts/combat.gd")
var failures: int = 0
var checks: int = 0

# The previous lookup is retained as a reference for exact combat replay.
class LinearCombat extends Combat:
	func find_enemy(id: int) -> Dictionary:
		for e in enemies:
			if int(e.id) == id and not bool(e.dead):
				return e
		return {}

class SlowCombat extends Combat:
	func advance(delta: float, _visuals: bool = true) -> void:
		OS.delay_usec(5000)
		elapsed += delta

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func prepare(c: RefCounted, stage: int) -> void:
	c.start_new(4262026)
	c.stage = stage
	c.wave = 10
	c.start_wave()
	c.automation = true
	c.levels.damage = 110
	c.levels.reload = 95
	c.levels.turrets = 48
	c.levels.area = 40
	c.levels.pierce = 20
	for s in range(stage + 1):
		c.owned[s] = true
		c.bodies[s] = (1 << c.BODIES[s].size()) - 1
	for i in range(120):
		c.spawn_enemy(100000)

func run() -> void:
	for stage in range(6):
		var indexed = Combat.new()
		var reference = LinearCombat.new()
		prepare(indexed, stage)
		prepare(reference, stage)
		for tick in range(120):
			if tick == 30:
				indexed.select_target(indexed.enemies.back().pos)
				reference.select_target(reference.enemies.back().pos)
			if tick == 60:
				indexed.ult_charge = 1.0
				reference.ult_charge = 1.0
				indexed.fire_ultimate()
				reference.fire_ultimate()
			indexed.advance(1.0 / 60.0)
			reference.advance(1.0 / 60.0)
		check(indexed.snapshot() == reference.snapshot(), "Combat replay changed at stage %d" % stage)
		var restored = Combat.new()
		check(restored.restore(indexed.snapshot()), "Dense save restore")
		for e in restored.enemies:
			check(restored.find_enemy(int(e.id)) == e if not bool(e.dead) else restored.find_enemy(int(e.id)).is_empty(), "Restored lookup")
		var old_ids: Array = restored.enemies_by_id.keys()
		restored.clear_battle()
		restored.spawn_enemy(1)
		for id in old_ids:
			check(restored.find_enemy(id).is_empty(), "Pooled enemy leaked through old ID")
		restored.start_boss()
		check(restored.find_enemy(int(restored.enemies[0].id)) == restored.enemies[0], "Boss lookup")
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var slow = SlowCombat.new()
	slow.start_new()
	game.sim = slow
	var before: int = Time.get_ticks_usec()
	var advanced: float = game.advance_frame(.1, 8.0)
	var ms: float = (Time.get_ticks_usec() - before) / 1000.0
	check(game.sim_steps_this_frame <= 2, "Slow ticks failed to yield")
	check(is_equal_approx(advanced, slow.elapsed), "Reported time differs from actual ticks")
	check(game.accumulator <= game.SIM_STEP * game.MAX_SIM_STEPS, "Unbounded catch-up debt")
	check(game.advance_frame(.1, 0.0) == 0.0, "Hit stop processed pending catch-up")
	slow.paused = true
	check(game.advance_frame(1.0, 8.0) == 0.0, "Pause advanced simulation")
	game.queue_free()
	await process_frame
	print("GALAXY_PERFORMANCE checks=", checks, " failures=", failures, " slow_frame_ms=", ms)
	quit(1 if failures else 0)
