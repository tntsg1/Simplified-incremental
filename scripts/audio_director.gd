extends Node

# Designed effects (tools/sfx_design.py): key -> number of variants.
const SFX: Dictionary = preload("res://assets/audio/sfx/sfx_manifest.json").data
# Per-role mix levels (dB on top of the files' own loudness targets).
const LEVEL := {"ult": -5.0, "ult_event": -9.0, "boss": -5.0, "flow": -5.0, "body": -12.0, "fire": -9.0, "fire_side": -15.0, "turret": -17.0, "hit": -13.0, "kill": -10.0, "kill_big": -6.0, "coin": -11.0, "ui": -6.0, "reward": -6.0}
# Pentatonic steps for sounds that climb (Fourier notes, prime beats).
const PENTA: Array[int]=[0,2,4,7,9]
# How many copies of one sound may ring at once.
const CAP := {"turret": 2, "coin": 3, "ui_click": 2}
# Local music trial: keep the original title theme, use the selected recordings
# for chapter ambience, boss combat, enrage and the scale transition.
const TRACKS: Array[String]=["music/ch01_city","music/solar_wind","music/solar_wind","music/dockside","music/dockside","music/dockside","music/glass","music/glass","music/dockside","music/glass"]
var voices: Array[AudioStreamPlayer]=[]
var priority_voices: Array[AudioStreamPlayer]=[]
var priority_cursor: int=0
var voice_cursor: int=0
var music: Array[AudioStreamPlayer]=[]
var tension: AudioStreamPlayer
var current_track: int=-1
var current_music_key: String=""
var active_music: int=1
var music_gains: Array[float]=[0.0,0.0]
var music_resume: Dictionary={}
var streams: Dictionary={}
var fire_limits: Array[float]=[0,0,0,0,0,0,0,0,0,0]
var hit_limits: Array[float]=[0,0,0,0,0,0,0,0,0,0]
var hit_limit: float=0
var event_limits: Dictionary={}
var material_limit: float=0
var destruction_limit: float=0
var big_limit: float=0
var turret_limit: float=0
var coin_limit: float=0
var coin_streak: int=0
var coin_quiet: float=0
var ult_stream: int=0
# Recent-sound pressure: the busier the field, the further each new sound sits back.
var pressure: float=0
var last_variant: Dictionary={}
# How many times each designed sound actually started (diagnostics and tests).
var played: Dictionary={}
var last_voice: AudioStreamPlayer
var sim_ref: RefCounted
# While an ultimate plays it owns the mix: everything else steps back.
var ult_duck: float=0.0
var ult_voice: AudioStreamPlayer
var focus_weapon: int=0
var enabled: bool=true
var stage_index: int=0
var last_mode: String=""
var alarm_second: int=-1
var random:=RandomNumberGenerator.new()
var music_level: float=.55
var effects_level: float=.65
var cinematic_cut: bool=false

func _exit_tree() -> void:
	for player in voices+priority_voices+music:
		player.stop()
		player.stream=null
	if is_instance_valid(tension):
		tension.stop()
		tension.stream=null
	streams.clear()

func _ready() -> void:
	random.seed=7823
	for bus in ["Skyguard Mix","Skyguard Music","Skyguard SFX"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master" if bus=="Skyguard Mix" else "Skyguard Mix")
	# The buses live in default_bus_layout.tres: the web build's sample playback only
	# mirrors buses that exist at startup (runtime-added ones played nothing in browsers).
	# Web ignores bus effects, so the missing limiter is offset by a little master headroom.
	if OS.has_feature("web"):
		AudioServer.set_bus_volume_db(0,-3.0)
	var master: int=AudioServer.get_bus_index("Skyguard Mix")
	# Gain follows the quiet calibrated source clips; the limiter stays last.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Skyguard Music"),5)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Skyguard SFX"),0)
	if AudioServer.get_bus_effect_count(master)==0:
		var limiter:=AudioEffectLimiter.new()
		limiter.threshold_db=-8
		limiter.ceiling_db=-5
		AudioServer.add_bus_effect(master,limiter)
	for i in range(32):
		var player:=AudioStreamPlayer.new()
		player.bus="Skyguard SFX"
		add_child(player)
		voices.append(player)
	for i in range(8):
		var player:=AudioStreamPlayer.new()
		player.bus="Skyguard SFX"
		add_child(player)
		priority_voices.append(player)
	for i in range(2):
		var player:=AudioStreamPlayer.new()
		player.bus="Skyguard Music"
		player.volume_db=-60
		add_child(player)
		music.append(player)
	tension=AudioStreamPlayer.new()
	tension.bus="Skyguard Music"
	tension.stream=get_stream("boss_pulse")
	tension.stream.loop=true
	tension.volume_db=-50
	add_child(tension)
	# Every button anywhere in the game clicks (no hover sound, by request).
	get_tree().node_added.connect(hook_button)

func hook_button(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func(): sfx("ui_click",LEVEL.ui))

func get_stream(key: String) -> AudioStream:
	if not streams.has(key):
		streams[key]=load("res://assets/audio/"+key+".ogg")
	return streams[key]

func prepare_stage(index: int) -> void:
	if index in range(TRACKS.size()):
		get_stream(TRACKS[index])

func set_enabled(value: bool) -> void:
	enabled=value
	for bus in ["Skyguard Music","Skyguard SFX"]:
		var level: float=music_level if bus=="Skyguard Music" else effects_level
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),not value or level<=0)

