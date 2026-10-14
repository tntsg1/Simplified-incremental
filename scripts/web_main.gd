extends "res://scripts/main.gd"

# Web-only entry. The native game and its save file keep their existing behavior.
var web_bridge: JavaScriptObject
var web_timer: float = 0.0
var web_home: bool = true

func _ready() -> void:
	super._ready()
	web_bridge = JavaScriptBridge.get_interface("SkyguardBridge")
	if web_bridge != null:
		web_bridge.ready()

func web_save() -> void:
	if sim.mode != "title":
		web_bridge.save(JSON.stringify(store.build(sim, settings_payload())))

func apply_language(value: String, rebuild: bool = true) -> void:
	super.apply_language(value, rebuild)
	if web_bridge != null:
		web_bridge.language(language)

func _process(delta: float) -> void:
	if web_bridge == null:
		super._process(delta)
		return
	var command: Variant = web_bridge.take()
	if command != null:
		var data: Variant = JSON.parse_string(str(command))
		if data is Dictionary:
			var prefs: Dictionary = data.get("settings", {})
			sound_on = bool(prefs.get("sound", true))
			audio.music_level = clampf(float(prefs.get("music_level", .55)), 0, 1)
			audio.effects_level = clampf(float(prefs.get("effects_level", .65)), 0, 1)
			reduced_effects = bool(prefs.get("reduced_effects", false))
			ui_motion = bool(prefs.get("ui_motion", ui_motion))
			if prefs.has("language") and str(prefs.language) != language:
				apply_language(str(prefs.language))
			audio.set_enabled(sound_on)
			match str(data.get("action", "")):
				"new":
					start_game()
					web_home = false
					web_bridge.started()
				"continue":
					var payload: Variant = JSON.parse_string(str(data.get("save", "")))
					if payload is Dictionary:
						saved = payload
						continue_game()
						web_home = false
						web_bridge.started()
				"home":
					web_save()
					sim.paused = true
					show_title()
				"settings":
					if not web_home:
						web_save()
	if not web_home and menu == "title":
		web_save()
		web_home = true
		web_bridge.home()
	if web_home:
		return
	super._process(delta)
	# Read-only presentation state lets the host verify cinematic timing without
	# guessing from the campaign's five-second save interval.
	web_bridge.cinematic_time = cinema.t
	web_bridge.cinematic_kind = cinema.kind
	web_bridge.game_menu = menu
	web_bridge.game_mode = sim.mode
	web_bridge.game_stage = sim.stage
	web_bridge.phase_time = sim.mode_time
	web_bridge.render_ms = field.draw_ms
	web_bridge.game_language = language
	web_bridge.hud_stage_text = stage_label.text
	web_bridge.hud_wave_text = wave_label.text
	web_bridge.hud_hint_text = hint.text
	if is_instance_valid(language_button) and language_button.is_visible_in_tree():
		var rect: Rect2 = language_button.get_global_rect()
		var screen_center: Vector2 = get_viewport().get_final_transform() * rect.get_center()
		web_bridge.language_button_x = screen_center.x
		web_bridge.language_button_y = screen_center.y
		web_bridge.language_button_visible = true
	else:
		web_bridge.language_button_visible = false
	web_bridge.ultimate_kind = str(sim.ult.get("kind", ""))
	web_bridge.ultimate_age = float(sim.ult.get("age", -1.0))
	web_timer += delta
	if web_timer >= 5.0:
		web_timer = 0.0
		web_save()
