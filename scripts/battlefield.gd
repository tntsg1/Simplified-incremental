extends Node2D

var sim: RefCounted
var font: Font
var clock: float = 0.0
var hover: Vector2 = Vector2(-1000, -1000)
var stars: Array[Vector3] = []
var galaxy_points: PackedVector2Array = []
var scene_transform := Transform2D.IDENTITY
var draw_ms: float=0
var star_mesh: MultiMesh
var galaxy_mesh: MultiMesh
var warm_galaxy_mesh: MultiMesh
var labels_left: int=24
var reduced_effects: bool=false
var trauma: float=0
var feedback: Array[Dictionary]=[]
var feedback_pool: Array[Dictionary]=[]
var recoil: Array[float]=[0,0,0,0,0,0]
var aims: Array[float]=[0,0,0,0,0,0]
var muzzle_limits: Array[float]=[0,0,0,0,0,0]
var spark_limits: Array[float]=[0,0,0,0,0,0]
var pierce_limits: Array[float]=[0,0,0,0,0,0]
var tint:=Color.WHITE
const RockTexture=preload("res://assets/rock.svg")
const ShipTexture=preload("res://assets/ship.svg")
const StarTexture=preload("res://assets/star.svg")
const Fleet=[preload("res://assets/fleet/ship_0.svg"),preload("res://assets/fleet/ship_1.svg"),preload("res://assets/fleet/ship_2.svg"),preload("res://assets/fleet/ship_3.svg"),preload("res://assets/fleet/ship_4.svg"),preload("res://assets/fleet/ship_5.svg")]
const Hazards=[preload("res://assets/fleet/hazard_0.svg"),preload("res://assets/fleet/hazard_1.svg"),preload("res://assets/fleet/hazard_2.svg"),preload("res://assets/fleet/hazard_3.svg"),preload("res://assets/fleet/hazard_4.svg"),preload("res://assets/fleet/hazard_5.svg")]
const Guns=[preload("res://assets/fleet/weapon_0.svg"),preload("res://assets/fleet/weapon_1.svg"),preload("res://assets/fleet/weapon_2.svg"),preload("res://assets/fleet/weapon_3.svg"),preload("res://assets/fleet/weapon_4.svg"),preload("res://assets/fleet/weapon_5.svg")]
const BossShip=preload("res://assets/fleet/boss_ship.svg")
const EarthTexture=preload("res://assets/worlds/earth.svg")
const PlanetTexture=preload("res://assets/worlds/rocky.svg")
const SunTexture=preload("res://assets/worlds/sun.svg")
var cyan := Color("65e2c1")
var muted := Color("647e92")

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var random := RandomNumberGenerator.new()
	random.seed = 9294
	for i in range(260):
		stars.append(Vector3(random.randf_range(-250, 1250), random.randf_range(-120, 720), random.randf_range(0.4, 1.7)))
	for i in range(1800):
		var t: float = random.randf()
		var r: float = sqrt(t) * 235
		var a: float = t * 7.5 + (i % 4) * TAU / 4 + random.randfn(0, 0.13)
		galaxy_points.append(Vector2(cos(a) * r, sin(a) * r * 0.46))
	star_mesh=MultiMesh.new()
	star_mesh.transform_format=MultiMesh.TRANSFORM_2D
	star_mesh.use_colors=true
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	star_mesh.mesh=quad
	star_mesh.instance_count=stars.size()
	for i in range(stars.size()):
		var s: Vector3=stars[i]
		star_mesh.set_instance_transform_2d(i,Transform2D(0,Vector2.ONE*s.z,0,Vector2(s.x,s.y)))
		star_mesh.set_instance_color(i,Color(.6,.77,.91,.2+s.z*.2))
	galaxy_mesh=make_galaxy_mesh(Color("9aa7d4"))
	warm_galaxy_mesh=make_galaxy_mesh(Color("c1a4c6"))
	for i in range(144):feedback_pool.append({})

func add_feedback(kind: String, point: Vector2, index: int, size: float, duration: float, destination: Vector2=Vector2.ZERO) -> void:
	if feedback.size()>=48:return
	var fx: Dictionary=feedback_pool.pop_back() if not feedback_pool.is_empty() else {}
	fx.clear()
	fx.merge({"kind":kind,"pos":point,"weapon":index,"size":size,"age":0.0,"duration":duration,"end":destination,"seed":int(point.x*17+point.y*23)})
	feedback.append(fx)

