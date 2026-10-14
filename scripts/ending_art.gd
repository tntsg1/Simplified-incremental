extends RefCounted
# Deterministic, presentation-only timeline. No campaign RNG or simulation writes.
const LENGTH := 52.0
const WHITE := Color("ededed")
const AMBER := Color("ffc94d")
var canvas: Control
var font: Font
var clock := 0.0
var soft := false
var stars: MultiMesh
var galaxy: MultiMesh
var cloud_levels: Dictionary = {}
var nodes: Array[Vector2] = []
var branches: Array[PackedVector2Array] = []
var buildings: Array[Vector3] = []

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 731509
	stars = cloud(rng, false)
	galaxy = cloud(rng, true)
	for mesh in [stars, galaxy]:
		var levels: Array[MultiMesh] = []
		for level in range(17):
			var faded: MultiMesh = mesh.duplicate()
			for i in range(mesh.instance_count):
				var color: Color = mesh.get_instance_color(i)
				color.a *= float(level)/16.0
				faded.set_instance_color(i,color)
			levels.append(faded)
		cloud_levels[mesh.get_instance_id()] = levels
	for i in range(48):
		var a := float(i) * 2.399963
		nodes.append(Vector2.from_angle(a) * sqrt(float(i + 1) / 48.0) * 440.0)
	for i in range(nodes.size()):
		var closest := -1
		var distance := INF
		for j in range(i):
			var d := nodes[i].distance_squared_to(nodes[j])
			if d < distance:
				distance = d
				closest = j
		if closest >= 0:
			var path := PackedVector2Array()
			var a := nodes[i]
			var b := nodes[closest]
			for k in range(17):
				var u := float(k) / 16.0
				path.append(a.lerp(b, u) + (b-a).orthogonal().normalized() * sin(u*PI)*19.0)
			branches.append(path)
	for i in range(35):
		buildings.append(Vector3(-560.0 + i*33.0, rng.randf_range(26.0, 125.0), rng.randf_range(15.0, 28.0)))

func cloud(rng: RandomNumberGenerator, spiral: bool) -> MultiMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var result := MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_2D
	result.use_colors = true
	result.mesh = mesh
	result.instance_count = 1800
	for i in range(result.instance_count):
		var r := sqrt(rng.randf()) * 440.0
		var a := rng.randf()*TAU
		if spiral:
			a = float(i%4)*PI*.5 + r*.013 + rng.randfn(0.0, .12)
		var p := Vector2(cos(a)*r, sin(a)*r*(.62 if spiral else .8))
		var dot := rng.randf_range(.7, 1.7)
		result.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ONE*dot, 0.0, p))
		result.set_instance_color(i, Color(WHITE, rng.randf_range(.12, .72)))
	return result

