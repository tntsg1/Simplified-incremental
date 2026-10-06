extends RefCounted

signal members_removed(point: Vector2, weapon: int, members: int, kind: String)
signal pierced(origin: Vector2, destination: Vector2, weapon: int)

signal notice(message: String)
signal checkpoint
signal stage_entered
signal fired(index: int, origin: Vector2, destination: Vector2, critical: bool)
signal turret_fired(slot: int, origin: Vector2, destination: Vector2, critical: bool)
signal body_fired(body_stage: int, slot: int, origin: Vector2, destination: Vector2, critical: bool)
signal body_converted(body_stage: int, slot: int)
signal hit(point: Vector2, weapon: int, amount: float, critical: bool, boss: bool, kind: String)
signal destroyed(point: Vector2, weapon: int, members: int, boss: bool, kind: String)

const Growth = preload("res://scripts/growth.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Catalog = preload("res://scripts/catalog.gd")
# Rewards grow slower than enemy HP, so upgrades must outpace each wave (sawtooth growth).
const REWARD_HP_EXPONENT: float = 0.4
# Turrets are real shooters: each fires on its own staggered beat. Together they
# deal 5% of the whole arsenal's firepower per turret bought.
# Rounds fly at one fixed, fast speed (the old speed upgrade added nothing real).
const PROJECTILE_SPEED: float = 1100.0
const TURRET_PERIOD: float = 0.25
const TURRET_SLOTS: int = 48
const TURRET_RINGS: Array[int] = [12, 16, 20]
# Celestial conversion: bodies drawn in each scale's scene can be clicked and
# turned into weapons. Each converted body fires on its own beat for a fixed
# share of the arsenal and keeps firing (from orbit round the core) in later scales.
const BODY_PERIOD: float = 0.4
const BODY_SHARE: float = 0.12
const BODY_PRICE_GROWTH: float = 2.2
const BODIES: Array = [
	[{"name": "西区摩天楼", "weapon": "楼顶炮台", "at": Vector2(150, 470), "size": 12.0}, {"name": "中央塔", "weapon": "塔顶导弹阵", "at": Vector2(330, 455), "size": 12.0}, {"name": "东区摩天楼", "weapon": "楼顶炮台", "at": Vector2(860, 470), "size": 12.0}],
	[{"name": "月球", "weapon": "月轨主炮", "orbit": 247.0, "angle": -0.13, "speed": 0.05, "size": 13.0}, {"name": "近地空间站", "weapon": "轨道炮站", "orbit": 190.0, "angle": 2.1, "speed": 0.11, "size": 8.0}, {"name": "同步卫星", "weapon": "激光卫星", "orbit": 190.0, "angle": 4.3, "speed": 0.11, "size": 8.0}],
	[{"name": "水星", "weapon": "水星炮", "orbit": 70.0, "angle": 0.2, "speed": 0.03, "size": 6.0}, {"name": "金星", "weapon": "金星炮", "orbit": 125.0, "angle": 1.92, "speed": 0.015, "size": 8.0}, {"name": "火星", "weapon": "火星炮", "orbit": 180.0, "angle": 3.64, "speed": 0.01, "size": 9.0}, {"name": "木星", "weapon": "木星巨炮", "orbit": 235.0, "angle": 5.36, "speed": 0.0075, "size": 12.0}, {"name": "土星", "weapon": "土星环炮", "orbit": 290.0, "angle": 0.8, "speed": 0.006, "size": 11.0}, {"name": "太阳", "weapon": "戴森球", "orbit": 0.0, "angle": 0.0, "speed": 0.0, "size": 42.0}],
	[{"name": "天狼星", "weapon": "天狼星炮", "orbit": 160.0, "angle": 0.1, "speed": 0.02, "size": 7.0}, {"name": "参宿四", "weapon": "红巨星炮", "orbit": 230.0, "angle": 1.7, "speed": 0.015, "size": 9.0}, {"name": "织女星", "weapon": "织女星炮", "orbit": 200.0, "angle": 3.3, "speed": 0.018, "size": 7.0}, {"name": "大角星", "weapon": "大角星炮", "orbit": 260.0, "angle": 4.8, "speed": 0.012, "size": 8.0}, {"name": "银心黑洞", "weapon": "黑洞引擎", "orbit": 0.0, "angle": 0.0, "speed": 0.0, "size": 14.0}],
	[{"name": "仙女座星系", "weapon": "仙女座阵列", "orbit": 215.0, "angle": 0.0, "speed": 0.0, "size": 18.0}, {"name": "三角座星系", "weapon": "三角座阵列", "orbit": 215.0, "angle": 2.4, "speed": 0.0, "size": 18.0}, {"name": "大麦哲伦云", "weapon": "麦哲伦阵列", "orbit": 215.0, "angle": 4.8, "speed": 0.0, "size": 18.0}, {"name": "小麦哲伦云", "weapon": "麦哲伦副阵", "orbit": 215.0, "angle": 7.2, "speed": 0.0, "size": 18.0}, {"name": "人马矮星系", "weapon": "人马阵列", "orbit": 215.0, "angle": 9.6, "speed": 0.0, "size": 18.0}, {"name": "大熊矮星系", "weapon": "大熊阵列", "orbit": 215.0, "angle": 12.0, "speed": 0.0, "size": 18.0}, {"name": "天龙矮星系", "weapon": "天龙阵列", "orbit": 215.0, "angle": 14.4, "speed": 0.0, "size": 18.0}],
	[{"name": "长城节点", "weapon": "长城引擎", "node": 5, "size": 8.0}, {"name": "室女座节点", "weapon": "室女座引擎", "node": 9, "size": 8.0}, {"name": "后发座节点", "weapon": "后发座引擎", "node": 14, "size": 8.0}, {"name": "巨引源", "weapon": "巨引源引擎", "node": 20, "size": 9.0}, {"name": "拉尼亚凯亚", "weapon": "超星系团引擎", "node": 26, "size": 9.0}, {"name": "牧夫座空洞", "weapon": "空洞引擎", "node": 31, "size": 9.0}],
]
const WAVE_GROUPS: Array[int] = [32, 48, 64, 80, 104, 128, 160, 192, 224, 256]
# Waves hold three times the threats at a third of the bounty each: a flood on
# screen with the same economy.
const WAVE_SCALE: int = 3
# Waves arrive as surges: a crowd floods in over ~1.4 s, gets shredded, then the
# next one comes. A steady trickle could never fill the screen.
const SURGE_SPREAD: float = 1.4
var catalog = Catalog.new()
var rng := RandomNumberGenerator.new()
var mode: String = "title"
var stage: int = 0
var wave: int = 1
var money: float = 0.0
var health: float = 100.0
var levels: Dictionary = {"damage": 0, "speed": 0, "reload": 0, "crit": 0, "area": 0, "pierce": 0, "targets": 0, "turrets": 0}
var owned: Array[bool] = [true, false, false, false, false, false]
var automation: bool = false
var paused: bool = false
var manual_held: bool = false
var manual_queued: bool = false
var priority_id: int = -1
var elapsed: float = 0.0
var wave_elapsed: float = 0.0
var mode_time: float = 0.0
var spawn_clock: float = 0.0
var surge_spawned: int = 0
# Converted celestial bodies: one bitmask per scale.
var bodies: Array[int] = [0, 0, 0, 0, 0, 0]
var spawn_left: int = 0
var wave_total: int = 0
var wave_killed: int = 0
var kills: int = 0
var attempts: int = 0
var stage_bosses: int = 0
var serial: int = 0
var boss_remaining: float = 0.0
var transition_from: int = 0
var transition_length: float = 7.0
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var enemy_pool: Array[Dictionary] = []
var shot_pool: Array[Dictionary] = []
var effect_pool: Array[Dictionary] = []
var weapon_damage: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var last_reward: float = 0.0
var boss_spawned: int = 0

func _init() -> void:
	rng.seed = 4262026
	for i in range(200):
		enemy_pool.append({})
	for i in range(512):
		shot_pool.append({})
	for i in range(180):
		effect_pool.append({})

func stage_data() -> Resource:
	return catalog.stages[stage]

func start_new(seed_value: int = 4262026) -> void:
	Campaign.start_new(self, seed_value)

func defense_position() -> Vector2:
	return Vector2(500.0, 572.0) if stage == 0 else Vector2(500.0, 325.0)

func weapon_origin(index: int) -> Vector2:
	if stage == 0:
		return Vector2(380.0 + index * 48.0, 565.0)
	var angle: float = -PI * 0.15 + index * TAU / 6.0
	var radius: float = 108.0 + index * 11.0
	return defense_position() + Vector2(cos(angle), sin(angle)) * radius

func damage_multiplier() -> float:
	return Growth.damage_multiplier(self)

func launcher_count() -> int:
	return Growth.launcher_count(self)

func shot_interval(index: int) -> float:
	return Growth.shot_interval(self, index)

func salvo_packets(index: int) -> float:
	return Growth.salvo_packets(self, index)

func shot_damage(index: int) -> float:
	return Growth.shot_damage(self, index)

func coverage(index: int) -> int:
	return Growth.coverage(self, index)

func crit_chance() -> float:
	return Growth.crit_chance(self)

func crit_multiplier() -> float:
	return Growth.crit_multiplier(self)

func nominal_dps() -> float:
	return Growth.nominal_dps(self)

func upgrade_cost(index: int, count: int = 1) -> float:
	return Growth.upgrade_cost(self, index, count)

func buy_upgrade(index: int, requested: int = 1) -> int:
	return Growth.buy_upgrade(self, index, requested)

func automation_available() -> bool:
	return Growth.automation_available(self)

func buy_automation() -> bool:
	return Growth.buy_automation(self)

func buy_weapon() -> bool:
	return Growth.buy_weapon(self)

func clear_battle() -> void:
	for e in enemies:
		enemy_pool.append(e)
	enemies.clear()
	for p in shots:
		shot_pool.append(p)
	shots.clear()
	priority_id = -1
	manual_held = false

func start_wave() -> void:
	Campaign.start_wave(self)

func hp_scale(at_wave: int = -1) -> float:
	var w: int = wave if at_wave < 0 else at_wave
	return float(stage_data().hp_base_scale) * pow(float(stage_data().hp_growth), w - 1)

func reward_scale() -> float:
	return pow(hp_scale(), REWARD_HP_EXPONENT)

func wave_seconds() -> float:
	return 25.0 + 7.0 * (wave - 1)

func surge_count() -> int:
	return 1 if wave_total <= 3 else clampi(2 + (wave - 1) / 3, 2, 5)

func surge_groups() -> int:
	var groups: int = ceili(float(wave_total) / group_size())
	return maxi(1, ceili(float(groups) / surge_count()))

func group_size() -> int:
	if stage == 0:
		return 1
	return maxi(1, ceili(float(wave_total) / WAVE_GROUPS[wave - 1]))

func wave_density() -> int:
	return 1 if stage==0 else int(stage_data().wave_density[wave-1])

func spawn_interval(members: int) -> float:
	return wave_seconds() * members / maxf(1.0, float(wave_total))

func spawn_enemy(members: int) -> void:
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.clear()
	serial += 1
	var alien: bool = stage >= 2 and rng.randf() < 0.5
	if stage == 1:
		alien = rng.randf() < 0.2
	var elite: bool = stage >= 1 and serial % 9 == 0
	if elite:
		members=1
	var kind: String = "ship" if alien else "rock"
	if elite:
		kind = "elite_ship" if alien else "heavy"
	var origin: Vector2
	var end: Vector2
	if stage == 0:
		origin = Vector2(rng.randf_range(130.0, 870.0), -20.0)
		end = Vector2(origin.x + rng.randf_range(-70.0, 70.0), 570.0)
	else:
		var a: float = rng.randf_range(-PI, PI)
		origin = Vector2(500.0, 315.0) + Vector2(cos(a) * 560.0, sin(a) * 300.0)
		end = defense_position() + (origin - defense_position()).normalized() * 68.0
	var lifetime: float = rng.randf_range(16.0, 22.0) if stage == 0 else rng.randf_range(17.0, 23.0)
	if elite:
		lifetime *= 0.74
	# Flood waves split the same total HP across WAVE_SCALE times the threats.
	var unit_hp: float = (300.0 if elite else 100.0) * hp_scale() / (WAVE_SCALE if stage > 0 else 1)
	e.merge({"id": serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": lifetime, "members": members, "initial_members": members, "unit_hp": unit_hp, "hp": unit_hp, "kind": kind, "elite": elite, "seed": rng.randi_range(1, 99999), "reserved": 0.0, "radius": 12.0 + (8.0 if elite else 0.0) + (minf(22.0, log(float(members)) * 3.0) if members > 1 else 0.0), "boss": false, "dead": false})
	enemies.append(e)

func start_boss() -> void:
	Campaign.start_boss(self)

func find_enemy(id: int) -> Dictionary:
	for e in enemies:
		if int(e.id) == id and not bool(e.dead):
			return e
	return {}

func select_target(point: Vector2) -> int:
	var nearest: float = INF
	var result: int = -1
	for e in enemies:
		if bool(e.dead):
			continue
		var distance: float = point.distance_to(e.pos)
		if distance < nearest and distance < maxf(60.0, float(e.radius) + 12.0):
			nearest = distance
			result = int(e.id)
	if result >= 0:
		priority_id = result
	return result

func pending_hp(e: Dictionary) -> float:
	return float(e.hp) + (int(e.members) - 1) * float(e.unit_hp) - float(e.reserved)

func target_for_weapon() -> Dictionary:
	var explicit: Dictionary = find_enemy(priority_id)
	if not explicit.is_empty() and pending_hp(explicit) > 0.0001:
		return explicit
	var best: Dictionary = {}
	var remaining: float = INF
	for e in enemies:
		if bool(e.dead) or pending_hp(e) <= 0.0001:
			continue
		var t: float = float(e.lifetime) - float(e.age)
		if t < remaining:
			remaining = t
			best = e
	return best

func fire_weapon(index: int, target: Dictionary) -> void:
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = shot_damage(index)
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = coverage(index)
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = weapon_origin(index)
	var destination: Vector2 = target.pos
	var speed: float = PROJECTILE_SPEED
	var duration: float = origin.distance_to(destination) / speed
	if bool(catalog.weapons[index].beam):
		duration = 0.12
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, duration), "damage": amount, "effective": effective, "coverage": cap, "weapon": index, "crit": critical, "beam": bool(catalog.weapons[index].beam)})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	fired.emit(index,origin,destination,critical)