func on_fire(index: int, point: Vector2, destination: Vector2, critical: bool) -> void:
	recoil[index]=1.0
	aims[index]=(destination-point).angle()
	if muzzle_limits[index]>0:return
	muzzle_limits[index]=.075
	add_feedback("muzzle",point,index,18+index*6,.16)
	if index>=2:add_feedback("beam",point,index,1.5+index*.8,.19,destination)
	if critical:add_feedback("critical",destination,index,24,.28)

func on_hit(point: Vector2, index: int, _amount: float, critical: bool, boss: bool, _kind: String) -> void:
	if spark_limits[index]>0:return
	spark_limits[index]=.085
	add_feedback("spark",point,index,22 if critical else 13,.28)
	trauma=minf(.42,trauma+(.07 if boss else .025))

func on_members_removed(point: Vector2, index: int, members: int, kind: String) -> void:
	add_feedback("debris_ship" if kind.contains("ship") else "debris_rock",point,index,12+minf(15,log(maxf(1,members))*1.2),.48)

func on_pierced(origin: Vector2, destination: Vector2, index: int) -> void:
	if pierce_limits[index]>0:return
	pierce_limits[index]=.14
	add_feedback("pierce",origin,index,1,.23,destination)

func on_destroyed(point: Vector2, index: int, members: int, boss: bool, kind: String) -> void:
	if boss and feedback.size()>=48:feedback_pool.append(feedback.pop_front())
	var size: float=92 if boss else 20+minf(22,log(maxf(1,members))*2)
	add_feedback("boss_death" if boss else "debris_ship" if kind.contains("ship") else "debris_rock",point,index,size,2.3 if boss else .85)
	trauma=.95 if boss else minf(.45,trauma+.1)

func animate(delta: float) -> void:
	trauma=maxf(0,trauma-delta*2.3)
	for i in range(6):
		recoil[i]=maxf(0,recoil[i]-delta*5.5)
		muzzle_limits[i]=maxf(0,muzzle_limits[i]-delta)
		spark_limits[i]=maxf(0,spark_limits[i]-delta)
		pierce_limits[i]=maxf(0,pierce_limits[i]-delta)
	for i in range(feedback.size()-1,-1,-1):
		feedback[i].age=float(feedback[i].age)+delta
		if float(feedback[i].age)>=float(feedback[i].duration):
			feedback_pool.append(feedback[i])
			feedback.remove_at(i)

func shake_offset() -> Vector2:
	if reduced_effects:return Vector2.ZERO
	return Vector2(sin(clock*47),sin(clock*59+1.7))*trauma*trauma*7

func draw_feedback() -> void:
	for fx in feedback:
		var t: float=float(fx.age)/float(fx.duration)
		var p: Vector2=fx.pos
		var c: Color=sim.catalog.weapons[int(fx.weapon)].color
		c.a=(1-t)*(.5 if reduced_effects else 1)
		var r: float=float(fx.size)
		match str(fx.kind):
			"pierce":
				var destination: Vector2=fx.end
				for j in range(4):draw_line(p.lerp(destination,j*.25),p.lerp(destination,j*.25+.15),Color(c,c.a*.6),1.2,true)
				draw_arc(destination,5+6*t,0,TAU,16,Color(c,c.a*.6),1,true)
			"beam":
				var destination: Vector2=fx.end
				draw_line(p,destination,Color(c,c.a*.045),r*7,true)
				draw_line(p,destination,Color(c,c.a*.65),r,true)
				draw_line(p,destination,Color(1,1,1,c.a*.8),.8,true)
			"muzzle":
				draw_texture_rect(StarTexture,Rect2(p-Vector2.ONE*r,Vector2.ONE*r*2),false,c)
			"spark","critical":
				draw_texture_rect(StarTexture,Rect2(p-Vector2.ONE*r*(1+t),Vector2.ONE*r*(2+2*t)),false,Color(1,.9,.78,c.a*.8))
				for j in range(3):
					var angle: float=j*TAU/5+int(fx.seed)
					var dir:=Vector2(cos(angle),sin(angle))
					draw_line(p+dir*r*t,p+dir*r*(t+.24),c,1.5,true)
				if fx.kind=="critical":ink("暴击",p+Vector2(16,-18-t*14),c,12)
			"debris_rock","debris_ship","boss_death":
				var boss: bool=fx.kind=="boss_death"
				draw_arc(p,r*(.3+t*2.2),0,TAU,48 if boss else 20,Color(c,c.a*.65),2.5 if boss else 1,true)
				draw_texture_rect(StarTexture,Rect2(p-Vector2.ONE*r*(1-t*.7),Vector2.ONE*r*2*(1-t*.7)),false,Color(c,c.a*.9))
				if not reduced_effects:
					for j in range(22 if boss else 4):
						var angle: float=j*2.399+int(fx.seed)
						var direction:=Vector2(cos(angle),sin(angle))
						var q: Vector2=p+direction*r*(1-pow(1-t,2))*(.6+(j%4)*.5)
						var shard: float=(4 if not boss else 9)*(1-t)+.2
						draw_texture_rect(ShipTexture if fx.kind=="debris_ship" else RockTexture,Rect2(q-Vector2.ONE*shard,Vector2.ONE*shard*2),false,Color(c,c.a))
						draw_line(q-direction*5,q,c,1,true)

