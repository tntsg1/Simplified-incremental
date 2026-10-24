extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
	Engine.max_fps=60; call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code; event.pressed=true; Input.parse_input_event(event)
	await process_frame
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event)
	await process_frame
func click(point: Vector2) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.position=point; event.global_position=point
	Input.parse_input_event(event); await process_frame
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await process_frame
func all_text(node: Node) -> String:
	if not is_instance_valid(node): return ""
	var text: String=str(node.text) if node is Label or node is Button else ""
	for child in node.get_children(): text+="\n"+all_text(child)
	return text
func primary(game: Control) -> Array[Button]:
	var buttons: Array[Button]=[]
	for child in game.modal.get_child(0).get_children():
		if child is Button: buttons.append(child)
	return buttons
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/correct-entries/"+name+".png")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.size=Vector2i(1280,720)
	var game=preload("res://scenes/main.tscn").instantiate()
	game.store.enabled=false; root.add_child(game); await process_frame
	game.saved={}; game.start_game(); game.sim.wave=6; game.sim.bodies[0]=7
	game.sim.paused=true; await create_timer(.6).timeout; game.layout()
	DirAccess.make_dir_recursive_absolute("res://build/correct-entries")
	await key(KEY_ESCAPE); await create_timer(.7).timeout
	var buttons: Array[Button]=primary(game)
	check(game.menu=="city_pause" and game.sim.paused, "Esc opens first pause page")
	check(buttons.size()==3 and buttons[0].text=="继续" and buttons[1].text=="设置" and buttons[2].text=="退出", "Exactly Continue, Settings, Quit")
	check(not all_text(game.modal).contains("导弹发射井") and not all_text(game.modal).contains("摩天楼"), "No weapons in pause menu")
	var time: float=game.sim.elapsed; await create_timer(.1).timeout
	check(is_equal_approx(game.sim.elapsed,time), "Battle time is paused")
	await capture("pause")
	buttons[1].pressed.emit(); await create_timer(.7).timeout
	check(game.menu=="city_general", "Settings is a child page")
	check(game.modal.find_children("*","HSlider",true,false).size()==2, "Audio volume sliders are in Settings")
	var text: String=all_text(game.modal)
	check(not text.contains("导弹发射井") and not text.contains("重点拦截") and not text.contains("三连发") and not text.contains("摩天楼"), "No weapons or attack selectors in Settings")
	check(text.contains("开发者模式"), "Developer mode can also be toggled in preferences")
	await capture("settings")
	await key(KEY_ESCAPE); check(game.menu=="city_pause", "Back from settings returns to first page")
	await key(KEY_QUOTELEFT); await create_timer(.7).timeout
	check(game.dev_mode and game.dev_bar.visible, "Tilde immediately enables the original developer toolbar")
	check(game.menu=="city_pause" and all_text(game.modal).contains("资金 ×10"), "Tools are directly on first pause page")
	check(primary(game).size()==3, "Three primary actions remain unchanged with developer mode")
	var rect: Rect2=game.modal.get_global_rect()
	check(rect.position.y>=10 and rect.end.y<=710, "Developer pause menu fits 720p")
	await capture("developer")
	await key(KEY_ESCAPE); check(game.menu=="" and not game.sim.paused, "Esc resumes combat")
	game.sim.paused=true; game.layout()
	await click(root.get_final_transform()*game.field.to_global(game.sim.body_position(0,2)))
	await process_frame; game.refresh_body_card()
	check(is_instance_valid(game.body_card) and game.body_card_stage==0 and game.body_card_slot==2, "Click right installation opens its own page")
	if is_instance_valid(game.body_card):
		check(all_text(game.body_card).contains("东区摩天楼") and not all_text(game.body_card).contains("导弹发射井") and not all_text(game.body_card).contains("西区摩天楼"), "Installation page lists only itself")
		game.body_card_modes[1].pressed.emit()
		check(game.sim.body_modes.count(0,2)==3 and game.sim.body_modes.count(0,0)==1, "Individual setting leaves neighbors alone")
		await capture("right-tower")
	var tower_width: float=game.body_card.size.x if is_instance_valid(game.body_card) else 328
	game.close_body_card()
	await process_frame
	game.sim.paused=false
	await click(root.get_final_transform()*game.field.to_global(game.sim.weapon_origin(0)))
	await create_timer(.7).timeout
	check(game.menu=="" and game.body_card_silo and not game.sim.paused, "Silo opens a small non-pausing card")
	text=all_text(game.body_card)
	check(text.contains("导弹发射井") and text.contains("重点拦截") and text.contains("分路拦截") and not text.contains("摩天楼"), "Silo page contains only silo modes")
	check(not is_instance_valid(game.modal) and not game.shade.visible, "No centered modal or background dimming for silo")
	check(absf(game.body_card.size.x-tower_width)<2 and game.body_card.size.x<=350, "Silo card matches the other installation card width")
	var silo_rect: Rect2=game.body_card.get_global_rect()
	check(silo_rect.position.x>=20 and silo_rect.end.x<=1260 and silo_rect.position.y>=124 and silo_rect.end.y<=610, "Silo card fits 720p play area")
	game.sim.paused=true
	for wave in range(1,6):
		game.sim.wave=wave; game.refresh_body_card(); await process_frame
		check(not game.silo_card_options.is_visible_in_tree() and not game.silo_card_modes[0].is_visible_in_tree() and not game.silo_card_modes[1].is_visible_in_tree(), "Wave %d hides locked mode options" % wave)
		check(not game.body_card_details.text.contains("解锁") and not game.body_card_details.text.contains("unlock"), "No locked-feature placeholder")
	check(game.body_card.size.y<240, "Locked modes leave no empty space in the card")
	await capture("silo-before-wave6")
	game.sim.wave=6; game.refresh_body_card(); await process_frame
	check(game.silo_card_options.is_visible_in_tree() and game.silo_card_modes[1].is_visible_in_tree() and not game.silo_card_modes[1].disabled, "Wave six reveals available modes in the already-open card")
	var expanded: Rect2=game.body_card.get_global_rect()
	check(expanded.end.y<=610, "Card expansion stays inside the play area")
	game.sim.paused=false
	var elapsed: float=game.sim.elapsed; await create_timer(.1).timeout
	check(game.sim.elapsed>elapsed, "Combat keeps running just like other small cards")
	var cooldown: float=game.sim.cooldowns[0]
	game.silo_card_modes[1].pressed.emit()
	check(game.sim.city_mode==0 and game.sim.city_mode_next==1 and is_equal_approx(game.sim.cooldowns[0],cooldown), "Small card preserves next-wave switching without reload reset")
	await capture("silo")
	root.size=Vector2i(1600,900); await process_frame; game.layout(); game.refresh_body_card(); await process_frame
	var large_rect: Rect2=game.body_card.get_global_rect()
	check(game.body_card.size.x<=350 and large_rect.end.x<=1580 and large_rect.end.y<=790, "Silo remains a small anchored card at 1600x900")
	await capture("silo-1600")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(game.body_card) and game.menu=="", "Esc closes silo card like other cards")
	game.sim.paused=true
	game.open_pause(); game.apply_language("en"); await create_timer(.7).timeout
	buttons=primary(game)
	check(buttons.size()==3 and buttons[0].text=="Continue" and buttons[1].text=="Settings" and buttons[2].text=="Quit", "Hierarchy persists across language switch")
	game.close_modal(); game.sim.stage=1; game.sim.start_wave(); game.sim.paused=true
	game.open_pause(); check(game.menu=="pause", "Other chapters retain the existing pause flow")
	game.queue_free(); await process_frame
	print("CORRECT_ENTRIES checks=",checks," failures=",failures)
	quit(1 if failures else 0)
