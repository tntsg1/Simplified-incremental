extends RefCounted
# Hand-drawn HUD pieces that follow the battlefield's art: pointer-driven
# buttons, a segmented boss bar and the doomsday-weapon cinematic overlay.

const INK := Color("ededed")
const GREY := Color("b4b4b4")
const DIM := Color("6a6a6a")
const ACCENT := Color("ffc94d")
const BG := Color("141414")
const ButtonShader = preload("res://assets/button_fx.gdshader")


static func ease_out(t: float, power: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), power)


# Overlay added to a Button: tracks the pointer and drives the shader.
class FxLayer extends Control:
	var host: Button
	var mat: ShaderMaterial
	var radius: float = 0.0
	var center: Vector2 = Vector2.ZERO
	var spot_alpha: float = 0.0
	var hovered: bool = false
	var amber: bool = false

	func setup(button: Button) -> void:
		host = button
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mat = ShaderMaterial.new()
		mat.shader = ButtonShader
		material = mat
		visible = false
		host.mouse_entered.connect(func():
			hovered = true
			center = host.get_local_mouse_position())
		host.mouse_exited.connect(func():
			hovered = false
			center = host.get_local_mouse_position())

	func _process(delta: float) -> void:
		if host == null:
			return
		var live: bool = hovered and not host.disabled and host.is_visible_in_tree()
		var diag: float = host.size.length() + 8.0
		radius = lerpf(radius, diag if live else 0.0, 1.0 - exp(-delta * (11.0 if live else 14.0)))
		spot_alpha = lerpf(spot_alpha, 1.0 if hovered and host.is_visible_in_tree() else 0.0, 1.0 - exp(-delta * 10.0))
		var active: bool = radius > .5 or spot_alpha > .02
		visible = active
		if not active:
			return
		if not live and radius > .5:
			# Drain toward where the pointer left.
			center = center.lerp(host.get_local_mouse_position().clamp(Vector2.ZERO, host.size), 1.0 - exp(-delta * 6.0))
		size = host.size
		mat.set_shader_parameter("rect_size", host.size)
		mat.set_shader_parameter("fill_center", center)
		mat.set_shader_parameter("fill_radius", radius)
		mat.set_shader_parameter("spot", host.get_local_mouse_position())
		mat.set_shader_parameter("spot_alpha", spot_alpha)
		mat.set_shader_parameter("tint", Color(1, .86, .55) if amber else Color.WHITE)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


static func decorate(button: Button) -> FxLayer:
	# A back-buffer copy right before the layer, so each button inverts its own pixels.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	button.add_child(copy)
	var fx := FxLayer.new()
	fx.setup(button)
	button.add_child(fx)
	return fx


