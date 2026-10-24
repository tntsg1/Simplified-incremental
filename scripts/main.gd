extends Control

# Expanding outline that leaves a button when it is clicked.
class Ripple extends Control:
	var t: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= .38:
			queue_free()
	func _draw() -> void:
		var k: float = t / .38
		var grow: float = 2.0 + (1.0 - pow(1.0 - k, 3.0)) * 16.0
		draw_rect(Rect2(-Vector2.ONE * grow, size + Vector2.ONE * grow * 2.0), Color(1, 1, 1, (1.0 - k) * .55), false, 1.5)

const Combat = preload("res://scripts/combat.gd")
const Battlefield = preload("res://scripts/battlefield.gd")
const UiFx = preload("res://scripts/ui_fx.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Catalog = preload("res://scripts/catalog.gd")
const AudioDirector=preload("res://scripts/audio_director.gd")
var audio: Node
var steam_features: Node
var camera_comfort: bool=false
var reduced_effects: bool=false
var ui_motion: bool=true
var language: String = "zh"
# Interface languages: Chinese is the source text, every other language has locales/<code>.json.
const LANGUAGES: Array[String] = ["zh", "en", "ja", "ko", "zh_TW", "fr", "de", "es", "pt_BR", "ru", "ar"]
const LANGUAGE_NAMES: Dictionary = {"zh": "简体中文", "en": "English", "ja": "日本語", "ko": "한국어", "zh_TW": "繁體中文", "fr": "Français", "de": "Deutsch", "es": "Español", "pt_BR": "Português", "ru": "Русский", "ar": "العربية"}
# Windows system faces that draw each script natively; the shared Chinese face stays as fallback.
const LANGUAGE_FONTS: Dictionary = {"ja": ["Yu Gothic UI", "Meiryo UI"], "ko": ["Malgun Gothic"], "zh_TW": ["Microsoft JhengHei UI", "Microsoft JhengHei"], "ar": ["Segoe UI", "Tahoma"]}
var preferences_path := "user://skyguard_preferences.cfg"
var title_screen: Control
var language_button: Button
var pointer_frame: UiFx.PointerFrame
var field_origin:=Vector2.ZERO
var field_zoom: float=1.0
var sim = Combat.new()
var store = SaveStore.new()
var field: Node2D
var font: Font
var ui: Control
var shade: ColorRect
var modal: PanelContainer
var stage_label: Label
var money_label: Label
# Live firepower readout under the money: damage and kills per game second.
var rate_label: Label
var rate_timer: float=0
var rate_damage: float=0
var rate_kills: float=0
var last_damage_total: float=0
var last_kills: int=0
var last_rate_time: float=0
var wave_label: Label
var health_label: Label
var hint: Label
var scale_label: Label
var city_tactics: PanelContainer
var boss_box: Control
var boss_title: Label
var boss_timer: Label
var boss_bar: ProgressBar
# Smoothed HUD values: bars glide, the boss bar keeps a lagging "damage ghost",
# lost defense shakes the health readout, a new wave number pops.
var boss_ghost: ProgressBar
var boss_shown: float = 100
var ghost_shown: float = 100
var ghost_hold: float = 0
var boss_fx: UiFx.BossBar
var ult_overlay: UiFx.UltOverlay
var cam_zoom: float = 1.0
var cam_target: float = 1.0
var cam_focus: Vector2 = Vector2(500,325)
var hitstop: float = 0.0
var boss_was_visible: bool = false
var cinema: UiFx.Cinema
var ending_skip: Button
var cine_mode: String = ""
var cam_hold: float = 0.0
var shatter: ColorRect
var resume_fx: UiFx.Resume
var lens: ColorRect
var mandel: ColorRect
var shatter_seeds: PackedVector2Array = PackedVector2Array()
var wave_shown: float = 0
var health_seen: float = 100
var health_shake: float = 0
var wave_seen: String = ""
var wave_bar: ProgressBar
var toast: Label
var toast_time: float = 0
var accumulator: float = 0
const SIM_STEP: float = 1.0 / 60.0
const MAX_SIM_STEPS: int = 16
const SIM_BUDGET_USEC: int = 8000
var sim_steps_this_frame: int = 0
var save_timer: float = 0
var ui_timer: float = 0
var purchase_count: int = 1
var menu: String = ""
var cards: Array[Dictionary] = []
var auto_button: Button
var hud_auto_button: Button
var ult_button: Button
var ult_fill: ColorRect
var ult_ready_seen: bool = false
# Fast-forward: the fixed 60 Hz sim simply takes more steps per frame, so a run
# plays out identically at any speed; field animation scales with it.
const SPEEDS: Array[int]=[1,2,4,8]
const RELEASE_SPEEDS: Array[int]=[1,2]
var game_speed: int=1
var speed_button: Button
# Developer mode (` key): test shortcuts and extra fast-forward steps.
var dev_mode: bool=false
# Celestial conversion card: opens beside a clicked body, battle keeps running.
var body_card: PanelContainer
var body_card_slot: int=-1
var body_card_stage: int=-1
var body_card_readonly: bool=false
var body_card_details: Label
var body_card_button: Button
var body_card_price: Label
# Boss kills play in slow motion for a moment (real seconds left).
var slowmo: float=0
var dev_god: bool=false
var dev_bar: HBoxContainer
var dev_god_button: Button
var dev_ult_button: Button
var dev_ult_kind_button: Button
var weapon_button: Button
var saved: Dictionary = {}
var proof: bool = false
var proof_frame: int = 0
var capture_at: int = 120
var capture_path: String = ""
var benchmark: bool = false
var performance_frames: Array[float] = []
var sound_on: bool = true
var old_kills: int = 0
var old_shots: int = 0
var display_mode: String=""
var display_stage: int=-1
# Money rolls toward the real value and pops on income.
var shown_money: float=0
var money_pulse: float=0
# Ultimate loot counter under the wallet: rolls up with the coin stream, lands on the real total.
var loot_label: Label
var loot_peak: float=0
var loot_shown: float=0
var loot_hold: float=0
var loot_pop: float=0

func panel_style(color: Color, edge: Color = Color("373737"), radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

func label(text: String, size: int = 18, color: Color = Color("eeeeee")) -> Label:
	var l := Label.new()
	l.text = TranslationServer.translate(text)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = TranslationServer.translate(text)
	b.custom_minimum_size = Vector2(0,46)
	b.add_theme_stylebox_override("normal",panel_style(Color("1f1f1f") if primary else Color("181818"),Color("8a8a8a") if primary else Color("3a3a3a"),2))
	b.add_theme_stylebox_override("hover",panel_style(Color("1f1f1f") if primary else Color("181818"),Color("ededed"),2))
	b.add_theme_stylebox_override("pressed",panel_style(Color("1f1f1f"),Color("ffffff"),2))
	b.add_theme_stylebox_override("disabled",panel_style(Color("151515"),Color("2a2a2a"),2))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ededed")
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focus)
	b.add_theme_color_override("font_color",Color("efefef"))
	b.add_theme_color_override("font_disabled_color",Color("6c6c6c"))
	b.pressed.connect(callback)
	juice(b)
	b.set_meta("fx",UiFx.decorate(b, func(): return ui_motion))
	return b

# Click feedback; the shared FxLayer owns continuous hover/press motion.
func juice(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * .5)
	b.button_up.connect(func():
		if ui_motion and b.is_hovered() and not b.disabled:
			burst(b, false, false))

func burst(anchor: Control, amber: bool, large: bool) -> void:
	if not is_instance_valid(anchor):
		return
	var fx := UiFx.ClickBurst.new()
	var rect: Rect2 = anchor.get_global_rect()
	var mouse: Vector2 = get_global_mouse_position()
	fx.setup(rect, mouse if rect.has_point(mouse) else rect.get_center(), amber, large)
	add_child(fx)

func spring(node: Control, target: float, duration: float) -> void:
	if not is_instance_valid(node):
		return
	var previous = node.get_meta("spring_tween") if node.has_meta("spring_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.set_meta("spring_tween", tween)

# A purchase lights its card and floats "+N" off the button.
func celebrate(anchor: Control, text: String) -> void:
	if not is_instance_valid(anchor):
		return
	var card: Control = anchor.get_parent().get_parent() if anchor.get_parent() and anchor.get_parent().get_parent() is Control else anchor
	burst(anchor, true, true)
	card.modulate = Color(1.9, 1.9, 1.9)
	card.create_tween().tween_property(card, "modulate", Color.WHITE, .35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tag := label(text, 26, Color("ffc94d"))
	tag.position = anchor.global_position + Vector2(anchor.size.x * .5 - 16, -6)
	tag.z_index = 60
	add_child(tag)
	tag.pivot_offset = Vector2(16, 14)
	tag.scale = Vector2.ONE * .4
	var rise := tag.create_tween().set_parallel(true)
	rise.tween_property(tag, "scale", Vector2.ONE, .32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(tag, "position:y", tag.position.y - 54, .75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(tag, "modulate:a", 0.0, .45).set_delay(.35)
	rise.chain().tween_callback(tag.queue_free)

# Children fade and rise in one after another instead of popping together.
func stagger(container: Node, gap: float = .035) -> void:
	var i: int = 0
	for child in container.get_children():
		if child is Control:
			var item: Control = child
			item.modulate.a = 0.0
			var tween := item.create_tween()
			tween.tween_interval(i * gap)
			tween.tween_property(item, "modulate:a", 1.0, .22)
			i += 1

func _ready() -> void:
	var preferences := ConfigFile.new()
	if not OS.has_feature("web") and preferences.load(preferences_path) == OK:
		language = str(preferences.get_value("ui", "language", language_code(OS.get_locale())))
	elif not OS.has_feature("web"):
		language = language_code(OS.get_locale())
	apply_language(language, false)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	# The startup language picks the primary face; the fallbacks draw every other script, so a
	# language switch never edits a live font (doing that blanked already-shaped title text).
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(LANGUAGE_FONTS.get(language, []) + ["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	var fallbacks: Array[Font] = []
	for code in LANGUAGE_FONTS:
		var face := SystemFont.new()
		face.font_names = PackedStringArray(LANGUAGE_FONTS[code])
		fallbacks.append(face)
	system_font.fallbacks = fallbacks
	font = load("res://assets/fonts/SkyguardSC.ttf") if OS.has_feature("web") else system_font
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 16
	theme = skin
	var bg := ColorRect.new()
	bg.color = Color("141414")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	field = Battlefield.new()
	field.sim = sim
	add_child(field)
	# Rewritten pi: the rendered battlefield shatters (shader over a fresh frame copy).
	var shatter_copy := BackBufferCopy.new()
	shatter_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(shatter_copy)
	shatter = ColorRect.new()
	shatter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shatter_mat := ShaderMaterial.new()
	shatter_mat.shader = preload("res://assets/shatter.gdshader")
	shatter.material = shatter_mat
	shatter.visible = false
	add_child(shatter)
	# Photoid: a gravitational lens follows the particle in.
	lens = ColorRect.new()
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = preload("res://assets/lens.gdshader")
	lens.material = lens_mat
	lens.visible = false
	add_child(lens)
	# Mandelbrot: the real set blooms over the battlefield (no screen copy needed).
	mandel = ColorRect.new()
	mandel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mandel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mandel_mat := ShaderMaterial.new()
	mandel_mat.shader = preload("res://assets/mandelbrot.gdshader")
	mandel.material = mandel_mat
	mandel.visible = false
	add_child(mandel)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	build_hud()
	shade = ColorRect.new()
	shade.color = Color(0.03,0.03,0.03,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.hide()
	sim.notice.connect(show_notice)
	sim.checkpoint.connect(func(): store.save_game_async(sim,settings_payload()))
	sim.stage_entered.connect(func(): show_notice(sim.stage_data().briefing))
	audio=AudioDirector.new()
	add_child(audio)
	audio.set_enabled(false)
	sim.fired.connect(audio.fire)
	sim.turret_fired.connect(audio.turret)
	sim.arch_introduced.connect(on_arch_introduced)
	sim.shield_broken.connect(audio.shield_broken)
	sim.enemy_split.connect(audio.enemy_split)
	sim.minion_launched.connect(audio.minion_launched)
	sim.ultimate_fired.connect(audio.ultimate)
	sim.ultimate_impact.connect(audio.ultimate_impact)
	sim.droplet_arrive.connect(audio.droplet_arrive)
	sim.droplet_shatter.connect(audio.droplet_shatter)
	sim.flattened.connect(audio.flattened)
	sim.fourier_hit.connect(audio.fourier_hit)
	sim.prime_strike.connect(audio.prime_strike)
	sim.boss_skill.connect(audio.boss_skill)
	sim.boss_launched.connect(audio.boss_launched)
	sim.shot_deflected.connect(audio.deflected)
	sim.body_strike.connect(audio.body_strike)
	sim.shell_burst.connect(audio.shell_burst)
	sim.hit.connect(audio.impact)
	sim.destroyed.connect(audio.destruction)
	sim.fired.connect(field.on_fire)
	sim.hit.connect(field.on_hit)
	sim.destroyed.connect(field.on_destroyed)
	sim.members_removed.connect(field.on_members_removed)
	sim.pierced.connect(field.on_pierced)
	sim.turret_fired.connect(field.on_turret_fired)
	sim.body_fired.connect(field.on_body_fired)
	sim.shell_burst.connect(field.on_shell_burst)
	sim.body_strike.connect(field.on_body_strike)
	sim.ultimate_fired.connect(field.on_ultimate_fired)
	sim.ultimate_impact.connect(field.on_ultimate_impact)
	sim.prime_strike.connect(field.on_prime_strike)
	sim.flattened.connect(field.on_flattened)
	sim.droplet_pass.connect(field.on_droplet_pass)
	sim.droplet_shatter.connect(field.on_droplet_shatter)
	sim.fourier_tour.connect(field.on_fourier_tour)
	sim.fourier_hit.connect(field.on_fourier_hit)
	sim.string_snap.connect(field.on_string_snap)
	sim.weapon_strike.connect(field.on_weapon_strike)
	sim.shot_deflected.connect(field.on_shot_deflected)
	sim.droplet_pass.connect(func(_pts): hitstop = maxf(hitstop, .05))
	sim.droplet_arrive.connect(field.on_droplet_arrive)
	sim.droplet_arrive.connect(func(_p): hitstop = maxf(hitstop, .18))
	sim.fourier_hit.connect(func(_p,_i,_n): hitstop = maxf(hitstop,.012))
	sim.boss_launched.connect(field.on_boss_launched)
	sim.boss_skill.connect(field.on_boss_skill)
	sim.ultimate_loot.connect(field.on_ultimate_loot)
	sim.ultimate_fired.connect(on_ult_fired)
	sim.ultimate_impact.connect(on_ult_impact)
	sim.prime_strike.connect(func(_p,_pts): hitstop = maxf(hitstop,.035))
	sim.body_converted.connect(field.on_body_converted)
	sim.retargeted.connect(field.on_retargeted)
	sim.focused.connect(field.on_focused)
	resized.connect(layout)
	parse_proof()
	steam_features = preload("res://scripts/steam_features.gd").new()
	add_child(steam_features)
	steam_features.setup(self)
	audio.set_enabled(sound_on and (not proof or "--listen" in OS.get_cmdline_user_args()))
	if not proof:
		saved = store.read_game()
		if not OS.has_feature("web") and not preferences.has_section_key("ui", "language"):
			apply_language(str(saved.get("settings", {}).get("language", language)), false)
		sound_on = bool(saved.get("settings",{}).get("sound",true))
		camera_comfort=bool(saved.get("settings",{}).get("camera_comfort",false))
		reduced_effects=bool(saved.get("settings",{}).get("reduced_effects",false))
		ui_motion=bool(saved.get("settings",{}).get("ui_motion",true))
		audio.music_level=clampf(float(saved.get("settings",{}).get("music_level",.55)),0,1)
		audio.effects_level=clampf(float(saved.get("settings",{}).get("effects_level",.65)),0,1)
		game_speed=int(saved.get("settings",{}).get("game_speed",1))
		if game_speed not in allowed_speeds():
			game_speed=1
		if not OS.has_feature("web") and preferences.has_section("ui"):
			sound_on = bool(preferences.get_value("ui","sound",sound_on))
			camera_comfort = bool(preferences.get_value("ui","camera_comfort",camera_comfort))
			reduced_effects = bool(preferences.get_value("ui","reduced_effects",reduced_effects))
			ui_motion = bool(preferences.get_value("ui","ui_motion",ui_motion))
			audio.music_level = clampf(float(preferences.get_value("ui","music_level",audio.music_level)),0,1)
			audio.effects_level = clampf(float(preferences.get_value("ui","effects_level",audio.effects_level)),0,1)
		refresh_speed_button()
		audio.set_enabled(sound_on)
		show_title()
	if DisplayServer.get_name()=="headless":audio.set_enabled(false)
	if "--silent-output" in OS.get_cmdline_user_args():AudioServer.set_bus_volume_db(0,-80)
	layout()
	update_hud()
	pointer_frame = UiFx.PointerFrame.new()
	pointer_frame.motion_enabled = func(): return ui_motion
	pointer_frame.target_rect = cursor_target_rect
	pointer_frame.over_button = func(): return cursor_button() != null
	pointer_frame.normal_style = func():
		var lock: float = smoothstep(0.0,1.0,field.reticle_lock) if field.show_reticle else 0.0
		return {"spin":field.clock*1.4*(1.0-lock),"lock":lock,"ink":(UiFx.ACCENT if field.lock_priority else UiFx.INK).lerp(UiFx.INK,1.0-lock)}
	add_child(pointer_frame)
	field.unified_cursor = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func cursor_button() -> Button:
	var b: Button = UiFx.hovered_button(get_viewport())
	if b != null and b.has_meta("fx") and not b.disabled and b.is_visible_in_tree():
		return b
	return null

func cursor_target_rect(mouse: Vector2) -> Rect2:
	var b: Button = cursor_button()
	if b != null:
		return b.get_global_rect().grow(7.0)
	var center: Vector2 = mouse
	var radius: float = 13.0
	if field.show_reticle and field.reticle_lock > 0.0:
		var lock: float = smoothstep(0.0,1.0,field.reticle_lock)
		center = mouse.lerp(field.to_global(field.lock_pos),lock)
		radius = lerpf(radius,(field.lock_radius+12.0)*field.global_scale.x,lock)
	return Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0)

func build_hud() -> void:
	var line := ColorRect.new()
	line.color = Color("2d2d2d")
	line.position = Vector2(36,116)
	line.size = Vector2(1528,1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(line)
	stage_label = label(TranslationServer.translate("城市"),30)
	ui.add_child(stage_label)
	scale_label = label("",13,Color("8a8a8a"))
	ui.add_child(scale_label)
	money_label = label("$ 0",28,Color("ededed"))
	ui.add_child(money_label)
	loot_label = label("",24,Color("ffc94d"))
	loot_label.visible = false
	ui.add_child(loot_label)
	rate_label = label("",13,Color("8a8a8a"))
	ui.add_child(rate_label)
	wave_label = label(TranslationServer.translate("第 01 / 10 波"),19)
	ui.add_child(wave_label)
	health_label = label(TranslationServer.translate("防线 100%"),18,Color("b4b4b4"))
	ui.add_child(health_label)
	wave_bar = ProgressBar.new()
	wave_bar.show_percentage = false
	wave_bar.add_theme_stylebox_override("background",panel_style(Color("262626"),Color("262626"),2))
	wave_bar.add_theme_stylebox_override("fill",panel_style(Color("ededed"),Color("ededed"),2))
	for key in ["background","fill"]:
		var bar_style: StyleBoxFlat = wave_bar.get_theme_stylebox(key)
		bar_style.content_margin_top=0
		bar_style.content_margin_bottom=0
	ui.add_child(wave_bar)
	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(boss_box)
	boss_title = label(TranslationServer.translate("巨型威胁"),16,Color("ededed"))
	boss_box.add_child(boss_title)
	boss_timer = label("",16,Color("ffc94d"))
	boss_box.add_child(boss_timer)
	boss_timer.position = Vector2(470,0)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.position = Vector2(0,30)
	boss_bar.size = Vector2(640,5)
	boss_bar.add_theme_stylebox_override("background",panel_style(Color("2a2a2a"),Color("2a2a2a"),2))
	boss_bar.add_theme_stylebox_override("fill",panel_style(Color("ffc94d"),Color("ffc94d"),2))
	for key in ["background","fill"]:
		var bar_style: StyleBoxFlat = boss_bar.get_theme_stylebox(key)
		bar_style.content_margin_top=0
		bar_style.content_margin_bottom=0
	boss_ghost = ProgressBar.new()
	boss_ghost.show_percentage = false
	boss_ghost.position = boss_bar.position
	boss_ghost.size = boss_bar.size
	boss_ghost.add_theme_stylebox_override("background",panel_style(Color(0,0,0,0),Color(0,0,0,0),2))
	boss_ghost.add_theme_stylebox_override("fill",panel_style(Color("ededed"),Color("ededed"),2))
	for key in ["background","fill"]:
		var ghost_style: StyleBoxFlat = boss_ghost.get_theme_stylebox(key)
		ghost_style.content_margin_top=0
		ghost_style.content_margin_bottom=0
	boss_box.add_child(boss_ghost)
	boss_box.add_child(boss_bar)
	boss_bar.visible = false
	boss_ghost.visible = false
	boss_title.visible = false
	boss_timer.visible = false
	boss_fx = UiFx.BossBar.new()
	boss_fx.size = Vector2(640,70)
	boss_box.add_child(boss_fx)
	boss_bar.add_theme_stylebox_override("background",panel_style(Color(0,0,0,0),Color(0,0,0,0),2))
	var bottom := Panel.new()
	bottom.name = "Bottom"
	bottom.add_theme_stylebox_override("panel",panel_style(Color("161616"),Color("323232"),12))
	ui.add_child(bottom)
	ui.move_child(boss_box,-1)
	hint = label("",15,Color("a6a6a6"))
	bottom.add_child(hint)
	hint.position = Vector2(24,23)
	hud_auto_button = button(TranslationServer.translate("开启自动防御 · $200"),buy_automation_from_hud,true)
	hud_auto_button.name = "AutomationButton"
	hud_auto_button.visible = false
	bottom.add_child(hud_auto_button)
	var shop := button(TranslationServer.translate("升级防线  [U]"),func():open_shop(),true)
	shop.name = "ShopButton"
	bottom.add_child(shop)
	var pause := button(TranslationServer.translate("暂停  [Esc]"),func():open_pause())
	pause.name = "PauseButton"
	bottom.add_child(pause)
	ult_button = button("",fire_ultimate_from_hud,true)
	ult_button.name = "UltButton"
	ult_button.tooltip_text = TranslationServer.translate("毁灭性打击：战斗时间与击毁共同充能  [Q]")
	ult_button.clip_contents = true
	ult_fill = ColorRect.new()
	ult_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ult_fill.show_behind_parent = false
	ult_button.add_child(ult_fill)
	ult_button.move_child(ult_fill,0)
	bottom.add_child(ult_button)
	speed_button = button("",cycle_speed)
	speed_button.name = "SpeedButton"
	speed_button.tooltip_text = TranslationServer.translate("加速游戏：×1 / ×2 / ×4 / ×8" if OS.is_debug_build() else "加速游戏：×1 / ×2")
	bottom.add_child(speed_button)
	dev_bar = HBoxContainer.new()
	dev_bar.add_theme_constant_override("separation",8)
	dev_bar.visible = false
	ui.add_child(dev_bar)
	for pair in [[TranslationServer.translate("开发：资金 ×10"),dev_money],[TranslationServer.translate("上一波"),dev_prev_wave],[TranslationServer.translate("跳过本波"),dev_skip_wave],[TranslationServer.translate("击毁 Boss"),dev_kill_boss],[TranslationServer.translate("上一章"),dev_prev_stage],[TranslationServer.translate("直达下一章"),dev_next_stage]]:
		var dev_button := button(pair[0],pair[1])
		dev_button.custom_minimum_size = Vector2(0,38)
		dev_bar.add_child(dev_button)
	dev_god_button = button(TranslationServer.translate("无敌：关"),dev_toggle_god)
	dev_god_button.custom_minimum_size = Vector2(0,38)
	dev_bar.add_child(dev_god_button)
	dev_ult_button = button(TranslationServer.translate("大招冷却：正常"),dev_toggle_ult)
	dev_ult_button.custom_minimum_size = Vector2(0,38)
	dev_bar.add_child(dev_ult_button)
	dev_ult_kind_button = button(TranslationServer.translate("大招：本章"),dev_cycle_ult_kind)
	dev_ult_kind_button.custom_minimum_size = Vector2(0,38)
	dev_bar.add_child(dev_ult_kind_button)
	refresh_speed_button()
	toast = label("",17,Color("dbdbdb"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)
	ult_overlay = UiFx.UltOverlay.new()
	ui.add_child(ult_overlay)
	cinema = UiFx.Cinema.new()
	add_child(cinema)
	resume_fx = UiFx.Resume.new()
	resume_fx.hide()
	add_child(resume_fx)
	ending_skip = button(TranslationServer.translate("跳过结局  Esc"),func():cinema.skip_ending())
	ending_skip.custom_minimum_size = Vector2(154,36)
	ending_skip.visible = false
	cinema.add_child(ending_skip)
	city_tactics = preload("res://scripts/city_tactics.gd").new()
	ui.add_child(city_tactics)
	city_tactics.setup(self)

func layout() -> void:
	if field == null:
		return
	var w: float = size.x
	var h: float = size.y
	var zoom: float = minf((w-90)/1100,(h-265)/620)
	field_zoom = zoom
	field.scale = Vector2.ONE*zoom
	field.position = Vector2(w*.5-500*zoom,145)
	field_origin=field.position
	# Threats materialise just inside the visible edge of the battlefield, so
	# every shot the defense fires lands somewhere the player can see.
	var top_left: Vector2 = (Vector2(0,118)-field_origin)/zoom
	var bottom_right: Vector2 = (Vector2(w,h-104)-field_origin)/zoom
	sim.spawn_rect = Rect2(top_left,bottom_right-top_left).grow(-16)
	# The dot grid covers the whole window (with room for camera shake).
	var screen: Rect2 = Rect2(-field_origin/zoom,Vector2(w,h)/zoom).grow(90)
	if field.grid_rect != null:
		field.grid_rect.position = screen.position
		field.grid_rect.size = screen.size
		field.grid_material.set_shader_parameter("origin",screen.position)
	stage_label.position = Vector2(40,26)
	scale_label.position = Vector2(42,72)
	money_label.position = Vector2(w*.45,29)
	rate_label.position = Vector2(w*.45+2,74)
	loot_label.position = Vector2(w*.45+2,94)
	wave_label.position = Vector2(w-395,32)
	health_label.position = Vector2(w-180,35)
	wave_bar.position = Vector2(w-395,75)
	wave_bar.size = Vector2(340,4)
	var line: Control = ui.get_child(0)
	line.size.x = w-72
	# Give the boss its own space; the bottom row already contains five controls.
	boss_fx.size.x = clampf(w * .34, 360.0, 640.0)
	boss_box.position = Vector2(w - boss_fx.size.x - 40, 132)
	var bottom: Control = ui.get_node("Bottom")
	bottom.position = Vector2(36,h-101)
	bottom.size = Vector2(w-72,72)
	hud_auto_button.position = Vector2(24,13)
	hud_auto_button.size = Vector2(320,46)
	var shop: Control = bottom.get_node("ShopButton")
	shop.position = Vector2(w-504,13)
	shop.size = Vector2(222,46)
	var pause: Control = bottom.get_node("PauseButton")
	pause.position = Vector2(w-263,13)
	pause.size = Vector2(167,46)
	speed_button.position = Vector2(w-686,13)
	speed_button.size = Vector2(166,46)
	for fixed in [shop, pause, speed_button]:
		fit_text(fixed, 16)
	ult_button.position = Vector2(w-912,13)
	ult_button.size = Vector2(210,46)
	dev_bar.position = Vector2(36,h-150)
	if is_instance_valid(ult_overlay):
		ult_overlay.position = Vector2.ZERO
		ult_overlay.size = Vector2(w,h)
	if is_instance_valid(cinema):
		cinema.position = Vector2.ZERO
		cinema.size = Vector2(w,h)
		ending_skip.position = Vector2(w-180,12)
		ending_skip.size = Vector2(154,36)
	toast.position = Vector2(w*.2,h-142)
	toast.size = Vector2(w*.6,30)
	if is_instance_valid(modal):
		modal.position = (size-modal.size)*.5

func new_modal(width: float, title: String, subtitle: String) -> VBoxContainer:
	if is_instance_valid(modal):
		modal.queue_free()
	if not shade.visible or shade.modulate.a < 1.0:
		var fade := shade.create_tween()
		fade.tween_property(shade,"modulate:a",1.0,.3)
	shade.show()
	if is_instance_valid(title_screen) and title_screen.visible:
		move_child(shade,get_child_count()-1)
		title_screen.set_menu_focus(false)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal = PanelContainer.new()
	audio.ui("ui_open")
	modal.add_theme_stylebox_override("panel",panel_style(Color("161616"),Color("454545"),3))
	modal.size.x = width
	add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",16)
	modal.add_child(v)
	var heading := label(title,30)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = width - 40
	v.add_child(heading)
	var explanation := label(subtitle,14,Color("a2a2a2"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = width - 40
	v.add_child(explanation)
	call_deferred("center_modal")
	return v

func current_menu_staggers() -> bool:
	return menu in ["title","pause","result"]

func center_modal() -> void:
	# Wrapped labels settle their minimum height after container layout.
	# Measuring immediately can clamp the panel to its initial unwrapped height.
	var panel := modal
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(panel) or panel != modal:
		return
	if is_instance_valid(modal):
		modal.size = modal.get_combined_minimum_size()
		modal.position = (size-modal.size)*.5
		# Panels spring open instead of popping in.
		# Panels unfold from a bright hairline into the full sheet.
		modal.pivot_offset = modal.size*.5
		modal.scale = Vector2(.6,.012)
		modal.modulate = Color(2.2,2.2,2.2,0)
		var tween := modal.create_tween().set_parallel(true)
		tween.tween_property(modal,"scale:x",1.0,.26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(modal,"scale:y",1.0,.38).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(.12)
		tween.tween_property(modal,"modulate",Color.WHITE,.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var body: Node = modal.get_child(0) if modal.get_child_count() > 0 else null
		if body is VBoxContainer:
			stagger(body,.03 if current_menu_staggers() else .012)

func show_title() -> void:
	if OS.has_feature("web"):
		show_classic_title()
		return
	if is_instance_valid(cinema):
		cinema.skip_ending()
		ending_skip.hide()
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	shade.hide()
	ui.hide()
	menu = "title"
	sim.paused = true
	sim.manual_held = false
	sim.manual_queued = false
	if not is_instance_valid(title_screen):
		title_screen = preload("res://scripts/title_screen.gd").new()
		add_child(title_screen)
		title_screen.setup(self)
	else:
		title_screen.refresh()
	title_screen.show()

func persist_preferences() -> void:
	if OS.has_feature("web") or not store.enabled: return
	var config := ConfigFile.new()
	for key in settings_payload(): config.set_value("ui",key,settings_payload()[key])
	config.save(preferences_path)

func export_campaign() -> void:
	if saved.is_empty(): return
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.json ; SKYGUARD campaign"])
	picker.current_file = "skyguard-campaign.json"
	picker.title = words("导出存档", "Export campaign")
	add_child(picker)
	picker.file_selected.connect(func(path: String):
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(saved,"\t"))
			file.close()
		else:
			var alert := AcceptDialog.new()
			alert.dialog_text = words("无法写入文件，请选择其他位置。", "Could not write the file. Choose another location.")
			add_child(alert)
			alert.popup_centered()
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered(Vector2i(900,600))

func show_classic_title() -> void:
	if is_instance_valid(cinema):
		cinema.skip_ending()
		ending_skip.hide()
	if is_instance_valid(pointer_frame):
		pointer_frame.suppressed = false
		pointer_frame.show()
	menu = "title"
	ui.hide()
	var v: VBoxContainer = new_modal(610,TranslationServer.translate("天穹防线"),TranslationServer.translate("SKYGUARD  /  从第一枚导弹，到宇宙最后的光"))
	var emblem := TextureRect.new()
	emblem.texture = preload("res://assets/emblem.svg")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(0,96)
	v.add_child(emblem)
	v.add_child(label(TranslationServer.translate("城市  →  地球  →  太阳系  →  银河  →  星系团  →  宇宙"),15,Color("c3c3c3")))
	var intro := label(TranslationServer.translate("击毁威胁赚取资金，让防御体系不断进化。\n早期点击目标发射；购买自动化后，点击指定集火。\n十道防线，十个巨型威胁，从城市一直打到宇宙之外。"),16,Color("bababa"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.y = 87
	v.add_child(intro)
	if not saved.is_empty():
		v.add_child(button(TranslationServer.translate("继续战役 · ")+TranslationServer.translate(sim.catalog.stages[sim.saved_stage(saved)].title),continue_game,true))
	v.add_child(button(TranslationServer.translate("开始新战役"),func():
		if saved.is_empty():
			start_game()
		else:
			confirm_new(),saved.is_empty()))
	v.add_child(button(TranslationServer.translate("退出"),func():get_tree().quit()))
	language_button = button(str(LANGUAGE_NAMES.get(language, language)) + "  ▸", toggle_language)
	v.add_child(language_button)
	v.add_child(label(TranslationServer.translate("鼠标优先  ·  U 升级  ·  Esc 暂停  ·  F11 全屏"),13,Color("7f7f7f")))

func confirm_new() -> void:
	var v: VBoxContainer = new_modal(540,TranslationServer.translate("开始新的防线？"),TranslationServer.translate("新战役会覆盖当前进度。"))
	var start: Button = button(TranslationServer.translate("开始新战役"),start_game,true)
	v.add_child(start)
	start.grab_focus()
	v.add_child(button(TranslationServer.translate("返回"),show_title))

func start_game() -> void:
	close_modal()
	sim.start_new()
	field.reset_growth()
	show_notice(TranslationServer.translate("点击或按住来袭目标发射导弹 · 升级面板暂停战斗"))

func play_resume() -> void:
	# Restore sequence, then the battle opens from the core with a small settle.
	if not ui_motion or not is_instance_valid(resume_fx):
		return
	resume_fx.size = size
	var chapter: String = "%02d  %s" % [sim.stage + 1, TranslationServer.translate(sim.stage_data().title)]
	var detail: String = (TranslationServer.translate("第 %d 波") % sim.wave) if sim.mode != "boss" else TranslationServer.translate("巨型威胁")
	resume_fx.play(field.get_global_transform() * sim.defense_position(), chapter, detail)
	cam_zoom = 1.12
	cam_target = 1.0
	cam_focus = sim.defense_position()

func continue_game() -> void:
	if sim.restore(saved):
		field.reset_growth()
		close_modal()
		play_resume()
		show_notice(TranslationServer.translate("战役已恢复 · 没有离线时间结算"))
	else:
		show_notice(TranslationServer.translate("存档无法读取，请开始新战役"))

func close_modal() -> void:
	if is_instance_valid(title_screen): title_screen.hide()
	if is_instance_valid(modal):
		audio.ui("ui_close")
		# Fold back into a hairline, then go.
		var old: PanelContainer = modal
		modal = null
		# The folding sheet no longer takes clicks.
		old.propagate_call("set",["mouse_filter",Control.MOUSE_FILTER_IGNORE])
		old.pivot_offset = old.size*.5
		var fold := old.create_tween().set_parallel(true)
		fold.tween_property(old,"scale:y",.012,.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		fold.tween_property(old,"scale:x",.5,.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(.14)
		fold.tween_property(old,"modulate",Color(2,2,2,0),.3).set_delay(.06)
		fold.chain().tween_callback(old.queue_free)
	if shade.visible:
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fade := shade.create_tween()
		fade.tween_property(shade,"modulate:a",0.0,.25)
		fade.tween_callback(func(): if modal == null: shade.hide())
	menu = ""
	ui.show()
	sim.paused = false
	sim.manual_held = false
	sim.manual_queued = false
	cards.clear()
	auto_button = null
	weapon_button = null
	accumulator = 0
	save_game()

func open_shop() -> void:
	if sim.mode in ["title","victory"]:
		return
	menu = "shop"
	sim.paused = true
	sim.manual_held = false
	sim.manual_queued = false
	cards.clear()
	var v: VBoxContainer = new_modal(minf(1120,size.x-80),TranslationServer.translate("升级防线"),TranslationServer.translate("战斗、撞击计时与收入已暂停 · 所有已购武器共享升级"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	v.add_child(row)
	var wallet := label("$ "+Catalog.number(sim.money),24,Color("ededed"))
	wallet.name = "Wallet"
	wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wallet)
	for pair in [[1,TranslationServer.translate("购买 ×1")],[10,TranslationServer.translate("购买 ×10")],[1000,TranslationServer.translate("购买最多")]]:
		var count: int = pair[0]
		row.add_child(button(pair[1],func():purchase_count=count;update_shop()))
	if sim.automation_available():
		auto_button = button(TranslationServer.translate("自动防御  $200  ·  导弹自主索敌"),func():
			if sim.buy_automation():
				play_tone("upgrade")
				open_shop()
			else:
				play_tone("deny"),true)
		v.add_child(auto_button)
	if not sim.owned[sim.stage]:
		weapon_button = button(TranslationServer.translate("部署")+TranslationServer.translate(sim.catalog.weapons[sim.stage].title)+"  $"+Catalog.number(sim.stage_data().weapon_price)+"  ·  "+TranslationServer.translate(sim.catalog.weapons[sim.stage].role),func():
			if sim.buy_weapon():
				play_tone("upgrade")
				open_shop()
			else:
				play_tone("deny"),true)
		v.add_child(weapon_button)
	var grid := GridContainer.new()
	grid.columns = 4 if sim.stage>=4 else 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	v.add_child(grid)
	for i in range(sim.catalog.upgrades.size()):
		var spec: Resource = sim.catalog.upgrades[i]
		if sim.stage < int(spec.unlock_stage) or bool(spec.retired):
			continue
		var p := PanelContainer.new()
		var card_width: float=(minf(1120,size.x-80)-40-12*(grid.columns-1))/grid.columns
		p.custom_minimum_size = Vector2(card_width,149)
		p.add_theme_stylebox_override("panel",panel_style(Color("1e1e1e"),Color("363636"),9))
		grid.add_child(p)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",7)
		p.add_child(card)
		var title := label("",19)
		card.add_child(title)
		var detail := label(TranslationServer.translate(spec.description),12,Color("acacac"))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(card_width-40,48 if grid.columns==4 else 36)
		card.add_child(detail)
		var index: int = i
		var buy := button("",func():
			var bought: int = sim.buy_upgrade(index,purchase_count)
			if bought>0:
				for entry in cards:
					if int(entry.index)==index:
						celebrate(entry.button,"+%d" %bought)
				play_tone("buy")
				update_shop()
			else:
				play_tone("deny"),true)
		card.add_child(buy)
		cards.append({"index":i,"title":title,"button":buy})
	var milestones := label("",13,Color("969696"))
	milestones.name="Milestones"
	v.add_child(milestones)
	var power := label("",14,Color("c9c9c9"))
	power.name="Power"
	v.add_child(power)
	v.add_child(button(TranslationServer.translate("继续防御  [U / Esc]"),close_modal,true))
	update_shop()
	stagger(grid,.04)

func update_shop() -> void:
	if not is_instance_valid(modal):
		return
	var wallet: Label = modal.find_child("Wallet",true,false)
	if wallet:
		wallet.text = "$ "+Catalog.number(sim.money)
	var milestones: Label=modal.find_child("Milestones",true,false)
	if milestones:
		var next_damage: int=-1
		for threshold in [10,25,50,75,100,125,150]:
			if int(sim.levels.damage)<threshold:
				next_damage=threshold
				break
		var damage_text: String=TranslationServer.translate("弹头突破全部完成") if next_damage<0 else TranslationServer.translate("弹头 Lv.%d 伤害翻倍")%next_damage
		var reload_text: String=TranslationServer.translate("发射器已达最大规模") if int(sim.levels.reload)>=140 else TranslationServer.translate("装填 Lv.%d 发射器翻倍")%((int(sim.levels.reload)/10+1)*10)
		milestones.text=TranslationServer.translate("下一突破：")+damage_text+"   ·   "+reload_text+TranslationServer.translate("   ·   老武器始终在役")
	var power: Label = modal.find_child("Power",true,false)
	if power:
		power.text=TranslationServer.translate("理论单体火力 $d / s   ·   齐射发射器 $l   ·   最大覆盖 $c 成员").replace("$d",Catalog.number(sim.nominal_dps())).replace("$l",Catalog.number(sim.launcher_count())).replace("$c",Catalog.number(sim.coverage(sim.stage) if sim.owned[sim.stage] else sim.coverage(maxi(0,sim.stage-1))))
	for c in cards:
		var spec: Resource = sim.catalog.upgrades[int(c.index)]
		c.title.text = TranslationServer.translate(spec.title)+"  Lv."+str(sim.levels[spec.key])
		# Long upgrade names (German, Russian...) shrink to the card instead of widening the shop.
		var title_room: float = (c.title.get_parent().get_parent() as Control).custom_minimum_size.x-28
		var title_px := 19
		while title_px > 13 and font.get_string_size(c.title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > title_room:
			title_px -= 1
		c.title.add_theme_font_size_override("font_size", title_px)
		var count: int = purchase_count
		if count==1000:
			var first: float = sim.upgrade_cost(int(c.index))
			var g: float=float(sim.catalog.upgrades[int(c.index)].cost_growth)
			count = maxi(1,int(floor(log(1+sim.money*(g-1)/first)/log(g))))
		var price: float = sim.upgrade_cost(int(c.index),count)
		c.button.text = "+%d  ·  $%s" %[count,Catalog.number(price)]
		c.button.disabled = sim.money+0.00001<price
	if is_instance_valid(auto_button):
		auto_button.disabled = sim.money<200
	if is_instance_valid(weapon_button):
		weapon_button.disabled = sim.money<float(sim.stage_data().weapon_price)

func open_pause() -> void:
	if sim.mode=="title":
		return
	menu = "pause"
	sim.paused = true
	sim.manual_held = false
	sim.manual_queued = false
	var v: VBoxContainer = new_modal(510,TranslationServer.translate("防线暂停"),TranslationServer.translate("所有模拟与计时已停止 · 进度已保存"))
	v.add_child(button(TranslationServer.translate("继续防御"),close_modal,true))
	v.add_child(button(TranslationServer.translate("升级防线"),open_shop))
	language_button = button(str(LANGUAGE_NAMES.get(language, language)) + "  ▸", toggle_language)
	v.add_child(language_button)
	var audio_toggle := button(TranslationServer.translate("声音：开启") if sound_on else TranslationServer.translate("声音：关闭"),func():
		sound_on = not sound_on
		audio.set_enabled(sound_on)
		open_pause()
		save_game())
	v.add_child(audio_toggle)
	for setting in ["music_level","effects_level"]:
		var audio_row:=HBoxContainer.new()
		audio_row.add_theme_constant_override("separation",14)
		var caption:=label(TranslationServer.translate("音乐") if setting=="music_level" else TranslationServer.translate("音效"),14)
		caption.custom_minimum_size=Vector2(58,30)
		audio_row.add_child(caption)
		var slider:=HSlider.new()
		slider.min_value=0
		slider.max_value=100
		slider.value=float(audio.get(setting))*100
		slider.step=1
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		audio_row.add_child(slider)
		var value_label:=label("%.0f%%"%slider.value,14)
		value_label.custom_minimum_size=Vector2(48,30)
		audio_row.add_child(value_label)
		var key: String=setting
		slider.value_changed.connect(func(value: float):audio.set(key,value/100);audio.set_enabled(sound_on);value_label.text="%.0f%%"%value)
		v.add_child(audio_row)
	v.add_child(button(TranslationServer.translate("特效：柔和") if reduced_effects else TranslationServer.translate("特效：标准"),func():reduced_effects=not reduced_effects;open_pause();save_game()))
	v.add_child(button(TranslationServer.translate("UI 动态效果：开启") if ui_motion else TranslationServer.translate("UI 动态效果：关闭"),func():ui_motion=not ui_motion;open_pause();save_game()))
	v.add_child(button(words("镜头运动：关闭", "Camera motion: Off") if camera_comfort else words("镜头运动：开启", "Camera motion: On"),func():camera_comfort=not camera_comfort;open_pause();save_game()))
	v.add_child(button(TranslationServer.translate("保存并返回主菜单"),func():
		save_game()
		saved = store.read_game()
		show_title()))
	v.add_child(label(TranslationServer.translate("累计防御 %.1f 分钟  ·  击毁 %s 个目标") %[sim.elapsed/60,Catalog.number(sim.kills)],14,Color("969696")))
	save_game()

func show_result() -> void:
	if menu in ["result","shop"]:
		return
	ui.show()
	menu = "result"
	var victory: bool = sim.mode=="victory"
	var v: VBoxContainer = new_modal(660,TranslationServer.translate("最后的光，留给文明。") if victory else TranslationServer.translate("防线已被突破"),TranslationServer.translate("战役完成  /  SKYGUARD") if victory else TranslationServer.translate("本波重来，资金、全部升级与已购武器保留"))
	var advice: String=TranslationServer.translate("巨型威胁未在撞击前击毁。升级伤害与暴击，缩短 Boss 战。") if sim.health>0 else TranslationServer.translate("群落超出了拦截能力。装填 Lv.%d 增加发射器。")%((int(sim.levels.reload)/10+1)*10)
	if not victory and sim.health<=0 and sim.stage>=2:advice+=TranslationServer.translate("\n范围与贯穿能消灭更多成员；部署本阶段的新炮。")
	var result_text := label(TranslationServer.translate("十道防线全部守住。\n你让城市的第一座发射井，一直战斗到宇宙之外。") if victory else advice,17,Color("c1c1c1"))
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = 620
	v.add_child(result_text)
	v.add_child(label(TranslationServer.translate("防御时间 %.1f 分钟   ·   击毁 %s   ·   重试 %d") %[sim.elapsed/60,Catalog.number(sim.kills),sim.attempts],16,Color("d5d5d5")))
	if victory:
		v.add_child(button(TranslationServer.translate("重播 · 宇宙的新生"),play_ending))
		v.add_child(button(TranslationServer.translate("返回主菜单"),func():saved=store.read_game();show_title(),true))
	else:
		v.add_child(button(TranslationServer.translate("重打本波"),func():close_modal();sim.retry(),true))
		v.add_child(button(TranslationServer.translate("先升级防线"),open_shop))

func buy_automation_from_hud() -> void:
	if sim.buy_automation():
		play_tone("upgrade")
		update_hud()

func update_hud() -> void:
	if is_instance_valid(city_tactics): city_tactics.refresh()
	stage_label.text = "%02d   %s" %[sim.stage+1,TranslationServer.translate(sim.stage_data().title)]
	scale_label.text = TranslationServer.translate(sim.stage_data().subtitle)+"     /     "+TranslationServer.translate(sim.stage_data().scale_label)
	wave_label.text = TranslationServer.translate("巨型威胁") if sim.mode=="boss" else TranslationServer.translate("第 %02d / 10 波") %sim.wave
	health_label.text = TranslationServer.translate("防线 %.0f%%") %sim.health
	health_label.modulate = Color("ffc94d") if sim.health<40 else Color.WHITE

	boss_box.visible = sim.mode=="boss" and menu==""
	if boss_box.visible and not boss_was_visible:
		var current_hp: float = 1.0
		if not sim.enemies.is_empty() and bool(sim.enemies[0].boss):
			current_hp = float(sim.enemies[0].hp) / sim.boss_max_hp()
		boss_fx.reset(current_hp)
	boss_was_visible = boss_box.visible
	if sim.mode=="boss":
		boss_title.text = TranslationServer.translate(sim.stage_data().boss_title)
		boss_timer.text = TranslationServer.translate("撞击倒计时  %.1f s") %sim.boss_remaining
		boss_fx.name_text = boss_title.text
		boss_fx.timer_text = boss_timer.text
		if not sim.enemies.is_empty() and bool(sim.enemies[0].boss):
			boss_fx.set_hp(float(sim.enemies[0].hp)/sim.boss_max_hp())
		if not sim.enemies.is_empty():
			var target: float = float(sim.enemies[0].hp)/sim.boss_max_hp()*100
			if target < boss_shown - .01:
				ghost_hold = .35
			boss_shown = target if target > boss_shown else boss_shown
			boss_title.text += "   /   HP "+Catalog.number(sim.enemies[0].hp)
	var parts: Array[String] = []
	for i in range(sim.STAGE_COUNT):
		if sim.owned[i]:
			parts.append(TranslationServer.translate(sim.catalog.weapons[i].title).trim_suffix(TranslationServer.translate("阵列")))
	var auto_available: bool = sim.automation_available() and sim.mode not in ["title","victory"]
	if auto_available and not hud_auto_button.visible:
		show_notice(TranslationServer.translate("自动防御已开放 · 花 $200 购买，所有武器自主索敌"))
	hud_auto_button.visible = auto_available
	hud_auto_button.disabled = sim.money<200
	hud_auto_button.text = TranslationServer.translate("开启自动防御 · $200") if sim.money>=200 else TranslationServer.translate("自动防御 · $200（还差 $%d）")%ceili(200-sim.money)
	hud_auto_button.tooltip_text = TranslationServer.translate("购买后所有武器自动索敌；点击目标可指定集火。")
	hint.position.x = 360 if auto_available else 24
	hint.visible = sim.mode!="boss" and size.x>1500
	update_ult_button()
	boss_box.position.x = size.x - boss_fx.size.x - 40
	if auto_available:
		hint.text = TranslationServer.translate("已开放购买 · 开启后自动攻击")
	elif not sim.automation:
		hint.text = TranslationServer.translate("点击 / 按住目标发射 · 第六波可花 $200 购买自动防御")
	elif not sim.owned[sim.stage]:
		hint.text = TranslationServer.translate("新武器可部署：")+TranslationServer.translate(sim.catalog.weapons[sim.stage].title)+TranslationServer.translate("  ·  打开升级防线")
	else:
		hint.text = TranslationServer.translate("自动拦截  ·  点击集火    /    ")+" + ".join(parts)
	if hint.text.length()>52:
		hint.add_theme_font_size_override("font_size",12)
	else:
		hint.add_theme_font_size_override("font_size",15)
	# Long weapon lists end in an ellipsis before the ultimate button instead of running under it.
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.size.x = maxf(0.0, size.x-912-hint.position.x-14)

const ARCH_LABEL: Dictionary = {"swarm": "蜂群", "dart": "飞镖", "armored": "重甲", "splitter": "分裂者", "shielded": "护盾者", "mother": "母舰"}
const ARCH_HINT: Dictionary = {"dart": "速度快，走弧线", "armored": "血厚、行动慢，装甲会一块块剥落", "splitter": "打碎后会裂成两块", "shielded": "先打破护盾才能伤到本体", "mother": "途中会不断放出小型敌人"}

func on_arch_introduced(arch: String, title: String, id: int) -> void:
	# A new kind of threat: a short tag, and a ring on the first one. No pause.
	field.intro_id = id
	field.intro_t = 3.0
	var cjk: bool = language in ["zh", "zh_TW", "ja"]
	show_notice(TranslationServer.translate("新威胁 · ") + TranslationServer.translate(title) + ("（" if cjk else " (") + TranslationServer.translate(ARCH_LABEL.get(arch, arch)) + ("）—— " if cjk else ") — ") + TranslationServer.translate(ARCH_HINT.get(arch, "")))

func show_notice(message: String) -> void:
	toast.text = message
	toast_time = 5.0
	if is_instance_valid(audio) and (message.to_lower().contains(TranslationServer.translate("突破").to_lower()) or message.to_lower().contains(TranslationServer.translate("进化").to_lower())):
		audio.play("milestone",-11,1,false,true)

func update_ult_button() -> void:
	var combat: bool = sim.mode in ["wave","boss","intermission"]
	ult_button.visible = combat
	if not combat:
		return
	var ready: bool = sim.ultimate_ready()
	var name: String = sim.ultimate_name()
	if not sim.ult.is_empty() and not sim.ult_unlimited:
		ult_button.text = name+TranslationServer.translate(" · 打击中")
	elif ready:
		ult_button.text = name+TranslationServer.translate(" · 就绪  [Q]")
	else:
		ult_button.text = "%s  %d%%" %[name,int(sim.ult_charge*100)]
	var px := 16
	while px > 9 and font.get_string_size(ult_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 166:
		px -= 1
	ult_button.add_theme_font_size_override("font_size", px)
	ult_button.disabled = not ready
	if ready and not ult_ready_seen:
		show_notice(name+TranslationServer.translate("已就绪 · 按 Q 或点击按钮发动"))
		spring(ult_button,1.12,.25)
	ult_ready_seen = ready

const ULT_ENGLISH: Dictionary = {"nuke":"NUCLEAR STRIKE","photoid":"PHOTOID STRIKE","droplet":"DROPLET  ·  STRONG INTERACTION","foil":"ONE-VECTOR FOIL","fourier":"FOURIER DECOMPOSITION","prime":"PRIME STRIKE","mandelbrot":"MANDELBROT  z → z² + c","lightspeed":"LIGHT SPEED · LOWERED","pi":"REWRITE  π  =  3","strings":"DIMENSIONAL RESONANCE"}

func on_ult_fired(kind: String, point: Vector2) -> void:
	ult_overlay.play(sim.ultimate_name(),str(ULT_ENGLISH.get(kind,"")),float(sim.ULT_DURATION.get(kind,3.0))*.8)
	# Lean the camera toward the strike while it winds up.
	cam_focus = point if kind in ["nuke","foil"] else sim.defense_position()
	cam_target = 1.04 if kind in ["photoid","droplet","mandelbrot"] else 1.1

# Big beats get a full-screen cinematic: boss entrance, boss destroyed + scale jump.
func stage_cinema() -> void:
	if sim.mode == cine_mode:
		return
	var previous: String = cine_mode
	cine_mode = sim.mode
	if sim.mode == "boss":
		var parts: PackedStringArray = TranslationServer.translate(sim.stage_data().boss_title).split(" · ")
		cinema.play("boss",2.9,parts[0],parts[-1] if parts.size() > 1 else "WARNING")
		field.banner = {}
		for e in sim.enemies:
			if bool(e.boss):
				cam_focus = e.pos
		cam_target = 1.13
		cam_hold = 1.7
		field.trauma = maxf(field.trauma,.5)
	elif sim.mode == "transition" and previous == "boss":
		hitstop = .24
		field.punch = 1.4
		toast_time = 0
		var next: Resource = sim.catalog.stages[sim.stage + 1]
		audio.prepare_stage(sim.stage + 1)
		cinema.play("jump",sim.transition_length,TranslationServer.translate(next.title),TranslationServer.translate(next.subtitle),"+ $"+Catalog.number(float(sim.stage_data().boss_reward)*sim.reward_scale()),"%02d" %(sim.stage + 2),TranslationServer.translate(sim.stage_data().scale_label),TranslationServer.translate(next.scale_label))
	elif sim.mode == "victory" and previous == "boss":
		hitstop = .3
		field.punch = 1.6
		play_ending()

func play_ending() -> void:
	close_modal()
	close_body_card()
	ui.hide()
	sim.manual_held = false
	toast_time = 0.0
	cinema.reduced_effects = reduced_effects or camera_comfort
	cinema.play("ending",UiFx.Cinema.EndingArt.LENGTH,"","")
	ending_skip.visible = true

func update_lens() -> void:
	var on: bool = not sim.ult.is_empty() and str(sim.ult.kind) == "photoid" and not reduced_effects
	var u: float = float(sim.ult.age) if on else 0.0
	on = on and u > .5 and u < sim.PHOTOID_IMPACT + .05
	lens.visible = on
	if not on:
		return
	var p: float = clampf((u - .6) / (sim.PHOTOID_IMPACT - .6), 0, 1)
	var head: Vector2 = field.get_global_transform() * field.photoid_head(u)
	var m: ShaderMaterial = lens.material
	m.set_shader_parameter("center", Vector2(head.x / size.x, head.y / size.y))
	m.set_shader_parameter("radius", (70.0 + 110.0 * p) / size.y)
	m.set_shader_parameter("strength", smoothstep(.5, .9, u) * (.45 + .55 * p))
	m.set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))

func update_mandel() -> void:
	var on: bool = not sim.ult.is_empty() and str(sim.ult.kind) == "mandelbrot"
	var u: float = float(sim.ult.age) if on else 0.0
	on = on and u > sim.MANDEL_START and u < float(sim.ULT_DURATION.mandelbrot)
	mandel.visible = on
	if not on:
		return
	var art = field.ultimate_art
	var xf: Transform2D = field.get_global_transform()
	var core: Vector2 = xf * sim.defense_position()
	var px_scale: float = xf.get_scale().y
	var m: ShaderMaterial = mandel.material
	m.set_shader_parameter("core", Vector2(core.x / size.x, core.y / size.y))
	m.set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
	var disc: float = sim.mandel_radius(u) * px_scale / size.y
	m.set_shader_parameter("radius", disc)
	m.set_shader_parameter("scale", art.mandel_scale(u, disc))
	m.set_shader_parameter("focus", art.mandel_focus(u))
	m.set_shader_parameter("max_iter", art.mandel_iterations(u))
	m.set_shader_parameter("time", 0.0 if reduced_effects else u)
	m.set_shader_parameter("fade", (1.0 - smoothstep(4.9, 5.6, u)) * (.75 if reduced_effects else 1.0))

func update_shatter() -> void:
	var on: bool = not sim.ult.is_empty() and str(sim.ult.kind) == "pi" and not reduced_effects
	var u: float = float(sim.ult.age) if on else 0.0
	var hit: float = sim.PI_IMPACT
	on = on and u > hit - .7 and u < hit + 1.7
	shatter.visible = on
	if not on:
		shatter_seeds.clear()
		return
	var core: Vector2 = field.get_global_transform() * sim.defense_position()
	var center: Vector2 = Vector2(core.x / size.x, core.y / size.y)
	if shatter_seeds.is_empty():
		# Shards are smaller near the strike and larger toward the edges.
		for i in range(20):
			var a: float = i * 2.39996 + randf() * .3
			var r: float = sqrt((i + .5) / 20.0) * .75
			shatter_seeds.append(center + Vector2(cos(a) * r * size.y / size.x, sin(a) * r))
	var m: ShaderMaterial = shatter.material
	var crack: float = smoothstep(hit - .7, hit, u)
	var fall: float = clampf((u - hit) / 1.0, 0, 1)
	m.set_shader_parameter("crack", crack)
	m.set_shader_parameter("progress", 1.0 - pow(1.0 - fall, 2.0) if u > hit else 0.0)
	m.set_shader_parameter("settle", smoothstep(hit + 1.0, hit + 1.7, u))
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("aspect", Vector2(size.x / size.y, 1.0))
	m.set_shader_parameter("seeds", shatter_seeds)

func on_ult_impact(_kind: String, _point: Vector2) -> void:
	hitstop = .13
	cam_target = 1.0
	cam_zoom = 1.2

func fire_ultimate_from_hud() -> void:
	fire_ultimate_at(Vector2.INF)

func fire_ultimate_at(point: Vector2) -> void:
	if menu!="" or not sim.fire_ultimate(point):
		return
	# Ultimates with their own designed sound carry themselves; the rest get a cue.
	if not audio.SFX.has("ult_"+str(sim.ult.get("kind",""))):
		audio.play("milestone",-6)
	toast_time = 0
	spring(ult_button,.92,.08)
	update_ult_button()

func animate_hud(delta: float) -> void:
	if is_instance_valid(ult_button) and ult_button.has_meta("fx"):
		ult_button.get_meta("fx").amber = sim.ultimate_ready()
	if is_instance_valid(ult_fill):
		var k: float = 1.0 if sim.ultimate_ready() else sim.ult_charge
		ult_fill.size = Vector2(ult_button.size.x*k,ult_button.size.y)
		var glow_k: float = .5+.5*sin(Time.get_ticks_msec()*.006) if sim.ultimate_ready() else 0.0
		ult_fill.color = Color(1,.79,.3,.18+.14*glow_k) if sim.ultimate_ready() else Color(1,1,1,.1)
	wave_shown = lerpf(wave_shown, sim.progress()*100, minf(1, delta*10))
	wave_bar.value = wave_shown
	if sim.mode == "boss" and not sim.enemies.is_empty():
		var target: float = float(sim.enemies[0].hp)/sim.boss_max_hp()*100
		boss_shown = lerpf(boss_shown, target, minf(1, delta*14))
		ghost_hold = maxf(0, ghost_hold-delta)
		if ghost_hold <= 0:
			ghost_shown = move_toward(ghost_shown, boss_shown, delta*45)
		ghost_shown = maxf(ghost_shown, boss_shown)
	else:
		boss_shown = 100
		ghost_shown = 100
	boss_bar.value = boss_shown
	boss_ghost.value = ghost_shown
	if sim.health < health_seen - .01:
		health_shake = 1.0
	health_seen = sim.health
	health_shake = maxf(0, health_shake-delta*3)
	health_label.position.x = size.x-180+(0.0 if camera_comfort else sin(Time.get_ticks_msec()*.07)*6*health_shake)
	if health_shake > 0:
		health_label.modulate = Color.WHITE.lerp(Color("ffc94d"), health_shake)
	if wave_label.text != wave_seen:
		wave_seen = wave_label.text
		wave_label.pivot_offset = wave_label.size*.5
		wave_label.scale = Vector2.ONE*1.25
		wave_label.create_tween().tween_property(wave_label,"scale",Vector2.ONE,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var enter: float = clampf((5.0-toast_time)/.3,0,1)
	toast.position.y = size.y-142+(1-enter)*(1-enter)*18

func open_body_card(slot: int) -> void:
	close_body_card()
	body_card_slot = slot
	body_card_stage = sim.stage
	var spec: Dictionary = sim.BODIES[sim.stage][slot]
	body_card = PanelContainer.new()
	body_card.add_theme_stylebox_override("panel",panel_style(Color("1a1a1a"),Color("ffc94d"),10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	body_card.add_child(v)
	v.add_child(label(TranslationServer.translate("改造 ") + TranslationServer.translate(str(spec.name)),20))
	var detail := label("→ " + TranslationServer.translate(str(spec.weapon)) + TranslationServer.translate("  ·  每 0.4 秒开火，相当于全体系火力 +12%"),13,Color("b4b4b4"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 260
	v.add_child(detail)
	var fold := label(TranslationServer.translate("换章后缩入核心，继续开火"),12,Color("7f7f7f"))
	fold.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fold.custom_minimum_size.x = 260
	v.add_child(fold)
	body_card_price = label("",15,Color("ffc94d"))
	v.add_child(body_card_price)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body_card_button = button(TranslationServer.translate("改造"),confirm_body_card,true)
	body_card_button.custom_minimum_size = Vector2(150,40)
	row.add_child(body_card_button)
	var cancel := button(TranslationServer.translate("取消"),close_body_card)
	cancel.custom_minimum_size = Vector2(100,40)
	row.add_child(cancel)
	v.add_child(row)
	ui.add_child(body_card)
	refresh_body_card()
	body_card.call_deferred("set","pivot_offset",Vector2(150,60))
	body_card.scale = Vector2.ONE*.85
	body_card.modulate.a = 0
	var tween := body_card.create_tween().set_parallel(true)
	tween.tween_property(body_card,"scale",Vector2.ONE,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_card,"modulate:a",1.0,.14)

func open_body_details(body_stage: int, slot: int) -> void:
	close_body_card()
	body_card_stage = body_stage
	body_card_slot = slot
	body_card_readonly = true
	var spec: Dictionary = sim.BODIES[body_stage][slot]
	body_card = PanelContainer.new()
	body_card.add_theme_stylebox_override("panel",panel_style(Color("1a1a1a"),Color("ffc94d"),10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	body_card.add_child(v)
	v.add_child(label(TranslationServer.translate(str(spec.weapon)),20))
	v.add_child(label(TranslationServer.translate(str(spec.name)) + words(" · 在役"," · ACTIVE"),13,Color("b4b4b4")))
	body_card_details = label("",14,Color("ededed"))
	body_card_details.custom_minimum_size.x = 270
	v.add_child(body_card_details)
	var inherited: String = words("保留原攻击方式 · 全局升级继续生效","Original attack · Global upgrades apply")
	var note := label(inherited,12,Color("b4b4b4"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 270
	v.add_child(note)
	v.add_child(button(words("关闭","CLOSE"),close_body_card))
	ui.add_child(body_card)
	refresh_body_card()

func refresh_body_card() -> void:
	if not is_instance_valid(body_card):
		return
	if body_card_slot < 0 or sim.mode in ["title","transition","victory","failed"] or (not body_card_readonly and sim.body_converted_at(sim.stage,body_card_slot)):
		close_body_card()
		return
	if body_card_readonly:
		var stats: Dictionary = sim.body_weapon_stats(body_card_stage,body_card_slot)
		body_card_details.text = words("基础齐射  ","Base volley  ") + Catalog.number(stats.damage) + "\n" + words("攻击间隔  ","Attack interval  ") + ("%.2f s" % stats.interval) + "\n" + words("每次覆盖  ","Coverage  ") + Catalog.number(stats.coverage)
	else:
		var price: float = sim.body_cost()
		var missing: float = price - sim.money
		body_card_price.text = TranslationServer.translate("价格  $") + Catalog.number(price)
		body_card_button.disabled = missing > 0
		body_card_button.text = TranslationServer.translate("改造") if missing <= 0 else TranslationServer.translate("还差 $") + Catalog.number(missing)
	var anchor: Vector2 = field.to_global(sim.body_position(body_card_stage,body_card_slot))
	var card_size: Vector2 = body_card.get_combined_minimum_size()
	var place: Vector2 = anchor + Vector2(28,-card_size.y*.5)
	if place.x + card_size.x > size.x - 20:
		place.x = anchor.x - 28 - card_size.x
	place.y = clampf(place.y,124,size.y-110-card_size.y)
	body_card.position = body_card.position.lerp(place,.35) if body_card.modulate.a > .5 else place

func confirm_body_card() -> void:
	if not body_card_readonly and body_card_slot >= 0 and sim.convert_body(body_card_slot):
		play_tone("buy")
		close_body_card()

func close_body_card() -> void:
	if is_instance_valid(body_card):
		body_card.queue_free()
	body_card = null
	body_card_slot = -1
	body_card_stage = -1
	body_card_readonly = false
	body_card_details = null

func settings_payload() -> Dictionary:
	return {"sound":sound_on,"camera_comfort":camera_comfort,"reduced_effects":reduced_effects,"ui_motion":ui_motion,"music_level":audio.music_level,"effects_level":audio.effects_level,"game_speed":game_speed,"language":language}

func available_languages() -> Array[String]:
	# The web build ships one Chinese/Latin font subset, so it offers Chinese and English only.
	return ["zh", "en"] if OS.has_feature("web") else LANGUAGES

func language_code(value: String) -> String:
	var v: String = value.replace("-", "_")
	if v in LANGUAGES:
		return v
	if v.begins_with("zh_TW") or v.begins_with("zh_HK") or v.begins_with("zh_MO") or v.begins_with("zh_Hant"):
		return "zh_TW"
	var base: String = v.split("_")[0]
	if base == "pt":
		return "pt_BR"
	return base if base in LANGUAGES else "en"

func words(zh: String, en: String) -> String:
	# Inline bilingual pairs: Chinese and English as written, other languages from the catalogue.
	if language == "zh":
		return zh
	if language == "en":
		return en
	var translated: String = TranslationServer.translate(zh)
	return en if translated == zh else translated

func toggle_language() -> void:
	var langs: Array[String] = available_languages()
	apply_language(langs[(langs.find(language) + 1) % langs.size()])
	save_game()

func apply_language(value: String, rebuild: bool = true) -> void:
	language = language_code(value)
	if not language in available_languages():
		language = "en" if language != "zh" else "zh"
	TranslationServer.set_locale(language)
	if is_instance_valid(language_button):
		language_button.text = str(LANGUAGE_NAMES.get(language, language)) + "  ▸"
	if rebuild and store.enabled and not OS.has_feature("web"):
		var preferences := ConfigFile.new()
		preferences.load(preferences_path)
		preferences.set_value("ui", "language", language)
		preferences.save(preferences_path)
	if not rebuild or not is_instance_valid(ui):
		return
	# Static HUD controls may have been constructed while English was selected.
	# Refresh from Chinese message IDs so switching back works after a native restart too.
	ui.get_node("Bottom/ShopButton").text = TranslationServer.translate("升级防线  [U]")
	ui.get_node("Bottom/PauseButton").text = TranslationServer.translate("暂停  [Esc]")
	fit_text(ui.get_node("Bottom/ShopButton"), 16)
	fit_text(ui.get_node("Bottom/PauseButton"), 16)
	ending_skip.text = TranslationServer.translate("跳过结局  Esc")
	ult_button.tooltip_text = TranslationServer.translate("毁灭性打击：战斗时间与击毁共同充能  [Q]")
	speed_button.tooltip_text = TranslationServer.translate("加速游戏：×1 / ×2 / ×4 / ×8" if OS.is_debug_build() else "加速游戏：×1 / ×2")
	var dev_labels := ["开发：资金 ×10", "上一波", "跳过本波", "击毁 Boss", "上一章", "直达下一章"]
	for i in range(dev_labels.size()):
		dev_bar.get_child(i).text = TranslationServer.translate(dev_labels[i])
	dev_god_button.text = TranslationServer.translate("无敌：开" if dev_god else "无敌：关")
	dev_ult_button.text = TranslationServer.translate("大招冷却：0" if sim.ult_unlimited else "大招冷却：正常")
	dev_ult_kind_button.text = TranslationServer.translate("大招：本章") if sim.ult_override == "" else TranslationServer.translate("大招：") + sim.ultimate_name()
	# Rebuild composed strings from their templates; preserve the paused campaign.
	toast_time = 0.0
	field.banner = {}
	close_body_card()
	update_hud()
	refresh_speed_button()
	update_rates(.25)
	match menu:
		"title": show_title()
		"pause": open_pause()
		"shop": open_shop()
		"result":
			menu = ""
			show_result()

func update_rates(delta: float) -> void:
	rate_timer += delta
	if rate_timer < .25:
		return
	rate_timer = 0
	var total: float=0
	for amount in sim.weapon_damage:
		total += amount
	var span: float=sim.elapsed-last_rate_time
	if span > .001 and total >= last_damage_total and sim.kills >= last_kills:
		rate_damage = lerpf(rate_damage,(total-last_damage_total)/span,.35)
		rate_kills = lerpf(rate_kills,float(sim.kills-last_kills)/span,.35)
	elif span < 0 or total < last_damage_total:
		rate_damage = 0
		rate_kills = 0
	last_damage_total = total
	last_kills = sim.kills
	last_rate_time = sim.elapsed
	rate_label.visible = sim.mode in ["wave","boss","intermission"]
	rate_label.text = TranslationServer.translate("每秒伤害 %s   ·   每秒击毁 %s") %[Catalog.number(rate_damage),Catalog.number(rate_kills)]

func allowed_speeds() -> Array[int]:
	return SPEEDS if OS.is_debug_build() else RELEASE_SPEEDS

func cycle_speed() -> void:
	var steps: Array[int]=allowed_speeds().duplicate()
	if OS.is_debug_build() and dev_mode:
		steps.append_array([16,32])
	game_speed = steps[(steps.find(game_speed)+1)%steps.size()]
	refresh_speed_button()

func update_loot_counter(delta: float) -> void:
	var flowing: float=0.0
	var progress: float=1.0
	for batch in sim.reward_batches:
		if bool(batch.released):
			flowing+=float(batch.reward)
			progress=minf(progress,clampf((float(batch.age)-sim.ULT_LOOT_DELAY)/sim.ULT_LOOT_FLIGHT,0.0,1.0))
	if flowing>0.0:
		loot_peak=flowing
		loot_shown=flowing*progress*progress*(3.0-2.0*progress)
		loot_hold=1.8
	elif loot_peak>0.0:
		if loot_shown<loot_peak:
			loot_shown=loot_peak
			loot_pop=1.0
		loot_hold-=delta
		if loot_hold<=0.0:
			loot_peak=0.0
	loot_pop=maxf(0.0,loot_pop-delta*2.5)
	loot_label.visible=loot_peak>0.0
	if loot_label.visible:
		loot_label.text="+ $"+Catalog.number(loot_shown)
		loot_label.modulate.a=clampf(loot_hold/.5,0.0,1.0)
		loot_label.pivot_offset=Vector2(0,loot_label.size.y*.5)
		loot_label.scale=Vector2.ONE*(1.0+.35*loot_pop+.05*money_pulse)

func toggle_dev_mode() -> void:
	if not OS.is_debug_build():
		return
	dev_mode = not dev_mode
	dev_bar.visible = dev_mode
	if not dev_mode:
		dev_god = false
		dev_god_button.text = TranslationServer.translate("无敌：关")
		sim.ult_unlimited = false
		sim.ult_override = ""
		dev_ult_button.text = TranslationServer.translate("大招冷却：正常")
		dev_ult_kind_button.text = TranslationServer.translate("大招：本章")
		if game_speed not in allowed_speeds():
			game_speed = allowed_speeds().back()
			refresh_speed_button()
	show_notice(TranslationServer.translate("开发者模式：") + (TranslationServer.translate("开启 · 加速可到 ×32") if dev_mode else TranslationServer.translate("关闭")))

func dev_money() -> void:
	if not OS.is_debug_build():
		return
	sim.money = sim.money * 10.0 + 1000.0
	update_hud()

func dev_skip_wave() -> void:
	if not OS.is_debug_build():
		return
	if sim.mode == "wave":
		sim.clear_battle()
		sim.spawn_left = 0

func dev_prev_wave() -> void:
	if not OS.is_debug_build():
		return
	if sim.mode == "boss":
		sim.wave = 10
	elif sim.mode in ["wave","intermission","failed"] and sim.wave > 1:
		sim.wave -= 1
	else:
		show_notice(TranslationServer.translate("已经是本章第一波"))
		return
	sim.start_wave()
	show_notice(TranslationServer.translate("回到第 %d 波") % sim.wave)

func dev_prev_stage() -> void:
	if not OS.is_debug_build():
		return
	if sim.stage <= 0:
		show_notice(TranslationServer.translate("已经是第一章"))
		return
	sim.stage -= 1
	sim.wave = 1
	sim.start_wave()
	field.reset_growth()
	show_notice(TranslationServer.translate("回到") + TranslationServer.translate(sim.stage_data().title))

func dev_kill_boss() -> void:
	if not OS.is_debug_build():
		return
	if sim.mode != "boss":
		show_notice(TranslationServer.translate("当前不是 Boss 战"))
		return
	for e in sim.enemies:
		if bool(e.boss) and not bool(e.dead):
			sim.apply_damage(e, float(e.hp) + 1.0, 1, 0)

func dev_next_stage() -> void:
	if not OS.is_debug_build():
		return
	if sim.stage >= sim.LAST_STAGE:
		show_notice(TranslationServer.translate("已经是最后一章"))
		return
	if sim.mode in ["wave","intermission","boss"]:
		sim.finish_boss()

func dev_toggle_god() -> void:
	if not OS.is_debug_build():
		return
	dev_god = not dev_god
	dev_god_button.text = TranslationServer.translate("无敌：开") if dev_god else TranslationServer.translate("无敌：关")

func dev_toggle_ult() -> void:
	if not OS.is_debug_build():
		return
	sim.ult_unlimited = not sim.ult_unlimited
	if sim.ult_unlimited:
		sim.ult_charge = 1.0
	dev_ult_button.text = TranslationServer.translate("大招冷却：0") if sim.ult_unlimited else TranslationServer.translate("大招冷却：正常")
	update_ult_button()

func dev_cycle_ult_kind() -> void:
	if not OS.is_debug_build():
		return
	# 本章 → 核弹 → 光粒打击 → … → 改写 π → 本章
	var kinds: Array[String] = sim.ULT_KINDS
	var i: int = kinds.find(sim.ult_override)
	sim.ult_override = kinds[i + 1] if i + 1 < kinds.size() else ""
	dev_ult_kind_button.text = TranslationServer.translate("大招：本章") if sim.ult_override == "" else TranslationServer.translate("大招：")+sim.ultimate_name()
	update_ult_button()

func refresh_speed_button() -> void:
	if is_instance_valid(speed_button):
		speed_button.text = TranslationServer.translate("加速 ×%d  [F]") %game_speed
		fit_text(speed_button, 16)

func fit_text(control: Control, px: int) -> void:
	# Fixed-width HUD buttons: longer languages step the font down rather than spill over.
	var room: float = control.size.x - 30
	while px > 11 and font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 1
	control.add_theme_font_size_override("font_size", px)

func save_game() -> void:
	persist_preferences()
	store.save_game(sim,settings_payload())

func play_tone(kind: String) -> void:
	match kind:
		"buy":audio.play("purchase")
		"upgrade":audio.sfx("upgrade",audio.LEVEL.reward,1.0,true)
		"deny":audio.ui("ui_deny")

func advance_frame(delta: float, time_scale: float) -> float:
	# Fixed ticks keep combat deterministic. Under load, yield to rendering and
	# input instead of multiplying a slow frame into ever more catch-up work.
	sim_steps_this_frame = 0
	if sim.paused:
		return 0.0
	# Loot uses real seconds: fast-forward must not erase the collection beat.
	sim.external_reward_clock = true
	sim.update_rewards(delta)
	if time_scale <= 0.0:
		return 0.0
	accumulator = minf(accumulator + minf(delta, .1) * time_scale, SIM_STEP * MAX_SIM_STEPS)
	var deadline: int = Time.get_ticks_usec() + SIM_BUDGET_USEC
	var sim_started: int = Time.get_ticks_usec()
	while accumulator >= SIM_STEP and sim_steps_this_frame < MAX_SIM_STEPS:
		sim.advance(SIM_STEP)
		accumulator -= SIM_STEP
		sim_steps_this_frame += 1
		if Time.get_ticks_usec() >= deadline:
			break
	field.profile_add("sim", sim_started)
	return sim_steps_this_frame * SIM_STEP

func _process(delta: float) -> void:
	var started: int=Time.get_ticks_usec()
	_process_frame(delta)
	field.profile_add("main_process", started)

func _process_frame(delta: float) -> void:
	var started: int=Time.get_ticks_usec()
	if proof and benchmark:
		sim.mode="wave"
		sim.health=100
		sim.spawn_clock=1000
		sim.spawn_left=1
		while sim.enemies.size()<120:
			sim.spawn_enemy(maxi(1,int(sim.stage_data().count_multiplier)/16))
			var actor: Dictionary=sim.enemies.back()
			actor.age=float(actor.lifetime)*(.1+float(int(actor.id)%12)*.04)
	if field.slowmo_request:
		field.slowmo_request=false
		slowmo=.7
	slowmo=maxf(0,slowmo-delta)
	hitstop=maxf(0,hitstop-delta)
	cam_hold=maxf(0,cam_hold-delta)
	update_shatter()
	update_lens()
	update_mandel()
	stage_cinema()
	if sim.ult.is_empty() and cam_hold<=0:
		cam_target=1.0
	cam_zoom=lerpf(cam_zoom,cam_target,1.0-exp(-delta*(2.4 if cam_target>cam_zoom else 4.0)))
	var time_scale: float=0.0 if hitstop>0 else game_speed*(.2 if slowmo>0 else 1.0)
	if is_instance_valid(resume_fx) and resume_fx.active():
		time_scale*=resume_fx.time_gate()
	if dev_god:
		sim.health = 100.0
	var advanced: float = advance_frame(delta, time_scale)
	# Cosmetic rounds and hit feedback follow the ticks actually processed,
	# including when a low-end browser cannot sustain the requested speed.
	var speed: float=advanced / maxf(delta, .000001) if not sim.paused else 1.0
	field.clock += delta*speed
	field.reduced_effects=reduced_effects
	field.animate(delta*speed, delta)
	# Camera punch: a quick zoom kick around the field centre on big moments.
	var kick: float=(1.0+field.punch*field.punch*.035)*cam_zoom
	var pivot: Vector2=Vector2(500,320).lerp(cam_focus,clampf((cam_zoom-1.0)/.12,0,1))
	if camera_comfort: kick = 1.0
	field.scale=Vector2.ONE*field_zoom*kick
	field.position=field_origin+(Vector2.ZERO if camera_comfort else field.shake_offset())-pivot*field_zoom*(kick-1.0)
	audio.cinematic_cut = cinema.ending_active() and cinema.t >= 50.0
	audio.update(sim,delta)
	field.hover = field.to_local(get_global_mouse_position())
	# Preserve combat targeting eligibility while the shared cursor covers all UI.
	var mouse: Vector2 = get_global_mouse_position()
	var over_field: bool = menu=="" and sim.mode in ["wave","boss","intermission"] and mouse.y > 118 and mouse.y < size.y-104
	var hovered_button: Button = UiFx.hovered_button(get_viewport())
	var over_button: bool = ui_motion and hovered_button != null and hovered_button.has_meta("fx") and not hovered_button.disabled
	field.show_reticle = over_field and not over_button
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if proof and "--inspect" in OS.get_cmdline_user_args() and not sim.enemies.is_empty():field.hover=sim.enemies[mini(3,sim.enemies.size()-1)].pos
	field.render_lead = minf(accumulator, SIM_STEP) if not sim.paused else 0.0
	if sim.money<shown_money or sim.money<=0:
		shown_money=sim.money
	elif sim.money>shown_money*1.0001+.5:
		money_pulse=1.0
		shown_money=lerpf(shown_money,sim.money,minf(1,delta*9)) if shown_money<=0 else exp(lerpf(log(shown_money),log(sim.money),minf(1,delta*9)))
	else:
		shown_money=sim.money
	money_pulse=maxf(0,money_pulse-delta*4)
	money_label.text="$ "+Catalog.number(shown_money)
	field.money_anchor=field.to_local(money_label.global_position+Vector2(36,22))
	if field.coin_arrivals>0:
		audio.coins(field.coin_arrivals,field.ult_arrivals)
		money_pulse=maxf(money_pulse,2.6 if field.ult_arrivals>0 else (1.8 if field.coin_arrivals>=8 else .7))
		field.coin_arrivals=0
		field.ult_arrivals=0
	update_rates(delta)
	money_label.pivot_offset=Vector2(0,money_label.size.y*.5)
	money_label.scale=Vector2.ONE*(1+money_pulse*.07)
	money_label.modulate=Color.WHITE.lerp(Color(1.0,.84,.45),clampf(money_pulse*.4,0.0,1.0))
	update_loot_counter(delta)
	ui_timer += delta
	if ui_timer>.1 or display_mode!=sim.mode or display_stage!=sim.stage:
		ui_timer = 0
		update_hud()
		display_mode=sim.mode
		display_stage=sim.stage
	animate_hud(delta)
	refresh_body_card()
	toast_time = maxf(0,toast_time-delta)
	toast.modulate.a = minf(1,toast_time)
	save_timer += delta
	if save_timer>=10 and not sim.paused:
		save_timer = 0
		store.save_game_async(sim,settings_payload())
	# A boss can fall during advance_frame: start its ending before opening results.
	stage_cinema()
	ending_skip.visible = cinema.ending_active() and cinema.t < 50.0
	pointer_frame.suppressed = cinema.ending_active() and cinema.t >= 50.0
	pointer_frame.visible = not pointer_frame.suppressed
	if sim.mode in ["failed","victory"] and menu=="" and not cinema.ending_active():
		show_result()
	field.queue_redraw()
	if proof:
		proof_frame += 1
		if benchmark and proof_frame>60:
			performance_frames.append(delta*1000)
			if proof_frame%30==0:
				print("BENCH_PROGRESS frame=",proof_frame," fps=",Engine.get_frames_per_second()," actors=",sim.enemies.size()," process_ms=",(Time.get_ticks_usec()-started)/1000.0," draw_ms=",field.draw_ms," shots=",sim.shots.size()," bullets=",field.b_age.size())
		if proof_frame==capture_at:
			capture_frame.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if cinema.ending_active():
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			cinema.skip_ending()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:
			var window_mode: int = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if window_mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode==KEY_QUOTELEFT and sim.mode!="title":
			toggle_dev_mode()
		elif event.keycode==KEY_F and menu=="" and sim.mode!="title":
			cycle_speed()
		elif event.keycode==KEY_Q and menu=="" and sim.mode in ["wave","boss"]:
			fire_ultimate_at(field.hover if field.show_reticle else Vector2.INF)
		elif event.keycode==KEY_ESCAPE and is_instance_valid(body_card):
			close_body_card()
		elif event.keycode in [KEY_U,KEY_ESCAPE] and sim.mode!="title" and menu!="title":
			if menu!="":
				close_modal()
			elif event.keycode==KEY_U:
				open_shop()
			else:
				open_pause()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		close_body_card()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			sim.manual_held = false
		elif menu=="" and sim.mode in ["wave","boss"]:
			var point: Vector2 = field.to_local(event.position)
			field.on_click(point)
			var body: int = field.body_at(point)
			if body >= 0:
				open_body_card(body)
				return
			var converted: Vector2i = field.converted_body_at(point)
			if converted.x >= 0:
				open_body_details(converted.x,converted.y)
				return
			close_body_card()
			var selected: int = sim.select_target(point)
			if selected>=0 and not sim.automation:
				sim.manual_held = true
				sim.manual_queued = true

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func parse_proof() -> void:
	if not OS.is_debug_build():
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
			proof = true
		if arg.begins_with("--frames="):
			capture_at = int(arg.trim_prefix("--frames="))
		if arg=="--benchmark":
			benchmark = true
	if not proof:
		return
	if benchmark:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	store.enabled = false
	start_game()
	var idx: int = 0
	var proof_mode: String = "wave"
	for arg in args:
		if arg.begins_with("--stage="):
			idx = clampi(int(arg.trim_prefix("--stage=")),0,sim.LAST_STAGE)
		if arg.begins_with("--mode="):
			proof_mode = arg.trim_prefix("--mode=")
	sim.stage = idx
	sim.wave = 10
	sim.money = 850*pow(24,idx)
	sim.levels.damage = 8+idx*23
	sim.levels.reload = 7+idx*12
	sim.levels.speed = 5+idx*4
	sim.levels.area = idx*4
	sim.levels.pierce = maxi(0,idx-2)*4
	sim.levels.targets = maxi(0,idx-3)*3
	sim.levels.turrets = 6+idx*8
	sim.automation = true
	for i in range(idx+1):
		sim.owned[i] = true
	sim.start_wave()
	toast_time=0
	if proof_mode=="boss":
		sim.start_boss()
		sim.wave_elapsed = 4
	else:
		for i in range(28 if idx>0 else 10):
			sim.spawn_enemy(1 if idx==0 else 5+idx*idx*85)
			var e: Dictionary = sim.enemies.back()
			e.age = e.lifetime*(.1+float(i%10)*.045)
	if proof_mode=="shop":
		open_shop()
	if proof_mode=="pause":
		open_pause()
	if proof_mode=="transition":
		sim.clear_battle()
		sim.mode = "transition"
		sim.mode_time = 2.5
	if proof_mode=="title":
		show_title()
	if "--save-smoke" in args:
		store.path="user://skyguard_export_check.json"
		store.enabled=true
		var written: bool=store.save_game(sim,{"sound":false})
		var restored=Combat.new()
		var data: Dictionary=store.read_game()
		var loaded: bool=restored.restore(data)
		var passed: bool=written and loaded and is_equal_approx(sim.money,restored.money) and sim.enemies.size()==restored.enemies.size() and sim.stage==restored.stage
		print("EXPORT_SAVE_SMOKE ",passed," stage=",restored.stage," enemies=",restored.enemies.size())
		if passed:
			saved=data
			sim.clear_battle()
			sim.mode="title"
			sim.money=0
			continue_game()
			passed=sim.mode==restored.mode and is_equal_approx(sim.money,restored.money) and sim.enemies.size()==restored.enemies.size()
			print("EXPORT_CONTINUE_SMOKE ",passed)
		store.enabled=false
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path+".bak"))
		if not passed:
			get_tree().quit(1)
	field.reset_growth()
	if proof_mode=="wave" and not benchmark:
		for i in range(idx+1):
			if not sim.enemies.is_empty():
				sim.fire_weapon(i,sim.enemies[mini(i*3,sim.enemies.size()-1)])
		for projectile in sim.shots:
			projectile.age=projectile.duration*.42
			projectile.pos=Vector2(projectile.from).lerp(projectile.end,.42)
		for actor in sim.enemies:
			actor.pos=Vector2(actor.start).lerp(actor.end,float(actor.age)/float(actor.lifetime))
		sim.paused=true

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var err: int = picture.save_png(capture_path)
	print("CAPTURE ",capture_path," result=",err," size=",picture.get_size())
	if benchmark and not performance_frames.is_empty():
		performance_frames.sort()
		var total: float = 0
		for ms in performance_frames:
			total += ms
		print("RENDER_BENCH frames=",performance_frames.size()," mean_ms=",total/performance_frames.size()," p95_ms=",performance_frames[int(performance_frames.size()*.95)]," fps=",Engine.get_frames_per_second()," actors=",sim.enemies.size()," shots=",sim.shots.size())
	get_tree().quit()

func _exit_tree() -> void:
	store.finish_pending()
