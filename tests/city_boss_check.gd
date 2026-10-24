extends SceneTree
const Combat = preload("res://scripts/combat.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func fresh() -> RefCounted:
	var c = Combat.new()
	c.start_new(4262026)
	c.wave = 10
	c.start_boss()
	return c
func run() -> void:
	var c = fresh()
	var b: Dictionary = c.boss_actor()
	var maximum: float = c.boss_max_hp()
	check(c.CityBoss.available(b), "City boss has a fissure")
	check(is_equal_approx(float(b.rift_max), maximum*.12), "Part durability uses boss scale")
	check(c.select_target(c.CityBoss.point(b)) == int(b.id) and bool(b.rift_selected), "Model hit area selects the part")
	c.select_city_part(false)
	check(not bool(b.rift_selected), "Body button clears part selection")
	var hp: float = b.hp
	c.apply_damage(b,maximum*.01,1,0)
	check(is_equal_approx(hp-float(b.hp),maximum*.01) and is_equal_approx(b.rift_hp,b.rift_max), "Direct body hits preserve part and normal damage")
	c.select_city_part(true)
	hp = b.hp
	c.apply_damage(b,maximum*.01,1,0,false,false,true)
	check(is_equal_approx(hp-float(b.hp), maximum*.006), "Part damage transfers 60 percent exactly once")
	check(is_equal_approx(float(b.rift_hp),maximum*.11), "Part loses its own durability")
	c.skill = {"kind":"meteor_rain","phase":"windup","age":1.0,"hp":float(b.hp)}
	c.escort_clock = 2.75
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.snapshot()))
	var restored = Combat.new()
	check(restored.restore(saved), "JSON save round trip")
	check(restored.CityBoss.charging(restored) and is_equal_approx(float(restored.skill.age),1.0), "Reload does not restart the windup")
	check(is_equal_approx(float(restored.boss_actor().rift_hp),float(b.rift_hp)) and bool(restored.boss_actor().rift_selected), "Part durability and selection survive reload")
	check(is_equal_approx(restored.escort_clock,2.75), "Escort timer survives reload")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.boss_skill_state = {"kind":"unknown", "phase":"active"}
	check(not restored.restore(malformed), "Malformed saved skill is rejected before mutating the run")
	malformed = saved.duplicate(true)
	malformed.enemies[0].rift_hp = -1
	check(not restored.restore(malformed), "Malformed part durability is rejected")
	check(is_equal_approx(c.boss_skill_windup("meteor_rain"),2.6), "First boss has a readable reaction window")
	hp = b.hp
	c.apply_damage(b,maximum*.06,1,0,false,false,true)
	check(float(b.rift_hp)==0.0 and not bool(b.rift_selected), "Charging doubles part damage and breaking returns to body")
	check(c.skill.is_empty(), "Breaking during windup cancels this rain")
	check(is_equal_approx(hp-float(b.hp), maximum*(.055*.6+.005)), "Large-hit overflow continues to body")
	c.fire_boss_skill("meteor_rain",b)
	check(c.enemies.size()==5, "Broken fissure produces four meteors")
	var alive: int = c.enemies.size()
	c.enraged = true
	c.fire_boss_skill("meteor_rain",b)
	check(c.enemies.size()-alive==4, "Enrage cannot regrow the part")
	check(not c.select_city_part(true), "Destroyed part cannot be selected again")
	saved = JSON.parse_string(JSON.stringify(c.snapshot()))
	check(c.restore(saved), "Broken state reloads")
	check(float(c.boss_actor().rift_hp)==0.0, "Part stays broken after reload")
	c = fresh(); b=c.boss_actor()
	c.fire_boss_skill("meteor_rain",b)
	check(c.enemies.size()==11, "Ignoring part retains original ten-meteor attack")
	c.apply_damage(b,c.boss_max_hp()*2,1,0)
	check(bool(b.dead) and float(b.rift_hp)>0, "Boss can die with the part intact")
	# Old mid-boss saves keep the old rules until the next new boss.
	c = fresh()
	saved = JSON.parse_string(JSON.stringify(c.snapshot()))
	for key in ["rift_hp","rift_max","rift_selected"]: saved.enemies[0].erase(key)
	for key in ["boss_skill_state","boss_skill_clock","boss_enraged","city_mode","city_mode_next","escort_clock"]: saved.erase(key)
	check(c.restore(saved) and not c.CityBoss.available(c.boss_actor()), "Pre-feature boss save stays playable")
	c.start_boss()
	check(c.CityBoss.available(c.boss_actor()), "Next fresh boss gains the part")
	# Real projectile pipeline: selection is recorded at launch, not impact.
	c.select_city_part(true)
	c.fire_weapon(0,c.boss_actor())
	check(c.manual_queued, "Fixed part selection also queues a shot without automation")
	check(bool(c.shots.back().city_rift), "Missile records the targeted part")
	c.select_city_part(false)
	c.cooldowns[0] = 100
	c.escort_clock = 100
	var previous_part: float = c.boss_actor().rift_hp
	for tick in range(180): c.advance(1.0/60.0,false)
	check(float(c.boss_actor().rift_hp)<previous_part, "In-flight part missile still hits the original part after a target change")
	# Two genuinely different salvos, fixed total payload and reload period.
	c = fresh()
	c.spawn_escorts(3,false)
	c.city_mode = 1
	c.fire_weapon(0,c.boss_actor())
	check(c.shots.size()==3, "Split salvo fires three real projectiles")
	var ids: Dictionary = {}
	var damage: float = 0
	for shot in c.shots: ids[int(shot.target)]=true; damage+=float(shot.damage)
	check(ids.size()==3, "Split missiles target three different threats")
	check(is_equal_approx(damage,c.shot_damage(0)), "Split mode conserves total noncritical payload")
	c.set_city_mode(0)
	check(c.city_mode==1 and c.city_mode_next==0, "Combat mode changes queue without changing this salvo")
	c.wave=8
	preload("res://scripts/campaign.gd").next_wave(c)
	check(c.city_mode==0, "Queued mode applies at next wave")
	c = fresh(); c.city_mode=1
	c.fire_weapon(0,c.boss_actor())
	check(c.shots.size()==1 and is_equal_approx(float(c.shots[0].damage),c.shot_damage(0)/3), "Empty split lanes do not concentrate unused payload")
	for stage in range(1,10):
		c.stage=stage; c.start_boss()
		check(not c.CityBoss.available(c.boss_actor()), "Other chapter keeps its own boss rules %d" % stage)
	# Converted defenses keep intercepting while the main missile targets the part.
	c = fresh(); c.automation=true; c.levels.turrets=4; c.spawn_escorts(4,false)
	c.select_city_part(true)
	for tick in range(30): c.advance(1.0/60.0,false)
	var escort_targets: int = 0
	for shot in c.shots:
		if shot.has("turret") and int(shot.target) != int(c.boss_actor().id): escort_targets += 1
	check(escort_targets > 0, "Turrets still intercept escorts while the main gun aims at the part")
	# Native interface and render coverage at normal and smaller desktop size.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	root.add_child(game)
	await process_frame
	game.start_game()
	game.sim.wave=10; game.sim.start_boss()
	game.sim.paused=true
	await create_timer(3.5).timeout
	game.sim.boss_actor().pos=Vector2(500,185)
	game.sim.boss_actor().age=15.0
	game.sim.skill={"kind":"meteor_rain","phase":"windup","age":1.5,"hp":float(game.sim.boss_actor().hp)}
	game.field.banner.clear()
	DirAccess.make_dir_recursive_absolute("res://build/city-boss")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution
		await process_frame
		game.layout(); game.update_hud()
		game.city_tactics.rift.pressed.emit()
		check(bool(game.sim.boss_actor().rift_selected), "Fixed part button works")
		check(game.boss_box.position.x > float(resolution.x)*.5+100, "Boss health clears the central model")
		check(game.city_tactics.get_global_rect().end.y<float(resolution.y)-104, "Tactics card clears bottom controls")
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/city-boss/charging-%d.png" % resolution.x)
	game.city_tactics.modes.pressed.emit()
	check(game.menu=="city_modes" and game.sim.paused, "Mode picker pauses battle")
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-boss/modes-1280.png")
	game.close_modal(); game.sim.paused=true
	await create_timer(.6).timeout
	game.sim.apply_damage(game.sim.boss_actor(),game.sim.boss_max_hp()*.1,1,0,false,false,true)
	game.sim.boss_actor()["flash"]=0.0
	game.update_hud(); game.field.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-boss/broken-1280.png")
	check(game.city_tactics.rift.disabled, "Destroyed part button is visibly disabled")
	# Capture the persistent model after the transient break burst has faded.
	game.sim.effects.clear()
	game.field.feedback.clear()
	game.field.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-boss/scar-1280.png")
	game.language="en"
	game.city_tactics.refresh()
	check(game.city_tactics.body.text.contains("Body"), "Tactics labels follow the chosen language")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-boss/english-1280.png")
	# Cosmetic split missiles must follow the same distinct-target rule.
	game.sim.city_mode=1; game.sim.spawn_escorts(3,false)
	var before_rounds: int = game.field.b_age.size()
	game.sim.fire_weapon(0,game.sim.boss_actor())
	var shown_targets: Array[int]=[]
	for round_index in range(before_rounds,game.field.b_age.size()): shown_targets.append(game.field.b_target[round_index])
	check(shown_targets.size()==3, "Split mode emits one cosmetic missile per real target at base launcher count")
	game.field.on_focused(int(game.sim.boss_actor().id))
	var unchanged: bool=true
	for round_index in range(before_rounds,game.field.b_age.size()):
		unchanged = unchanged and game.field.b_target[round_index] == shown_targets[round_index-before_rounds]
	check(unchanged, "Focus feedback cannot visually collapse a distributed salvo")
	# A short active scene measures actual draw cost, independent of a frame cap.
	game.sim.automation=true; game.sim.health=1000000
	game.sim.paused=false; game.sim.escort_clock=100
	game.sim.spawn_escorts(80,false)
	var samples: Array[float]=[]
	for frame in range(100):
		await process_frame
		await RenderingServer.frame_post_draw
		if frame>=20: samples.append(float(game.field.draw_ms))
	samples.sort()
	print("CITY_DRAW_PROFILE actors=",game.sim.enemies.size()," median_ms=",samples[samples.size()/2]," p95_ms=",samples[int(samples.size()*.95)])
	game.queue_free()
	await process_frame
	print("CITY_BOSS_CHECK checks=",checks," failures=",failures)
	quit(1 if failures else 0)

