extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Field = preload("res://scripts/battlefield.gd")
const OUT = "E:/godot/zengliang/build/legacy-weapons/"
var checks := 0
var failures := 0
class ObservedField extends Field:
	var forms: Array[Dictionary] = []
	var segments: Array[float] = []
	var radii: Array[float] = []
	var models: Array[Dictionary] = []
	var draw_mode := "bodies"
	var folded := false
	func _draw() -> void:
		forms.clear()
		segments.clear()
		radii.clear()
		models.clear()
		if draw_mode == "bodies":
			draw_bodies()
		elif draw_mode == "models":
			weapon(2, Vector2(260,220), not folded, .7 if folded else 1.0, folded)
		elif draw_mode == "gallery":
			for index in range(9):
				var point := Vector2(270 + (index % 3) * 460, 150 + (index / 3) * 255)
				weapon(index, point, true, 2.2)
				ink(TranslationServer.translate(sim.catalog.weapons[index].title), point + Vector2(-50, 110), INK, 18)
		elif draw_mode == "full":
			super._draw()
		else:
			draw_strikes()
	func stage_scene(index: int, reveal: float = -1.0) -> void:
		models.append({"stage":index,"transform":scene_transform})
		super.stage_scene(index,reveal)
	func draw_form(form: String, at: Vector2, r: float, lit: float, k: int, big: bool, aim: Vector2 = Vector2.UP, build: float = 1.0, visual_scale: float = 1.0) -> void:
		forms.append({"form":form,"at":at,"radius":r * visual_scale})
		super.draw_form(form,at,r,lit,k,big,aim,build,visual_scale)
	func stroke(a: Vector2, b: Vector2, color: Color, width: float = 1.5) -> void:
		segments.append(a.distance_to(b))
		super.stroke(a,b,color,width)
	func arc_segments(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
		radii.append(radius)
		super.arc_segments(center,radius,from,to,color)
func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func render(node: Node2D) -> void:
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.set_process(false)
	game.audio.set_enabled(false)
	var c = game.sim
	c.stage = 9
	c.mode = "wave"
	c.elapsed = 40
	c.levels.damage = 40
	for s in range(c.STAGE_COUNT):
		c.owned[s] = true
		c.bodies[s] = (1 << c.BODIES[s].size()) - 1
	var observer := ObservedField.new()
	observer.sim = c
	observer.font = game.font
	observer.clock = 40
	root.add_child(observer)
	observer.glow.visible = false
	game.field.visible = false
	var snapshot: String = JSON.stringify(c.snapshot())
	await render(observer)
	check(observer.forms.size() == c.total_bodies(), "every converted body uses its original geometry")
	var index: int = 0
	for s in range(c.STAGE_COUNT):
		for k in range(c.BODIES[s].size()):
			var spec: Dictionary = c.BODIES[s][k]
			var drawn: Dictionary = observer.forms[index]
			index += 1
			check(drawn.form == spec.form, "original form survives: " + str(spec.weapon))
			if s < c.stage:
				check(float(drawn.radius) >= 10.0 and float(drawn.radius) <= 18.0, "thumbnail remains readable")
			var stats: Dictionary = c.body_weapon_stats(s,k)
			check(stats.damage > 0 and stats.interval > 0 and stats.coverage > 0, "real combat stats available")
	check(JSON.stringify(c.snapshot()) == snapshot, "render and stat queries do not change campaign")
	observer.draw_mode = "models"
	observer.folded = true
	observer.core_outer = 123.0
	await render(observer)
	check(observer.models.size() == 1 and observer.models[0].stage == 2, "handoff uses original inner-system model")
	var handoff_model: Transform2D = observer.models[0].transform
	observer.folded = false
	await render(observer)
	check(observer.models.size() == 1 and observer.models[0].stage == 2, "active inherited weapon keeps original scene model")
	check(observer.models[0].transform.is_equal_approx(handoff_model), "handoff and active miniature have identical final pose")
	check(observer.scene_transform == Transform2D.IDENTITY and observer.miniature_stroke_scale == 1 and observer.core_outer == 123.0, "miniature restores shared drawing state")
	game.visible = false
	observer.draw_mode = "gallery"
	await render(observer)
	check(observer.models.size() == 9, "all nine earlier chapter models preserved")
	root.get_texture().get_image().save_png(OUT + "miniature-gallery.png")
	game.visible = true
	observer.draw_mode = "full"
	c.stage = 2
	c.mode = "transition"
	c.mode_time = c.transition_length
	for i in range(c.STAGE_COUNT):
		c.owned[i] = i <= 2
	await render(observer)
	var transition_model: Transform2D = observer.models.back().transform
	c.advance(.01)
	check(c.stage == 3 and c.mode == "wave", "actual simulation completes chapter handoff")
	await render(observer)
	check(observer.models.back().stage == 2 and observer.models.back().transform.is_equal_approx(transition_model), "actual full renderer keeps the same miniature after handoff")
	observer.draw_mode = "strikes"
	c.body_strike.connect(observer.on_body_strike)
	# A real inherited beam must draw from muzzle to impact, not a 34px shorthand.
	c.stage = 3
	c.clear_battle()
	c.mode = "wave"
	c.spawn_enemy(1)
	var target: Dictionary = c.enemies.back()
	target.hp = 1e30
	target.unit_hp = 1e30
	target.pos = Vector2(720,180)
	c.fire_body(2,4,target)
	await render(observer)
	check(observer.segments.any(func(length: float): return length > 100), "inherited Dyson beam keeps full path")
	# A real inherited well must show its area, not one tiny impact glyph.
	c.stage = 4
	c.wells.clear()
	observer.strikes.clear()
	c.fire_body(3,0,target)
	c.wells[0].age = .5
	await render(observer)
	check(observer.radii.any(func(radius: float): return radius > 50), "inherited Jupiter gravity well shows real area")
	observer.queue_free()
	await process_frame
	game.field.visible = true
	# Click a real inherited weapon; the same UI is available for current weapons.
	c.stage = 3
	c.mode = "wave"
	for i in range(c.STAGE_COUNT):
		c.owned[i] = i <= 3
	c.bodies[2] |= 1 << 4
	var point: Vector2 = c.body_position(2,4)
	var picked: Vector2i = game.field.converted_body_at(point)
	check(picked == Vector2i(2,4), "inherited weapon is selectable")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_final_transform() * game.field.to_global(point)
	click.global_position = click.position
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	check(game.body_card_readonly and game.body_card_stage == 2 and game.body_card_slot == 4, "click opens inherited weapon stats")
	if game.body_card_readonly:
		var money: float = c.money
		game.confirm_body_card()
		check(c.money == money, "inspection cannot buy another conversion")
		var shown: String = game.body_card_details.text
		c.levels.damage += 10
		game.refresh_body_card()
		check(game.body_card_details.text != shown, "stats follow real global upgrades")
		game.update_hud()
		await render(game.field)
		root.get_texture().get_image().save_png(OUT + "inherited-dyson-details.png")
	game.close_body_card()
	# Actual game scenes before, during and after a chapter handoff.
	for s in [2,3,6,9]:
		c.stage = s
		c.clear_battle()
		c.mode = "wave"
		c.elapsed = 40
		for i in range(c.STAGE_COUNT):
			c.owned[i] = i <= s
		game.field.clock = 40
		game.field.banner.clear()
		game.field.strikes.clear()
		game.field.feedback.clear()
		game.field.hover = Vector2(-999,-999)
		game.update_hud()
		await render(game.field)
		root.get_texture().get_image().save_png(OUT + "stage-%d.png" % s)
		c.spawn_enemy(1)
		target = c.enemies.back()
		target.hp = 1e30
		target.unit_hp = 1e30
		target.pos = Vector2(720,180)
		for k in range(c.BODIES[s].size()):
			c.fire_body(s,k,target)
		# Fire earlier cannons as well: beams, rails, rings and wells use their real signals.
		for inherited_stage in range(s):
			for k in range(c.BODIES[inherited_stage].size()):
				c.fire_body(inherited_stage,k,target)
		for well in c.wells:
			well.age = .3
		game.field.clock += .1
		await render(game.field)
		root.get_texture().get_image().save_png(OUT + "stage-%d-firing.png" % s)
	c.stage = 2
	c.mode = "transition"
	for i in range(c.STAGE_COUNT):
		c.owned[i] = i <= 2
	for second in [0.0,3.5,c.transition_length]:
		c.mode_time = second
		await render(game.field)
		check(game.field.scene_transform == Transform2D.IDENTITY, "handoff restores transform")
		root.get_texture().get_image().save_png(OUT + "handoff-%.1f.png" % second)
	check(c.restore(c.snapshot()), "inherited conversions survive restore")
	game.queue_free()
	await process_frame
	print("LEGACY_WEAPONS checks=",checks," failures=",failures)
	quit(1 if failures else 0)
