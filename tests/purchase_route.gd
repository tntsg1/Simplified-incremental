extends RefCounted

static func buy(c: RefCounted, policy: String="balanced") -> void:
	if c.automation_available():
		c.buy_automation()
	if c.stage>0 and not c.owned[c.stage] and not c.buy_weapon():
		return
	var reserve: float=200 if c.stage==0 and not c.automation and c.wave>=5 else 0
	for purchase in range(60):
		var best: int=-1
		var score: float=0
		for i in range(c.catalog.upgrades.size()):
			var u: Resource=c.catalog.upgrades[i]
			if c.stage<int(u.unlock_stage):
				continue
			var cost: float=c.upgrade_cost(i)
			if policy=="balanced" and cost>c.money-reserve:
				continue
			var level: int=c.levels[u.key]
			var weight: float=0
			match u.key:
				"damage": weight=1.0
				"reload": weight=1.25 if level<30 else .8
				"speed": weight=.2 if level<3+c.stage*4 else 0
				"crit": weight=.23 if level<25 else .06
				"area": weight=.65 if level<c.stage*12 else .12
				"pierce": weight=.24 if level<c.stage*6 else .08
				"targets": weight=.3 if level<30 else .12
				"turrets": weight=.9
			if policy=="damage":
				if u.key=="damage":weight*=1.5
				elif u.key in ["area","pierce","targets"]:weight*=.8
			elif policy=="coverage":
				if u.key in ["area","pierce","targets"]:weight*=1.7
				elif u.key=="damage":weight*=.85
			if weight/cost>score:
				score=weight/cost
				best=i
		if best<0:
			break
		if c.upgrade_cost(best)>c.money-reserve:break
		c.buy_upgrade(best)