# Segmented boss health: lights up on arrival, trails damage, sheds chunks.
class BossBar extends Control:

	static func eo(t: float, power: float = 3.0) -> float:
		return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), power)
	const SEGMENTS: int = 48
	var shown: float = 1.0
	var target: float = 1.0
	var ghost: float = 1.0
	var hold: float = 0.0
	var shake: float = 0.0
	var intro: float = 0.0
	var clock: float = 0.0
	var chips: Array[Dictionary] = []
	var name_text: String = ""
	var timer_text: String = ""
	var font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = get_theme_font("font", "Label")

	func reset() -> void:
		shown = 1.0
		target = 1.0
		ghost = 1.0
		intro = 0.0
		chips.clear()

	func set_hp(value: float) -> void:
		value = clampf(value, 0.0, 1.0)
		if value < target - .001:
			var lost: float = target - value
			hold = .4
			shake = minf(1.0, shake + lost * 18.0 + .08)
			if lost > .03:
				# A big blow breaks whole segments off the bar.
				var w: float = size.x / SEGMENTS
				var from: int = int(floor(value * SEGMENTS))
				var to: int = int(ceil(target * SEGMENTS))
				for s in range(from, to):
					chips.append({"x": s * w, "vx": randf_range(-40, 90), "vy": randf_range(-160, -60), "age": 0.0, "spin": randf_range(-6, 6)})
		target = value

	func _process(delta: float) -> void:
		clock += delta
		intro = minf(1.0, intro + delta / .9)
		shown = lerpf(shown, target, 1.0 - exp(-delta * 16.0))
		hold = maxf(0.0, hold - delta)
		if hold <= 0.0:
			ghost = move_toward(ghost, shown, delta * .5)
		ghost = maxf(ghost, shown)
		shake = maxf(0.0, shake - delta * 4.0)
		for i in range(chips.size() - 1, -1, -1):
			var c: Dictionary = chips[i]
			c.age = float(c.age) + delta
			c.vy = float(c.vy) + 520.0 * delta
			if float(c.age) > .9:
				chips.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		var jitter := Vector2(sin(clock * 90.0), cos(clock * 77.0)) * shake * 3.0
		var bar_y: float = 34.0
		var h: float = 9.0
		var w: float = size.x / SEGMENTS
		var low: bool = target < .25
		var pulse: float = .5 + .5 * sin(clock * 9.0) if low else 0.0
		# Title and countdown.
		var reveal: float = eo(intro / .6)
		draw_string(font, Vector2(0, 18) + jitter * .3, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK, reveal))
		var tw: float = font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(size.x - tw, 18), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ACCENT, reveal))
		# Bracket frame draws in from the centre.
		var open: float = eo(intro / .5)
		var half: float = size.x * .5 * open
		var mid: float = size.x * .5
		for side in [-1.0, 1.0]:
			var x0: float = mid + side * half
			draw_line(Vector2(x0, bar_y - 5), Vector2(x0, bar_y + h + 5), Color(INK, .7 * open), 1.0)
			draw_line(Vector2(x0, bar_y - 5), Vector2(x0 - side * 8, bar_y - 5), Color(INK, .7 * open), 1.0)
			draw_line(Vector2(x0, bar_y + h + 5), Vector2(x0 - side * 8, bar_y + h + 5), Color(INK, .7 * open), 1.0)
		for s in range(SEGMENTS):
			var x: float = s * w
			var lit_at: float = float(s) / SEGMENTS
			var on: float = clampf((intro * 1.4 - lit_at) * 6.0, 0.0, 1.0)
			var rect := Rect2(Vector2(x + 1, bar_y) + jitter, Vector2(w - 2, h))
			var frac: float = (s + 1.0) / SEGMENTS
			if frac <= shown + .0001:
				var col: Color = INK.lerp(ACCENT, pulse * .7)
				draw_rect(rect, Color(col, on))
			elif frac <= ghost + .0001:
				draw_rect(rect, Color(ACCENT, .75 * on))
			else:
				draw_rect(rect, Color(1, 1, 1, .08 * on))
		# Quarter ticks.
		for q in [.25, .5, .75]:
			var x: float = size.x * q
			draw_line(Vector2(x, bar_y + h + 3), Vector2(x, bar_y + h + 8), Color(GREY, .6 * open), 1.0)
		# Head marker riding the edge of the remaining health.
		var head_x: float = size.x * shown
		draw_line(Vector2(head_x, bar_y - 7) + jitter, Vector2(head_x, bar_y + h + 7) + jitter, Color(1, 1, 1, .9 * open), 2.0)
		var pct: String = "%.1f%%" % (target * 100.0)
		draw_string(font, Vector2(clampf(head_x - 18, 0, size.x - 40), bar_y + h + 24), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GREY, open))
		for c in chips:
			var k: float = float(c.age) / .9
			var p := Vector2(float(c.x) + float(c.vx) * float(c.age), bar_y + float(c.vy) * float(c.age) * .5 + 260.0 * float(c.age) * float(c.age))
			draw_set_transform(p + Vector2(w * .5, h * .5), float(c.spin) * float(c.age), Vector2.ONE)
			draw_rect(Rect2(Vector2(-w * .5 + 1, -h * .5), Vector2(w - 2, h)), Color(ACCENT, 1.0 - k))
			draw_set_transform(Vector2.ZERO)


