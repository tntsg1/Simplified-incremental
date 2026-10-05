extends SceneTree
const Route = preload("res://tests/purchase_route.gd")
var game: Control
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("UI_CHECK ",description," ",ok)
	if not ok:
		failures+=1

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2, hold: bool=false) -> void:
	var event := InputEventMouseButton.new()
	var physical: Vector2=root.get_final_transform()*point
	event.position=physical
	event.global_position=physical
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	if not hold:
		event.pressed=false
		Input.parse_input_event(event)
		await process_frame

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text==title:
		return node
	for child in node.get_children():
		var found: Button=find_button(child,title)
		if found:
			return found
	return null

func screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/"+file_name+".png")

func run() -> void:
	game=preload("res://scenes/main.tscn").instantiate()
	game.store.path="user://skyguard_ui_check.json"
	game.store.enabled=false
	game.pause_on_focus_loss=false
	root.add_child(game)
	await process_frame
	await process_frame
	await screenshot("title")
	var begin: Button=find_button(game,"开始新战役")
	check(begin!=null,"new-game button exists")
	await click(begin.get_global_rect().get_center())
	check(game.sim.mode=="wave" and game.menu=="","mouse starts campaign")
	if game.sim.mode!="wave":
		quit(1)
		return
	game.sim.advance(.3)
	var first: Dictionary=game.sim.enemies[0]
	first.pos=Vector2(430,260)
	first.start=first.pos
	await click(game.field.to_global(first.pos))
	game.sim.advance(1.0/60)
	check(game.sim.shots.size()>0,"a short click launches a missile")
	var shop_tested: bool=false
	var boss_captured: bool=false
	var transition_captured: bool=false
	for frame in range(1500):
		if not game.sim.automation:
			if not game.sim.enemies.is_empty():
				await click(game.field.to_global(game.sim.enemies[0].pos),true)
			game.sim.manual_held=true
		if game.sim.money>=20 and not shop_tested:
			await key(KEY_U)
			check(game.menu=="shop" and game.sim.paused,"keyboard opens paused upgrade panel")
			var elapsed: float=game.sim.elapsed
			var money: float=game.sim.money
			for n in range(6):
				await process_frame
			check(game.sim.elapsed==elapsed and game.sim.money==money,"UI pause freezes time and income")
			var card_button: Button=game.cards[0].button
			await click(card_button.get_global_rect().get_center())
			check(game.sim.levels.damage==1 and is_equal_approx(game.sim.money,money-20),"mouse purchase deducts earned funds")
			await screenshot("city_upgrade")
			await key(KEY_U)
			shop_tested=true
		if game.sim.mode=="boss" and not boss_captured:
			game.update_hud()
			await screenshot("city_boss")
			boss_captured=true
		if game.sim.mode=="transition" and not transition_captured:
			while game.sim.mode_time<3:
				game.sim.advance(1.0/60)
			game.update_hud()
			await process_frame
			await screenshot("city_to_earth")
			transition_captured=true
		if game.sim.stage==1:
			check(game.sim.stage_bosses==1,"actual city waves and boss reach Earth")
			for tick in range(14000):
				game.sim.advance(1.0/60)
				if game.sim.money>=game.sim.stage_data().weapon_price:
					break
			await key(KEY_U)
			check(game.weapon_button!=null and not game.weapon_button.disabled,"Earth weapon purchase available from earned money")
			await click(game.weapon_button.get_global_rect().get_center())
			check(game.sim.owned[1],"mouse deploys orbital railgun")
			await key(KEY_U)
			await screenshot("earth_played")
			await key(KEY_ESCAPE)
			check(game.sim.paused,"Escape pauses")
			await key(KEY_ESCAPE)
			check(not game.sim.paused,"Escape resumes")
			break
		for tick in range(120):
			if tick==0:
				Route.buy(game.sim)
			game.sim.manual_held=not game.sim.automation
			if not game.sim.automation:
				var clicked: Dictionary=game.sim.target_for_weapon()
				if not clicked.is_empty():
					game.sim.priority_id=int(clicked.id)
			game.sim.advance(1.0/60)
			if game.sim.mode in ["failed","transition"]:
				break
		await process_frame
	check(game.sim.stage==1 and game.sim.owned[1] and shop_tested,"city-to-Earth UI flow complete")
	print("PRESENTATION_RESULT failures=",failures)
	quit(0 if failures==0 else 1)