func turret_count() -> int:
	return mini(TURRET_SLOTS, int(levels.get("turrets", 0)))

func turret_position(slot: int) -> Vector2:
	if stage == 0:
		var side: float = -1.0 if slot % 2 == 0 else 1.0
		return Vector2(500.0 + side * (56.0 + (slot / 2) * 24.0), 586.0)
	var count: int = turret_count()
	var placed: int = 0
	var radius: float = 74.0
	for ring in range(TURRET_RINGS.size()):
		var in_ring: int = mini(TURRET_RINGS[ring], count - placed)
		if slot < placed + in_ring:
			var a: float = (slot - placed) * TAU / in_ring + ring * 0.3
			return defense_position() + Vector2(cos(a), sin(a)) * radius
		placed += in_ring
		radius += 12.0
	return defense_position()

func arsenal_rate(value: Callable) -> float:
	var total: float = 0.0
	for i in range(6):
		if owned[i]:
			total += float(value.call(i)) / shot_interval(i)
	return total

func turret_shot_damage() -> float:
	return 0.05 * int(levels.get("turrets", 0)) * arsenal_rate(shot_damage) * TURRET_PERIOD / maxi(1, turret_count())

func turret_coverage() -> int:
	return maxi(1, int(0.05 * int(levels.get("turrets", 0)) * arsenal_rate(coverage) * TURRET_PERIOD / maxi(1, turret_count())))