func make_galaxy_mesh(color: Color) -> MultiMesh:
	var mesh:=MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_2D
	mesh.use_colors=true
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	mesh.mesh=quad
	mesh.instance_count=galaxy_points.size()
	for i in range(galaxy_points.size()):
		mesh.set_instance_transform_2d(i,Transform2D(0,Vector2.ONE*(1.0 if i%4 else 2.1),0,galaxy_points[i]))
		mesh.set_instance_color(i,Color(color,.22+(i%7)*.07))
	return mesh

func ink(text: String, pos: Vector2, color: Color = Color("8fa5b8"), size: int = 12) -> void:
	if not scene_transform.is_equal_approx(Transform2D.IDENTITY):
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func orbit(center: Vector2, radius: Vector2, color: Color, width: float = 1.0) -> void:
	var points := PackedVector2Array()
	for j in range(81):
		var a: float = j * TAU / 80
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(points, color, width, true)

func glow(center: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(StarTexture,Rect2(center-Vector2.ONE*radius*2,Vector2.ONE*radius*4),false,Color(color,color.a*.33))
	draw_circle(center, radius, color)

func planet(center: Vector2, radius: float, earth: bool = true) -> void:
	var extent: float=radius*256.0/224
	draw_texture_rect(EarthTexture if earth else PlanetTexture,Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2),false,tint)

func city() -> void:
	for i in range(7):
		draw_line(Vector2(-220, 525 + i * 7), Vector2(1220, 525 + i * 7), Color(0.2, 0.48, 0.52, 0.025), 8)
	for layer in range(3):
		for i in range(35):
			var x: float = -210 + i * 43 + layer * 17
			var height: float = 28 + fmod(i * 39.3 + layer * 43, 104) + (40 if i % 8 == 0 else 0)
			var y: float = 555 + layer * 22
			var shade := Color("0b1c2d") if layer == 0 else Color("102739") if layer == 1 else Color("163347")
			draw_rect(Rect2(x, y - height, 28 + layer * 7, height), shade)
			draw_line(Vector2(x, y - height), Vector2(x + 28 + layer * 7, y - height), Color("365166"), 1)
			if i % 5 == 0:
				draw_line(Vector2(x + 12, y-height), Vector2(x+12,y-height-15), muted, 1)
			for row in range(int(height / 12) - 1):
				for col in range(3):
					if (row + col + i) % 4 != 0:
						draw_rect(Rect2(x + 5 + col * 7, y - height + 9 + row * 11, 2, 3), Color("658779") if layer < 2 else Color("afaf73"))
	draw_rect(Rect2(-250, 600, 1500, 130), Color("081725"))
	draw_line(Vector2(-250, 601), Vector2(1250, 601), cyan * Color(1,1,1,0.25), 1)
	for x in range(-200, 1200, 80):
		draw_line(Vector2(x, 617), Vector2(x + 30, 617), Color("254155"), 2)
	ink("01  /  防御控制中心", Vector2(555, 579), Color("b4c9d1"), 12)
	ink("地表发射阵列  ──────", Vector2(190, 650), muted)