func play(key: String, volume: float=-10, pitch: float=1.0, vary: bool=false, important: bool=false) -> void:
	# Progression cues now come from the designed set; the old procedural alarm,
	# victory and failure stingers stay silent until their replacements land.
	match key:
		"purchase":sfx("purchase",LEVEL.reward,1.0,true)
		"milestone":sfx("milestone",LEVEL.reward,1.0,true)
		"wave_clear":sfx("wave_clear",LEVEL.reward,1.0,true)

func sfx(key: String, volume: float=0.0, pitch: float=1.0, important: bool=false) -> void:
	if not enabled or effects_level<=0 or not SFX.has(key):
		return
	var same: int=0
	for player in voices:
		if player.playing and player.get_meta("key","")==key:same+=1
	if same>=int(CAP.get(key,3)) and not important:
		return
	var count: int=int(SFX[key])
	var pick: int=random.randi()%count
	if count>1 and pick==int(last_variant.get(key,-1)):
		pick=(pick+1)%count
	last_variant[key]=pick
	var voice: AudioStreamPlayer
	if important:
		voice=priority_voices[priority_cursor]
		priority_cursor=(priority_cursor+1)%priority_voices.size()
	else:
		voice=voices[voice_cursor]
		voice_cursor=(voice_cursor+1)%voices.size()
	# Dense fights duck each new sound a little, never the important ones.
	# Coins duck with a crowded fight like everything else, but not under an ultimate:
	# the loot stream that follows it is the payoff.
	var duck: float=0.0 if important else -minf(9.0,3.0*log(1.0+pressure/3.0)/log(2.0))+(0.0 if key=="coin" else ult_duck)
	pressure+=1.0
	voice.stop()
	voice.stream=get_stream("sfx/"+key+"_"+str(pick))
	voice.volume_db=volume+duck+linear_to_db(maxf(.01,effects_level))
	voice.pitch_scale=pitch*(1.0 if key=="coin" else random.randf_range(.97,1.03))
	voice.set_meta("key",key)
	voice.play()
	played[key]=int(played.get(key,0))+1
	last_voice=voice

func fire(index: int, _point: Vector2, _end: Vector2, _critical: bool) -> void:
	if index<0 or index>=fire_limits.size() or fire_limits[index]>0:
		return
	var focus: bool=index==focus_weapon
	# The pulsar lighthouse fires in fours: its beat must survive the limiter.
	fire_limits[index]=(.075 if index==6 else .11) if focus else .34
	sfx("w%d_fire" %index,LEVEL.fire if focus else LEVEL.fire_side)

func turret(_slot: int, _origin: Vector2, _end: Vector2, _critical: bool) -> void:
	if turret_limit>0:
		return
	turret_limit=.12
	sfx("turret",LEVEL.turret)

func impact(_point: Vector2, index: int, _amount: float, critical: bool, boss: bool, kind: String) -> void:
	if hit_limit>0 or ult_duck<-6.0:
		return
	var key: String
	var source: String=str(sim_ref.landing_source) if sim_ref!=null else "main"
	if source=="main" and index>=0 and index<hit_limits.size():
		if hit_limits[index]>0:
			return
		hit_limits[index]=.08
		key="w%d_hit" %index
	else:
		# Turret and body rounds land as plain material knocks, kept sparse.
		if material_limit>0:
			return
		material_limit=.14
		var mat: String=str(sim_ref.event_mat) if sim_ref!=null else ("metal" if kind.contains("ship") else "rock")
		key={"metal":"hit_ship","energy":"hit_energy","exotic":"hit_exotic"}.get(mat,"hit_rock")
	hit_limit=.035
	sfx(key,LEVEL.hit+(2.0 if critical or boss else 0.0),.94 if critical else 1.0)

func destruction(_point: Vector2, _index: int, members: int, boss: bool, kind: String) -> void:
	if boss:
		sfx("boss_death",LEVEL.boss,1.0,true)
	elif ult_duck<-6.0:
		# Kills inside an ultimate are carried by the ultimate's own sound.
		return
	elif kind.contains("elite") or kind=="heavy" or members>=20:
		if big_limit<=0:
			big_limit=.25
			sfx("kill_big",LEVEL.kill_big)
	elif ult_duck<-6.0:
		return
	elif destruction_limit<=0:
		destruction_limit=.05
		var mat: String=str(sim_ref.event_mat) if sim_ref!=null else "rock"
		sfx({"metal":"kill_metal","energy":"kill_energy","exotic":"kill_exotic"}.get(mat,"kill"),LEVEL.kill)

