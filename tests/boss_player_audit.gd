extends SceneTree
# Ordinary-player assumptions, never ranks upgrades by DPS or price efficiency.
const Combat = preload("res://scripts/combat.gd")
var output: Dictionary = {"profiles": [], "runs": [], "bosses": []}
const PROFILES: Array = [
	{"id": "core", "label": "直觉主升伤害和装填", "interval": 20.0, "clicks": 12, "batch": 10, "weights": [0,2,0,2,7,3,4,5,6], "bodies": 1, "reserve": 0.0},
	{"id": "spread", "label": "各项轮流升级", "interval": 25.0, "clicks": 10, "batch": 10, "weights": [0,2,7,3,4,5,6], "bodies": 1, "reserve": 0.0},
	{"id": "builder", "label": "喜欢炮塔和天体改造", "interval": 25.0, "clicks": 10, "batch": 10, "weights": [7,7,7,0,2,0,2,3,4,5,6], "bodies": 2, "reserve": 0.0},
	{"id": "saver", "label": "慢半拍并留20%现金", "interval": 40.0, "clicks": 8, "batch": 10, "weights": [0,2,7,3,4,5,6], "bodies": 1, "reserve": .2},
	{"id": "single", "label": "一直逐级点买未用批量", "interval": 25.0, "clicks": 10, "batch": 1, "weights": [0,2,0,2,7,3,4,5,6], "bodies": 1, "reserve": 0.0}
]

