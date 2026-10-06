extends RefCounted

static func damage_multiplier(ctx: RefCounted) -> float:
	var l: int = int(ctx.levels.damage)
	var bonuses: int = 0
	for threshold in [10, 25, 50, 75, 100, 125, 150]:
		if l >= threshold:
			bonuses += 1
	return pow(1.15, l) * pow(2.0, bonuses)


static func launcher_count(ctx: RefCounted) -> int:
	return int(pow(2.0, mini(int(ctx.levels.reload) / 10, 14)))


static func shot_interval(ctx: RefCounted, index: int) -> float:
	return maxf(1.0/30.0, float(ctx.catalog.weapons[index].interval) / pow(1.1, int(ctx.levels.reload)))


static func salvo_packets(ctx: RefCounted, index: int) -> float:
	# Pack sub-frame launches into a volley without losing the promised +10% cadence.
	var theoretical: float = float(ctx.catalog.weapons[index].interval) / pow(1.1, int(ctx.levels.reload))
	return maxf(1.0,(1.0/30.0)/theoretical)


static func shot_damage(ctx: RefCounted, index: int) -> float:
	var targeting: float = 1.0 + int(ctx.levels.targets) * 0.25
	return 50.0 * ctx.damage_multiplier() * float(ctx.catalog.weapons[index].damage_multiplier) * ctx.launcher_count() * targeting * ctx.salvo_packets(index)


static func coverage(ctx: RefCounted, index: int) -> int:
	if ctx.stage==0:return ctx.launcher_count()
	# Spatial overlap prevents thousands of colocated rounds from counting the
	# same blast footprint repeatedly. Raw single-target damage stays additive.
	var value: float = float(ctx.catalog.weapons[index].coverage) * sqrt(ctx.launcher_count()) * sqrt(ctx.salvo_packets(index))
	value *= 1.0+float(int(ctx.levels.damage)/25)*.1
	if ctx.stage >= 2:
		value *= 1.0 + int(ctx.levels.area) * 0.18
		value *= 1.3 if int(ctx.levels.area)>=10 else 1.0
		value *= 1.25 if int(ctx.levels.area)>=25 else 1.0
	value *= 1.0 + int(ctx.levels.pierce) * 0.25 + int(ctx.levels.targets) * 0.3
	# Coverage is the secondary stat; damage vs. rising HP is the main wall.
	value *= 12.0
	return maxi(1, int(value))


static func crit_chance(ctx: RefCounted) -> float:
	return minf(0.5, int(ctx.levels.crit) * 0.02)


static func crit_multiplier(ctx: RefCounted) -> float:
	return 2.0 + int(ctx.levels.crit) / 25


static func nominal_dps(ctx: RefCounted) -> float:
	var total: float = 0.0
	for i in range(6):
		if ctx.owned[i]:
			total += ctx.shot_damage(i) / ctx.shot_interval(i)
	# Turrets together add 5% of the arsenal per turret bought.
	total *= 1.0 + 0.05 * int(ctx.levels.get("turrets", 0))
	return total * (1.0 + ctx.crit_chance() * (ctx.crit_multiplier() - 1.0))


static func upgrade_cost(ctx: RefCounted, index: int, count: int = 1) -> float:
	var u: Resource = ctx.catalog.upgrades[index]
	var level: int = int(ctx.levels[u.key])
	var g: float = float(u.cost_growth)
	return float(u.base_cost) * pow(g, level) * (pow(g, count) - 1.0) / (g - 1.0)


static func buy_upgrade(ctx: RefCounted, index: int, requested: int = 1) -> int:
	if index < 0 or index >= ctx.catalog.upgrades.size():
		return 0
	var u: Resource = ctx.catalog.upgrades[index]
	if ctx.stage < int(u.unlock_stage):
		return 0
	var bought: int = 0
	for i in range(mini(requested, 1000)):
		var price: float = ctx.upgrade_cost(index)
		if ctx.money + 0.00001 < price:
			break
		ctx.money = maxf(0.0, ctx.money - price)
		ctx.levels[u.key] = int(ctx.levels[u.key]) + 1
		bought += 1
	if bought > 0:
		if u.key == "reload" and int(ctx.levels.reload) / 10 > (int(ctx.levels.reload) - bought) / 10:
			ctx.notice.emit("发射器进化 · 齐射规模翻倍")
		elif u.key == "damage":
			for threshold in [150,125,100,75,50,25,10]:
				if int(ctx.levels.damage)>=threshold and int(ctx.levels.damage)-bought<threshold:
					ctx.notice.emit("弹头突破 · Lv.%d 全体系伤害翻倍"%threshold)
					break
		ctx.checkpoint.emit()
	return bought


static func automation_available(ctx: RefCounted) -> bool:
	return not ctx.automation and (ctx.stage > 0 or ctx.wave >= 6)


static func buy_automation(ctx: RefCounted) -> bool:
	if not ctx.automation_available() or ctx.money < 200.0:
		return false
	ctx.money -= 200.0
	ctx.automation = true
	ctx.manual_held = false
	ctx.manual_queued = false
	ctx.notice.emit("自动防御已上线 · 点击目标即可指定集火")
	ctx.checkpoint.emit()
	return true


static func buy_weapon(ctx: RefCounted) -> bool:
	var price: float = float(ctx.stage_data().weapon_price)
	if ctx.owned[ctx.stage] or ctx.money < price:
		return false
	ctx.money -= price
	ctx.owned[ctx.stage] = true
	ctx.cooldowns[ctx.stage] = 0.0
	ctx.notice.emit(ctx.catalog.weapons[ctx.stage].title + "上线 · 全局升级已继承")
	ctx.checkpoint.emit()
	return true

