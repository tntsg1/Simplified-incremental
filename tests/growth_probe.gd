extends SceneTree
# Growth-feel probe: runs the balanced purchase route through the campaign and
# prints, per wave, how deep threats get before dying (0 = at spawn, 1 = impact)
# plus damage/coverage headroom. Target: sawtooth, not a flat 0.00.
# Optional overrides: -- --set=<stage>,<hp_base_scale>,<hp_growth>[,<boss_hp>]
const Combat=preload("res://scripts/combat.gd")
const Route=preload("res://tests/purchase_route.gd")

func sci(x: float) -> String:
	if x<1000:return "%.1f"%x
	var e: int=int(floor(log(x)/log(10.0)))
	return "%.1fe%d"%[x/pow(10.0,e),e]

func _initialize() -> void:
	var c=Combat.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			var v: PackedStringArray=arg.trim_prefix("--set=").split(",")
			var spec: Resource=c.catalog.stages[int(v[0])]
			spec.hp_base_scale=float(v[1])
			spec.hp_growth=float(v[2])
			if v.size()>3:spec.boss_hp=float(v[3])
	c.start_new(4262026)
	var last: Dictionary={}
	var depths: Array[float]=[]
	var key: String=""
	var started: float=0
	var peak: int=0
	var headroom: String=""
	for tick in range(1500000):
		if tick%120==0:Route.buy(c,"balanced")
		c.manual_held=not c.automation
		if not c.automation:
			var t: Dictionary=c.target_for_weapon()
			if not t.is_empty():c.priority_id=int(t.id)
		if c.mode=="failed":
			print("  FAIL ",key," health=",c.health," boss_hp_left=",sci(c.enemies[0].hp) if c.mode=="boss" and not c.enemies.is_empty() else "")
			c.retry()
		if c.mode=="victory":break
		if c.mode in ["wave","boss"]:
			var k: String="%d-%s"%[c.stage,str(c.wave) if c.mode=="wave" else "B"]
			if k!=key:
				key=k;started=c.elapsed;depths.clear();peak=0;last.clear()
				var dmg: float=0
				var cov: float=0
				for i in range(6):
					if c.owned[i]:
						dmg+=c.shot_damage(i)/c.shot_interval(i)/(100.0*c.hp_scale())*(1.0+0.05*int(c.levels.get("turrets",0)))
						cov+=c.coverage(i)/c.shot_interval(i)
				var need: float=c.wave_total/c.wave_seconds() if c.mode=="wave" else 0.0
				headroom=" dmg_x=%s cov_x=%s"%[sci(dmg/maxf(need,1e-9)),sci(cov/maxf(need,1e-9))] if c.mode=="wave" else " boss_hp=%s dps=%s"%[sci(c.boss_max_hp()),sci(c.nominal_dps())]
		var active: bool=c.mode in ["wave","boss"]
		if active and tick%6==0:
			var now: Dictionary={}
			for e in c.enemies:now[int(e.id)]=float(e.age)/float(e.lifetime)
			for id in last:
				if not now.has(id) and last[id]<.97:depths.append(last[id])
			last=now
			peak=maxi(peak,c.enemies.size())
		c.advance(1.0/60,false)
		if active and c.mode not in ["wave","boss"]:
			var avg: float=0
			for d in depths:avg+=d
			print("WAVE %-5s %4ds depth=%.2f peak=%3d $%s%s"%[key,int(c.elapsed-started),avg/maxi(1,depths.size()),peak,sci(c.money),headroom])
	print("SUMMARY mode=",c.mode," hours=%.2f retries=%d"%[c.elapsed/3600,c.attempts])
	quit()
