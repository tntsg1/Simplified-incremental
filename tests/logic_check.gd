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
	c.enemies[0].pos=Vector2(350,350)
	c.enemies[1].pos=Vector2(650,350)
	check(c.select_target(Vector2(650,350))==c.enemies[1].id,"target switch")
	check(c.target_for_weapon().id==c.enemies[1].id,"shared priority")
	c.fire_weapon(0,c.enemies[0])
	c.select_target(Vector2(650,350))
	check(int(c.shots.back().target)==c.enemies[0].id,"focus fire refuses targets outside launch cone")
	c.enemies[1].pos=Vector2(365,350)
	c.select_target(Vector2(365,350))
	check(int(c.shots.back().target)==c.enemies[1].id,"focus fire turns rounds smoothly toward reachable targets")
	c.priority_id=-1
	c.enemies[1].reserved=1000
	check(c.target_for_weapon().id==c.enemies[0].id,"reserved lethal damage avoids overkill")
	c.clear_battle()
	c.wave=1
	c.spawn_enemy(10)
	# Pin a plain swarm group at 100 HP per member: this checks the group mechanics only.
	c.enemies[0].merge({"arch":"swarm","unit_hp":100.0,"hp":100.0,"elite":false},true)
	c.enemies[0].erase("shield")
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
	check(c.mode=="wave" and c.wave==2 and c.health==100,"wave rolls straight into the next and heals")
	c.wave_elapsed=200
	c.start_boss()
	check(c.wave_elapsed==0 and c.boss_remaining==45,"Boss receives its own full impact window")
	c.clear_battle()
	c.money=123
	c.levels.damage=14
	var wave_before: int = c.wave
	c.fail_stage()
	c.retry()
	check(c.wave==wave_before and c.money==123 and c.levels.damage==14 and c.automation,"failure retries the same wave and inherits growth")
	c.spawn_enemy(15)
	c.fire_weapon(0,c.enemies[0])
	c.advance(.1)
	var d=Combat.new()
	var parsed: Dictionary=JSON.parse_string(JSON.stringify(c.snapshot()))
	check(d.restore(parsed),"JSON battle restore")
	check(d.enemies[0].members==c.enemies[0].members and d.shots.size()==c.shots.size(),"restore members and in-flight shots")
	check(is_equal_approx(d.elapsed,c.elapsed) and is_equal_approx(d.money,c.money),"no offline settlement")
	check(not d.restore({"game":"colony","version":1}),"old saves rejected")
	# A six-chapter (version 1) save resumes in the matching ten-chapter stage.
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(c.snapshot()))
	legacy.version = 1
	legacy.stage = 3
	legacy.mode = "boss"
	legacy.owned = [true, true, true, true, false, false]
	legacy.cooldowns = [0, 0, 0, 0, 0, 0]
	legacy.weapon_damage = [1, 2, 3, 4, 0, 0]
	legacy.bodies = [7, 1, 32, 16, 0, 0]
	legacy.enemies = []
	legacy.shots = []
	legacy.reward_batches = [{"age": 0.2, "released": false, "kind": "nuke", "reward": 50.0, "drops": []}]
	var migrated = Combat.new()
	check(migrated.restore(legacy), "version 1 save migrates")
	check(migrated.stage == 6 and migrated.mode == "intermission" and migrated.wave == 10, "old galaxy boss resumes before the new galaxy boss")
	check(migrated.owned[5] and migrated.owned[3] and migrated.owned[4] and not migrated.owned[6], "old stellar cannon maps forward; passed chapters' weapons granted")
	check(migrated.bodies[2] == 16 and migrated.bodies[6] == 32, "old Sun and galactic black hole keep their conversions")
	check(is_equal_approx(migrated.money, c.money + 50.0), "pending loot paid out on migration")
	check(migrated.saved_stage(legacy) == 6, "title screen shows the migrated chapter")
	# Droplet fragments break only once; a second droplet erases them without new ones.
	var dr = Combat.new()
	dr.start_new()
	dr.stage = 2
	dr.wave = 3
	dr.start_wave()
	dr.spawn_left = 0
	dr.grace = 9999.0
	for i in range(8):
		dr.spawn_enemy(3)
	dr.ult_override = "droplet"
	dr.ult_charge = 1.0
	dr.fire_ultimate()
	for i in range(200):
		dr.advance(1.0 / 60, false)
	var first_fragments: int = 0
	for e in dr.enemies:
		if bool(e.get("fragment", false)) and not bool(e.dead):
			first_fragments += 1
	check(first_fragments > 0, "droplet shatters threats into fragments")
	dr.ult = {}
	dr.ult_charge = 1.0
	dr.fire_ultimate()
	for i in range(200):
		dr.advance(1.0 / 60, false)
	var second_fragments: int = 0
	for e in dr.enemies:
		if bool(e.get("fragment", false)) and not bool(e.dead):
			second_fragments += 1
	check(second_fragments == 0, "fragments never shatter into more fragments")
	# Fragments that reach the defense do no damage.
	dr.ult = {}
	dr.enemies.clear()
	dr.enemies_by_id.clear()
	dr.spawn_fragment(Vector2(500, 120), 20.0, 0.0)
	var frag: Dictionary = dr.enemies.back()
	frag.age = float(frag.lifetime)
	var before_hp: float = dr.health
	dr.advance(1.0 / 60, false)
	check(dr.health == before_hp and bool(frag.dead), "droplet fragments burn up harmlessly at the defense")
	# Enemy archetypes: the wave budget is unchanged, and each behaviour does its one thing.
	var ar = Combat.new()
	ar.start_new()
	for st in range(10):
		var w: Dictionary = ar.arch_weights(st)
		var norm: Array = ar.arch_norm(st)
		var hp_total: float = 0.0
		var life_total: float = 0.0
		var share: float = 0.0
		for a in w:
			hp_total += float(w[a]) * (float(ar.ARCH_HP[a]) + float(ar.ARCH_EXTRA[a])) * float(norm[0])
			life_total += float(w[a]) * float(ar.ARCH_LIFE[a]) * float(norm[1])
			share += float(w[a])
		check(is_equal_approx(hp_total, 1.0) and is_equal_approx(life_total, 1.0) and is_equal_approx(share, 1.0), "chapter %d keeps its wave HP and timing budget" % (st + 1))
	ar.stage = 6
	ar.wave = 3
	ar.start_wave()
	ar.spawn_left = 0
	ar.grace = 9999.0
	ar.clear_battle()
	ar.serial = 1
	ar.spawn_enemy(8)
	var sp: Dictionary = ar.enemies.back()
	sp.merge({"arch": "splitter"}, true)
	sp.erase("shield")
	ar.apply_damage(sp, 1e30, 999, 0)
	ar.advance(1.0 / 60, false)
	var pieces: Array = ar.enemies.filter(func(x): return bool(x.get("child", false)) and not bool(x.dead))
	check(pieces.size() == 2, "a splitter breaks into two pieces")
	for piece in pieces:
		ar.apply_damage(piece, 1e30, 999, 0)
	ar.advance(1.0 / 60, false)
	check(ar.enemies.filter(func(x): return bool(x.get("child", false)) and not bool(x.dead)).is_empty(), "split pieces never split again")
	ar.clear_battle()
	ar.serial = 1
	ar.spawn_enemy(6)
	var sh: Dictionary = ar.enemies.back()
	sh.merge({"arch": "shielded", "shield": 500.0, "shield_max": 500.0}, true)
	var members_before: int = int(sh.members)
	ar.apply_damage(sh, 300.0, 999, 0)
	check(int(sh.members) == members_before and is_equal_approx(float(sh.shield), 200.0), "the shield soaks damage before any member falls")
	ar.clear_battle()
	ar.serial = 1
	ar.spawn_enemy(8)
	var mo: Dictionary = ar.enemies.back()
	mo.merge({"arch": "mother", "launch_t": .5, "launched": 0, "lifetime": 60.0}, true)
	mo.erase("shield")
	for i in range(240):
		ar.advance(1.0 / 60, false)
	check(ar.enemies.filter(func(x): return bool(x.get("child", false))).size() >= 2, "a mothership launches swarms on its way in")
	var dart := {"start": Vector2(0, 0), "end": Vector2(400, 0), "arch": "dart", "swerve": 1.0}
	check(ar.enemy_point(dart, 1.0).distance_to(Vector2(400, 0)) < .01 and absf(ar.enemy_point(dart, .25).y) > 20.0, "darts swerve off the line yet land on the core")
	# Wave 10 cleared: nothing may be left hanging in flight during the intermission.
	var iw = Combat.new()
	iw.start_new()
	iw.stage = 0
	iw.wave = 10
	iw.start_wave()
	iw.spawn_left = 0
	iw.clear_battle()
	iw.shots.append({"target": -1, "from": Vector2.ZERO, "pos": Vector2(100, 100), "end": Vector2(200, 200), "age": 0.0, "duration": 5.0, "damage": 1.0, "effective": 1.0, "coverage": 1, "weapon": 0, "crit": false, "beam": false, "mode": "missile"})
	iw.advance(1.0 / 60, false)
	check(iw.mode == "intermission" and iw.shots.is_empty(), "rounds in flight are retired when the last wave ends")
	# A round changes target at most MAX_RETARGETS times, then flies off as a stray.
	var rt = Combat.new()
	rt.start_new()
	rt.stage = 1
	rt.wave = 2
	rt.start_wave()
	rt.spawn_left = 0
	for i in range(6):
		rt.spawn_enemy(1)
	rt.fire_weapon(0, rt.enemies[0])
	var round: Dictionary = rt.shots.back()
	for i in range(5):
		for e in rt.enemies:
			if int(e.id) == int(round.target):
				e.dead = true
		rt.advance(1.0 / 60, false)
	check(int(round.get("turns", 0)) <= rt.MAX_RETARGETS and bool(round.get("stray", false)), "rounds retarget at most three times, then fly off-screen")
	# Magnetar's field bends incoming rounds away; instant attacks still land.
	var mg = Combat.new()
	mg.start_new()
	mg.stage = 6
	mg.wave = 10
	mg.start_wave()
	mg.start_boss()
	var magnetar: Dictionary = mg.boss_actor()
	mg.skill = {"kind": "magnetic_field", "phase": "active", "age": 0.0, "hp": float(magnetar.hp)}
	var bent: Array = [0]
	mg.shot_deflected.connect(func(_p, _h, _t): bent[0] += 1)
	for i in range(40):
		mg.fire_weapon(0, magnetar)
	for i in range(120):
		mg.skill.age = 0.0
		mg.advance(1.0 / 60, false)
	check(mg.magnet_field_radius() > 0.0 and int(bent[0]) >= 10, "magnetar field deflects incoming rounds (%d of 40)" % int(bent[0]))
	# Every chapter weapon has its own attack geometry and still lands its volley.
	for w in range(c.STAGE_COUNT):
		var m = Combat.new()
		m.start_new()
		m.stage = 1
		m.wave = 3
		m.start_wave()
		for i in range(12):
			m.spawn_enemy(3)
		var target: Dictionary = m.enemies[0]
		var hp_before: float = m.pending_hp(target) + float(target.reserved)
		m.fire_weapon(w, target)
		for i in range(90):
			m.advance(1.0 / 60, false)
			if m.find_enemy(int(target.id)).is_empty():
				break
		var after: Dictionary = m.find_enemy(int(target.id))
		var hp_after: float = 0.0 if after.is_empty() else float(after.hp) + (int(after.members) - 1) * float(after.unit_hp)
		check(hp_after < hp_before, "chapter weapon %d (%s) damages its target" % [w, m.WEAPON_MODES[w]])
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
	if failed==0 and not "--logic-only" in OS.get_cmdline_user_args():
		for seed_value in [4262026,9294,71491]:
			campaign(seed_value)
	print("TOTAL_CHECKS ",checks," failures=",failed)
	quit(0 if failed==0 else 1)

