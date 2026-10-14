extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pointer_frame.set_process(false)
	game.pointer_frame._process(1.0/60.0)
	# Actual pointer visibility and system cursor suppression are checked in
	# Chrome; the headless DisplayServer has no mouse/window cursor capability.
	var free_rect: Rect2 = game.cursor_target_rect(Vector2(500,300))
	check(free_rect.get_center() == Vector2(500,300) and free_rect.size == Vector2(26,26),"Free cursor retains the original reticle radius")
	check(game.pointer_frame.button_mix == 0.0,"Blank space uses the normal reticle")
	var b: Button = game.button("Probe",func(): pass)
	game.add_child(b)
	b.size = Vector2(300,46)
	b.pivot_offset = b.size*.5
	var fx = b.get_meta("fx")
	fx.set_process(false)
	b.mouse_entered.emit()
	fx._process(.03)
	check(fx.radius > 0 and fx.radius < b.size.length(),"Entry must visibly progress rather than instantly fill")
	for i in range(90): fx._process(1.0/120.0)
	check(fx.radius >= b.size.length(),"Hover reaches full fill")
	b.button_down.emit()
	fx._process(.04)
	check(b.scale.x < .99 and b.scale.x >= .8799,"Press produces bounded compression")
	var velocity: float = fx.scale_velocity
	var scale_before: Vector2 = b.scale
	b.button_up.emit()
	check(fx.scale_velocity == velocity and b.scale == scale_before,"Release preserves position and momentum")
	for i in range(16):
		b.mouse_exited.emit()
		fx._process(.015)
		b.mouse_entered.emit()
		fx._process(.015)
		check(is_finite(b.scale.x) and b.scale.x >= .8799 and b.scale.x <= 1.0801,"Interrupted motion stays bounded")
	game.ui_motion = false
	game.pointer_frame._process(1.0/60.0)
	check(game.pointer_frame.corners.size() == 4 and not game.pointer_frame.motion_enabled.call(),"Button frame remains available in static mode")
	fx._process(.016)
	check(b.scale == Vector2.ONE and not fx.visible and fx.buffer.copy_mode == BackBufferCopy.COPY_MODE_DISABLED,"Static preference stops decorative motion and copying")
	game.ui_motion = true
	b.disabled = true
	fx._process(.016)
	check(not fx.visible,"Disabled button must not light up")
	b.disabled = false
	b.mouse_exited.emit()
	for i in range(240): fx._process(1.0/120.0)
	check(absf(b.scale.x-1.0)<.001 and not fx.visible,"Exit settles and stops screen copying")
	b.scale = Vector2.ONE*1.12
	fx._process(1.0/120.0)
	check(b.scale.x > 1.10,"Event emphasis must settle without a scale jump")
	check(b.get_theme_stylebox("focus") is StyleBoxFlat,"Keyboard focus remains visible")
	check(game.settings_payload().ui_motion == true,"Motion preference is saved")
	game.field.show_reticle = true
	game.field.reticle_lock = 1.0
	game.field.lock_pos = Vector2(400,220)
	game.field.lock_radius = 24.0
	var enemy_rect: Rect2 = game.cursor_target_rect(Vector2(900,300))
	check(enemy_rect.get_center().distance_to(game.field.to_global(game.field.lock_pos)) < .001,"Unified frame preserves enemy locking")
	check(game.field.unified_cursor and game.field.show_reticle,"Shared cursor replaces drawing without disabling combat targeting")
	print("UI_MOTION failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
