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
	web_timer += delta
	if web_timer >= 5.0:
		web_timer = 0.0
		web_save()