static func smooth(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return u*u*(3.0-2.0*u)

func phase(start: float, end: float) -> float:
	return smooth((clock-start)/(end-start))

func line(a: Vector2, b: Vector2, alpha: float = .4, amber: bool = false, width: float = 1.0) -> void:
	canvas.draw_line(a, b, Color(AMBER if amber else WHITE, alpha), width, true)

func ring(p: Vector2, radius: float, alpha: float, amber: bool = false) -> void:
	if radius > .1:
		canvas.draw_arc(p, radius, 0, TAU, 96, Color(AMBER if amber else WHITE, alpha), 1.0, true)

func dots(mesh: MultiMesh, p: Vector2, scale: float, alpha: float, rotation: float = 0.0) -> void:
	canvas.draw_set_transform(p, rotation, Vector2.ONE*maxf(.00001,scale))
	canvas.draw_multimesh(cloud_levels[mesh.get_instance_id()][clampi(roundi(alpha*16.0),0,16)], null)
	canvas.draw_set_transform(Vector2.ZERO)

func text(value: String, p: Vector2, px: int, alpha: float = 1.0, amber: bool = false) -> void:
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	canvas.draw_string(font, p-Vector2(w*.5,0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(AMBER if amber else WHITE,alpha))

func web(p: Vector2, scale: float, alpha: float) -> void:
	canvas.draw_set_transform(p, 0.0, Vector2.ONE*scale)
	for path in branches:
		canvas.draw_polyline(path, Color(WHITE,alpha*.18), 1.0, true)
	for i in range(nodes.size()):
		var n := nodes[i]
		canvas.draw_circle(n, 1.5, Color(WHITE,alpha*.65))
		if i%3 == 0:
			canvas.draw_arc(n, 5.0+i%4, 0, TAU, 20, Color(WHITE,alpha*.14),1.0,true)
	canvas.draw_set_transform(Vector2.ZERO)

func earth(p: Vector2, radius: float, life: float, cities: float, alpha: float) -> void:
	canvas.draw_circle(p, radius, Color(.035,.04,.04,alpha))
	ring(p, radius, alpha*.8)
	ring(p, radius+5, alpha*.14, true)
	# Subpixel continent triangles are unstable in WebGL. Introduce geographic
	# detail only once this planet occupies enough pixels to resolve it.
	if radius < 8.0:
		return
	for k in [-.6, -.3, 0.0, .3, .6]:
		var path := PackedVector2Array()
		for j in range(49):
			var a := -PI*.5+float(j)/48.0*PI
			path.append(p+Vector2(sin(a)*radius*k,cos(a)*radius))
		canvas.draw_polyline(path,Color(WHITE,alpha*.12),1.0,true)
		var x := sqrt(1.0-k*k)*radius
		line(p+Vector2(-x,radius*k),p+Vector2(x,radius*k),alpha*.1)
	var continents := [PackedVector2Array([Vector2(-.65,-.42),Vector2(-.4,-.58),Vector2(-.12,-.37),Vector2(-.27,-.12),Vector2(-.14,.06),Vector2(-.3,.26),Vector2(-.39,.04),Vector2(-.57,-.02)]),PackedVector2Array([Vector2(.05,-.39),Vector2(.42,-.52),Vector2(.73,-.14),Vector2(.48,.02),Vector2(.3,-.1),Vector2(.14,.15),Vector2(.32,.38),Vector2(.12,.57),Vector2(-.04,.18),Vector2(-.08,-.09)]),PackedVector2Array([Vector2(.5,.4),Vector2(.72,.33),Vector2(.78,.51),Vector2(.58,.61)])]
	for shape in continents:
		var path := PackedVector2Array()
		for v in shape:
			path.append(p+v*radius)
		canvas.draw_colored_polygon(path, Color(WHITE,alpha*(.04+.12*life)))
		path.append(path[0])
		canvas.draw_polyline(path,Color(WHITE,alpha*.32),1.0,true)
	for i in range(20):
		var a := float(i)*2.399963
		var n := Vector2.from_angle(a)*sqrt(float(i+1)/24.0)*radius*.72
		var grow := smooth(cities*2.0-float(i)/20.0)
		if grow > 0.0:
			canvas.draw_circle(p+n,1.5+grow,Color(AMBER,alpha*grow*.85))
			if i%4==0:
				ring(p+n, 6.0+grow*8.0,alpha*grow*.16,true)
	# Branching growth precedes the illuminated city network.
	for i in range(9):
		var a := float(i)*2.399963
		var origin := p+Vector2.from_angle(a)*radius*.28
		var growth := smooth(life*1.8-float(i)/12.0)
		var tip := origin+Vector2.from_angle(a+.7)*radius*.17*growth
		line(origin,tip,alpha*growth*.38,true)
		for side in [-1.0,1.0]:
			line(origin.lerp(tip,.6),origin.lerp(tip,.6)+Vector2.from_angle(a+side*.8)*radius*.06*growth,alpha*growth*.25,true)

func city(p: Vector2, scale: float, alpha: float, build: float = 1.0) -> void:
	canvas.draw_set_transform(p,0.0,Vector2.ONE*scale)
	for i in range(buildings.size()):
		var b := buildings[i]
		var growth := smooth(build*2.0-float(i)/35.0)
		var height := b.y*growth
		canvas.draw_rect(Rect2(b.x,-height,b.z,height),Color(WHITE,alpha*.045))
		canvas.draw_rect(Rect2(b.x,-height,b.z,height),Color(WHITE,alpha*.35),false,1.0)
		for floor_index in range(int(height/12.0)):
			if (i+floor_index)%3 != 0:
				canvas.draw_rect(Rect2(b.x+5,-height+6+floor_index*12,2,2),Color(AMBER,alpha*.55))
	line(Vector2(-620,0),Vector2(620,0),alpha*.6)
	# Return to the same central launch position and geometric defense glyph.
	canvas.draw_rect(Rect2(-28,-18,56,18),Color(WHITE,alpha*.75),false,1.0)
	line(Vector2(0,-18),Vector2(0,-45),alpha*.9,true,2.0)
	ring(Vector2(0,-45),8.0,alpha*.9,true)
	canvas.draw_circle(Vector2(0,-45),2,Color(AMBER,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func bubble(center: Vector2, radius: float, time: float, mode: int, alpha: float, press: float, contact: Vector2) -> void:
	# A universe's membrane, ringing; where it presses the other one it flattens.
	var skin := PackedVector2Array()
	for i in range(129):
		var a := float(i)*TAU/128.0
		var dir := Vector2.from_angle(a)
		var r := radius*(1.0+.025*sin(float(mode)*a)*cos(time*1.4)+.012*sin(float(mode+3)*a+1.0)*cos(time*.8))
		var p := center+dir*r
		# Flatten toward the contact plane as the bubbles squeeze together.
		var along := (p-contact).dot((contact-center).normalized())
		if along > 0.0:
			p -= (contact-center).normalized()*along*press
		skin.append(p)
	canvas.draw_polyline(skin,Color(WHITE,alpha*.8),1.6,true)
	var inner := PackedVector2Array()
	for i in range(97):
		inner.append(skin[int(float(i)/96.0*128.0)].lerp(center,.035))
	canvas.draw_polyline(inner,Color(WHITE,alpha*.18),1.0,true)

func render(target: Control, time: float, reduced: bool) -> void:
	canvas = target
	font = target.font
	clock = time
	soft = reduced
	var size := canvas.size
	var unit := minf(size.x/1280.0,size.y/800.0)
	var c := size*Vector2(.5,.46)
	canvas.draw_rect(Rect2(Vector2.ZERO,size),Color("090a0b"))
	var caption := TranslationServer.translate("两个宇宙，仍在靠近。")
	var sub := "TWO UNIVERSES IN THE BULK"
	var start := 0.0
	if time < 11.0:
		# Prologue: our universe and the other bubble close the last gap and collide.
		var approach := phase(0.0,7.5)
		var shrink := phase(7.5,11.0)
		var r_ours := 190.0*unit*(1.0-shrink)
		var r_other := 225.0*unit*(1.0-shrink)
		var gap := lerpf(260.0,0.0,approach)*unit
		var ours_c := c-Vector2(r_ours+gap*.5,0)
		var other_c := c+Vector2(r_other+gap*.5,0)
		var press := smoothstep(.85,1.0,approach)*.6
		dots(stars,ours_c,unit*.4*(1.0-shrink),.55*(1.0-shrink),time*.01)
		web(ours_c,unit*.4*(1.0-shrink),.7*(1.0-shrink))
		dots(galaxy,other_c,unit*.45*(1.0-shrink),.3*(1.0-shrink),-time*.012)
		bubble(ours_c,r_ours,time,5,1.0-shrink*.5,press,c)
		bubble(other_c,r_other,time+2.0,4,.8-shrink*.4,press,c)
		if approach > .85:
			# The seam: a vertical line of light where the two skins touch.
			var seam := (smoothstep(.85,1.0,approach)*170.0*(1.0-shrink))*unit
			line(c-Vector2(0,seam),c+Vector2(0,seam),.9,true,1.0+3.0*(1.0-shrink))
			canvas.draw_circle(c,lerpf(5.0,1.6,shrink)*unit,Color(WHITE,.6+shrink*.4))
		if time >= 7.5:
			caption = TranslationServer.translate("膜，相撞。所有距离，归于一点。")
			sub = "BRANE COLLISION / SPACE FOLDS INWARD"
			start = 7.5
		if time >= 7.3 and time < 9.5:
			# Contact: a white-out and a flattened shock ring racing along the bulk.
			var hit := (time-7.3)/2.2
			if not soft:
				canvas.draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,pow(maxf(0.0,1.0-hit*3.0),2.0)*.75))
			canvas.draw_set_transform(c,0.0,Vector2(.22,1.0))
			for k in range(3):
				canvas.draw_arc(Vector2.ZERO,(40.0+hit*(900.0+k*260.0))*unit,0,TAU,128,Color(AMBER if k==0 else WHITE,(1.0-hit)*(.8-k*.2)),2.0,true)
			canvas.draw_set_transform(Vector2.ZERO)

	elif time < 14.0:
		caption = TranslationServer.translate("零。亦是无限。")
		sub = "SINGULARITY / A NEW BEGINNING"
		start = 11.0
		canvas.draw_circle(c,1.8*unit,WHITE)
		var breath := .5+.5*sin((time-11.0)*PI)
		ring(c,(12.0+breath*7.0)*unit,.16,true)
		line(c-Vector2(55,0)*unit,c-Vector2(22,0)*unit,.2)
		line(c+Vector2(22,0)*unit,c+Vector2(55,0)*unit,.2)
	elif time < 20.0:
		caption = TranslationServer.translate("光，再次诞生。")
		sub = "THE BIG BANG"
		start = 14.0
		var age := time-14.0
		var expansion := 1.0-exp(-age*1.1)
		dots(stars,c,unit*expansion*(1.0+age*.1),minf(1.0,age),age*.025)
		for i in range(5):
			var wave := maxf(0.0,age-float(i)*.18)
			ring(c,wave*220.0*unit,maxf(0.0,1.0-wave/4.0)*(.2 if soft else .48),i==0)
		if not soft:
			for i in range(64):
				var a := float(i)*TAU/64.0
				var depth := .6+float((i*37)%23)/23.0
				line(c+Vector2.from_angle(a)*age*90.0*unit*depth,c+Vector2.from_angle(a)*(age*240.0+20)*unit*depth,maxf(0.0,.8-age*.2))
			for i in range(12,0,-1):
				canvas.draw_circle(c,(4+float(i)*6)*unit*maxf(.05,1.0-age*.8),Color(WHITE,maxf(0.0,.05-age*.06)))
		canvas.draw_circle(c,maxf(1.0,18.0-age*22.0)*unit,Color(WHITE,maxf(0.0,1.0-age)))
	elif time < 25.0:
		caption = TranslationServer.translate("引力织成星海。")
		sub = "MATTER / STARS / GALAXIES"
		start = 20.0
		dots(stars,c,unit*1.4,.3,(time-20)*.005)
		web(c,unit*(.8+phase(20,25)*.15),phase(20,22))
		for i in range(8):
			var n := nodes[i*5]
			dots(galaxy,c+n*unit,unit*.06,phase(20+float(i)*.2,22+float(i)*.2)*.7,float(i))
	elif time < 30.0:
		caption = TranslationServer.translate("一颗星球，学会了生长。")
		sub = "WATER / LIFE / CIVILIZATION"
		start = 25.0
		var life := phase(25,28)
		dots(stars,c,unit*1.4,.16)
		earth(c,unit*(115+life*25),life,phase(27,30),1.0)
		city(c+Vector2(0,185)*unit,unit*.25,phase(28,30),phase(28,30))
	elif time < 34.0:
		caption = TranslationServer.translate("宇宙很大。我们仍在这里。")
		sub = "UNIVERSE → MILKY WAY"
		start = 30.0
		var zoom := phase(30,34)
		web(c,unit*(1+zoom*4),1.0-zoom)
		dots(galaxy,c,unit*lerpf(.09,1.15,zoom),.4+zoom*.6,-.25)
		ring(c,3.0*unit,.7,true)
	elif time < 38.0:
		caption = TranslationServer.translate("银河系。太阳系。")
		sub = "MILKY WAY → SOLAR SYSTEM"
		start = 34.0
		var zoom := phase(34,38)
		var anchor := Vector2(122,-66)*unit
		dots(galaxy,c-anchor*zoom*7.0,unit*(1.15+zoom*7.0),1.0-zoom,-.25)
		var solar_scale := unit*lerpf(.12,1.0,zoom)
		canvas.draw_circle(c,12*solar_scale,Color(WHITE,zoom))
		for i in range(5):
			var r := (55.0+i*36.0)*solar_scale
			ring(c,r,zoom*.3)
			var a := .5+float(i)*1.3+(time-34)*.035
			if i == 2:
				earth(c+Vector2.from_angle(a)*r,5.0*solar_scale,1.0,1.0,zoom)
			else:
				canvas.draw_circle(c+Vector2.from_angle(a)*r,3.0*solar_scale,Color(WHITE,zoom))
	elif time < 42.0:
		caption = TranslationServer.translate("地球。那座熟悉的城市。")
		sub = "SOLAR SYSTEM → EARTH"
		start = 38.0
		var zoom := phase(38,42)
		dots(stars,c,unit*1.5,.2*(1-zoom))
		var earth_origin := c+Vector2.from_angle(3.1+4.0*.035)*127.0*unit*(1.0-zoom)
		earth(earth_origin,unit*lerpf(5,255,zoom),1.0,1.0,1.0)
		var pin := earth_origin+Vector2(.3,-.1)*unit*lerpf(5,255,zoom)
		ring(pin,unit*(8+zoom*10),.7,true)
		canvas.draw_circle(pin,2*unit,AMBER)
	elif time < 50.0:
		caption = TranslationServer.translate("最后的光，留给文明。")
		sub = "EARTH → HOME"
		start = 42.0
		var zoom := phase(42,45)
		var horizon := c+Vector2(0,180)*unit
		earth(c+Vector2(0,zoom*500)*unit,unit*(255+zoom*500),1.0,1.0,1.0-zoom)
		dots(stars,c,unit*1.5,.25*zoom)
		city(horizon,unit*lerpf(.12,1.0,zoom),zoom)
		if time >= 46.0:
			caption = ""
			sub = "INCOMING"
			start = 46.0
			var u := pow(clampf((time-46.0)/4.0,0,1),1.6)
			var from := c+Vector2(490,-300)*unit
			var to := horizon-Vector2(0,90)*unit
			var p := from.lerp(to,u)
			var direction := (from-to).normalized()
			for i in range(4):
				line(p+direction*float(i)*16*unit,p+direction*(75+float(i)*25)*unit,.36/(i+1),false,unit)
			var meteor := PackedVector2Array()
			for i in range(7):
				meteor.append(p+Vector2.from_angle(float(i)*TAU/7.0+time*.5)*(7.0+u*9.0)*unit)
			canvas.draw_colored_polygon(meteor,WHITE)
			var aim := horizon-Vector2(0,45)*unit
			for i in range(4):
				var a := float(i)*PI*.5+time*.3
				canvas.draw_arc(aim,26*unit,a,a+.7,12,Color(AMBER,.6),1.0,true)
			canvas.draw_circle(aim,2.0*unit,AMBER)
	else:
		# Hard cut before impact: the opening threat returns, without resetting the save.
		canvas.draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		caption = ""
		sub = ""
	# Letterbox and restrained chapter typography hold the visual system together.
	var bar := 56.0*unit
	canvas.draw_rect(Rect2(0,0,size.x,bar),Color.BLACK)
	canvas.draw_rect(Rect2(0,size.y-bar,size.x,bar),Color.BLACK)
	if time < 50.0:
		var opacity := phase(start,start+.7)
		text(caption,Vector2(size.x*.5,size.y-bar-55*unit),int(24*unit),opacity)
		text(sub,Vector2(size.x*.5,size.y-bar-27*unit),int(11*unit),opacity*.6,true)
		line(Vector2(38,size.y-25),Vector2(size.x-38,size.y-25),.12)
		line(Vector2(38,size.y-25),Vector2(38+(size.x-76)*time/LENGTH,size.y-25),.6,true)