func turret_lanes() -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	for e in enemies:
		if not bool(e.dead):
			lanes.append(e)
	lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.lifetime) - float(a.age) < float(b.lifetime) - float(b.age))
	return lanes

func body_converted_at(body_stage: int, slot: int) -> bool:
	return (bodies[body_stage] >> slot) & 1 == 1

func converted_count(body_stage: int) -> int:
	var n: int = 0
	for k in range(BODIES[body_stage].size()):
		if body_converted_at(body_stage, k):
			n += 1
	return n

func total_bodies() -> int:
	var n: int = 0
	for s in range(stage + 1):
		n += converted_count(s)
	return n

func body_cost() -> float:
	var base: float = 80.0 if stage == 0 else float(stage_data().weapon_price) * 2.0
	return base * pow(BODY_PRICE_GROWTH, converted_count(stage))

func convert_body(slot: int) -> bool:
	if slot < 0 or slot >= BODIES[stage].size() or body_converted_at(stage, slot) or mode in ["title", "transition", "victory"]:
		return false
	var price: float = body_cost()
	if money + 0.00001 < price:
		return false
	money -= price
	bodies[stage] |= 1 << slot
	body_converted.emit(stage, slot)
	notice.emit(str(BODIES[stage][slot].name) + "改造完成 · " + str(BODIES[stage][slot].weapon) + "上线")
	checkpoint.emit()
	return true

