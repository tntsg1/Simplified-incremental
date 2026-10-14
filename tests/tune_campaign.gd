extends SceneTree
# Chapter-by-chapter balance tuner. Plays the balanced purchase route (firing the
# doomsday weapon whenever it is charged, like an engaged player) and, for each
# chapter in turn, searches the threat HP scale so the ten waves take about the
# target time, then sizes the boss from the damage the route actually deals.
# Writes the overrides consumed by tools/generate_ten_stages.py.
# Usage: --script res://tests/tune_campaign.gd -- [out.json] [wave_target_seconds]
const Combat = preload("res://scripts/combat.gd")
const Route = preload("res://tests/purchase_route.gd")
const BOSS_SHARE: float = 0.68
const DEPTH: float = 0.28
const EARLY_CAP: float = 0.35
const GROWTH: float = 1.5
const GROWTHS: Array[float] = [3.0]
var wave_target: float = 300.0

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://tune_overrides.json"
	if args.size() > 1:
		wave_target = float(args[1])
	var c = Combat.new()
	c.start_new(4262026)
	var overrides: Dictionary = {}
	var total: float = 0.0
	# The manual city opening keeps its hand-tuned numbers.
	var city_time: float = play_until(c, 1, 1, 7200.0)
	print("TUNE stage=0 seconds=%.0f money=%s" % [city_time, sci(c.money)])
	total += city_time
	for s in range(1, c.STAGE_COUNT):
		var spec: Resource = c.catalog.stages[s]
		var entry: Dictionary = c.snapshot()
		var entry_money: float = c.money
		spec.weapon_price = nice(entry_money * 0.5)
		# Waves keep their schedule, so time is fixed; difficulty is HP. For each HP
		# growth, bisect the base scale toward an average depth of DEPTH with no
		# failure; prefer the growth whose early and late waves press equally.
		var start_ms: int = Time.get_ticks_msec()
		var pick_score: float = INF
		var pick_base: float = float(spec.hp_base_scale)
		var pick_growth: float = GROWTH
		for g in GROWTHS:
			spec.hp_growth = g
			var lo: float = log(maxf(1.0, float(spec.hp_base_scale) / 3e4))
			var hi: float = log(float(spec.hp_base_scale) * 1e2)
			var best: float = exp(lo)
			var best_result: Dictionary = {}
			var best_gap: float = INF
			for it in range(15):
				var mid: float = (lo + hi) * .5
				spec.hp_base_scale = exp(mid)
				c.restore(entry.duplicate(true))
				var result: Dictionary = waves_phase(c, s)
				var depth: float = float(result.depth)
				if int(result.fails) > 0 or depth > DEPTH:
					hi = mid
				else:
					lo = mid
				if int(result.fails) == 0 and absf(depth - DEPTH) < best_gap:
					best_gap = absf(depth - DEPTH)
					best = exp(mid)
					best_result = result
				if hi - lo < .08:
					break
			if best_result.is_empty():
				continue
			# Sawtooth: the chapter's opening waves should push in (early depth up to
			# EARLY_CAP); late waves are the player's reward. Lower growth wins ties.
			var score: float = -minf(float(best_result.early), EARLY_CAP) + g * .002
			print("  TRY stage=%d growth=%.1f hp=%s depth=%.2f early=%.2f late=%.2f" % [s, g, sci(best), float(best_result.depth), float(best_result.early), float(best_result.late)])
			if score < pick_score:
				pick_score = score
				pick_base = best
				pick_growth = g
			spec.hp_base_scale = best
		spec.hp_growth = pick_growth
		spec.hp_base_scale = pick_base
		print("  search %.1fs" % ((Time.get_ticks_msec() - start_ms) / 1000.0))
		# Boss: measure the route's damage over the window against an unkillable boss.
		c.restore(entry.duplicate(true))
		var waves: Dictionary = waves_phase(c, s)
		var dealt: float = boss_damage(c, s)
		spec.boss_hp = maxf(1.0, dealt * BOSS_SHARE / c.hp_scale(10))
		c.restore(entry.duplicate(true))
		var seconds_stage: float = play_until(c, s + 1, 1, 7200.0) if s < c.LAST_STAGE else play_to_victory(c)
		total += seconds_stage
		overrides[str(s)] = {"hp_base_scale": snapped_float(spec.hp_base_scale), "hp_growth": spec.hp_growth, "boss_hp": snapped_float(spec.boss_hp), "weapon_price": spec.weapon_price}
		print("TUNE stage=%d depth=%.2f hp=%s waves=%.0fs boss_hp=%s price=%s stage_seconds=%.0f retries=%d total_min=%.1f" % [s, float(waves.depth), sci(spec.hp_base_scale), float(waves.seconds), sci(spec.boss_hp), sci(spec.weapon_price), seconds_stage, c.attempts, total / 60.0])
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(overrides, "  "))
		file.close()
	print("TUNE_DONE total_minutes=%.1f retries=%d mode=%s" % [total / 60.0, c.attempts, c.mode])
	quit()

