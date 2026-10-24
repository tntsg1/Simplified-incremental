extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
	Engine.max_fps=60
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func escape() -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_ESCAPE; event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event)
	await process_frame
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.size=Vector2i(1280,720)
	var game=preload("res://scenes/main.tscn").instantiate()
	game.store.enabled=false; root.add_child(game); await process_frame
	game.saved={}; game.start_game(); game.sim.wave=6
	game.sim.money=100000
	game.update_hud()
	check(game.ui.get_node("Bottom/PauseButton").text.contains("设置"), "City has an explicit Settings entry")
	check(not game.city_combat_hints, "Combat descriptions are off by default")
	await escape()
	await create_timer(.7).timeout
	check(game.menu=="city_settings" and game.sim.paused, "Escape opens centralized settings")
	var before: float=game.sim.elapsed
	await create_timer(.15).timeout
	check(is_equal_approx(game.sim.elapsed,before), "Settings pauses actual simulation")
	check(game.city_tactics.rows.size()==3, "All city installations appear in the same page")
	for slot in range(3):
		var price: float=game.sim.body_cost()
		var money: float=game.sim.money
		game.city_tactics.rows[slot].convert.pressed.emit()
		check(game.sim.body_converted_at(0,slot) and is_equal_approx(money-game.sim.money,price), "Settings conversion keeps original price %d" % slot)
		check(game.city_tactics.rows[slot].single.visible and not game.city_tactics.rows[slot].convert.visible, "Conversion reveals the same installation's mode choices")
	game.city_tactics.rows[2].triple.pressed.emit()
	check(game.sim.body_modes.count(0,2)==3 and game.sim.body_modes.count(0,1)==1, "Independent modes remain independent")
	game.city_tactics.main_choices[1].pressed.emit()
	check(game.sim.city_mode==0 and game.sim.city_mode_next==1, "Main missile changes keep the next-wave rule")
	game.city_tactics.hints.pressed.emit()
	check(game.city_combat_hints and game.field.city_combat_hints and bool(game.settings_payload().city_combat_hints), "Combat hint toggle reaches drawing and saved settings")
	game.city_tactics.hints.pressed.emit()
	check(not game.city_combat_hints, "Hints can be hidden again")
	DirAccess.make_dir_recursive_absolute("res://build/city-settings")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=resolution; await process_frame; game.layout()
		game.city_tactics.open_settings(); await create_timer(.7).timeout
		var rect: Rect2=game.modal.get_global_rect()
		check(rect.position.x>=10 and rect.end.x<=resolution.x-10 and rect.position.y>=10 and rect.end.y<=resolution.y-10, "Settings modal fits %s" % resolution)
		check(game.city_tactics.rows[2].triple.get_global_rect().end.y<game.modal.get_global_rect().end.y-50, "Third installation controls are not clipped")
		var last_button: Rect2=game.city_tactics.rows[2].triple.get_global_rect()
		check(last_button.end.x<=rect.end.x-20, "Mode buttons stay inside the settings panel")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/city-settings/weapons-%d.png" % resolution.x)
	root.size=Vector2i(1280,720); await process_frame; game.layout()
	game.city_tactics.open_settings("help"); await create_timer(.7).timeout
	check(game.menu=="city_controls" and game.sim.paused, "Operation instructions live inside settings")
	await escape(); check(game.menu=="city_settings" and game.sim.paused, "Escape from a settings subpage returns to city settings")
	game.open_pause(true); await create_timer(.7).timeout
	check(game.menu=="city_general" and game.sim.paused, "General sound and display settings remain reachable")
	var general_rect: Rect2=game.modal.get_global_rect()
	check(general_rect.position.y>=10 and general_rect.end.y<=710, "General settings fits 720p")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-settings/general-1280.png")
	game.apply_language("en"); await create_timer(.7).timeout
	check(game.menu=="city_general", "Changing language stays in the same settings category")
	await escape(); await create_timer(.7).timeout
	check(game.city_tactics.rows[2].triple.text.contains("Triple"), "Weapon settings rebuild in the chosen language")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-settings/english-1280.png")
	await escape(); await create_timer(.4).timeout
	check(game.menu=="" and not game.sim.paused, "Escape from settings resumes combat")
	game.sim.paused=true; game.apply_language("zh")
	game.toggle_dev_mode(); game.update_hud()
	check(game.dev_mode and not game.dev_bar.visible, "City debug buttons do not occupy the battlefield")
	game.city_tactics.open_settings("debug"); await create_timer(.7).timeout
	check(game.menu=="city_debug" and game.sim.paused, "Existing debug actions are available inside settings")
	var debug_money: float=game.sim.money
	for control in game.modal.find_children("*","Button",true,false):
		if control.text=="资金 ×10": control.pressed.emit(); break
	check(is_equal_approx(game.sim.money,debug_money*10+1000) and game.menu=="", "Relocated funds tool invokes its original action")
	game.city_tactics.open_settings("debug"); await create_timer(.6).timeout
	await escape(); check(game.menu=="city_settings", "Escape from developer tools returns to settings")
	game.close_modal(); game.sim.paused=true
	game.sim.stage=1; game.sim.start_wave(); game.sim.paused=true
	game.update_hud(); game.open_pause()
	check(game.menu=="pause", "Other chapters retain the original pause entry")
	game.close_modal(); game.sim.paused=true
	game.open_body_details(0,1)
	check(is_instance_valid(game.body_card) and game.menu=="", "Other chapter inspection cards are unchanged")
	game.queue_free(); await process_frame
	print("CITY_SETTINGS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