func scene_body_position(body_stage: int, slot: int) -> Vector2:
	# Where the body sits in its own scale's scene (orbits follow game time).
	var spec: Dictionary = BODIES[body_stage][slot]
	var c := Vector2(500.0, 325.0)
	if spec.has("at"):
		return spec.at
	if spec.has("node"):
		var i: int = int(spec.node)
		var r: float = sqrt(float(i) / 34.0) * 290.0
		return c + Vector2(cos(i * 2.399), sin(i * 2.399)) * r
	var a: float = float(spec.angle) + elapsed * float(spec.speed)
	return c + Vector2(cos(a), sin(a)) * float(spec.orbit)

func body_position(body_stage: int, slot: int) -> Vector2:
	if body_stage == stage:
		return scene_body_position(body_stage, slot)
	# Bodies from smaller scales have shrunk into an orbit round the core.
	var index: int = 0
	for s in range(body_stage):
		index += BODIES[s].size()
	index += slot
	var a: float = index * 0.71 + elapsed * 0.25
	var radius: float = 150.0 + (index % 3) * 14.0
	return defense_position() + Vector2(cos(a), sin(a) * (0.55 if stage == 0 else 1.0)) * radius

func body_shot_damage() -> float:
	return BODY_SHARE * arsenal_rate(shot_damage) * BODY_PERIOD

