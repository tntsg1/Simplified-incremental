extends SceneTree
# Diagnostic: which threats break through when a chapter is slightly too hard.
# Usage: -- <stage> <hp_base_scale> [growth]
const Combat = preload("res://scripts/combat.gd")
const Route = preload("res://tests/purchase_route.gd")

func step(c: RefCounted, tick: int) -> void:
	if tick % 120 == 0 and c.mode != "transition":
		Route.buy(c, "balanced")
	c.manual_held = not c.automation
	if not c.automation:
		var t: Dictionary = c.target_for_weapon()
		if not t.is_empty():
			c.priority_id = int(t.id)
	if c.ultimate_ready():
		c.fire_ultimate()
	c.advance(1.0 / 60, false)

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var stage: int = int(args[0])
	var c = Combat.new()
	c.start_new(4262026)
	var tick: int = 0
	while not (c.stage >= stage and c.mode == "wave"):
		if c.mode == "failed":
			c.retry()
		step(c, tick)
		tick += 1
	c.catalog.stages[stage].hp_base_scale = float(args[1])
	if args.size() > 2:
		c.catalog.stages[stage].hp_growth = float(args[2])
	c.restore(JSON.parse_string(JSON.stringify(c.snapshot())))
	var health: float = c.health
	var alive_ids: Dictionary = {}
	for i in range(400000):
		if c.mode in ["failed", "intermission", "boss"] or c.stage != stage:
			break
		var before: Dictionary = {}
		for e in c.enemies:
			if not bool(e.dead):
				before[int(e.id)] = e
		step(c, tick)
		tick += 1
		if c.health < health - .01:
			for id in before:
				var e: Dictionary = before[id]
				if float(e.age) >= float(e.lifetime) - 1.0 / 30.0:
					print("BREACH wave=", c.wave, " t=", snappedf(c.wave_elapsed, .1), " kind=", e.kind, " elite=", e.elite, " members=", e.members, "/", e.initial_members, " hp=", e.hp, " unit=", e.unit_hp, " flood=", e.get("flood", false), " alive=", c.living_count(), " health=", c.health, " age=", snappedf(float(e.age), .1), "/", snappedf(float(e.lifetime), .1))
		health = c.health
	print("END mode=", c.mode, " wave=", c.wave, " dps=", c.nominal_dps(), " levels=", c.levels)
	quit()
