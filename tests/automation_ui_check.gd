extends SceneTree
var game: Control
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	print("AUTOMATION_UI ",description," ",ok)
	if not ok:failures+=1
func click(point: Vector2) -> void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*point
	e.global_position=e.position
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	Input.parse_input_event(e)
	await process_frame
	e.pressed=false
	Input.parse_input_event(e)
	await process_frame
func capture(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://proofs/automation_"+title+"_"+str(root.size.x)+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	root.add_child(game)
	await process_frame
	game.start_game()
	game.sim.paused=true
	game.sim.wave=5
	game.update_hud()
	check(not game.hud_auto_button.visible,"not advertised before wave six")
	game.sim.wave=6
	game.sim.money=84
	game.update_hud()
	check(game.hud_auto_button.visible and game.hud_auto_button.disabled,"wave six shows unaffordable purchase")
	check(game.hud_auto_button.text.contains("116") and game.hint.text.contains("已开放"),"exact missing funds and unlocked explanation")
	game.sim.wave=10
	game.update_hud()
	check(game.hud_auto_button.visible,"purchase remains visible at wave ten")
	await capture("missing")
	await click(game.hud_auto_button.get_global_rect().get_center())
	check(not game.sim.automation and game.sim.money==84,"disabled purchase does not spend or enable")
	game.sim.money=200
	game.update_hud()
	check(not game.hud_auto_button.disabled,"purchase enabled at exact cost")
	await capture("ready")
	await click(game.hud_auto_button.get_global_rect().get_center())
	check(game.sim.automation and game.sim.money==0,"real mouse enables automation and deducts exactly 200")
	check(not game.hud_auto_button.visible and game.hint.text.contains("自动拦截"),"purchased HUD changes to automatic defense")
	check(game.menu=="" and game.sim.wave==10,"direct purchase keeps current wave without a modal")
	await capture("enabled")
	var saved: Dictionary=game.sim.snapshot()
	var restored=load("res://scripts/combat.gd").new()
	check(restored.restore(saved) and restored.automation and restored.wave==10,"restored progress keeps purchased automation")
	print("AUTOMATION_UI_RESULT failures=",failures)
	quit(1 if failures else 0)
