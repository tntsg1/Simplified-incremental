extends SceneTree
# Damage share probe: who actually deals the damage at each chapter's boss —
# main arsenal, turret ring, converted bodies (nominal rates on the balanced route).
const Combat=preload("res://scripts/combat.gd")
const Route=preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	var c=Combat.new()
	c.start_new(4262026)
	var seen: Dictionary={}
	for tick in range(1500000):
		if tick%120==0:Route.buy(c,"balanced")
		c.manual_held=not c.automation
		if not c.automation:
			var t: Dictionary=c.target_for_weapon()
			if not t.is_empty():c.priority_id=int(t.id)
		if c.mode=="failed":c.retry()
		if c.mode=="victory":break
		if c.mode=="intermission" or (c.mode=="boss" and not seen.has(c.stage)):
			if c.mode=="boss" or not seen.has("w%d_%d"%[c.stage,c.wave]):
				seen["w%d_%d"%[c.stage,c.wave]]=true
				var sd: Dictionary=c.source_damage
				var sum: float=maxf(1.0,sd.main+sd.turret+sd.body)
				print("LANDED stage=%d wave=%d mode=%s main=%.0f%% turret=%.0f%% body=%.0f%%"%[c.stage,c.wave,c.mode,100*sd.main/sum,100*sd.turret/sum,100*sd.body/sum])
				c.source_damage={"main":0.0,"turret":0.0,"body":0.0}
		if c.mode=="boss" and not seen.has(c.stage):
			seen[c.stage]=true
			var arsenal: float=c.arsenal_rate(c.shot_damage)
			var tur: float=c.turret_shot_damage()/c.TURRET_PERIOD*c.turret_count()
			var bod: float=c.body_shot_damage()/c.BODY_PERIOD*c.total_bodies()
			var total: float=arsenal+tur+bod
			var shots: float=0.0
			for i in range(6):
				if c.owned[i]:shots+=1.0/c.shot_interval(i)
			print("STAGE %d arsenal=%.0f%% turrets=%.0f%% (n=%d lvl=%d) bodies=%.0f%% (n=%d) main_shots_per_s=%.1f barrage=%d" % [c.stage,100*arsenal/total,100*tur/total,c.turret_count(),int(c.levels.turrets),100*bod/total,c.total_bodies(),shots,0])
		c.advance(1.0/60,false)
	quit()