# Full-screen cinematic for a doomsday weapon: bars, vignette, title card.
class UltOverlay extends Control:

	static func eo(t: float, power: float = 3.0) -> float:
		return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), power)
	var t: float = -1.0
	var dur: float = 3.0
	var title: String = ""
	var subtitle: String = ""
	var font: Font
	var vignette: GradientTexture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		font = get_theme_font("font", "Label")
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, .78))
		g.set_offset(0, .45)
		vignette = GradientTexture2D.new()
		vignette.gradient = g
		vignette.fill = GradientTexture2D.FILL_RADIAL
		vignette.fill_from = Vector2(.5, .5)
		vignette.fill_to = Vector2(1.0, .5)
		vignette.width = 256
		vignette.height = 256

	func play(name: String, english: String, length: float) -> void:
		title = name
		subtitle = english
		dur = length
		t = 0.0

	func _process(delta: float) -> void:
		if t < 0.0:
			return
		t += delta
		if t > dur + .6:
			t = -1.0
		queue_redraw()

	func _draw() -> void:
		if t < 0.0:
			return
		var w: float = size.x
		var h: float = size.y
		var inn: float = eo(t / .45)
		var out: float = eo((t - dur) / .6) if t > dur else 0.0
		var k: float = inn * (1.0 - out)
		draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, k))
		# Letterbox bars slide in.
		var bar: float = 74.0 * k
		draw_rect(Rect2(0, 0, w, bar), Color(0, 0, 0, .96))
		draw_rect(Rect2(0, h - bar, w, bar), Color(0, 0, 0, .96))
		draw_line(Vector2(0, bar), Vector2(w, bar), Color(1, 1, 1, .25 * k), 1.0)
		draw_line(Vector2(0, h - bar), Vector2(w, h - bar), Color(1, 1, 1, .25 * k), 1.0)
		# Title card: glyphs rise one by one, then the whole card lifts away.
		var card_in: float = clampf(t / 1.1, 0.0, 1.0)
		var card_out: float = eo((t - 1.6) / .7)
		if card_out >= 1.0:
			return
		var cy: float = h * .3 - card_out * 40.0
		var size_px: int = 64
		var spacing: float = 26.0
		var glyphs: PackedStringArray = []
		for i in range(title.length()):
			glyphs.append(title.substr(i, 1))
		var widths: Array[float] = []
		var total: float = 0.0
		for g in glyphs:
			var gw: float = font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			widths.append(gw)
			total += gw + spacing
		total -= spacing
		var x: float = w * .5 - total * .5
		for i in range(glyphs.size()):
			var local: float = clampf((t - .12 - i * .07) / .5, 0.0, 1.0)
			var e: float = eo(local, 4.0)
			var a: float = e * (1.0 - card_out)
			var lift: float = (1.0 - e) * 26.0
			draw_string_outline(font, Vector2(x, cy + lift), glyphs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, Color(0, 0, 0, .6 * a))
			draw_string(font, Vector2(x, cy + lift), glyphs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 1, 1, a))
			x += widths[i] + spacing
		# A hairline draws out from the centre under the title.
		var line: float = eo((t - .25) / .7) * (1.0 - card_out)
		draw_line(Vector2(w * .5 - 260 * line, cy + 26), Vector2(w * .5 + 260 * line, cy + 26), Color(1, 1, 1, .55 * line), 1.0)
		var sub_a: float = clampf((t - .5) / .5, 0.0, 1.0) * (1.0 - card_out)
		var spaced: String = ""
		for i in range(subtitle.length()):
			spaced += subtitle.substr(i, 1) + (" " if i < subtitle.length() - 1 else "")
		var sw: float = font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(w * .5 - sw * .5, cy + 52), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ACCENT, sub_a))