func coins(count: int, ult_count: int=0) -> void:
	# Loot landing in the wallet. Ordinary coins climb a little in pitch and reset; an ultimate's
	# stream rings up a pentatonic arpeggio over an octave and a half, and lands on a jackpot.
	if count<=0:
		return
	ult_stream+=ult_count
	if coin_limit>0:
		return
	coin_limit=.045
	coin_quiet=0.0
	coin_streak+=1
	if ult_count>0:
		sfx("coin",LEVEL.coin,.8*scale_pitch(coin_streak%8))
	else:
		sfx("coin",LEVEL.coin,1.0+minf(.3,coin_streak*.012))

func ultimate(kind: String, _point: Vector2) -> void:
	if SFX.has("ult_"+kind):
		sfx("ult_"+kind,LEVEL.ult,1.0,true)
		ult_voice=last_voice

func ultimate_impact(kind: String, _point: Vector2) -> void:
	# The blast cuts the launch dead: silence-then-boom, in sync at any game speed.
	if not SFX.has("ult_"+kind+"_boom"):
		return
	if is_instance_valid(ult_voice) and ult_voice.playing and str(ult_voice.get_meta("key",""))=="ult_"+kind:
		ult_voice.stop()
	sfx("ult_"+kind+"_boom",LEVEL.ult,1.0,true)

func limited(key: String, gap: float) -> bool:
	# True when `key` played less than `gap` seconds ago (per-key rate limit).
	if float(event_limits.get(key,0.0))>0.0:
		return true
	event_limits[key]=gap
	return false

func scale_pitch(step: int) -> float:
	return pow(2.0,(PENTA[step%5]+12*(step/5))/12.0)

func droplet_arrive(_point: Vector2) -> void:
	sfx("drop_arrive",LEVEL.ult,1.0,true)

func droplet_shatter(_point: Vector2, _radius: float, _pieces: int, boss: bool) -> void:
	if boss or not limited("drop_shatter",.035):
		sfx("drop_shatter",LEVEL.ult_event+(3.0 if boss else 0.0),.8 if boss else 1.0,true)

func flattened(_point: Vector2, _radius: float, _sides: int, _heading: float, _members: int) -> void:
	if not limited("foil_flatten",.05):
		sfx("foil_flatten",LEVEL.ult_event,1.0,true)

func fourier_hit(_point: Vector2, index: int, total: int) -> void:
	# The pen climbs two octaves of a pentatonic scale over the whole tour.
	if limited("fourier_note",.05):
		return
	var step: int=int(10.0*index/maxf(1.0,total))
	sfx("fourier_note",LEVEL.ult_event,scale_pitch(step),true)

func prime_strike(prime: int, _points: PackedVector2Array) -> void:
	var step: int=maxi(0,[2,3,5,7,11,13,17,19,23,29].find(prime))
	sfx("prime_beat",LEVEL.ult_event+(4.0 if step==9 else float(step)*.3),scale_pitch(step)*.5,true)
	if step==9:
		# The tenth prime crowns the run with the full chord.
		sfx("prime_finale",LEVEL.ult,1.0,true)

func boss_skill(event: String, kind: String, _point: Vector2) -> void:
	match event:
		"windup":sfx("boss_windup",LEVEL.boss,1.0,true)
		"fire":sfx("boss_"+kind,LEVEL.boss,1.0,true)
		"broken":sfx("boss_broken",LEVEL.boss,1.0,true)
		"enrage":sfx("boss_enrage",LEVEL.boss,1.0,true)

func boss_launched(_point: Vector2, _count: int) -> void:
	if not limited("boss_escort",.4):
		sfx("boss_escort",LEVEL.boss-4.0)

func deflected(_point: Vector2, _heading: Vector2, _turned: float) -> void:
	if not limited("deflect",.15):
		sfx("deflect",LEVEL.hit)

func body_strike(kind: String, _stage: int, _slot: int, _origin: Vector2, _end: Vector2, _points: PackedVector2Array, _critical: bool) -> void:
	if limited("body",.12) or limited("body_"+kind,.3):
		return
	sfx("body_"+kind,LEVEL.body)

func shell_burst(_point: Vector2, _radius: float, _stage: int, _critical: bool) -> void:
	if not limited("body_shell",.14):
		sfx("body_shell",LEVEL.body)

func shield_broken(_point: Vector2, _radius: float) -> void:
	if ult_duck<-6.0:
		return
	if not limited("shield_break",.12):
		sfx("shield_break",LEVEL.kill)