func autobuy(c: RefCounted) -> void:
	if c.automation_available():
		c.buy_automation()
	if c.stage>0 and not c.owned[c.stage] and not c.buy_weapon():
		return
	for slot in range(c.BODIES[c.stage].size()):
		if not c.body_converted_at(c.stage, slot) and c.money >= c.body_cost():
			c.convert_body(slot)
	var reserve: float=200 if c.stage==0 and not c.automation and c.wave>=5 else 0
	for purchase in range(60):
		var best: int=-1
		var score: float=0
		for i in range(c.catalog.upgrades.size()):
			var u: Resource=c.catalog.upgrades[i]
			if c.stage<int(u.unlock_stage) or bool(u.retired):
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
				"turrets": weight=.9
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
	var weapon_wave: Array[int]=[1,0,0,0,0,0,0,0,0,0]
	var early_passes: int=0
	var last_wave: int=1
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
				# The new chapter weapon is part of the opening now; old guns must hold wave 1.
				for early_wave in [1]:
					incumbent.wave=early_wave
					incumbent.start_wave()
					for early_tick in range(30000):
						incumbent.advance(1.0/60,false)
						if incumbent.wave>early_wave or incumbent.mode=="failed":
							break
					check(incumbent.wave>early_wave and incumbent.mode!="failed","existing system without new cannon handles stage %d wave %d" %[c.stage,early_wave])
			print("STAGE seed=",seed_value," stage=",c.stage," seconds=",snappedf(c.elapsed,.1)," levels=",c.levels," cash=",snappedf(c.money,.1))
			previous_stage=c.stage
		# Waves roll seamlessly: a wave counts as passed when the next one begins
		# (or, for wave 10, when the pre-boss intermission starts).
		if c.mode=="wave" and c.wave==last_wave+1:
			ordinary+=1
			if c.stage>0 and last_wave<=2:
				early_passes+=1
		if c.mode=="wave" or c.wave!=last_wave:
			last_wave=c.wave
		if c.mode!=previous_mode:
			if c.mode=="intermission":
				ordinary+=1
			if c.mode=="transition":
				transitions+=1
			if c.mode=="boss":
				print("BOSS stage=",c.stage," dps=",snappedf(c.nominal_dps(),1)," required=",c.boss_max_hp()/float(c.stage_data().boss_window)," levels=",c.levels)
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
	check(ordinary>=100 and transitions==c.LAST_STAGE and c.stage_bosses==c.STAGE_COUNT,"100 waves 10 bosses 9 transitions")
	check(auto_wave>=6 and auto_wave<=8,"city automation wave6-8")
	# Short dense waves: the length comes from upgrade/push loops, not slow spawns.
	check(c.elapsed>=2880 and c.elapsed<=9000,"active time 0.8-2.5 hours")
	check(early_passes>=10,"first two waves survived")
	for stage in range(c.STAGE_COUNT):
		check(c.owned[stage] and c.weapon_damage[stage]>0,"old weapon contributes "+str(stage))
		if stage>0:
			check(weapon_wave[stage]<=2 and weapon_wave[stage]>0,"new weapon affordable by wave2 "+str(stage))
	print("CAMPAIGN seed=",seed_value," mode=",c.mode," hours=",c.elapsed/3600," retries=",c.attempts," waves=",ordinary," transitions=",transitions," bosses=",c.stage_bosses," automation_wave=",auto_wave," weapon_waves=",weapon_wave," damage=",c.weapon_damage)
