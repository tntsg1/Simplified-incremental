extends Node
# Steam SDK calls use a dynamic singleton so Web/non-Steam builds remain playable.
const APP_ID := 5427620
const CATALOG: Array = preload("res://assets/achievements/catalog.json").data
const Combat = preload("res://scripts/combat.gd")
const ULTIMATE_ACHIEVEMENTS := {"nuke":"ULT_NUKE","photoid":"ULT_PHOTOID","droplet":"ULT_DROPLET","foil":"ULT_FOIL","fourier":"ULT_FOURIER","prime":"ULT_PRIME","mandelbrot":"ULT_MANDELBROT","lightspeed":"ULT_LIGHTSPEED","pi":"ULT_PI","strings":"ULT_STRINGS"}
var game: Control
var steam: Object
var active := false
var enabled := true
var status := "offline"
var account_id := ""
var progress_path := "user://skyguard_achievements_v1.json"
var unlocked: Dictionary = {}
var pending: Array[String] = []
var in_flight: Array[String] = []
var in_flight_age := 0.0
var elapsed := 0.0
var retry := 0.0
var tainted := false

func setup(owner_game: Control) -> void:
	game = owner_game
	enabled = game.store.enabled and not game.proof and not OS.has_feature("web")
	if not enabled: return
	if OS.has_feature("steam") and DisplayServer.get_name() != "headless" and Engine.has_singleton("Steam") and "--no-steam" not in OS.get_cmdline_user_args():
		steam = Engine.get_singleton("Steam")
		var result: Dictionary = steam.call("steamInitEx",APP_ID,false)
		active = int(result.get("status",-1)) == 0
		if active and int(steam.call("getAppID")) != APP_ID:
			steam.call("steamShutdown")
			active = false
		if active:
			account_id = str(steam.call("getSteamID"))
			if not game.store.select_steam_profile(account_id):
				status = "storage_error"
				steam.call("steamShutdown")
				active = false
			else:
				progress_path = game.store.path.get_base_dir()+"/skyguard_achievements_v1.json"
				steam.connect("user_stats_stored",_on_stats_stored)
				status = "connected"
	if not active and game.store.path != game.store.PATH:
		progress_path = game.store.path.get_base_dir()+"/skyguard_achievements_v1.json"
	load_progress()
	game.sim.ultimate_fired.connect(_on_ultimate_fired)
	game.sim.boss_skill.connect(_on_boss_skill)
	sync_pending()
	if "--steam-diagnostics" in OS.get_cmdline_user_args():
		print("STEAM_FEATURES status=",status," active=",active," pending=",pending.size())
		if active: print("STEAM_FEATURES app=",steam.call("getAppID")," achievements=",steam.call("getNumAchievements"))

func _on_ultimate_fired(kind: String, _point: Vector2) -> void:
	if not can_record() or not ULTIMATE_ACHIEVEMENTS.has(kind): return
	unlock("FIRST_ULTIMATE")
	unlock(ULTIMATE_ACHIEVEMENTS[kind])
	for id in ULTIMATE_ACHIEVEMENTS.values():
		if not unlocked.has(id): return
	unlock("ULT_MASTER")

func _on_boss_skill(event: String, kind: String, _point: Vector2) -> void:
	if not can_record() or event != "broken" or kind not in ["siege_beam","devour"]: return
	unlock("BOSS_BREAK")
	unlock("SIEGE_BREAK" if kind == "siege_beam" else "DEVOUR_BREAK")

func can_record() -> bool:
	if game != null and (game.proof or game.dev_mode): tainted = true
	return enabled and not tainted

func load_progress() -> void:
	for candidate in [progress_path,progress_path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if not data is Dictionary or not data.get("unlocked") is Dictionary or not data.get("pending") is Array: continue
		for item in CATALOG:
			if bool(data.unlocked.get(item.id,false)): unlocked[item.id] = true
		for id in data.pending:
			if unlocked.has(str(id)) and str(id) not in pending: pending.append(str(id))
		return

func persist() -> void:
	if not enabled: return
	var file := FileAccess.open(progress_path+".tmp",FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"pending":pending}))
	file.close()
	if FileAccess.file_exists(progress_path): DirAccess.copy_absolute(progress_path,progress_path+".bak")
	DirAccess.rename_absolute(progress_path+".tmp",progress_path)

func unlock(id: String) -> void:
	if not can_record() or unlocked.has(id): return
	var known := false
	for item in CATALOG:
		if item.id == id: known = true
	if not known: return
	unlocked[id] = true
	pending.append(id)
	persist()
	if game != null:
		for item in CATALOG:
			if item.id == id:
				game.show_notice(game.words("成就解锁：", "Achievement unlocked: ") + game.words(item.name_zh, item.name_en))
	# Queue remains durable until Steam acknowledges StoreStats.
	retry = 29.5