func galaxy(center: Vector2, size: float, color: Color, rotation: float = 0) -> void:
	draw_set_transform_matrix(scene_transform * Transform2D(rotation,Vector2.ONE*size,0,center))
	draw_multimesh(warm_galaxy_mesh if color.r>color.b*.95 else galaxy_mesh,StarTexture)
	glow(Vector2.ZERO, 14, Color(color, 0.7))
	draw_set_transform_matrix(scene_transform)

func stage_scene(index: int) -> void:
	var c := Vector2(500, 325)
	match index:
		0:
			city()
		1:
			orbit(c, Vector2(190, 85), Color("294655"))
			orbit(c, Vector2(247, 128), Color("182f42"))
			planet(c, 81)
			planet(c + Vector2(247, -33), 12, false)
			ink("地球", c + Vector2(-15, 109), Color("b1d9e9"), 14)
			ink("城市防线", c + Vector2(92, -59))
			draw_line(c + Vector2(47, 31), c + Vector2(91, -45), Color("497f8d"), 1)
			draw_circle(c + Vector2(47,31), 3, cyan)
		2:
			for i in range(5):
				orbit(c, Vector2(70 + i*58, 36 + i*29), Color("30404c"))
			glow(c, 37, Color("eabd63"))
			draw_texture_rect(SunTexture,Rect2(c-Vector2.ONE*43,Vector2.ONE*86),false)
			draw_arc(c, 43, clock*.1, clock*.1+4.3, 48, Color("8d633e"), 1)
			for i in range(5):
				var a: float = i * 1.72 + 0.2
				var p: Vector2 = c + Vector2(cos(a)*(70+i*58),sin(a)*(36+i*29))
				planet(p, 5 + i * 2, i == 1)
			ink("太阳", c + Vector2(-15, 65), Color("dfc287"), 14)
			ink("地球轨道炮", c + Vector2(104, 52))
		3:
			galaxy(c, 1.35, Color("909ece"), -0.2)
			orbit(c, Vector2(275, 130), Color("2d3552"))
			ink("银河核心", c + Vector2(-29, 46), Color("c3b8e7"), 14)
			draw_circle(c + Vector2(160, 16), 3, Color("eac37f"))
			ink("太阳系", c + Vector2(170, 22))
		4:
			for i in range(7):
				var a: float = i * 2.4
				var p: Vector2 = c + Vector2(cos(a)*230, sin(a)*140)
				draw_line(c, p, Color("263949"), 1)
				galaxy(p, 0.33, Color("c1a4c6"), a*.3)
			galaxy(c, 0.62, Color("a3b7dc"), -0.4)
			orbit(c, Vector2(313,183), Color("3b304c"))
			ink("本星系群", c + Vector2(-25, 68), Color("d3bdde"), 14)
		5:
			for i in range(34):
				var a: float = i * 2.399
				var r: float = sqrt(float(i)/34)*360
				var p: Vector2 = c + Vector2(cos(a)*r, sin(a)*r*.63)
				var p2: Vector2 = c + Vector2(cos(a+1.5)*r*.75, sin(a+1.5)*r*.63)
				draw_line(p,p2,Color("223d50"),1)
				glow(p, 3 + i%3, Color("7696ba"))
			orbit(c,Vector2(358,226), Color("456278"),1.4)
			orbit(c,Vector2(360,95), Color("2c4556"))
			galaxy(c,.10,Color("c1a4c6"),-.4)
			ink("可观测宇宙 · 防御枢纽", c+Vector2(-65,56),Color("bdd7e5"),14)