# Click feedback: a white flash through the button, corner brackets bursting
# outward, and sparks fired from the exact click point.
class ClickBurst extends Control:
	var t: float = 0.0
	var box: Rect2
	var hit: Vector2
	var col: Color = Color.WHITE
	var big: bool = false
	var sparks: Array[Vector2] = []

	static func eo(x: float, power: float = 3.0) -> float:
		return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), power)

	func setup(rect: Rect2, at: Vector2, amber: bool, large: bool) -> void:
		box = rect
		hit = at
		big = large
		col = Color("ffc94d") if amber else Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 50
		var n: int = 16 if large else 10
		for i in range(n):
			var a: float = TAU * i / n + randf_range(-.2, .2)
			sparks.append(Vector2.from_angle(a) * randf_range(60.0, 150.0) * (1.6 if large else 1.0))

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > .6:
			queue_free()

	func _draw() -> void:
		var k: float = t / .6
		# Flash through the button body.
		var flash: float = pow(maxf(0.0, 1.0 - t / .2), 2.0)
		if flash > 0.0:
			draw_rect(box, Color(col, .55 * flash))
		# Corner brackets fly outward and fade.
		var push: float = eo(t / .45) * (22.0 if big else 14.0)
		var arm: float = 12.0
		var a: float = clampf(1.0 - t / .45, 0.0, 1.0)
		var r: Rect2 = box.grow(push + 2.0)
		var corners: Array = [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]
		for c in corners:
			var p: Vector2 = c[0]
			var d: Vector2 = c[1]
			draw_line(p, p + Vector2(d.x * arm, 0), Color(col, a), 1.6)
			draw_line(p, p + Vector2(0, d.y * arm), Color(col, a), 1.6)
		# Thin outline that races outward.
		draw_rect(box.grow(eo(t / .5) * (34.0 if big else 20.0)), Color(col, (1.0 - k) * .35), false, 1.0)
		# Sparks from the click point.
		for s in sparks:
			var travel: float = eo(t / .5, 2.5)
			var p: Vector2 = hit + s * travel
			var tail: Vector2 = hit + s * maxf(0.0, travel - .12)
			draw_line(tail, p, Color(col, (1.0 - k) * .9), 1.4)