func observe(snapshot: Dictionary) -> void:
	if not can_record() or str(snapshot.get("mode","title")) == "title": return
	if int(snapshot.get("kills",0)) >= 1: unlock("FIRST_INTERCEPT")
	if int(snapshot.get("kills",0)) >= 1000: unlock("THOUSAND_INTERCEPTS")
	if int(snapshot.get("kills",0)) >= 100: unlock("HUNDRED_INTERCEPTS")
	if int(snapshot.get("kills",0)) >= 10000: unlock("TEN_THOUSAND_INTERCEPTS")
	var levels: Dictionary = snapshot.get("levels",{})
	for value in levels.values():
		if int(value)>0: unlock("FIRST_UPGRADE"); break
	if bool(snapshot.get("automation",false)): unlock("AUTOMATED_DEFENSE")
	if int(levels.get("damage",0)) >= 10: unlock("WARHEAD_TEN")
	if int(levels.get("damage",0)) >= 50: unlock("WARHEAD_FIFTY")
	if int(levels.get("turrets",0)) >= 12: unlock("TURRET_RING")
	if int(levels.get("turrets",0)) >= 48: unlock("TURRET_FORTRESS")
	var owned: Array = snapshot.get("owned",[])
	if owned.size() == Combat.STAGE_COUNT and not owned.has(false): unlock("FULL_ARSENAL")
	for value in snapshot.get("bodies",[]):
		if int(value)>0: unlock("FIRST_ORBITAL"); break
	var bodies: Array = snapshot.get("bodies",[])
	var all_bodies := bodies.size() == Combat.BODIES.size()
	for i in range(Combat.BODIES.size()):
		var mask := int(bodies[i]) if i < bodies.size() else 0
		var valid_mask: int = (1 << Combat.BODIES[i].size())-1
		var complete: bool = (mask & valid_mask) == valid_mask
		all_bodies = all_bodies and complete
		if i == 0 and complete: unlock("ROOFTOP_NETWORK")
		if i == 1 and mask & 1: unlock("LUNAR_CANNON")
		if i == 2 and mask & (1 << 4): unlock("DYSON_WEAPON")
		if i == 6 and mask & (1 << 5): unlock("BLACK_HOLE_ENGINE")
		if i == 7 and complete: unlock("CLUSTER_NETWORK")
		if i == 8 and complete: unlock("COSMIC_NETWORK")
		if i == 9 and complete: unlock("BRANE_NETWORK")
	if all_bodies: unlock("ALL_CONVERSIONS")
	var stage := clampi(int(snapshot.get("stage",0)),0,Combat.LAST_STAGE)
	var stages := ["CITY_SAFE","EARTH_SAFE","SOLAR_SAFE","OUTER_SAFE","OORT_SAFE","NEIGHBOR_SAFE","GALAXY_SAFE","CLUSTER_SAFE","COSMOS_SAFE"]
	for i in range(stage): unlock(stages[i])
	if str(snapshot.get("mode","")) == "victory": unlock("LAST_LIGHT")

func sync_pending() -> void:
	if not active or not enabled or not in_flight.is_empty(): return
	if str(steam.call("getSteamID")) != account_id:
		status = "account_changed"
		return
	if int(steam.call("getNumAchievements")) == 0:
		status = "awaiting_configuration"
		return
	status = "connected"
	var changed := false
	for item in CATALOG:
		var info: Dictionary = steam.call("getAchievement",str(item.id))
		if bool(info.get("ret",false)) and bool(info.get("achieved",false)):
			if not unlocked.has(item.id): unlocked[item.id]=true; changed=true
	if changed: persist()
	for id in pending:
		var info: Dictionary = steam.call("getAchievement",id)
		if bool(info.get("ret",false)) and (bool(info.get("achieved",false)) or bool(steam.call("setAchievement",id))): in_flight.append(id)
	if not in_flight.is_empty() and not bool(steam.call("storeStats")):
		in_flight.clear()
	in_flight_age = 0.0

func _on_stats_stored(app_id: int, result: int) -> void:
	if app_id != APP_ID: return
	if str(steam.call("getSteamID")) != account_id:
		status = "account_changed"
		in_flight.clear()
		return
	if result == 1:
		for id in in_flight: pending.erase(id)
		persist()
	in_flight.clear()

func _process(delta: float) -> void:
	if not enabled: return
	if active: steam.call("run_callbacks")
	if not in_flight.is_empty():
		in_flight_age += delta
		if in_flight_age >= 60.0: in_flight.clear()
	elapsed += delta
	retry += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		# Only fields needed by achievements: never clone a dense combat snapshot here.
		if game != null: observe({"mode":game.sim.mode,"kills":game.sim.kills,"levels":game.sim.levels,"automation":game.sim.automation,"bodies":game.sim.bodies,"owned":game.sim.owned,"stage":game.sim.stage})
	if retry >= 30.0:
		retry = 0.0
		sync_pending()

func _exit_tree() -> void:
	persist()
	if active and is_instance_valid(steam):
		if steam.is_connected("user_stats_stored",_on_stats_stored): steam.disconnect("user_stats_stored",_on_stats_stored)
		steam.call("steamShutdown")