func weapon(index: int, point: Vector2, small: bool = false) -> void:
	var c: Color = sim.catalog.weapons[index].color
	var tier: int = int(sim.levels.reload) / 10
	var s: float = 0.72 if small else 1.0
	var direction:=Vector2(cos(aims[index]),sin(aims[index]))
	var position: Vector2=point-direction*recoil[index]*(3+index)
	draw_set_transform_matrix(scene_transform * Transform2D(0 if index==0 else aims[index],Vector2.ONE*s,0,position))
	if index==0 and tier>=1:
		draw_texture_rect(Guns[index],Rect2(-59,-22,56,28),false)
		draw_texture_rect(Guns[index],Rect2(3,-22,56,28),false)
	else:
		draw_texture_rect(Guns[index],Rect2(-42,-21,84,42),false)
	for j in range(mini(5,tier)):
		draw_line(Vector2(-17+j*7,17),Vector2(-13+j*7,17),c,2,true)
	if index>=2:glow(Vector2(23,0),3+index*.4,c)
	draw_set_transform_matrix(scene_transform)
	if not small and (index==sim.stage or hover.distance_to(point)<48):
		ink(sim.catalog.weapons[index].title,point+Vector2(-30,43),Color("a0b5c5"),10)
	if hover.distance_to(point)<30:
		var panel: Vector2=point+Vector2(-115,-96)
		draw_rect(Rect2(panel,Vector2(230,65)),Color("0b1d2b"))
		draw_rect(Rect2(panel,Vector2(230,65)),Color(c,.45),false,1)
		ink(sim.catalog.weapons[index].title+" · 在役",panel+Vector2(10,19),c,13)
		ink("齐射 "+sim.Catalog.number(sim.shot_damage(index))+" / "+("%.2f s"%sim.shot_interval(index)),panel+Vector2(10,38),Color("b1c4d2"),11)
		ink("每次覆盖 "+sim.Catalog.number(sim.coverage(index))+" 成员",panel+Vector2(10,55),Color("89a5b8"),11)

func asteroid(point: Vector2, radius: float, seed_value: int, boss: bool = false) -> void:
	var shade: Color=Color("cbb5b6") if boss else Color(1,1,1,1) if seed_value%3 else Color("b8b1bf")
	draw_set_transform_matrix(scene_transform*Transform2D(seed_value*.19+clock*.06,point))
	draw_texture_rect(Hazards[sim.stage],Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,shade*tint)
	draw_set_transform_matrix(scene_transform)
	if boss:
		draw_line(point+Vector2(-radius*.6,-radius*.4),point+Vector2(radius*.3,radius*.55),Color("d77a5a"),2)

func ship(point: Vector2, radius: float, boss: bool = false, angle: float=0) -> void:
	draw_set_transform_matrix(scene_transform*Transform2D(angle,point))
	draw_texture_rect(BossShip if boss else Fleet[sim.stage],Rect2(-Vector2.ONE*radius,Vector2.ONE*radius*2),false,tint)
	if boss:
		for i in range(4):
			var x: float = (i-1.5)*radius*.35
			draw_rect(Rect2(x-5,-radius*.2,10,radius*.45),Color("a07391"))
			glow(Vector2(x,radius*.6),4,Color("d47ec1"))
	draw_set_transform_matrix(scene_transform)

func enemy(e: Dictionary) -> void:
	var p: Vector2 = e.pos
	var radius: float = float(e.radius)
	var boss: bool = bool(e.boss)
	var focused: bool=int(e.id)==sim.priority_id or hover.distance_to(p)<radius+13
	var dense: bool=sim.enemies.size()>70
	if dense and not boss and not focused:radius*=.75
	var flash: float=clampf(float(e.get("flash",0))/.12,0,1)
	tint=Color(1+flash*2,1+flash*2,1+flash*2,1)
	p+=Vector2(sin(clock*70),cos(clock*63))*flash*(.5 if boss else 1.6)
	var danger: float = float(e.age)/float(e.lifetime)
	if dense and not boss and not focused:
		tint.a=clampf(.48+danger*.5+flash*.45,.48,1)
	var trail: Vector2 = (Vector2(e.start)-Vector2(e.end)).normalized()
	draw_line(p,p+trail*radius*3,Color(0.8,0.46,0.49,0.1),radius*.7,true)
	var kind: String = e.kind
	var heading: float=(-trail).angle()+PI*.5+sin(clock*.8+int(e.seed))*.035
	if kind in ["ship","elite_ship","mothership"]:
		ship(p,radius,boss,heading)
	elif kind == "star":
		glow(p,radius,Color("ee9671"))
		draw_texture_rect(SunTexture,Rect2(p-Vector2.ONE*radius*1.14,Vector2.ONE*radius*2.28),false,tint)
		draw_arc(p,radius+12,clock,clock+5.2,80,Color("b875a0"),3,true)
	elif kind == "planet":
		planet(p,radius,false)
	elif kind == "rift":
		for j in range(7,0,-1):
			draw_arc(p,radius+j*4,clock*(.08+j*.04),clock*(.08+j*.04)+5.6,80,Color(.45,.65,.86,.16),2,true)
		draw_circle(p,radius*.65,Color("030912"))
		draw_arc(p,radius*.72,-clock*.2,-clock*.2+5.5,80,Color("c2ddf2"),3,true)
	else:
		asteroid(p,radius,int(e.seed),boss)
	if int(e.members)>1:
		var companions: int=6 if not dense else 2 if focused or danger>.8 else 0
		for j in range(mini(companions,int(e.members)-1)):
			var a: float = j*2.39
			var q: Vector2 = p + Vector2(cos(a),sin(a))*radius*1.5
			if kind == "ship":
				ship(q,5,false,heading)
			else:
				asteroid(q,4,int(e.seed)+j)
		if labels_left>0 or int(e.id)==sim.priority_id or p.distance_to(hover)<radius+13:
			ink("×"+sim.Catalog.number(e.members),p+Vector2(-15,radius+20),Color("b5c5d4"),12)
			labels_left-=1
	if bool(e.elite) and not boss:
		draw_arc(p,radius+6,0,TAU,40,Color("c393a9"),1,true)
		if sim.enemies.size()<60 or hover.distance_to(p)<radius+13 or int(e.id)==sim.priority_id:
			ink("精英",p+Vector2(-12,-radius-11),Color("d8b9ce"),10)
	if danger>.7:
		draw_arc(p,radius+10,-PI*.5,-PI*.5+TAU*danger,40,Color("e99b77"),1.5,true)
	if int(e.id)==sim.priority_id or p.distance_to(hover)<radius+13:
		var col: Color = cyan if int(e.id)==sim.priority_id else Color("a4b6c7")
		for j in range(4):
			var a: float = PI*.25+j*PI*.5
			draw_arc(p,radius+14,a,a+.45,8,col,2,true)
		if not boss and int(e.id)==sim.priority_id and not hover.distance_to(p)<radius+13:
			ink("HP %s   /   %.1fs" %[sim.Catalog.number(float(e.hp)+(int(e.members)-1)*float(e.unit_hp)),float(e.lifetime)-float(e.age)],p+Vector2(25,-radius-17),col,11)
	tint=Color.WHITE