func body_coverage() -> int:
	return maxi(1, int(BODY_SHARE * arsenal_rate(coverage) * BODY_PERIOD))

func fire_body(body_stage: int, slot: int, target: Dictionary) -> void:
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = body_shot_damage()
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = body_coverage()
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = body_position(body_stage, slot)
	var destination: Vector2 = target.pos
	var speed: float = PROJECTILE_SPEED
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, origin.distance_to(destination) / speed), "damage": amount, "effective": effective, "coverage": cap, "weapon": mini(body_stage, 5), "crit": critical, "beam": false, "body": slot})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	body_fired.emit(body_stage, slot, origin, destination, critical)

func fire_turret(slot: int, target: Dictionary) -> void:
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = turret_shot_damage()
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = turret_coverage()
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = turret_position(slot)
	var destination: Vector2 = target.pos
	var speed: float = PROJECTILE_SPEED
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, origin.distance_to(destination) / speed), "damage": amount, "effective": effective, "coverage": cap, "weapon": 0, "crit": critical, "beam": false, "turret": slot})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	turret_fired.emit(slot, origin, destination, critical)

func add_effect(point: Vector2, kind: String, amount: float = 0.0, weapon: int = 0) -> void:
	if effects.size() >= 160:
		return
	var f: Dictionary = effect_pool.pop_back() if not effect_pool.is_empty() else {}
	f.clear()
	f.merge({"pos": point, "kind": kind, "age": 0.0, "duration": 0.8 if kind != "reward" else 1.3, "amount": amount, "weapon": weapon})
	effects.append(f)

func apply_damage(e: Dictionary, amount: float, cap: int, weapon_index: int, critical: bool=false) -> float:
	if bool(e.dead):
		return 0.0
	if bool(e.boss):
		var used: float = minf(float(e.hp), amount)
		e.hp = maxf(0.0, float(e.hp) - amount)
		e["flash"]=.09
		hit.emit(e.pos,weapon_index,used,critical,true,str(e.kind))
		weapon_damage[weapon_index] += used
		if float(e.hp) <= 0.0:
			e.dead = true
			add_effect(e.pos,"boss_burst",e.radius,weapon_index)
			destroyed.emit(e.pos,weapon_index,1,true,str(e.kind))
		return used
	var budget: float = minf(amount, float(cap) * float(e.unit_hp))
	var initial_budget: float = budget
	var old_count: int = int(e.members)
	e["flash"]=.12
	hit.emit(e.pos,weapon_index,minf(amount,float(old_count)*float(e.unit_hp)),critical,false,str(e.kind))
	if budget < float(e.hp):
		e.hp = float(e.hp) - budget
		weapon_damage[weapon_index] += budget
		return budget
	budget -= float(e.hp)
	var removed: int = mini(old_count, 1 + int(floor(budget / float(e.unit_hp))))
	removed = mini(removed, cap)
	e.members = old_count - removed
	var consumed: float = float(e.hp) + (removed - 1) * float(e.unit_hp)
	if int(e.members) > 0:
		var remainder: float = minf(maxf(0.0, budget - (removed - 1) * float(e.unit_hp)), float(e.unit_hp) - 0.00001)
		e.hp = float(e.unit_hp) - remainder
		consumed += remainder
	else:
		e.hp = 0.0
		e.dead = true
	var reward: float = removed * 10.0 * float(stage_data().reward_multiplier) / wave_density() / (WAVE_SCALE if stage > 0 else 1) * (2.0 if bool(e.elite) else 1.0) * reward_scale()
	money += reward
	last_reward = reward
	kills += removed
	if removed>1 and not bool(e.dead):members_removed.emit(e.pos,weapon_index,removed,str(e.kind))
	wave_killed += removed
	weapon_damage[weapon_index] += minf(initial_budget, consumed)
	if bool(e.dead):
		destroyed.emit(e.pos,weapon_index,int(e.initial_members),false,str(e.kind))
		add_effect(e.pos, "burst", float(e.radius), weapon_index)
		add_effect(e.pos, "reward", reward, weapon_index)
	return minf(initial_budget, consumed)

