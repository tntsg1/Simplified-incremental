extends SceneTree
const Combat = preload("res://scripts/combat.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func fresh(chapter: int=0, slot: int=1) -> RefCounted:
	var c=Combat.new()
	c.start_new(4262026)
	c.stage=chapter; c.wave=1; c.start_wave()
	c.spawn_clock=10000; c.spawn_left=1
	c.bodies[chapter]=1<<slot
	c.spawn_enemy(1)
	var target: Dictionary=c.enemies.back()
	target.hp=100000000.0; target.unit_hp=100000000.0
	target.pos=Vector2(500,160); target.start=target.pos; target.end=target.pos
	return c
func run() -> void:
	var c=fresh()
	var target: Dictionary=c.enemies[0]
	var base: Dictionary=c.body_weapon_stats(0,1)
	check(c.set_body_shots(0,1,3), "Converted installation can select triple fire")
	check(c.body_modes.count(0,0)==1 and c.body_modes.count(0,2)==1 and c.city_mode==0, "Neighbors and main missile mode do not change")
	check(not c.set_body_shots(0,0,3) and not c.set_body_shots(-1,0,3) and not c.set_body_shots(0,1,2), "Unconverted, invalid and unsupported configurations are rejected")
	var stats: Dictionary=c.body_weapon_stats(0,1)
	check(stats.shots==3 and is_equal_approx(stats.damage,base.damage) and is_equal_approx(stats.interval,base.interval) and stats.coverage==base.coverage, "Each shot and original reload interval remain unchanged")
	check(is_equal_approx(stats.volley_damage,base.damage*3), "Inspector shows actual triple payload")
	var fired: Array[float]=[]
	var observe: Callable=func(_s,_k,_o,_d,_crit):fired.append(c.elapsed)
	c.body_fired.connect(observe)
	c.fire_body(0,1,target)
	check(fired.size()==1, "First beam fires immediately")
	for tick in range(6): c.advance(1.0/60.0,false)
	check(fired.size()==1, "Second beam is not simultaneous")
	for tick in range(12): c.advance(1.0/60.0,false)
	check(fired.size()==3 and fired[1]>=.12 and fired[2]>=.24, "Real simulation emits three separated beams")
	check(is_equal_approx(float(c.source_damage.body),float(base.damage)*3), "Three beams each deal their own full base damage")
	check(c.body_modes.pending.is_empty(), "Finished burst releases its queue entry")
	c.body_fired.disconnect(observe)
	# Mid-burst save and pause: no repeats, no lost third shot.
	c=fresh(); target=c.enemies[0]; c.set_body_shots(0,1,3)
	c.fire_body(0,1,target)
	for tick in range(8): c.advance(1.0/60.0,false)
	check(int(c.body_modes.pending[0].left)==1, "Save fixture is between second and third shots")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(c.snapshot()))
	var restored=Combat.new()
	check(restored.restore(saved), "Burst queue survives JSON save and load")
	var remaining: Array[int]=[0]
	restored.body_fired.connect(func(_s,_k,_o,_d,_crit):remaining[0]+=1)
	restored.paused=true; restored.advance(.5,false)
	check(remaining[0]==0 and int(restored.body_modes.pending[0].left)==1, "Pause freezes the remaining burst")
	restored.paused=false; restored.advance(.15,false)
	check(remaining[0]==1 and restored.body_modes.pending.is_empty(), "Reload emits only the remaining third shot")
	var bad: Dictionary=saved.duplicate(true)
	bad.body_fire_modes.pending[0].slot=999
	check(not restored.restore(bad), "Malformed queued slot is rejected")
	bad=saved.duplicate(true); bad.body_fire_modes.triples[0]=999999
	check(not restored.restore(bad), "Malformed mode mask is rejected")
	saved.erase("body_fire_modes")
	check(restored.restore(saved) and restored.body_modes.count(0,1)==1 and restored.body_modes.pending.is_empty(), "Old saves default to original single fire")
	# A finished wave must not leave an overdue burst in its preparation save.
	c=fresh(); target=c.enemies[0]; c.wave=10; c.spawn_left=0
	c.set_body_shots(0,1,3); c.fire_body(0,1,target); target.dead=true
	c.advance(1.0/60.0,false); c.advance(1.0,false)
	check(c.mode=="intermission" and c.body_modes.pending.is_empty(), "Finishing the last wave retires pending attacks")
	saved=JSON.parse_string(JSON.stringify(c.snapshot()))
	check(restored.restore(saved), "Preparation save cannot be invalidated by an overdue burst")
	# Changing during a burst applies to future volleys, without firing from UI.
	c=fresh(); target=c.enemies[0]; c.set_body_shots(0,1,3)
	c.fire_body(0,1,target)
	c.set_body_shots(0,1,1)
	check(c.body_modes.pending.size()==1, "Changing mode does not cancel an in-progress burst")
	for tick in range(18): c.advance(1.0/60.0,false)
	check(c.body_modes.pending.is_empty() and c.body_modes.count(0,1)==1, "In-progress burst finishes under old selection")
	c.fire_body(0,1,target)
	check(c.body_modes.pending.is_empty(), "Next single volley queues no extra shots")
	c.set_body_shots(0,1,3); c.fire_body(0,1,target)
	c.clear_battle()
	check(c.body_modes.pending.is_empty() and c.body_modes.count(0,1)==3, "Battle cleanup clears pending attacks while keeping configuration")
	c.stage=1; c.start_wave()
	check(not c.body_weapon_stats(0,1).has("shots") and not c.set_body_shots(0,1,3), "Next chapter keeps original attack stats and has no independent setting")
	saved=JSON.parse_string(JSON.stringify(c.snapshot()))
	check(c.restore(saved) and c.body_modes.count(0,1)==3, "City configuration record persists without enabling it in other chapters")
	c.start_new()
	check(c.body_modes.count(0,1)==1, "New campaign resets independent settings")
	# Only city installations gain triple fire; all other models retain one attack.
	for chapter in range(c.STAGE_COUNT):
		for slot in range(c.BODIES[chapter].size()):
			c=fresh(chapter,slot); target=c.enemies[0]
			var emitted: Array[int]=[0]
			c.body_fired.connect(func(_s,_k,_o,_d,_crit): emitted[0]+=1)
			check(c.set_body_shots(chapter,slot,3)==(chapter==0), "Only city installations accept new settings")
			var original: String=c.body_attack(chapter,slot)
			c.fire_body(chapter,slot,target)
			for tick in range(18): c.advance(1.0/60.0,false)
			check(emitted[0]==(3 if chapter==0 else 1) and c.body_attack(chapter,slot)==original, "Scoped attack count %d:%d %s" % [chapter,slot,original])
	# Actual mouse entry into the right-hand city installation's page.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,720)
	var game=preload("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	root.add_child(game)
	await process_frame
	game.start_game(); game.sim.wave=6
	game.sim.bodies[0]=7
	game.sim.paused=true
	await create_timer(.6).timeout
	game.layout()
	game.update_hud()
	check(not game.city_tactics is Control, "No permanent top-left missile mode button remains")
	game.field.banner.clear()
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	click.position=root.get_final_transform()*game.field.to_global(game.sim.body_position(0,2))
	click.global_position=click.position
	Input.parse_input_event(click)
	await process_frame
	click=click.duplicate(); click.pressed=false; Input.parse_input_event(click)
	await process_frame
	check(not is_instance_valid(game.body_card) and game.menu=="", "City installation click no longer opens a floating configuration card")
	game.ui.get_node("Bottom/PauseButton").pressed.emit()
	await create_timer(.7).timeout
	check(game.menu=="city_settings" and game.sim.paused, "Settings button opens the centralized paused city page")
	check(game.city_tactics.rows.size()==3, "Settings lists all three city installations")
	var old_shots: int=game.sim.shots.size()
	game.city_tactics.rows[2].triple.pressed.emit()
	check(game.sim.body_modes.count(0,2)==3 and game.sim.body_modes.count(0,0)==1 and game.sim.body_modes.count(0,1)==1, "Central settings changes only the selected installation")
	check(game.sim.shots.size()==old_shots and game.sim.body_modes.pending.is_empty(), "Configuration cannot generate an extra attack")
	check(game.city_tactics.rows[2].triple.disabled, "Settings confirms the selected mode")
	var pinned: Vector2=game.modal.position
	game.field.position+=Vector2(-20,0)
	check(game.modal.position.is_equal_approx(pinned), "Settings never follows a moving installation")
	var rect: Rect2=game.modal.get_global_rect()
	check(rect.position.x>=10 and rect.end.x<=1270 and rect.position.y>=10 and rect.end.y<=710, "Settings fits 720p")
	DirAccess.make_dir_recursive_absolute("res://build/body-fire-modes")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/body-fire-modes/city-settings.png")
	game.city_tactics.rows[2].single.pressed.emit()
	check(game.sim.body_modes.count(0,2)==1, "Settings restores only this installation to single fire")
	game.close_modal(); game.sim.paused=true
	game.sim.stage=1; game.sim.start_wave(); game.sim.paused=true
	game.open_body_details(0,1); await process_frame
	check(is_instance_valid(game.body_card) and game.menu=="", "Other chapters retain the original inspection page")
	game.close_body_card(); game.sim.stage=0; game.sim.start_wave(); game.sim.paused=true
	game.language="en"; game.open_pause(); await create_timer(.7).timeout
	check(game.city_tactics.rows[1].triple.text.contains("Triple"), "Central controls have readable English labels")
	game.close_modal(); game.sim.paused=true
	game.language="zh"; game.set_process(false)
	game.sim.stage=0; game.sim.start_wave(); game.sim.bodies[0]=2
	game.sim.spawn_left=1; game.sim.spawn_clock=10000
	game.sim.spawn_enemy(1)
	var live: Dictionary=game.sim.enemies[0]
	live.hp=100000000; live.unit_hp=100000000
	live.pos=Vector2(530,180); live.start=live.pos; live.end=live.pos
	game.sim.set_body_shots(0,1,3)
	game.sim.paused=false
	game.field.strikes.clear(); game.field.feedback.clear(); game.field.banner.clear()
	game.layout(); game.update_hud()
	var actual_strikes: Array[int]=[0]
	game.sim.body_strike.connect(func(kind,_s,_k,_o,_d,_points,_crit):
		if kind=="beam": actual_strikes[0]+=1)
	game.sim.fire_body(0,1,live)
	for frame in range(18):
		game.sim.advance(1.0/60.0)
		game.field.clock+=1.0/60.0
		game.field.animate(1.0/60.0)
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [0,7,14]: root.get_texture().get_image().save_png("res://build/body-fire-modes/beam-%d.png" % frame)
	check(actual_strikes[0]==3, "Native field receives three independent beam effects")
	# Short active city scene with the selected beam in burst mode.
	for extra in range(80): game.sim.spawn_enemy(1)
	check(game.sim.enemies.size()>70, "Native profile contains a real crowd")
	var samples: Array[float]=[]
	for frame in range(90):
		game.sim.advance(1.0/60.0)
		game.field.clock+=1.0/60.0
		game.field.animate(1.0/60.0)
		game.field.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame>=20: samples.append(float(game.field.draw_ms))
	samples.sort()
	print("BODY_MODE_DRAW median_ms=",samples[samples.size()/2]," p95_ms=",samples[int(samples.size()*.95)])
	game.queue_free(); await process_frame
	print("BODY_FIRE_MODES checks=",checks," failures=",failures)
	quit(1 if failures else 0)