func inspector() -> void:
	var selected: Dictionary={}
	var distance: float=INF
	for e in sim.enemies:
		if bool(e.dead):continue
		var d: float=hover.distance_to(e.pos)
		if d<distance and d<float(e.radius)+13:
			selected=e
			distance=d
	if selected.is_empty():return
	var p:=Vector2(-120 if hover.x>500 else 865,35)
	var col: Color=sim.stage_data().accent
	draw_rect(Rect2(p,Vector2(260,209)),Color(.025,.06,.095,.97))
	draw_rect(Rect2(p,Vector2(260,209)),Color(col,.45),false,1)
	var kind: String=selected.kind
	var boss: bool=selected.boss
	var title: String=sim.stage_data().boss_title.split(" · ")[0] if boss else "精英舰船" if kind=="elite_ship" else "外星舰群" if kind=="ship" else "精英天体" if selected.elite else "自然威胁群" if int(selected.members)>1 else "来袭天体"
	ink(title,p+Vector2(13,25),col,15)
	var texture: Texture2D=BossShip if kind=="mothership" else Fleet[sim.stage] if kind.contains("ship") else SunTexture if kind=="star" else PlanetTexture if kind=="planet" else Hazards[sim.stage]
	draw_texture_rect(texture,Rect2(p+Vector2(11,44),Vector2(88,88)),false)
	ink("成员 "+sim.Catalog.number(selected.members),p+Vector2(109,60),Color("c7d7e1"),12)
	ink("总生命",p+Vector2(109,82),muted,11)
	var hp: float=float(selected.hp)+(int(selected.members)-1)*float(selected.unit_hp)
	ink(sim.Catalog.number(hp),p+Vector2(109,104),Color("dce5e8"),14)
	var remaining: float=maxf(0,float(selected.lifetime)-float(selected.age))
	ink("撞击 %.1f 秒"%remaining,p+Vector2(13,155),Color("e5a485") if remaining<10 else Color("9eb9ca"),12)
	ink("在途伤害 "+sim.Catalog.number(selected.reserved),p+Vector2(13,176),Color("7a9fae"),11)
	ink("点击指定全体系优先目标" if sim.automation else "点击 / 按住目标发射",p+Vector2(13,195),col,11)