func snapped_float(v: float) -> float:
	var e: float = floor(log(v) / log(10.0))
	return snappedf(v / pow(10.0, e), .001) * pow(10.0, e)

func nice(v: float) -> float:
	if v < 100.0:
		return 100.0
	var e: float = pow(10.0, floor(log(v) / log(10.0)) - 1)
	return round(v / e) * e

func sci(x: float) -> String:
	if x < 1000:
		return "%.1f" % x
	var e: int = int(floor(log(x) / log(10.0)))
	return "%.2fe%d" % [x / pow(10.0, e), e]

var ultimates: bool = true
var boss_dealt: float = 0.0

func on_hit(_point: Vector2, _weapon: int, amount: float, _critical: bool, boss: bool, _kind: String) -> void:
	if boss:
		boss_dealt += amount

func step(c: RefCounted, tick: int) -> void:
	if tick % 120 == 0 and c.mode != "transition":
		Route.buy(c, "balanced")
	c.manual_held = not c.automation
	if not c.automation:
		var t: Dictionary = c.target_for_weapon()
		if not t.is_empty():
			c.priority_id = int(t.id)
	if ultimates and c.ultimate_ready():
		c.fire_ultimate()
	c.advance(1.0 / 60, false)

func waves_phase(c: RefCounted, s: int) -> Dictionary:
	# Ten waves of chapter s; a failure ends the measurement.
	var start: float = c.elapsed
	var fails: int = c.attempts
	# Depth: how far (0 = edge, 1 = impact) each threat got before it died.
	var last: Dictionary = {}
	var total: float = 0.0
	var samples: int = 0
	var half: Array[float] = [0.0, 0.0]
	var half_n: Array[int] = [0, 0]
	for tick in range(600000):
		if c.mode == "failed" or c.attempts > fails:
			return {"seconds": c.elapsed - start, "fails": 1, "depth": 1.0, "early": 1.0, "late": 1.0}
		if c.stage != s or c.mode in ["intermission", "boss"]:
			break
		step(c, tick)
		if tick % 6 == 0:
			var now: Dictionary = {}
			for e in c.enemies:
				if not bool(e.boss) and not bool(e.get("fragment", false)):
					now[int(e.id)] = float(e.age) / float(e.lifetime)
			for id in last:
				if not now.has(id) and float(last[id]) < .97:
					total += float(last[id])
					samples += 1
					var h: int = 0 if c.wave <= 5 else 1
					half[h] += float(last[id])
					half_n[h] += 1
			last = now
	return {"seconds": c.elapsed - start, "fails": 0, "depth": total / maxi(1, samples), "early": half[0] / maxi(1, half_n[0]), "late": half[1] / maxi(1, half_n[1])}

func boss_damage(c: RefCounted, s: int) -> float:
	var spec: Resource = c.catalog.stages[s]
	var saved: float = float(spec.boss_hp)
	spec.boss_hp = 1e250
	# Measured without the doomsday weapon; one strike (20%) is budgeted below.
	ultimates = false
	for tick in range(600000):
		if c.mode == "boss":
			break
		step(c, tick)
	var window: float = float(spec.boss_window)
	var start: float = c.elapsed
	boss_dealt = 0.0
	if not c.hit.is_connected(on_hit):
		c.hit.connect(on_hit)
	for tick in range(600000):
		if c.mode != "boss" or c.elapsed - start >= window:
			break
		step(c, tick)
	c.hit.disconnect(on_hit)
	spec.boss_hp = saved
	ultimates = true
	return boss_dealt / (1.0 - c.ULT_BOSS_SHARE)

func play_until(c: RefCounted, stage: int, wave: int, cap: float) -> float:
	var start: float = c.elapsed
	for tick in range(5000000):
		if c.mode == "failed":
			c.retry()
		if c.stage >= stage and c.wave >= wave and c.mode == "wave":
			break
		if c.elapsed - start > cap:
			break
		step(c, tick)
	return c.elapsed - start

func play_to_victory(c: RefCounted) -> float:
	var start: float = c.elapsed
	for tick in range(5000000):
		if c.mode == "failed":
			c.retry()
		if c.mode == "victory" or c.elapsed - start > 7200.0:
			break
		step(c, tick)
	return c.elapsed - start