# Screen-space cinematics for the big beats: boss entrance, boss destroyed and
# the scale jump (destroyed stamp, then hyperspace and the new chapter card).
class Cinema extends Control:
	var kind: String = ""
	var t: float = -1.0
	var dur: float = 2.5
	var title: String = ""
	var sub: String = ""
	var extra: String = ""
	var number: String = ""
	var from_text: String = ""
	var to_text: String = ""
	var font: Font
	var vignette: GradientTexture2D
	var streaks: Array[Vector3] = []

	static func eo(x: float, power: float = 3.0) -> float:
		return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), power)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		font = get_theme_font("font", "Label")
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, .82))
		g.set_offset(0, .4)
		vignette = GradientTexture2D.new()
		vignette.gradient = g
		vignette.fill = GradientTexture2D.FILL_RADIAL
		vignette.fill_from = Vector2(.5, .5)
		vignette.fill_to = Vector2(1.0, .5)
		for i in range(160):
			streaks.append(Vector3(randf() * TAU, randf(), randf_range(.4, 1.0)))

	func play(what: String, length: float, a: String, b: String, c: String = "", n: String = "", from: String = "", to: String = "") -> void:
		kind = what
		dur = length
		title = a
		sub = b
		extra = c
		number = n
		from_text = from
		to_text = to
		t = 0.0

	func _process(delta: float) -> void:
		if t < 0.0:
			return
		t += delta
		if t > dur + .2:
			t = -1.0
		queue_redraw()

	func glyphs(text: String, center: Vector2, px: int, spacing: float, start: float, step: float, col: Color, fade: float, rise_px: float = 28.0) -> void:
		var widths: Array[float] = []
		var total: float = 0.0
		for i in range(text.length()):
			var gw: float = font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			widths.append(gw)
			total += gw + spacing
		total -= spacing
		var x: float = center.x - total * .5
		for i in range(text.length()):
			var e: float = eo((t - start - i * step) / .55, 4.0)
			var a: float = e * fade
			if a > .003:
				var p := Vector2(x, center.y + (1.0 - e) * rise_px)
				draw_string_outline(font, p, text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px, 8, Color(0, 0, 0, .55 * a))
				draw_string(font, p, text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, a))
			x += widths[i] + spacing

	func spaced(text: String) -> String:
		var out: String = ""
		for i in range(text.length()):
			out += text.substr(i, 1) + (" " if i < text.length() - 1 else "")
		return out

	func centered(text: String, pos: Vector2, px: int, col: Color) -> void:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, Vector2(pos.x - w * .5, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

	func bars(k: float, height: float = 70.0) -> void:
		var h: float = height * k
		draw_rect(Rect2(0, 0, size.x, h), Color(0, 0, 0, .96))
		draw_rect(Rect2(0, size.y - h, size.x, h), Color(0, 0, 0, .96))
		draw_line(Vector2(0, h), Vector2(size.x, h), Color(1, 1, 1, .22 * k), 1.0)
		draw_line(Vector2(0, size.y - h), Vector2(size.x, size.y - h), Color(1, 1, 1, .22 * k), 1.0)

	func stamp(at: float, length: float, big: String, small: String, reward: String) -> void:
		# Slams in oversized, settles, then fades away.
		var k: float = clampf((t - at) / .32, 0.0, 1.0)
		if k <= 0.0:
			return
		var out: float = eo((t - at - length + .45) / .45)
		var fade: float = 1.0 - out
		if fade <= 0.0:
			return
		var scale: float = lerpf(1.9, 1.0, eo(k, 4.0))
		var c := Vector2(size.x * .5, size.y * .42)
		for i in range(28):
			var a: float = i * TAU / 28 + .1
			var r0: float = 120.0 + eo(k) * 60.0
			var r1: float = r0 + 40.0 + eo((t - at) / .7) * 420.0
			draw_line(c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a) * r1, Color(1, 1, 1, .22 * fade * (1.0 - eo((t - at) / 1.2))), 1.0)
		draw_set_transform(c, 0, Vector2.ONE * scale)
		var w: float = font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		draw_string_outline(font, Vector2(-w * .5, 18), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 10, Color(0, 0, 0, .7 * fade * k))
		draw_string(font, Vector2(-w * .5, 18), big, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(1, 1, 1, fade * k))
		draw_set_transform(Vector2.ZERO)
		var rule: float = eo((t - at - .2) / .5) * fade
		draw_line(c + Vector2(-300 * rule, 46), c + Vector2(300 * rule, 46), Color(ACCENT, .8 * rule), 1.5)
		centered(spaced(small), c + Vector2(0, 76), 14, Color(ACCENT, rule))
		if reward != "":
			centered(reward, c + Vector2(0, 112), 22, Color(1, 1, 1, eo((t - at - .45) / .4) * fade))

	func _draw() -> void:
		if t < 0.0:
			return
		var w: float = size.x
		var h: float = size.y
		var c := Vector2(w * .5, h * .5)
		var k: float = eo(t / .4) * (1.0 - eo((t - dur + .5) / .5))
		match kind:
			"boss":
				draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, k))
				bars(k, 64.0)
				# Hazard bands with a scrolling ticker.
				for band_y in [64.0 * k - 18.0, h - 64.0 * k]:
					draw_rect(Rect2(0, band_y, w, 18), Color(0, 0, 0, .9 * k))
					var off: float = fmod(t * 120.0, 36.0)
					var x: float = -36.0 + off
					while x < w + 36.0:
						draw_colored_polygon(PackedVector2Array([Vector2(x, band_y + 18), Vector2(x + 12, band_y + 18), Vector2(x + 24, band_y), Vector2(x + 12, band_y)]), Color(ACCENT, .85 * k))
						x += 36.0
				var ticker: String = "WARNING   ·   巨型威胁接近   ·   "
				var tw: float = font.get_string_size(ticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				var tx: float = -fmod(t * 160.0, tw)
				while tx < w:
					draw_string(font, Vector2(tx, 64.0 * k + 18), ticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ACCENT, .9 * k))
					tx += tw
				# The edge frame pulses three times.
				var pulse: float = maxf(0.0, sin(t * 7.5)) * (1.0 - clampf(t / 1.6, 0.0, 1.0))
				draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(ACCENT, .6 * pulse), false, 3.0)
				var fade: float = 1.0 - eo((t - dur + .7) / .6)
				glyphs(title, Vector2(w * .5, h * .34), 66, 22.0, .25, .07, Color.WHITE, fade)
				var line: float = eo((t - .5) / .6) * fade
				draw_line(Vector2(w * .5 - 280 * line, h * .34 + 26), Vector2(w * .5 + 280 * line, h * .34 + 26), Color(ACCENT, .7 * line), 1.5)
				centered(spaced(sub), Vector2(w * .5, h * .34 + 54), 14, Color(ACCENT, line))
			"clear":
				draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, k * .8))
				bars(k, 56.0)
				stamp(.05, dur, title, sub, extra)
			"jump":
				# Phase one: the destroyed stamp. Phase two: hyperspace and the chapter card.
				draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, k))
				bars(k, 70.0)
				stamp(.05, 2.3, "巨型威胁已摧毁", "THREAT ELIMINATED", extra)
				var warp: float = clampf((t - 1.6) / 1.4, 0.0, 1.0) * (1.0 - clampf((t - dur + 1.2) / 1.2, 0.0, 1.0))
				var speed: float = sin(warp * PI * .5)
				if warp > 0.0:
					for s in streaks:
						var depth: float = fmod(s.y + t * (.25 + speed * 1.6) * s.z, 1.0)
						var r: float = pow(depth, 2.2) * w * .75
						var reach: float = (14.0 + 220.0 * speed) * depth
						var p0: Vector2 = c + Vector2.from_angle(s.x) * r
						var p1: Vector2 = c + Vector2.from_angle(s.x) * (r + reach)
						draw_line(p0, p1, Color(1, 1, 1, warp * depth * .8), 1.0 + depth)
				var card: float = clampf((t - 2.6) / .5, 0.0, 1.0)
				if card > 0.0:
					var fade: float = 1.0 - eo((t - dur + .7) / .6)
					# A giant chapter number drifts behind the card.
					var drift: float = (t - 2.6) * 22.0
					var nw: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 260).x
					draw_string(font, Vector2(w * .5 - nw * .5 + 80 - drift, h * .5 + 80), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 260, Color(1, 1, 1, .07 * eo(card) * fade))
					centered(spaced("SCALE  " + number), Vector2(w * .5, h * .3), 13, Color(GREY, eo(card) * fade))
					glyphs(title, Vector2(w * .5, h * .44), 84, 30.0, 2.75, .09, Color.WHITE, fade, 36.0)
					var line: float = eo((t - 3.1) / .7) * fade
					draw_line(Vector2(w * .5 - 320 * line, h * .44 + 30), Vector2(w * .5 + 320 * line, h * .44 + 30), Color(1, 1, 1, .5 * line), 1.0)
					centered(spaced(sub), Vector2(w * .5, h * .44 + 60), 14, Color(ACCENT, line))
					# The scale readout flips from the old scale to the new one.
					var flip: float = clampf((t - 3.6) / .5, 0.0, 1.0)
					var readout: String = from_text if flip < .5 else to_text
					var squash: float = absf(cos(flip * PI))
					draw_set_transform(Vector2(w * .5, h * .44 + 108), 0, Vector2(1.0, maxf(.05, squash)))
					var rw: float = font.get_string_size(readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
					draw_string(font, Vector2(-rw * .5, 9), readout, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, line))
					draw_set_transform(Vector2.ZERO)
