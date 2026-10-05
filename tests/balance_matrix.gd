extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Route=preload("res://tests/purchase_route.gd")
var failures: int=0
func _initialize() -> void:
	for policy in ["balanced","damage","coverage"]:
		if "--balanced-only" in OS.get_cmdline_user_args() and policy!="balanced":continue
		for seed_value in [4262026,9294,71491]:
			if "--balanced-only" in OS.get_cmdline_user_args() and seed_value!=4262026:continue
			var c=Combat.new()
			c.start_new(seed_value)
			var boss_times: Array=[]
			var boss_started: float=-1
			var previous: String=""
			var min_health: float=100
			var stage_health: Array[float]=[100,100,100,100,100,100]
			for tick in range(1800000):
				if tick%120==0:Route.buy(c,policy)
				c.manual_held=not c.automation
				if not c.automation:
					var target: Dictionary=c.target_for_weapon()
					if not target.is_empty():c.priority_id=int(target.id)
				if c.mode!=previous:
					if c.mode=="boss":boss_started=c.elapsed
					if c.mode in ["transition","victory"] and boss_started>=0:
						boss_times.append(snappedf(c.elapsed-boss_started,.01))
						boss_started=-1
					previous=c.mode
				min_health=minf(min_health,c.health)
				stage_health[c.stage]=minf(stage_health[c.stage],c.health)
				if c.mode=="failed":
					print("MATRIX_RETRY policy=",policy," stage=",c.stage," wave=",c.wave," cash=",c.money," levels=",c.levels)
					if c.attempts>=8:break
					c.retry()
				if c.mode=="victory":break
				c.advance(1.0/60,false)
			var passed: bool=c.mode=="victory" and c.elapsed>=2880 and c.elapsed<=9000
			if not passed:failures+=1
			print("MATRIX policy=",policy," seed=",seed_value," victory=",c.mode=="victory"," hours=",snappedf(c.elapsed/3600,.001)," retries=",c.attempts," min_health=",min_health," stage_min_health=",stage_health," boss_ttk=",boss_times," pass=",passed)
	print("MATRIX failures=",failures)
	quit(1 if failures else 0)
