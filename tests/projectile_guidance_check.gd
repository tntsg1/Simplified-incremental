extends SceneTree
const Guidance = preload("res://scripts/projectile_guidance.gd")
const Combat = preload("res://scripts/combat.gd")
const Field = preload("res://scripts/battlefield.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func enemy(id: int, at: Vector2) -> Dictionary:
	return {"id":id,"pos":at,"start":at,"end":at,"lifetime":100.0,"dead":false,"boss":false,"unit_hp":100.0,"reserved":0.0,"radius":12.0}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for angle in [-180,-90,-31,31,90,180]:
		check(not Guidance.within(Vector2.RIGHT.rotated(deg_to_rad(angle)),0.0),"outside launch cone")
	for angle in [-30,-20,0,20,30]:
		check(Guidance.within(Vector2.RIGHT.rotated(deg_to_rad(angle)),0.0),"inside launch cone")
	var sim = Combat.new()
	var field = Field.new()
	field.sim = sim
	field.spawn_barrage(0,Vector2.ZERO,Vector2(900,0),false,1)
	var target = enemy(2,Vector2(900,80))
	field.b_age[0] = .1
	var before: Vector2 = field.round_heading(0,field.b_age[0]/field.b_dur[0])
	var original: float = field.b_launch[0]
	field.swerve(0,target)
	check(field.b_target[0]==2,"forward target accepted")
	check(field.round_heading(0,0.0).dot(before)>.99999,"continuous incoming tangent")
	var previous := Vector2.ZERO
	var samples: Array[Vector2] = []
	for i in range(101):
		var heading: Vector2 = field.round_heading(0,i/100.0)
		check(Guidance.within(heading,original),"entire curve within30 degrees")
		samples.append(field.round_position(0,i/100.0))
	for i in range(1,samples.size()):
		check(absf(samples[i].distance_to(samples[i-1])-field.b_paths[0][-1]/100.0)<.1,"constant arc speed")
	var saved_target: int = field.b_target[0]
	field.swerve(0,enemy(3,Vector2(-900,0)))
	check(field.b_target[0]==saved_target,"visual cannot turn behind")
	for a in [12.0,24.0,36.0,90.0,180.0]:
		field.swerve(0,enemy(4,Vector2.RIGHT.rotated(deg_to_rad(a))*1000.0))
		check(field.b_launch[0]==original,"repeated turns preserve original launch")
		for i in range(21):check(Guidance.within(field.round_heading(0,i/20.0),original),"repeated turn stays bounded")
	field.deflect_round(0,field.round_position(0,0.2))
	for i in range(51):check(Guidance.within(field.round_heading(0,i/50.0),original),"magnetic exit within cone")
	var p: Dictionary = {"target":1,"from":Vector2.ZERO,"pos":Vector2(100,0),"end":Vector2(900,0),"age":.1,"duration":1.0,"damage":10.0,"effective":10.0,"coverage":1,"weapon":0,"crit":false,"beam":false}
	var old = enemy(1,Vector2(900,0));old.reserved=10.0
	var back = enemy(3,Vector2(-800,0))
	sim.enemies.assign([old,back]);sim.enemies_by_id={1:old,3:back};sim.shots.assign([p])
	sim.focus_shots(back)
	check(p.target==1,"simulation focus refuses behind")
	check(old.reserved==10.0,"rejected focus preserves reservation")
	old.dead=true
	check(sim.retarget_shot(p).is_empty(),"dead-target search refuses behind")
	sim.make_stray(p,PI)
	check(Guidance.within(Vector2(p.end)-Vector2(p.from),float(p.launch_angle)),"stray cannot reverse")
	var saved = JSON.parse_string(JSON.stringify(sim.encode_entity(p)))
	check(sim.decode_entity(saved).launch_angle==p.launch_angle,"launch bound survives save JSON")
	check(not Guidance.accepts(Vector2.ZERO,Vector2(5,0),Vector2(10,2),0.0,850.0),"sharp close turn rejected")
	field.free()
	print("PROJECTILE_GUIDANCE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
