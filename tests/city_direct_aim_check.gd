extends SceneTree
const Combat=preload("res://scripts/combat.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1; push_error(message)
func fresh() -> RefCounted:
	var c=Combat.new(); c.start_new(); c.wave=10; c.start_boss()
	c.skill={"kind":"meteor_rain","phase":"windup","age":1.5,"hp":float(c.boss_actor().hp)}
	c.cooldowns.fill(1000); c.escort_clock=1000
	return c
func aim(c: RefCounted) -> void:
	c.select_city_part(true)
	c.manual_queued=false
	c.city_aim_held=true
	c.city_aim_point=c.CityBoss.point(c.boss_actor())
func run() -> void:
	var c=fresh()
	var boss: Dictionary=c.boss_actor()
	var original: float=boss.hp
	var part: float=boss.rift_hp
	aim(c)
	for tick in range(15):
		c.city_aim_point=c.CityBoss.point(boss)
		c.advance(1.0/60.0,false)
	check(float(boss.rift_track)>.2 and not bool(boss.rift_aim_used), "Following the exposed crack builds partial aim progress")
	c.city_aim_point=Vector2(-1000,-1000); c.advance(1.0/60.0,false)
	check(float(boss.rift_track)==0, "Losing the moving weak point resets the hold")
	aim(c)
	for tick in range(12):
		c.city_aim_point=c.CityBoss.point(boss); c.advance(1.0/60.0,false)
	c.city_aim_held=false; c.advance(1.0/60.0,false)
	check(float(boss.rift_track)==0, "Releasing the mouse resets partial progress")
	c=fresh(); boss=c.boss_actor(); aim(c)
	c.paused=true
	c.advance(1.0,false)
	check(float(boss.rift_track)==0 and is_equal_approx(float(c.skill.age),1.5), "Paused time cannot complete an aim interruption")
	c.paused=false
	for tick in range(34):
		c.city_aim_point=c.CityBoss.point(boss); c.advance(1.0/60.0,false)
	check(bool(boss.rift_aim_used) and c.skill.is_empty(), "A sustained on-target hold interrupts the rain")
	check(is_equal_approx(float(boss.hp),original) and is_equal_approx(float(boss.rift_hp),part), "The manual interrupt grants no free body or part damage")
	c.skill={"kind":"meteor_rain","phase":"windup","age":1.5,"hp":float(boss.hp)}
	for tick in range(40):
		c.city_aim_point=c.CityBoss.point(boss); c.advance(1.0/60.0,false)
	check(not c.skill.is_empty(), "A single Boss cannot be infinitely stun-locked by holding")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(c.snapshot()))
	var copy=Combat.new()
	check(copy.restore(saved) and bool(copy.boss_actor().rift_aim_used), "The spent interruption persists through save/load")
	check(not copy.city_aim_held and float(copy.boss_actor().rift_track)==0, "Load does not invent held mouse input")
	c=fresh(); boss=c.boss_actor(); c.skill.age=.1; aim(c)
	for tick in range(35):
		c.city_aim_point=c.CityBoss.point(boss); c.advance(1.0/60.0,false)
	check(not bool(boss.rift_aim_used) and float(boss.rift_track)==0, "Early targeting cannot charge before the exposed window")
	c=fresh(); boss=c.boss_actor()
	for tick in range(80): c.advance(1.0/60.0,false)
	check(str(c.skill.get("phase",""))=="active" and c.enemies.size()==11, "Ignoring the weak point preserves the normal ten-meteor attack")
	for chapter in range(1,10):
		c.stage=chapter; c.start_boss(); aim(c)
		c.skill={"kind":"meteor_rain","phase":"windup","age":.5,"hp":float(c.boss_actor().hp)}
		c.advance(.1,false)
		check(not c.boss_actor().has("rift_track"), "No manual weak-point mechanic added outside city %d" % chapter)
	# Exercise the actual mouse pipeline, including automatic-fire players.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.size=Vector2i(1280,720)
	var game=preload("res://scenes/main.tscn").instantiate()
	game.store.enabled=false; root.add_child(game); await process_frame
	game.start_game(); game.sim.wave=10; game.sim.start_boss(); game.sim.paused=true
	await create_timer(3.4).timeout
	game.sim.automation=true; game.sim.cooldowns.fill(1000); game.sim.escort_clock=1000
	game.sim.skill={"kind":"meteor_rain","phase":"windup","age":1.5,"hp":float(game.sim.boss_actor().hp)}
	game.field.banner.clear(); game.camera_comfort=true; game.layout()
	DirAccess.make_dir_recursive_absolute("res://build/city-direct-aim")
	var button:=InputEventMouseButton.new()
	button.button_index=MOUSE_BUTTON_LEFT; button.pressed=true
	button.position=root.get_final_transform()*game.field.to_global(game.sim.CityBoss.point(game.sim.boss_actor()))
	button.global_position=button.position
	Input.parse_input_event(button); await process_frame
	check(game.sim.manual_held and bool(game.sim.boss_actor().rift_selected), "Direct crack click arms held aiming with automation enabled")
	game.sim.paused=false
	for frame in range(40):
		var motion:=InputEventMouseMotion.new()
		motion.position=root.get_final_transform()*game.field.to_global(game.sim.CityBoss.point(game.sim.boss_actor()))
		motion.global_position=motion.position
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.warp_mouse(motion.position)
		Input.parse_input_event(motion)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame==16: root.get_texture().get_image().save_png("res://build/city-direct-aim/tracking.png")
	check(bool(game.sim.boss_actor().rift_aim_used), "Native mouse tracking triggers the actual interruption")
	check(not game.city_tactics is Control and game.city_tactics.get_child_count()==0, "There is no target-selection panel on the battlefield")
	button=button.duplicate(); button.pressed=false; Input.parse_input_event(button); await process_frame
	check(not game.sim.manual_held, "Releasing native mouse exits held aiming")
	root.get_texture().get_image().save_png("res://build/city-direct-aim/interrupted.png")
	game.queue_free(); await process_frame
	print("CITY_DIRECT_AIM checks=",checks," failures=",failures)
	quit(1 if failures else 0)