func _draw() -> void:
	var started: int=Time.get_ticks_usec()
	if sim == null or font == null:
		return
	draw_multimesh(star_mesh,StarTexture)
	var idx: int = sim.stage
	labels_left=6 if sim.enemies.size()>70 else 24
	if sim.mode == "transition":
		var t: float = smoothstep(0.0,1.0,sim.mode_time/sim.transition_length)
		var future_scale: float = lerpf(3.0,1.0,t)
		scene_transform = Transform2D(0,Vector2.ONE*future_scale,0,Vector2(500,325)*(1-future_scale))
		draw_set_transform_matrix(scene_transform)
		stage_scene(idx+1)
		# The previous defense remains anchored at the next scene's central object.
		var scale_value: float = pow(0.04,t)
		var previous_center: Vector2 = Vector2(500,570) if idx==0 else Vector2(500,325)
		var anchors: Array[Vector2]=[Vector2(547,356),Vector2(456,386),Vector2(660,341),Vector2(500,325),Vector2(500,325)]
		var anchor: Vector2=Vector2(500,325)+(anchors[idx]-Vector2(500,325))*future_scale
		scene_transform = Transform2D(0,Vector2.ONE*scale_value,0,anchor-previous_center*scale_value)
		draw_set_transform_matrix(scene_transform)
		stage_scene(idx)
		for i in range(6):
			if sim.owned[i]:
				weapon(i,sim.weapon_origin(i),idx>0 and i<idx)
		scene_transform = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO)
		ink("尺度跃迁  /  "+sim.catalog.stages[idx+1].title,Vector2(405,100),Color("d5e2ed"),22)
	else:
		stage_scene(idx)
		for i in range(6):
			if sim.owned[i]:
				weapon(i,sim.weapon_origin(i),idx>0 and i<idx)
		for e in sim.enemies:
			if not bool(e.dead):
				enemy(e)
		for p in sim.shots:
			var col: Color = sim.catalog.weapons[int(p.weapon)].color
			if bool(p.beam):
				draw_line(p.from,p.end,Color(col,.07),13+int(p.weapon)*2,true)
				draw_line(p.from,p.end,Color(col,.48),2.0+int(p.weapon)*.3,true)
				draw_line(p.from,p.end,Color("e3eff7"),.7,true)
			else:
				var pos: Vector2 = p.pos
				var dir: Vector2 = (Vector2(p.end)-Vector2(p.from)).normalized()
				var visible_rounds: int=mini(4,sim.launcher_count())
				for round_index in range(visible_rounds):
					var q: Vector2=pos+dir.orthogonal()*(round_index-(visible_rounds-1)*.5)*4
					draw_line(q-dir*22,q,Color(col,.22),3,true)
					draw_line(q-dir*8,q,col,2,true)
					draw_circle(q,2,Color("f1ebdd"))
		var rewards_left: int=16
		for fx in sim.effects:
			var t: float = float(fx.age)/float(fx.duration)
			var col: Color = sim.catalog.weapons[int(fx.weapon)].color
			col.a = 1-t
			if fx.kind == "reward":
				if rewards_left>0:
					ink("+$"+sim.Catalog.number(fx.amount),Vector2(fx.pos)+Vector2(8,-18-t*22),Color(cyan,1-t),11)
					rewards_left-=1
			else:
				var r: float = 4+float(fx.amount)*(t+.1)
				draw_arc(fx.pos,r,0,TAU,32,col,1.7,true)
				if fx.kind=="burst" and sim.effects.size()<60:
					for j in range(6):
						var v: Vector2 = Vector2(cos(j*TAU/6),sin(j*TAU/6))
						draw_line(Vector2(fx.pos)+v*r,Vector2(fx.pos)+v*(r+5),col,1,true)
		if sim.mode == "intermission":
			ink("拦截完成 · 下一波即将来袭",Vector2(395,190),Color("b9d4d7"),18)
	# Sparse range marks make the battlefield feel like a tactical instrument.
	draw_feedback()
	inspector()
	for corner in [Vector2(-140,0),Vector2(1140,0),Vector2(-140,620),Vector2(1140,620)]:
		var dir := Vector2(1 if corner.x<0 else -1,1 if corner.y<100 else -1)
		draw_line(corner,corner+Vector2(dir.x*18,0),Color("294258"),1)
		draw_line(corner,corner+Vector2(0,dir.y*18),Color("294258"),1)
	draw_ms=(Time.get_ticks_usec()-started)/1000.0
