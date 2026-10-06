extends Node

const WEAPON_SOUNDS: Array[String]=["clean_fire_0","clean_fire_1","clean_fire_2","clean_fire_3","clean_fire_4","clean_fire_5"]
var voices: Array[AudioStreamPlayer]=[]
var priority_voices: Array[AudioStreamPlayer]=[]
var priority_cursor: int=0
var voice_cursor: int=0
var music: Array[AudioStreamPlayer]=[]
var tension: AudioStreamPlayer
var current_track: int=-1
var streams: Dictionary={}
var fire_limits: Array[float]=[0,0,0,0,0,0]
var hit_limit: float=0
var destruction_limit: float=0
var fire_gap: float=0
var focus_weapon: int=0
var enabled: bool=true
var stage_index: int=0
var last_mode: String=""
var alarm_second: int=-1
var random:=RandomNumberGenerator.new()
var music_level: float=.55
var effects_level: float=.65

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
	var master: int=AudioServer.get_bus_index("Skyguard Mix")
	# Gain follows the quiet calibrated source clips; the limiter stays last.
	for bus in ["Skyguard Music","Skyguard SFX"]:AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),5)
	if AudioServer.get_bus_effect_count(master)==0:
		var limiter:=AudioEffectLimiter.new()
		limiter.threshold_db=-8
		limiter.ceiling_db=-5
		AudioServer.add_bus_effect(master,limiter)
	for i in range(24):
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

func get_stream(key: String) -> AudioStream:
	if not streams.has(key):
		streams[key]=load("res://assets/audio/"+key+".ogg")
	return streams[key]

func set_enabled(value: bool) -> void:
	enabled=value
	for bus in ["Skyguard Music","Skyguard SFX"]:
		var level: float=music_level if bus=="Skyguard Music" else effects_level
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),not value or level<=0)

func play(key: String, volume: float=-10, pitch: float=1.0, vary: bool=false, important: bool=false) -> void:
	# Keep purchases and progression cues; repetitive combat/alarm effects are silent.
	if key not in ["purchase", "milestone", "wave_clear"]:
		return
	if not enabled or effects_level<=0:
		return
	if not important:
		var active: int=0
		for player in voices:
			if player.playing:active+=1
		if active>=5:return
	var voice: AudioStreamPlayer=voices[voice_cursor]
	voice_cursor=(voice_cursor+1)%voices.size()
	if important:
		voice=priority_voices[priority_cursor]
		priority_cursor=(priority_cursor+1)%priority_voices.size()
	voice.stop()
	voice.stream=get_stream(key)
	voice.volume_db=volume+linear_to_db(maxf(.01,effects_level))
	voice.pitch_scale=pitch*random.randf_range(.94,1.06) if vary else pitch
	voice.play()

func fire(index: int, _point: Vector2, _end: Vector2, _critical: bool) -> void:
	if fire_limits[index]>0 or fire_gap>0:
		return
	fire_limits[index]=.72 if index==focus_weapon else 2.4
	fire_gap=.22
	play(WEAPON_SOUNDS[index],-18 if index==focus_weapon else -24,1.0,true)

func impact(_point: Vector2, index: int, _amount: float, critical: bool, boss: bool, kind: String) -> void:
	if hit_limit>0:
		return
	hit_limit=.28 if not boss else .42
	play("clean_hit_ship" if kind.contains("ship") else "clean_hit_rock",-23 if not critical else -21,1.02-index*.015,true)

func destruction(_point: Vector2, _index: int, members: int, boss: bool, kind: String) -> void:
	if boss:
		play("clean_boss",-13,1,false,true)
	elif destruction_limit<=0:
		destruction_limit=.75
		play("clean_elite" if kind.contains("elite") or kind=="heavy" else "clean_destroy",-20,1.0,true)

func update(sim: RefCounted, delta: float) -> void:
	if not enabled:return
	for i in range(6):
		fire_limits[i]=maxf(0,fire_limits[i]-delta)
	hit_limit=maxf(0,hit_limit-delta)
	destruction_limit=maxf(0,destruction_limit-delta)
	fire_gap=maxf(0,fire_gap-delta)
	stage_index=sim.stage
	for i in range(5,-1,-1):
		if sim.owned[i]:
			focus_weapon=i
			break
	if current_track!=sim.stage:
		current_track=sim.stage
		var player: AudioStreamPlayer=music[sim.stage%2]
		player.stream=get_stream("music_"+str(sim.stage))
		player.stream.loop=true
		player.volume_db=-55
		player.play()
	var target_db: float=-16 if sim.mode!="boss" else -21
	if sim.paused:target_db-=7
	for i in range(2):
		var desired: float=target_db if i==sim.stage%2 else -60
		desired+=linear_to_db(maxf(.01,music_level))
		music[i].volume_db=move_toward(music[i].volume_db,desired,delta*18)
		if desired<=-60 and music[i].volume_db<=-59:music[i].stop()
	# Boss pulse is intentionally silent; retain the chapter's background music.
	var tension_target: float=(-29+linear_to_db(maxf(.001,music_level))) if sim.mode=="boss" and not sim.paused else -60
	tension.volume_db=move_toward(tension.volume_db,tension_target,delta*25)
	if sim.mode!="boss" and tension.volume_db<=-59:tension.stop()
	if sim.mode!=last_mode:
		match sim.mode:
			"boss":play("alarm",-18,.8,false,true)
			"intermission":play("wave_clear",-15)
			"transition":play("milestone",-15,.85,false,true)
			"victory":play("victory",-13,1,false,true)
			"failed":play("failed",-15,1,false,true)
		last_mode=sim.mode
	if sim.mode=="boss" and not sim.paused and sim.boss_remaining<10:
		var second: int=ceili(sim.boss_remaining)
		if second!=alarm_second:
			alarm_second=second
			play("alarm",-22,1.0,false,true)
