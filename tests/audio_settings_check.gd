extends SceneTree
var game: Control
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	print("AUDIO_SETTING ",title," ",ok)
	if not ok:failures+=1
func sliders(node: Node, result: Array[HSlider]) -> void:
	if node is HSlider:result.append(node)
	for child in node.get_children():sliders(child,result)
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
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.store.enabled=false
	game.pause_on_focus_loss=false
	game.store.path="user://skyguard_audio_settings_check.json"
	root.add_child(game)
	await process_frame
	game.start_game()
	game.audio.set_enabled(true)
	AudioServer.set_bus_volume_db(0,-80)
	game.open_pause()
	await process_frame
	var controls: Array[HSlider]=[]
	sliders(game.modal,controls)
	check(controls.size()==2,"separate music and effects controls")
	if controls.size()!=2:quit(1);return
	for i in range(2):
		var slider: HSlider=controls[i]
		var rect: Rect2=slider.get_global_rect()
		await click(Vector2(rect.position.x+1,rect.get_center().y))
		check(slider.value==0,"mouse can mute channel "+str(i))
		var bus: int=AudioServer.get_bus_index("Skyguard Music" if i==0 else "Skyguard SFX")
		check(AudioServer.is_bus_mute(bus),"zero level mutes whole bus "+str(i))
		await click(rect.get_center())
		check(slider.value>0 and not AudioServer.is_bus_mute(bus),"mouse restores channel "+str(i))
	game.sound_on=false
	game.audio.set_enabled(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Skyguard Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Skyguard SFX")),"global mute covers both buses")
	game.store.enabled=true
	game.save_game()
	var saved: Dictionary=game.store.read_game()
	check(not saved.settings.sound and is_equal_approx(float(saved.settings.music_level),game.audio.music_level) and is_equal_approx(float(saved.settings.effects_level),game.audio.effects_level),"save retains both levels and mute")
	game.store.enabled=false
	game.pause_on_focus_loss=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.store.path+".bak"))
	print("AUDIO_SETTINGS_RESULT failures=",failures)
	quit(1 if failures else 0)