func advance(delta: float, visuals: bool = true) -> void:
	if paused or mode in ["title", "failed", "victory"]:
		return
	elapsed += delta
	mode_time += delta
	for i in range(effects.size() - 1, -1, -1):
		var fx: Dictionary = effects[i]
		fx.age = float(fx.age) + delta
		if float(fx.age) >= float(fx.duration) or not visuals:
			effect_pool.append(fx)
			effects.remove_at(i)
	if Campaign.advance_phase(self):
		return
	if mode not in ["wave", "boss"]:
		return
	wave_elapsed += delta
	if mode == "wave" and spawn_left > 0:
		spawn_clock -= delta
		# Cleared the field? The next surge rolls in almost at once, so a strong
		# defense pushes through waves faster instead of staring at empty space.
		if surge_spawned == 0 and spawn_clock > 0.6 and enemies.is_empty():
			spawn_clock = 0.6
		while spawn_clock <= 0.0 and spawn_left > 0:
			var members: int = mini(spawn_left, group_size())
			if stage >= 1 and (serial + 1) % 9 == 0:
				members = 1
			spawn_enemy(members)
			spawn_left -= members
			surge_spawned += 1
			if surge_spawned >= surge_groups():
				surge_spawned = 0
				spawn_clock += wave_seconds() / surge_count()
			else:
				spawn_clock += SURGE_SPREAD / surge_groups()
	for e in enemies:
		if bool(e.dead):
			continue
		e["flash"]=maxf(0,float(e.get("flash",0))-delta)
		e.age = float(e.age) + delta
		var ratio: float = clampf(float(e.age) / float(e.lifetime), 0.0, 1.0)
		e.pos = Vector2(e.start).lerp(e.end, ratio)
	# Ready heavy weapons reserve group damage first; fast legacy launchers fill gaps.
	for i in range(5, -1, -1):
		cooldowns[i] -= delta
		if not owned[i] or cooldowns[i] > 0.0:
			continue
		if automation or manual_held or manual_queued:
			var target: Dictionary = target_for_weapon() if automation else find_enemy(priority_id)
			if not target.is_empty() and pending_hp(target)<=0:
				target={}
			if not target.is_empty():
				fire_weapon(i, target)
				cooldowns[i] = shot_interval(i)
				manual_queued = false
	# Stateless staggered beat: turret k fires when its phase crosses a period
	# boundary, so saves need no turret cooldowns and replay deterministically.
	# Turrets are automatic and always busy: turret k takes the k-th soonest
	# living threat (ignoring damage the main guns have already reserved), so
	# the whole array sweeps every group at once instead of idling.
	var turret_total: int = turret_count()
	if turret_total > 0:
		var lanes: Array[Dictionary] = []
		var lanes_built: bool = false
		for k in range(turret_total):
			var phase: float = TURRET_PERIOD * k / turret_total
			if floor((elapsed + phase) / TURRET_PERIOD) > floor((elapsed - delta + phase) / TURRET_PERIOD):
				var target: Dictionary = {}
				if not lanes_built:
					lanes = turret_lanes()
					lanes_built = true
				var explicit: Dictionary = find_enemy(priority_id)
				if not explicit.is_empty() and k % 2 == 0:
					target = explicit
				elif not lanes.is_empty():
					target = lanes[k % lanes.size()]
				if not target.is_empty():
					fire_turret(k, target)
	# Converted bodies keep a staggered beat of their own, fanned like turrets.
	var body_total: int = total_bodies()
	if body_total > 0:
		var body_lanes: Array[Dictionary] = []
		var body_lanes_built: bool = false
		var beat: int = 0
		for s in range(stage + 1):
			for k in range(BODIES[s].size()):
				if not body_converted_at(s, k):
					continue
				var phase: float = BODY_PERIOD * beat / body_total
				beat += 1
				if floor((elapsed + phase) / BODY_PERIOD) > floor((elapsed - delta + phase) / BODY_PERIOD):
					if not body_lanes_built:
						body_lanes = turret_lanes()
						body_lanes_built = true
					if not body_lanes.is_empty():
						fire_body(s, k, body_lanes[(beat * 3) % body_lanes.size()])
	for i in range(shots.size() - 1, -1, -1):
		var p: Dictionary = shots[i]
		p.age = float(p.age) + delta
		var target: Dictionary = find_enemy(int(p.target))
		if not target.is_empty():
			p.end = target.pos
		var t: float = clampf(float(p.age) / float(p.duration), 0.0, 1.0)
		p.pos = Vector2(p.from).lerp(p.end, t)
		if t >= 1.0 or target.is_empty():
			if not target.is_empty():
				target.reserved = maxf(0.0, float(target.reserved) - float(p.effective))
				var spent: float = apply_damage(target, float(p.damage), int(p.coverage), int(p.weapon),bool(p.crit))
				if stage >= 3 and int(levels.pierce) > 0 and float(p.damage) > spent:
					var spare: float = float(p.damage) - spent
					var radius: float = 55.0 + int(levels.area) * 2.0
					var traced: int=0
					for other in enemies:
						if other != target and not bool(other.dead) and Vector2(other.pos).distance_to(target.pos) < radius:
							spare -= apply_damage(other, spare, int(p.coverage), int(p.weapon))
							if visuals and traced<3:
								pierced.emit(target.pos,other.pos,int(p.weapon))
								traced+=1
							if spare <= 0.0:
								break
				if visuals:
					add_effect(p.end, "impact", 10.0 if not bool(p.crit) else 20.0, int(p.weapon))
			shot_pool.append(p)
			shots.remove_at(i)
	if mode == "boss":
		boss_remaining = maxf(0.0, float(stage_data().boss_window) - wave_elapsed)
		var defeated: bool = false
		for e in enemies:
			if bool(e.boss) and bool(e.dead):
				defeated = true
		if defeated:
			finish_boss()
			return
		if boss_remaining <= 0.0:
			fail_stage()
			return
	else:
		for e in enemies:
			if not bool(e.dead) and float(e.age) >= float(e.lifetime):
				var fraction: float = float(e.members) / maxi(1, int(e.initial_members))
				var impact: float = (25.0 if int(e.initial_members) > 1 or bool(e.elite) else 10.0) * fraction
				health = maxf(0.0, health - maxf(1.0, impact))
				e.dead = true
				if visuals:
					add_effect(e.pos, "breach", 25.0)
				if health <= 0.0:
					fail_stage()
					return
	for i in range(enemies.size() - 1, -1, -1):
		if bool(enemies[i].dead):
			enemy_pool.append(enemies[i])
			enemies.remove_at(i)
	if mode == "wave" and spawn_left == 0 and enemies.is_empty():
		mode = "intermission"
		mode_time = 0.0
		health = 100.0
		manual_held = false
		notice.emit("第 %d 波完成 · 防线已恢复" % wave)
		checkpoint.emit()

