extends SceneTree
const Fx = preload("res://scripts/ui_fx.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	root.size = Vector2i(800, 300)
	var bar = Fx.BossBar.new()
	bar.position = Vector2(40, 80)
	bar.size = Vector2(640, 70)
	root.add_child(bar)
	await process_frame
	bar.set_process(false)
	bar.reset()
	bar._process(1.0)
	bar.set_hp(.65)
	check(bar.chips.size() > 0, "Large damage still creates falling yellow pieces")
	for hp in [.60, .55, .50]:
		bar.set_hp(hp)
		bar._process(1.0 / 60.0)
	for i in range(33): bar._process(1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png("res://proofs/boss-bar-damage.png")
	var yellow: int = 0
	for x in range(430, 670):
		for y in range(115, 122):
			var c: Color = image.get_pixel(x, y)
			if c.r > .45 and c.g > .30 and c.b < c.r * .65: yellow += 1
	check(yellow == 0, "Lost-health area must not retain yellow fill after pieces fall: %d" % yellow)
	check(not bar.chips.is_empty(), "Falling animation remains visible while old bar area is empty")
	bar.reset(.50)
	bar.set_hp(.50)
	check(bar.chips.is_empty() and bar.shown == .50, "Reopening HUD must start at actual HP without fake damage")
	bar.set_hp(.10)
	for i in range(120): bar._process(1.0 / 60.0)
	check(bar.chips.is_empty() and absf(bar.shown - .10) < .001, "Repeated damage settles and clears debris")
	print("BOSS_BAR_VISUAL failures=", failures, " yellow_lost_area_pixels=", yellow)
	quit(1 if failures else 0)

