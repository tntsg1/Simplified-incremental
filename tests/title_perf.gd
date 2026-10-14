extends SceneTree
# Title-screen frame pacing in a real window.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	for i in range(90):
		await process_frame
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i in range(300):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	print("TITLE_PERF median=%.2f p95=%.2f max=%.2f fps=%d title_draw_ms=%.2f field_draw_ms=%.2f" % [times[150], times[285], times[-1], Engine.get_frames_per_second(), game.title_screen.draw_usec/1000.0, game.field.draw_ms])
	quit()
