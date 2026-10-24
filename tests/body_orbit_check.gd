extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Field = preload("res://scripts/battlefield.gd")
var checks := 0
var failures := 0
class TransitionField extends Field:
	var points: Array[Vector2] = []
	func _draw() -> void:
		points.clear()
		draw_transition_bodies(Transform2D.IDENTITY,1.0)
	func draw_form(form: String, at: Vector2, r: float, lit: float, k: int, big: bool, aim: Vector2 = Vector2.UP, build: float = 1.0, visual_scale: float = 1.0) -> void:
		points.append(at)
		super.draw_form(form,at,r,lit,k,big,aim,build,visual_scale)
func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func verify_orbits(c: RefCounted) -> void:
	var rings: Dictionary = {}
	var points: Array[Vector2] = []
	var center: Vector2 = c.defense_position()
	for s in range(c.stage):
		for k in range(c.BODIES[s].size()):
			if not c.body_converted_at(s,k): continue
			var at: Vector2 = c.body_position(s,k)
			points.append(at)
			var relative: Vector2 = at - center
			var radius: int = int(round(relative.length()))
			if not rings.has(radius): rings[radius] = []
			rings[radius].append(fposmod(relative.angle(),TAU))
	check(rings.size() <= 1, "all inherited cannons share one orbit")
	for radius in rings:
		var angles: Array = rings[radius]
		angles.sort()
		check(absf(radius - c.body_orbit_radius()) < .001, "orbit matches chapter clearance radius")
		for i in range(angles.size()):
			var gap: float = float(angles[(i+1)%angles.size()]) - float(angles[i])
			if i == angles.size()-1: gap += TAU
			check(absf(gap-TAU/angles.size()) < .0001, "equal circular gaps including wrap-around")
	for i in range(points.size()):
		for j in range(i):
			check(points[i].distance_to(points[j]) > 40.0, "readable models have at least 40px centre separation")
	for k in range(c.BODIES[c.stage].size()):
		check(c.body_position(c.stage,k) == c.scene_body_position(c.stage,k), "current chapter bodies keep their original orbits")
func run() -> void:
	# Circular/elliptical background guides occupy these radial bands. The
	# inherited circle must stay outside each band with a visible gap.
	var guide_bands := {
		1: [Vector2(190,190),Vector2(247,247)],
		2: [Vector2(70,70),Vector2(118,118),Vector2(165,165),Vector2(215,215)],
		3: [Vector2(92,92),Vector2(148,148),Vector2(205,205),Vector2(255,255),Vector2(296,296)],
		4: [Vector2(22,22),Vector2(276,300)],
		5: [Vector2(60.2,70),Vector2(120.4,140),Vector2(189.2,220),Vector2(258,300)],
		9: [Vector2(259.5,264.5)]
	}
	var layout = Combat.new()
	for stage in guide_bands:
		var radius: float = layout.body_orbit_radius(stage)
		for band in guide_bands[stage]:
			var gap: float = maxf(float(band.x)-radius,radius-float(band.y))
			check(gap >= 15.0, "single orbit clears existing background guides")
	for stage in range(1,10):
		for sparse in [false,true]:
			var c = Combat.new()
			c.start_new(4262026)
			c.stage = stage
			for s in range(stage):
				c.bodies[s] = ((1 << c.BODIES[s].size())-1) & (0x15 if sparse else 0xffff)
			for elapsed in [0.0,12.3,5000.0]:
				c.elapsed = elapsed
				verify_orbits(c)
			var restored = Combat.new()
			check(restored.restore(c.snapshot()), "existing save format restores")
			for s in range(stage):
				for k in range(c.BODIES[s].size()):
					if c.body_converted_at(s,k):
						check(restored.body_position(s,k).distance_to(c.body_position(s,k)) < .001, "save restore preserves orbit arrangement")
	var game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	game.set_process(false)
	game.audio.set_enabled(false)
	var c = game.sim
	c.stage = 5
	c.elapsed = 12.3
	c.mode = "wave"
	for s in range(c.STAGE_COUNT):
		c.bodies[s] = (1 << c.BODIES[s].size())-1 if s<5 else 0
		c.owned[s] = s<=5
	game.update_hud()
	game.field.clock = c.elapsed
	game.field.banner.clear()
	game.toast.modulate.a = 0
	game.field.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/godot/zengliang/build/orbit-distribution-fixed.png")
	c.spawn_enemy(1)
	var target: Dictionary = c.enemies.back()
	target.hp = 1e30
	target.unit_hp = 1e30
	target.pos = Vector2(500,100)
	c.body_fired.connect(func(s: int,k: int,origin: Vector2,_to: Vector2,_crit: bool): check(origin.distance_to(c.body_position(s,k))<.001,"real shot starts on displayed orbit"))
	for s in range(c.stage):
		for k in range(c.BODIES[s].size()):
			if c.body_converted_at(s,k): c.fire_body(s,k,target)
	game.field.visible = false
	c.bodies[5] = (1 << c.BODIES[5].size())-1
	var transition := TransitionField.new()
	transition.sim = c
	transition.font = game.font
	root.add_child(transition)
	transition.glow.visible = false
	transition.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var projected: Array[Vector2] = transition.points.duplicate()
	c.stage = 6
	var i: int = 0
	for s in range(c.stage):
		for k in range(c.BODIES[s].size()):
			if not c.body_converted_at(s,k): continue
			check(projected[i].distance_to(c.body_position(s,k)) < .001,"transition lands exactly on active orbit")
			i += 1
	check(i == projected.size(),"no missing handoff bodies")
	transition.queue_free()
	game.queue_free()
	await process_frame
	print("BODY_ORBIT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