func _initialize() -> void:
	for p in PROFILES:
		output.profiles.append(p)
	for stage in range(6):
		var c = Combat.new()
		c.stage = stage
		c.wave = 10
		var ceiling: float = 0.0
		for w in range(1, 11):
			ceiling += float(c.stage_data().wave_members[w - 1]) * float(c.stage_data().count_multiplier) * 10.0 * float(c.stage_data().reward_multiplier) * pow(c.hp_scale(w), c.REWARD_HP_EXPONENT)
		output.bosses.append({"stage": stage, "name": c.stage_data().title, "hp": c.boss_max_hp(), "base_hp": c.stage_data().boss_hp, "window": c.stage_data().boss_window, "required_dps": c.boss_max_hp() / float(c.stage_data().boss_window), "full_regular_income_reference": ceiling})
	for p in PROFILES:
		for seed_value in [4262026, 9294, 71491]:
			run_policy(p, seed_value)
	var file = FileAccess.open("res://proofs/boss_player_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("BOSS_AUDIT_COMPLETE runs=", output.runs.size())
	quit()

func shopping(c: RefCounted, p: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary) -> void:
	if c.automation_available() and c.money >= 200:
		var before: float = c.money
		c.buy_automation()
		ledger.automation += before - c.money
	if c.stage > 0 and not c.owned[c.stage] and c.money >= float(c.stage_data().weapon_price):
		var before: float = c.money
		c.buy_weapon()
		ledger.weapons += before - c.money
	var reserve: float = c.money * float(p.reserve)
	if c.stage == 0 and not c.automation and c.wave >= 5:
		reserve = maxf(200, reserve)
	# Upgrade choices are random habitual clicks, never marginal-gain/cost scores.
	for click in range(int(p.clicks)):
		var i: int = p.weights[rng.randi_range(0, p.weights.size() - 1)]
		var u: Resource = c.catalog.upgrades[i]
		if c.stage < int(u.unlock_stage) or bool(u.retired):
			continue
		for level in range(1 if c.stage == 0 else int(p.batch)):
			if c.upgrade_cost(i) > c.money - reserve:
				break
			var before: float = c.money
			c.buy_upgrade(i)
			ledger.upgrades[u.key] = float(ledger.upgrades.get(u.key, 0.0)) + before - c.money
	for purchase in range(int(p.bodies)):
		# Builders convert before the next purchase session; other profiles use spare cash.
		if c.body_cost() > c.money - reserve:
			break
		for slot in range(c.BODIES[c.stage].size()):
			if not c.body_converted_at(c.stage, slot):
				var before: float = c.money
				c.convert_body(slot)
				ledger.bodies += before - c.money
				break

func new_ledger() -> Dictionary:
	return {"automation": 0.0, "weapons": 0.0, "bodies": 0.0, "upgrades": {}}

func run_policy(p: Dictionary, seed_value: int) -> void:
	var c = Combat.new()
	c.start_new(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1009
	var records: Array = []
	var stage: int = 0
	var ledger: Dictionary = new_ledger()
	var income: float = 0.0
	var start_cash: float = 0.0
	var previous_boss_rewards: float = 0.0
	var next_shop: float = 7.0
	var next_click: float = 0.0
	var next_auto: float = 0.0
	var attempts: int = 0
	var record: Dictionary = {}
	var cohorts: Dictionary = {}
	var tracked: Dictionary = {}
	for tick in range(500000):
		if c.stage != stage:
			stage = c.stage
			ledger = new_ledger()
			income = 0.0
			start_cash = c.money
			attempts = 0
			next_shop = c.elapsed + 5.0
		if c.mode in ["wave", "intermission"] and c.elapsed >= next_shop:
			shopping(c, p, rng, ledger)
			next_shop = c.elapsed + float(p.interval)
		# The visible automation button is noticed with up to five seconds delay.
		if c.automation_available() and c.money >= 200 and c.elapsed >= next_auto:
			var before: float = c.money
			c.buy_automation()
			ledger.automation += before - c.money
			next_auto = c.elapsed + 5.0
		if not c.automation:
			if c.elapsed >= next_click:
				var alive: Array = []
				for e in c.enemies:
					if not bool(e.dead): alive.append(e)
				if not alive.is_empty():
					var target: Dictionary = alive[rng.randi_range(0, alive.size() - 1)]
					c.priority_id = int(target.id)
				next_click = c.elapsed + .8
			c.manual_held = not c.find_enemy(c.priority_id).is_empty()
		if c.mode == "boss" and record.is_empty():
			# One ordinary shopping visit on the warning, then fixed upgrades for the fight.
			shopping(c, p, rng, ledger)
			record = {"stage": stage, "attempt": attempts, "boss_hp": c.boss_max_hp(), "window": c.stage_data().boss_window, "cash": c.money, "start_cash": start_cash, "mob_income": income, "ledger": ledger.duplicate(true), "levels": c.levels.duplicate(), "owned": c.owned.duplicate(), "bodies": c.total_bodies(), "nominal_dps": c.nominal_dps(), "started": c.elapsed, "first_attempt": attempts == 0, "prior_boss_rewards": previous_boss_rewards}
		var before_cash: float = c.money
		var before_mode: String = c.mode
		var before_bosses: int = c.stage_bosses
		var before_stage: int = c.stage
		var before_wave: int = c.wave
		for e in c.enemies:
			if not bool(e.boss) and not bool(e.dead) and not tracked.has(int(e.id)):
				register_mob(e, c.stage, c.wave, attempts, cohorts, tracked)
		for id in tracked:
			tracked[id].previous = int(tracked[id].entity.members)
		c.advance(1.0 / 60.0, false)
		for e in c.enemies:
			if not bool(e.boss) and not tracked.has(int(e.id)):
				register_mob(e, before_stage, before_wave, attempts, cohorts, tracked)
		for id in tracked.keys():
			var t: Dictionary = tracked[id]
			var e: Dictionary = t.entity
			var removed: int = maxi(0, int(t.previous) - int(e.members))
			var row: Dictionary = cohorts[t.key]
			row.killed += removed
			row.depth_weighted += removed * minf(1.0, float(e.age) / float(e.lifetime))
			if t.asteroid:
				row.asteroid_killed += removed
			if bool(e.dead):
				if float(e.hp) > 0 and float(e.age) >= float(e.lifetime):
					row.leaked += int(e.members)
					if t.asteroid: row.asteroid_leaked += int(e.members)
				tracked.erase(id)
		var delta_cash: float = c.money - before_cash
		if c.stage_bosses > before_bosses:
			previous_boss_rewards += delta_cash
		else:
			income += delta_cash
		if not record.is_empty() and before_mode == "boss" and c.mode != "boss":
			record["won"] = c.mode in ["transition", "victory"]
			record["ttk"] = c.elapsed - float(record.started)
			record["remaining_hp_fraction"] = 0.0 if bool(record.won) else float(c.enemies[0].hp) / float(record.boss_hp)
			record["measured_dps"] = float(record.boss_hp) * (1.0 - float(record.remaining_hp_fraction)) / float(record.ttk)
			records.append(record)
			print("BOSS_AUDIT ", p.id, " seed=", seed_value, " stage=", stage, " attempt=", attempts, " won=", record.won, " ttk=", snappedf(record.ttk, .01), " remaining=", snappedf(record.remaining_hp_fraction, .001), " levels=", record.levels)
			record = {}
		if c.mode == "failed":
			attempts += 1
			if attempts > 2:
				break
			shopping(c, p, rng, ledger)
			c.retry()
			tracked.clear()
			next_shop = c.elapsed + float(p.interval)
		if c.mode == "victory":
			break
	output.runs.append({"profile": p.id, "seed": seed_value, "mode": c.mode, "stopped_stage": c.stage, "stopped_wave": c.wave, "elapsed": c.elapsed, "retries": c.attempts, "records": records, "waves": cohorts.values(), "last_levels": c.levels, "last_cash": c.money, "unreached_stages_are_unknown": true})
	var partial = FileAccess.open("res://proofs/boss_player_audit.json", FileAccess.WRITE)
	partial.store_string(JSON.stringify(output, "\t"))
	print("PLAYER_RUN ", p.id, " seed=", seed_value, " mode=", c.mode, " stage=", c.stage, " attempts=", c.attempts)

func register_mob(e: Dictionary, stage: int, wave: int, attempt: int, cohorts: Dictionary, tracked: Dictionary) -> void:
	var key: String = "%d-%d-%d" % [stage, attempt, wave]
	if not cohorts.has(key):
		cohorts[key] = {"stage": stage, "wave": wave, "attempt": attempt, "spawned": 0, "killed": 0, "leaked": 0, "asteroid_spawned": 0, "asteroid_killed": 0, "asteroid_leaked": 0, "depth_weighted": 0.0}
	var asteroid: bool = str(e.kind) in ["rock", "heavy"]
	cohorts[key].spawned += int(e.initial_members)
	if asteroid: cohorts[key].asteroid_spawned += int(e.initial_members)
	tracked[int(e.id)] = {"entity": e, "previous": int(e.initial_members), "key": key, "asteroid": asteroid}
