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