func enemy_split(_point: Vector2, _pieces: int) -> void:
	if not limited("enemy_split",.1):
		sfx("enemy_split",LEVEL.kill)

func minion_launched(_point: Vector2) -> void:
	if not limited("minion_launch",.25):
		sfx("minion_launch",LEVEL.kill-3.0)

func ui(key: String) -> void:
	sfx(key,LEVEL.ui,1.0,true)

func music_cue(sim: RefCounted) -> String:
	if sim.mode == "title":
		return "bgm_main"
	if sim.mode == "transition":
		return "music/scale_jump"
	if sim.mode == "boss":
		return "music/boss_fury" if sim.enraged else "music/boss_tactical"
	if sim.mode in ["failed", "victory"] and current_music_key != "":
		return current_music_key
	return TRACKS[clampi(sim.stage,0,TRACKS.size()-1)]

func update_music(sim: RefCounted, delta: float) -> void:
	current_track = sim.stage
	var key: String = music_cue(sim)
	if key != current_music_key:
		active_music = 1 - active_music
		var player: AudioStreamPlayer = music[active_music]
		if player.playing:
			music_resume[player.stream.resource_path] = player.get_playback_position()
		player.stop()
		player.stream = get_stream(key)
		player.stream.loop = key != "music/scale_jump"
		music_gains[active_music] = 0.0
		player.volume_db = -80.0
		var resume: float = float(music_resume.get(player.stream.resource_path,0.0)) if key in TRACKS or key == "bgm_main" else 0.0
		player.play(resume)
		current_music_key = key
	# Linear-amplitude crossfades avoid a dip through inaudible dB values.
	var level: float = -16.0 + ult_duck * .5
	if sim.paused or sim.mode == "failed":
		level -= 7.0
	for i in range(music.size()):
		music_gains[i] = move_toward(music_gains[i],1.0 if i == active_music else 0.0,delta / 1.2)
		music[i].volume_db = level + linear_to_db(maxf(.0001,music_gains[i] * music_level))
		if i != active_music and music_gains[i] <= 0.0 and music[i].playing:
			music_resume[music[i].stream.resource_path] = music[i].get_playback_position()
			music[i].stop()

func update(sim: RefCounted, delta: float) -> void:
	if not enabled:return
	if cinematic_cut:
		for player in music:
			player.volume_db = -80.0
		tension.volume_db = -80.0
		return
	for i in range(fire_limits.size()):
		fire_limits[i]=maxf(0,fire_limits[i]-delta)
		hit_limits[i]=maxf(0,hit_limits[i]-delta)
	hit_limit=maxf(0,hit_limit-delta)
	material_limit=maxf(0,material_limit-delta)
	for key in event_limits.keys():
		event_limits[key]=float(event_limits[key])-delta
	destruction_limit=maxf(0,destruction_limit-delta)
	big_limit=maxf(0,big_limit-delta)
	turret_limit=maxf(0,turret_limit-delta)
	coin_limit=maxf(0,coin_limit-delta)
	pressure*=pow(.06,delta)
	var ult_on: bool=sim.ult is Dictionary and not sim.ult.is_empty()
	ult_duck=move_toward(ult_duck,-14.0 if ult_on else 0.0,delta*(60.0 if ult_on else 10.0))
	coin_quiet+=delta
	if coin_quiet>.3 and ult_stream>=20:
		sfx("coin_jackpot",LEVEL.reward-2.0,1.0,true)
		ult_stream=0
	if coin_quiet>.6:
		coin_streak=0
		ult_stream=0
	stage_index=sim.stage
	sim_ref=sim
	for i in range(sim.LAST_STAGE,-1,-1):
		if sim.owned[i]:
			focus_weapon=i
			break
	update_music(sim,delta)
	# Boss pulse is intentionally silent; retain the chapter's background music.
	var tension_target: float=(-29+linear_to_db(maxf(.001,music_level))) if sim.mode=="boss" and not sim.paused else -60
	tension.volume_db=move_toward(tension.volume_db,tension_target,delta*25)
	if sim.mode!="boss" and tension.volume_db<=-59:tension.stop()
	if sim.mode!=last_mode:
		match sim.mode:
			"boss":sfx("boss_alarm",LEVEL.boss,1.0,true)
			"intermission":play("wave_clear")
			"transition":sfx("jump",LEVEL.flow,1.0,true)
			"victory":sfx("victory",LEVEL.flow,1.0,true)
			"failed":sfx("failed",LEVEL.flow,1.0,true)
		last_mode=sim.mode
	if sim.mode=="boss" and not sim.paused and sim.boss_remaining<10:
		var second: int=ceili(sim.boss_remaining)
		if second!=alarm_second:
			alarm_second=second
			sfx("boss_tick",LEVEL.boss-6.0,1.0,true)