func finish_boss() -> void:
	Campaign.finish_boss(self)

func fail_stage() -> void:
	Campaign.fail_stage(self)

func retry() -> void:
	Campaign.retry(self)

func progress() -> float:
	return Campaign.progress(self)

func encode_entity(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	for key in ["pos", "start", "end", "from"]:
		if out.has(key) and out[key] is Vector2:
			var p: Vector2 = out[key]
			out[key] = [p.x, p.y]
	return out

func decode_entity(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	for key in ["pos", "start", "end", "from"]:
		if out.has(key) and out[key] is Array:
			out[key] = Vector2(float(out[key][0]), float(out[key][1]))
	return out

func snapshot() -> Dictionary:
	var actors: Array = []
	var projectiles: Array = []
	for e in enemies:
		actors.append(encode_entity(e))
	for p in shots:
		projectiles.append(encode_entity(p))
	return {"game": "skyguard", "version": 1, "stage": stage, "wave": wave, "mode": mode, "money": money, "health": health, "levels": levels.duplicate(), "owned": owned.duplicate(), "automation": automation, "elapsed": elapsed, "wave_elapsed": wave_elapsed, "mode_time": mode_time, "spawn_clock": spawn_clock, "surge_spawned": surge_spawned, "bodies": bodies.duplicate(), "spawn_left": spawn_left, "wave_total": wave_total, "wave_killed": wave_killed, "kills": kills, "attempts": attempts, "stage_bosses": stage_bosses, "boss_spawned": boss_spawned, "serial": serial, "boss_remaining": boss_remaining, "transition_from": transition_from, "priority_id": priority_id, "cooldowns": cooldowns.duplicate(), "weapon_damage": weapon_damage.duplicate(), "rng_state": str(rng.state), "enemies": actors, "shots": projectiles}

func restore(data: Dictionary) -> bool:
	if str(data.get("game", "")) != "skyguard" or int(data.get("version", 0)) != 1:
		return false
	if int(data.get("stage", -1)) not in range(6) or int(data.get("wave", 0)) not in range(1, 11):
		return false
	if str(data.get("mode", "")) not in ["wave", "intermission", "boss", "transition", "failed", "victory"]:
		return false
	if not data.get("levels", {}) is Dictionary or not data.get("owned", []) is Array or data.get("owned", []).size() != 6:
		return false
	for key in levels:
		# Saves from before the turret upgrade simply start it at zero.
		if key == "turrets" and not data.levels.has(key):
			continue
		if not data.levels.has(key) or int(data.levels[key]) < 0 or int(data.levels[key]) > 1000:
			return false
	var saved_money: float = float(data.get("money", -1))
	if not is_finite(saved_money) or saved_money < 0.0:
		return false
	for key in ["health","elapsed","wave_elapsed","mode_time","spawn_clock","spawn_left","wave_total","wave_killed","kills","attempts","stage_bosses","serial","boss_remaining","transition_from","priority_id","rng_state","automation"]:
		if not data.has(key):
			return false
	for key in ["cooldowns","weapon_damage"]:
		if not data.get(key) is Array or data[key].size()!=6:
			return false
	for key in ["enemies","shots"]:
		if not data.get(key) is Array or data[key].size()>10000:
			return false
		for entity in data[key]:
			if not entity is Dictionary:
				return false
			var required: Array = ["id","pos","start","end","age","lifetime","members","initial_members","unit_hp","hp","kind","elite","seed","reserved","radius","boss","dead"] if key=="enemies" else ["target","from","pos","end","age","duration","damage","effective","coverage","weapon","crit","beam"]
			for field_name in required:
				if not entity.has(field_name):
					return false
			for vector_key in (["pos","start","end"] if key=="enemies" else ["from","pos","end"]):
				if not entity[vector_key] is Array or entity[vector_key].size()!=2:
					return false
			if key=="shots" and int(entity.weapon) not in range(6):
				return false
			if key=="enemies" and (float(entity.lifetime)<=0 or int(entity.members)<0):
				return false
	clear_battle()
	stage = int(data.stage)
	wave = int(data.wave)
	mode = str(data.mode)
	money = saved_money
	health = clampf(float(data.health), 0.0, 100.0)
	for key in levels:
		levels[key] = int(data.levels.get(key, 0))
	for i in range(6):
		owned[i] = bool(data.owned[i])
		cooldowns[i] = float(data.get("cooldowns", [0, 0, 0, 0, 0, 0])[i])
		weapon_damage[i] = float(data.get("weapon_damage", [0, 0, 0, 0, 0, 0])[i])
	owned[0] = true
	automation = bool(data.automation)
	elapsed = float(data.elapsed)
	wave_elapsed = float(data.wave_elapsed)
	mode_time = float(data.mode_time)
	spawn_clock = float(data.spawn_clock)
	spawn_left = int(data.spawn_left)
	surge_spawned = int(data.get("surge_spawned", 0))
	var saved_bodies: Variant = data.get("bodies", [])
	for s in range(6):
		bodies[s] = int(saved_bodies[s]) if saved_bodies is Array and saved_bodies.size() == 6 else 0
	wave_total = int(data.wave_total)
	wave_killed = int(data.wave_killed)
	kills = int(data.kills)
	attempts = int(data.attempts)
	stage_bosses = int(data.stage_bosses)
	boss_spawned = int(data.get("boss_spawned", 0))
	serial = int(data.serial)
	boss_remaining = float(data.boss_remaining)
	transition_from = int(data.transition_from)
	priority_id = int(data.priority_id)
	rng.state = int(str(data.rng_state))
	for e in data.get("enemies", []):
		enemies.append(decode_entity(e))
	for p in data.get("shots", []):
		shots.append(decode_entity(p))
	paused = false
	manual_held = false
	return true

func boss_max_hp() -> float:
	return float(stage_data().boss_hp) * hp_scale(10)
