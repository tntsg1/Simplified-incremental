extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Store = preload("res://scripts/save_store.gd")
var failed: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error("FAIL: "+description)

func run() -> void:
	var c = Combat.new()
	c.start_new()
	c.spawn_enemy(1)
	c.apply_damage(c.enemies[0],100,1,0)
	check(c.money==10 and c.kills==1,"kill reward")
	c.money=50
	check(c.buy_upgrade(0)==1 and is_equal_approx(c.money,30),"upgrade deduction")
	check(is_equal_approx(c.shot_damage(0),57.5),"damage growth")
	c.wave=6
	c.money=200
	check(c.buy_automation() and c.money==0,"automation cost")
	c.clear_battle()
	c.spawn_enemy(1)
	c.spawn_enemy(1)
	c.enemies[0].pos=Vector2(200,200)
	c.enemies[1].pos=Vector2(700,200)
	check(c.select_target(Vector2(700,200))==c.enemies[1].id,"target switch")
	check(c.target_for_weapon().id==c.enemies[1].id,"shared priority")
	c.enemies[1].reserved=100
	check(c.target_for_weapon().id==c.enemies[0].id,"reserved lethal damage avoids overkill")
	c.clear_battle()
	c.spawn_enemy(10)
	c.money=0
	c.apply_damage(c.enemies[0],350,4,0)
	check(c.enemies[0].members==7 and is_equal_approx(c.enemies[0].hp,50) and c.money==30,"group partial damage and reward")
	c.apply_damage(c.enemies[0],10000,2,0)
	check(c.enemies[0].members==5,"coverage caps kills")
	var radius_before: int=c.coverage(0)
	c.stage=2
	c.levels.area=10
	check(c.coverage(0)>radius_before,"area upgrades improve group interception independently")
	c.stage=0
	c.levels.area=0
	c.paused=true
	var before: Dictionary=c.snapshot()
	for i in range(100):
		c.advance(1.0/60)
	check(c.snapshot()==before,"pause freezes all state and timers")
	c.paused=false
	c.health=32
	c.spawn_left=0
	c.clear_battle()
	c.advance(1.0/60)
	check(c.mode=="intermission" and c.health==100,"wave heals fully")
	c.wave_elapsed=200
	c.start_boss()
	check(c.wave_elapsed==0 and c.boss_remaining==45,"Boss receives its own full impact window")
	c.clear_battle()
	c.money=123
	c.levels.damage=14
	c.fail_stage()
	c.retry()
	check(c.wave==1 and c.money==123 and c.levels.damage==14 and c.automation,"failure inherits growth")
	c.spawn_enemy(15)
	c.fire_weapon(0,c.enemies[0])
	c.advance(.1)
	var d=Combat.new()
	var parsed: Dictionary=JSON.parse_string(JSON.stringify(c.snapshot()))
	check(d.restore(parsed),"JSON battle restore")
	check(d.enemies[0].members==c.enemies[0].members and d.shots.size()==c.shots.size(),"restore members and in-flight shots")
	check(is_equal_approx(d.elapsed,c.elapsed) and is_equal_approx(d.money,c.money),"no offline settlement")
	check(not d.restore({"game":"colony","version":1}),"old saves rejected")
	for i in range(60):
		c.advance(1.0/60,false)
		d.advance(1.0/60,false)
	check(c.rng.state==d.rng.state and c.kills==d.kills and is_equal_approx(c.money,d.money) and c.enemies.size()==d.enemies.size() and c.shots.size()==d.shots.size(),"deterministic restored simulation")
	for i in range(c.enemies.size()):
		check(Vector2(c.enemies[i].pos).is_equal_approx(d.enemies[i].pos) and is_equal_approx(c.enemies[i].hp,d.enemies[i].hp),"restored target position and health")
	var store=Store.new()
	store.path="user://skyguard_test_atomic.json"
	check(store.save_game(c,{"sound":false}),"first atomic save")
	c.money+=9
	check(store.save_game(c,{"sound":true}),"atomic overwrite")
	check(is_equal_approx(float(store.read_game().money),c.money),"read newest save")
	var corrupt:=FileAccess.open(store.path,FileAccess.WRITE)
	corrupt.store_string("{bad-json")
	corrupt.close()
	check(not store.read_game().is_empty(),"backup recovers corrupt main save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path+".bak"))
	print("LOGIC_CHECKS ",checks," failures=",failed)
	if failed==0:
		for seed_value in [4262026,9294,71491]:
			campaign(seed_value)
	print("TOTAL_CHECKS ",checks," failures=",failed)
	quit(0 if failed==0 else 1)

func autobuy(c: RefCounted) -> void:
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
			if cost>c.money-reserve:
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
			if weight/cost>score:
				score=weight/cost
				best=i
		if best<0:
			break
		c.buy_upgrade(best)

func campaign(seed_value: int) -> void:
	var c=Combat.new()
	c.start_new(seed_value)
	var previous_stage: int=-1
	var previous_mode: String=""
	var ordinary: int=0
	var transitions: int=0
	var auto_wave: int=0
	var weapon_wave: Array[int]=[1,0,0,0,0,0]
	var early_passes: int=0
	for tick in range(1800000):
		if tick%120==0:
			autobuy(c)
			if c.automation and auto_wave==0:
				auto_wave=c.wave
			if c.owned[c.stage] and weapon_wave[c.stage]==0:
				weapon_wave[c.stage]=c.wave
		c.manual_held=not c.automation
		if not c.automation:
			var clicked: Dictionary=c.target_for_weapon()
			if not clicked.is_empty():
				c.priority_id=int(clicked.id)
		if c.stage!=previous_stage:
			if c.stage>0:
				var incumbent=Combat.new()
				var old_snapshot: Dictionary=JSON.parse_string(JSON.stringify(c.snapshot()))
				incumbent.restore(old_snapshot)
				incumbent.owned[c.stage]=false
				for early_wave in [1,2]:
					incumbent.wave=early_wave
					incumbent.start_wave()
					for early_tick in range(30000):
						incumbent.advance(1.0/60,false)
						if incumbent.mode in ["intermission","failed"]:
							break
					check(incumbent.mode=="intermission","existing system without new cannon handles stage %d wave %d" %[c.stage,early_wave])
			print("STAGE seed=",seed_value," stage=",c.stage," seconds=",snappedf(c.elapsed,.1)," levels=",c.levels," cash=",snappedf(c.money,.1))
			previous_stage=c.stage
		if c.mode!=previous_mode:
			if c.mode=="intermission":
				ordinary+=1
				if c.stage>0 and c.wave<=2:
					early_passes+=1
			if c.mode=="transition":
				transitions+=1
			if c.mode=="boss":
				print("BOSS stage=",c.stage," dps=",snappedf(c.nominal_dps(),1)," required=",float(c.stage_data().boss_hp)/float(c.stage_data().boss_window)," levels=",c.levels)
			previous_mode=c.mode
		if c.mode=="failed":
			print("RETRY stage=",c.stage," wave=",c.wave," levels=",c.levels," cash=",c.money)
			if c.attempts>=12:
				break
			c.retry()
		if c.mode=="victory":
			break
		c.advance(1.0/60,false)
	check(c.mode=="victory","six bosses seed "+str(seed_value))
	check(ordinary>=60 and transitions==5 and c.stage_bosses==6,"60 waves 6 bosses 5 transitions")
	check(auto_wave>=6 and auto_wave<=8,"city automation wave6-8")
	check(c.elapsed>=10800 and c.elapsed<=18000,"active time 3-5 hours")
	check(early_passes>=10,"first two waves survived")
	for stage in range(6):
		check(c.owned[stage] and c.weapon_damage[stage]>0,"old weapon contributes "+str(stage))
		if stage>0:
			check(weapon_wave[stage]<=2 and weapon_wave[stage]>0,"new weapon affordable by wave2 "+str(stage))
	print("CAMPAIGN seed=",seed_value," mode=",c.mode," hours=",c.elapsed/3600," retries=",c.attempts," waves=",ordinary," transitions=",transitions," bosses=",c.stage_bosses," automation_wave=",auto_wave," weapon_waves=",weapon_wave," damage=",c.weapon_damage)
