extends RefCounted
const Guidance = preload("res://scripts/projectile_guidance.gd")

signal members_removed(point: Vector2, weapon: int, members: int, kind: String)
signal pierced(origin: Vector2, destination: Vector2, weapon: int)

signal notice(message: String)
signal checkpoint
signal stage_entered
signal fired(index: int, origin: Vector2, destination: Vector2, critical: bool)
signal turret_fired(slot: int, origin: Vector2, destination: Vector2, critical: bool)
signal body_fired(body_stage: int, slot: int, origin: Vector2, destination: Vector2, critical: bool)
signal body_converted(body_stage: int, slot: int)
signal shell_burst(point: Vector2, radius: float, body_stage: int, critical: bool)
# Instant body attacks (beam / rail / chain / ring): the visual gets every point it touched.
signal body_strike(kind: String, body_stage: int, slot: int, origin: Vector2, destination: Vector2, points: PackedVector2Array, critical: bool)
signal ultimate_fired(kind: String, point: Vector2)
signal ultimate_impact(kind: String, point: Vector2)
signal prime_strike(prime: int, points: PackedVector2Array)
signal flattened(point: Vector2, radius: float, sides: int, heading: float, members: int)
signal ultimate_loot(point: Vector2, members: int, flight: float)
# New doomsday weapons report their real geometry so the visuals follow the sim.
signal droplet_pass(points: PackedVector2Array)
signal droplet_shatter(point: Vector2, radius: float, pieces: int, boss: bool)
signal droplet_arrive(point: Vector2)
# Fourier: the tour through every frozen threat (core first) and each hit along it.
signal fourier_tour(points: PackedVector2Array, fractions: PackedFloat32Array)
signal fourier_hit(point: Vector2, index: int, total: int)
signal string_snap(points: PackedVector2Array)
# Chapter weapons with their own attack geometry report what they touched.
signal weapon_strike(kind: String, index: int, origin: Vector2, destination: Vector2, points: PackedVector2Array, critical: bool)
signal retargeted(old_target: int, new_target: int)
signal focused(target_id: int)
signal hit(point: Vector2, weapon: int, amount: float, critical: bool, boss: bool, kind: String)
signal destroyed(point: Vector2, weapon: int, members: int, boss: bool, kind: String)
signal shield_broken(point: Vector2, radius: float)
signal enemy_split(point: Vector2, pieces: int)
signal minion_launched(point: Vector2)
signal arch_introduced(arch: String, title: String, id: int)

const Growth = preload("res://scripts/growth.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Catalog = preload("res://scripts/catalog.gd")
# Rewards grow slower than enemy HP, so upgrades must outpace each wave (sawtooth growth).
const REWARD_HP_EXPONENT: float = 0.4
# Turrets are real shooters: each fires on its own staggered beat. Together they
# deal 5% of the whole arsenal's firepower per turret bought.
# Rounds fly at one fixed, fast speed (the old speed upgrade added nothing real).
const PROJECTILE_SPEED: float = 850.0
const TURRET_PERIOD: float = 0.25
const TURRET_SLOTS: int = 48
const TURRET_RINGS: Array[int] = [12, 16, 20]
# Celestial conversion: bodies drawn in each scale's scene can be clicked and
# turned into weapons. Each converted body fires on its own beat for a fixed
# share of the arsenal and keeps firing (from orbit round the core) in later scales.
const BODY_PERIOD: float = 0.4
const BODY_SHARE: float = 0.12
const BODY_PRICE_GROWTH: float = 2.2
# Celestial cannons lob slow heavy shells that burst over a whole area —
# their job is suppression: every threat in the blast takes the hit.
const BODY_SPEED: float = 520.0
const BODY_SPLASH: float = 95.0
const BODY_SPLASH_SHARE: float = 0.6
const BODY_SPLASH_LIMIT: int = 24
# Every celestial cannon has its own way of attacking. Slow, heavy attacks fire
# on fewer beats with the damage of the skipped beats folded in.
const ATTACK_EVERY: Dictionary = {"shell": 1, "swarm": 2, "beam": 1, "rail": 2, "chain": 1, "cluster": 2, "gravity": 5, "ring": 3, "wave": 2, "quake": 3, "meteor": 3, "prism": 2}
const SWARM_SPEED: float = 620.0
const SWARM_COUNT: int = 5
# Doomsday weapons, one per scale. Charged by time and by kills, fired by hand.
const ULT_KINDS: Array[String] = ["nuke", "photoid", "droplet", "foil", "fourier", "prime", "mandelbrot", "lightspeed", "pi", "strings"]
const ULT_NAMES: Array[String] = ["核弹", "光粒打击", "水滴", "一向箔", "傅里叶分解", "质数打击", "曼德博分形", "降低光速", "改写 π", "维度震荡"]
const ULT_TIME: float = 55.0
const ULT_PER_KILL: float = 0.0016
const ULT_KILL_RATE_CAP: float = 0.03
const ULT_BOSS_SHARE: float = 0.2
# Each weapon has a readable wind-up before it lands (impact times below).
const ULT_DURATION: Dictionary = {"nuke": 3.8, "photoid": 3.8, "droplet": 5.4, "foil": 6.6, "fourier": 6.8, "prime": 4.4, "mandelbrot": 5.6, "lightspeed": 7.4, "pi": 4.2, "strings": 6.6}
const NUKE_IMPACT: float = 1.5
const PHOTOID_IMPACT: float = 2.2
const PI_IMPACT: float = 2.0
const LIGHT_DOMAIN_SEAL: float = 4.6
const LIGHTSPEED_IMPACT: float = 6.0
# One-vector foil: a square sheet that opens slowly once the card has settled.
const FOIL_OPEN: float = 1.8
const FOIL_GROW: float = 3.4
const PRIMES: Array[int] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
const NUKE_RADIUS: float = 300.0
# Droplet: in a single instant it threads every threat on the field, time holds
# for a heartbeat, then everything it passed through shatters into small bodies.
const DROPLET_PASS: float = 1.15
# The pass itself is visible: the drop tears through every stop in TRAVEL seconds,
# everything hangs for DROPLET_HOLD, then the stops detonate in path order.
const DROPLET_HOLD: float = 0.35
const DROPLET_CASCADE: float = 0.35
const DROPLET_SHATTER: float = 1.6
const DROPLET_FRAGMENT_CAP: int = 150
const FRAGMENT_REWARD: float = 0.3
# Enemy archetypes: one behaviour each, re-skinned per scale (ROSTER).
const ARCHES: Array[String] = ["swarm", "dart", "armored", "splitter", "shielded", "mother"]
const ARCH_HP: Dictionary = {"swarm": 1.0, "dart": 0.7, "armored": 1.8, "splitter": 0.8, "shielded": 1.0, "mother": 2.0}
# HP an archetype brings beyond its body: split children, shield, launched minions.
const ARCH_EXTRA: Dictionary = {"swarm": 0.0, "dart": 0.0, "armored": 0.0, "splitter": 0.35, "shielded": 0.5, "mother": 0.4}
const ARCH_LIFE: Dictionary = {"swarm": 1.0, "dart": 0.5, "armored": 1.55, "splitter": 1.0, "shielded": 1.05, "mother": 1.5}
const SPECIAL_SHARE: Array[float] = [0.25, 0.25, 0.25, 0.35, 0.35, 0.35, 0.45, 0.45, 0.45, 0.45]
const CHILD_REWARD: float = 0.5
const MOTHER_GAP: float = 3.0
const MOTHER_LAUNCHES: int = 4
# Per chapter: archetype -> [name, material]. Materials pick the sound and the kind.
const ROSTER: Array = [
	{"swarm": ["陨石碎屑", "rock"], "armored": ["铁陨石", "rock"]},
	{"swarm": ["太空垃圾", "metal"], "dart": ["侦察无人机", "metal"], "armored": ["废弃卫星", "metal"]},
	{"swarm": ["小行星碎块", "rock"], "dart": ["外星截击机", "metal"], "armored": ["金属小行星", "rock"], "splitter": ["碎石堆小行星", "rock"]},
	{"swarm": ["环带冰砾", "rock"], "dart": ["截击机编队", "metal"], "armored": ["外星装甲舰", "metal"], "splitter": ["双核彗星", "rock"], "shielded": ["等离子护盾舰", "metal"]},
	{"swarm": ["冰彗核群", "rock"], "dart": ["长尾彗星", "rock"], "armored": ["巨型冰核", "rock"], "splitter": ["冰晶团", "rock"], "shielded": ["冰壳舰", "metal"], "mother": ["彗星母巢", "rock"]},
	{"swarm": ["等离子团", "energy"], "dart": ["耀斑弹", "energy"], "armored": ["褐矮星", "energy"], "splitter": ["双星", "energy"], "shielded": ["日冕护罩舰", "metal"], "mother": ["星际方舟", "metal"]},
	{"swarm": ["星团流", "energy"], "dart": ["脉冲星碎片", "energy"], "armored": ["中子星", "energy"], "splitter": ["球状星团", "energy"], "shielded": ["磁层舰", "metal"], "mother": ["星系母舰", "metal"]},
	{"swarm": ["矮星系", "energy"], "dart": ["相对论喷流团", "energy"], "armored": ["椭圆星系", "energy"], "splitter": ["并合星系", "energy"], "shielded": ["暗物质晕", "exotic"], "mother": ["星系团核心", "energy"]},
	{"swarm": ["类星体光点", "exotic"], "dart": ["伽马暴", "exotic"], "armored": ["宇宙长城段", "exotic"], "splitter": ["宇宙网节点", "exotic"], "shielded": ["暗能量泡", "exotic"], "mother": ["原初黑洞", "exotic"]},
	{"swarm": ["量子泡沫", "exotic"], "dart": ["快子", "exotic"], "armored": ["宇宙弦结", "exotic"], "splitter": ["婴儿宇宙", "exotic"], "shielded": ["膜泡", "exotic"], "mother": ["另一宇宙的裂口", "exotic"]},
]
# The archetype each chapter introduces (shown once with a HUD tag).
const NEW_ARCH: Array[String] = ["armored", "dart", "splitter", "shielded", "mother", "", "", "", "", ""]
# Fourier: the swarm freezes into a signal; a chain of epicycles draws one closed
# curve through every threat, and each one bursts as the tip passes through it.
const FOURIER_SAMPLE: float = 0.55
const FOURIER_TRACE: float = 1.2
const FOURIER_TOUR_CAP: int = 220
# Mandelbrot: the set's boundary blooms out of the core and swallows the field.
const MANDEL_START: float = 0.9
const MANDEL_COVER: float = 3.5
# Dimensional resonance: threats are reduced to vibrating strings, driven to
# resonance by the shaking extra dimensions, then all snap at once.
const STRINGS_REVEAL: float = 1.3
const STRINGS_IMPACT: float = 4.4
const ULT_LOOT_DELAY: float = 1.0
const ULT_LOOT_FLIGHT: float = 1.8
# Campaign length: every per-stage table below has one entry per chapter.
const STAGE_COUNT: int = 10
const LAST_STAGE: int = STAGE_COUNT - 1
const BODIES: Array = [
	[{"name": "西区摩天楼", "attack": "swarm", "form": "twin", "style": 0, "weapon": "楼顶炮台", "at": Vector2(150, 470), "size": 12.0}, {"name": "中央塔", "attack": "beam", "form": "pods", "style": 0, "weapon": "塔顶导弹阵", "at": Vector2(330, 455), "size": 12.0}, {"name": "东区摩天楼", "attack": "quake", "form": "twin", "style": 1, "weapon": "楼顶炮台", "at": Vector2(860, 470), "size": 12.0}],
	[{"name": "月球", "attack": "rail", "form": "crescent", "style": 1, "weapon": "月轨主炮", "orbit": 247.0, "angle": -0.13, "speed": 0.05, "size": 13.0}, {"name": "近地空间站", "attack": "prism", "form": "panels", "style": 1, "weapon": "轨道炮站", "orbit": 190.0, "angle": 2.1, "speed": 0.11, "size": 8.0}, {"name": "同步卫星", "attack": "chain", "form": "dish", "style": 3, "weapon": "激光卫星", "orbit": 190.0, "angle": 4.3, "speed": 0.11, "size": 8.0}],
	[{"name": "水星", "attack": "cluster", "form": "tri", "style": 0, "weapon": "水星炮", "orbit": 70.0, "angle": 0.2, "speed": 0.03, "size": 6.0}, {"name": "金星", "attack": "wave", "form": "penta", "style": 2, "weapon": "金星炮", "orbit": 118.0, "angle": 1.92, "speed": 0.018, "size": 8.0}, {"name": "火星", "attack": "meteor", "form": "star4", "style": 4, "weapon": "火星炮", "orbit": 215.0, "angle": 3.64, "speed": 0.012, "size": 8.0}, {"name": "灶神星", "attack": "swarm", "form": "potato", "style": 1, "weapon": "小行星带阵列", "orbit": 272.0, "angle": 5.0, "speed": 0.008, "size": 7.0}, {"name": "太阳", "attack": "beam", "form": "dyson", "style": 3, "weapon": "戴森球", "orbit": 0.0, "angle": 0.0, "speed": 0.0, "size": 42.0, "disc": false}],
	[{"name": "木星", "attack": "gravity", "form": "octa", "style": 1, "weapon": "木星巨炮", "orbit": 92.0, "angle": 5.36, "speed": 0.02, "size": 13.0}, {"name": "土星", "attack": "ring", "form": "ringed", "style": 2, "weapon": "土星环炮", "orbit": 148.0, "angle": 0.8, "speed": 0.014, "size": 11.0}, {"name": "天王星", "attack": "prism", "form": "tilted", "style": 5, "weapon": "天王星炮", "orbit": 205.0, "angle": 2.6, "speed": 0.009, "size": 9.0}, {"name": "海王星", "attack": "chain", "form": "trident", "style": 3, "weapon": "海王星炮", "orbit": 255.0, "angle": 4.1, "speed": 0.007, "size": 9.0}, {"name": "冥王星", "attack": "rail", "form": "binary", "style": 0, "weapon": "冥卫双星炮", "orbit": 296.0, "angle": 1.5, "speed": 0.005, "size": 6.0}],
	[{"name": "旅行者一号", "note": "165 AU", "attack": "rail", "form": "probe", "style": 2, "weapon": "旅行者信标", "orbit": 150.0, "angle": -0.55, "speed": 0.004, "size": 7.0}, {"name": "塞德娜", "note": "937 AU", "attack": "quake", "form": "sedna", "style": 4, "weapon": "塞德娜冰炮", "orbit": 232.0, "angle": 3.9, "speed": 0.006, "size": 7.0}, {"name": "海尔-波普彗星", "note": "370 AU", "attack": "meteor", "form": "comet", "style": 1, "weapon": "彗尾炮", "orbit": 284.0, "angle": 0.6, "speed": 0.01, "size": 8.0}, {"name": "太阳引力透镜", "note": "550 AU", "attack": "beam", "form": "lens", "style": 3, "weapon": "引力透镜炮", "orbit": 182.0, "angle": 2.45, "speed": 0.003, "size": 9.0}, {"name": "奥尔特彗核群", "note": "~50,000 AU", "attack": "cluster", "form": "ice", "style": 5, "weapon": "彗核阵列", "orbit": 258.0, "angle": 5.3, "speed": 0.004, "size": 8.0}],
	[{"name": "半人马座 α", "note": "4.37 ly", "attack": "chain", "form": "trinary", "style": 3, "weapon": "三体星炮", "orbit": 112.0, "angle": -0.7, "speed": 0.004, "size": 9.0}, {"name": "天狼星", "note": "8.6 ly", "attack": "rail", "form": "star5", "style": 3, "weapon": "天狼星炮", "orbit": 168.0, "angle": 2.2, "speed": 0.003, "size": 8.0}, {"name": "巴纳德星", "note": "5.96 ly", "attack": "swarm", "form": "star4", "style": 0, "weapon": "巴纳德星炮", "orbit": 138.0, "angle": 1.0, "speed": 0.0035, "size": 6.0}, {"name": "织女星", "note": "25 ly", "attack": "prism", "form": "star7", "style": 2, "weapon": "织女星炮", "orbit": 250.0, "angle": 4.2, "speed": 0.002, "size": 7.0}, {"name": "大角星", "note": "36.7 ly", "attack": "quake", "form": "star8", "style": 5, "weapon": "大角星炮", "orbit": 288.0, "angle": 3.1, "speed": 0.0018, "size": 8.0}],
	[{"name": "参宿四", "note": "548 ly", "attack": "quake", "form": "star6", "style": 4, "weapon": "红巨星炮", "orbit": 230.0, "angle": 1.7, "speed": 0.015, "size": 9.0}, {"name": "蟹状星云脉冲星", "note": "6,500 ly", "attack": "beam", "form": "pulsar", "style": 2, "weapon": "蟹云脉冲炮", "orbit": 172.0, "angle": 3.6, "speed": 0.017, "size": 7.0}, {"name": "半人马座 ω", "note": "17,000 ly", "attack": "cluster", "form": "globular", "style": 1, "weapon": "球状星团炮", "orbit": 262.0, "angle": 5.4, "speed": 0.011, "size": 9.0}, {"name": "大麦哲伦云", "note": "160,000 ly", "attack": "meteor", "form": "spiral", "style": 3, "weapon": "麦哲伦阵列", "orbit": 305.0, "angle": 0.35, "speed": 0.006, "size": 14.0, "disc": false}, {"name": "小麦哲伦云", "note": "200,000 ly", "attack": "swarm", "form": "spiral", "style": 0, "weapon": "麦哲伦副阵", "orbit": 296.0, "angle": 0.95, "speed": 0.006, "size": 11.0, "disc": false}, {"name": "银心黑洞", "note": "26,000 ly", "attack": "gravity", "form": "hole", "style": 5, "weapon": "黑洞引擎", "orbit": 0.0, "angle": 0.0, "speed": 0.0, "size": 14.0}],
	[{"name": "仙女座星系", "note": "2.5 Mly", "attack": "swarm", "form": "spiral", "style": 4, "weapon": "仙女座阵列", "at": Vector2(590, 410), "size": 16.0, "disc": false}, {"name": "三角座星系", "note": "2.7 Mly", "attack": "wave", "form": "spiral", "style": 2, "weapon": "三角座阵列", "at": Vector2(408, 420), "size": 13.0, "disc": false}, {"name": "室女座星系团", "note": "54 Mly", "attack": "prism", "form": "cluster", "style": 2, "weapon": "室女座引擎", "at": Vector2(305, 210), "size": 16.0, "disc": false}, {"name": "后发座星系团", "note": "320 Mly", "attack": "chain", "form": "cluster", "style": 5, "weapon": "后发座引擎", "at": Vector2(735, 170), "size": 16.0, "disc": false}, {"name": "巨引源", "note": "250 Mly", "attack": "gravity", "form": "attractor", "style": 4, "weapon": "巨引源引擎", "at": Vector2(205, 470), "size": 14.0, "disc": false}, {"name": "拉尼亚凯亚", "note": "520 Mly", "attack": "quake", "form": "node", "style": 5, "weapon": "超星系团引擎", "at": Vector2(800, 455), "size": 12.0, "disc": false}],
	[{"name": "斯隆长城", "note": "1.4 Gly", "attack": "rail", "form": "wall", "style": 5, "weapon": "长城引擎", "node": 5, "size": 8.0, "disc": false}, {"name": "武仙-北冕座长城", "note": "10 Gly", "attack": "wave", "form": "wall", "style": 3, "weapon": "武仙长城引擎", "node": 9, "size": 8.0, "disc": false}, {"name": "最远类星体", "note": "13 Gly", "attack": "beam", "form": "quasar", "style": 2, "weapon": "类星体喷流", "node": 14, "size": 8.0, "disc": false}, {"name": "宇宙微波背景", "note": "46.5 Gly", "attack": "ring", "form": "cmb", "style": 4, "weapon": "背景辐射炮", "node": 20, "size": 9.0, "disc": false}, {"name": "CMB 冷斑", "note": "3 Gly", "attack": "gravity", "form": "void", "style": 5, "weapon": "冷斑引擎", "node": 26, "size": 9.0, "disc": false}, {"name": "牧夫座空洞", "note": "700 Mly", "attack": "meteor", "form": "void", "style": 1, "weapon": "空洞引擎", "node": 31, "size": 9.0, "disc": false}],
	[{"name": "第五维", "attack": "rail", "form": "calabi", "style": 5, "weapon": "第五维共振器", "orbit": 236.0, "angle": 0.52, "speed": 0.01, "size": 10.0, "disc": false}, {"name": "第六维", "attack": "prism", "form": "calabi", "style": 2, "weapon": "第六维共振器", "orbit": 236.0, "angle": 1.57, "speed": 0.01, "size": 10.0, "disc": false}, {"name": "第七维", "attack": "chain", "form": "calabi", "style": 3, "weapon": "第七维共振器", "orbit": 236.0, "angle": 2.62, "speed": 0.01, "size": 10.0, "disc": false}, {"name": "第八维", "attack": "wave", "form": "calabi", "style": 4, "weapon": "第八维共振器", "orbit": 236.0, "angle": 3.67, "speed": 0.01, "size": 10.0, "disc": false}, {"name": "第九维", "attack": "gravity", "form": "calabi", "style": 1, "weapon": "第九维共振器", "orbit": 236.0, "angle": 4.71, "speed": 0.01, "size": 10.0, "disc": false}, {"name": "第十维", "attack": "ring", "form": "calabi", "style": 0, "weapon": "第十维共振器", "orbit": 236.0, "angle": 5.76, "speed": 0.01, "size": 10.0, "disc": false}],
]
const WAVE_GROUPS: Array[int] = [32, 48, 64, 80, 104, 128, 160, 192, 224, 256]
# Waves hold three times the threats at a third of the bounty each: a flood on
# screen with the same economy.
const WAVE_SCALE: int = 3
# Extra volume per wave (full HP and bounty per threat): the flood lasts longer.
const WAVE_VOLUME: int = 1
# Threats arrive as one continuous flood: a steady stream that is topped up at
# once whenever the field thins out, so a stronger defense simply devours it faster.
var catalog = Catalog.new()
var rng := RandomNumberGenerator.new()
var mode: String = "title"
var stage: int = 0
var wave: int = 1
var money: float = 0.0
var health: float = 100.0
var landing_source: String = "main"
# Material of the threat behind the latest hit/destroyed signal (rock, metal, energy, exotic).
var event_mat: String = "rock"
# Archetypes already introduced to the player (saved), and work queued during the enemy pass.
var introduced: Array = []
var pending_splits: Array[Dictionary] = []
var pending_minions: Array[Dictionary] = []
var arch_norm_cache: Dictionary = {}
var levels: Dictionary = {"damage": 0, "speed": 0, "reload": 0, "crit": 0, "area": 0, "pierce": 0, "targets": 0, "turrets": 0}
var owned: Array[bool] = [true, false, false, false, false, false, false, false, false, false]
var automation: bool = false
var paused: bool = false
var manual_held: bool = false
var manual_queued: bool = false
var priority_id: int = -1
var elapsed: float = 0.0
var wave_elapsed: float = 0.0
var mode_time: float = 0.0
var spawn_clock: float = 0.0
# Converted celestial bodies: one bitmask per scale.
var bodies: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var wells: Array[Dictionary] = []
var ult_charge: float = 0.0
var ult_deaths: int = 0
var ult: Dictionary = {}
var reward_batches: Array[Dictionary] = []
var external_reward_clock: bool = false
var deferred_kill: bool = false
var boss_reward_queued: bool = false
var spawn_hold: float = 0.0
# Space threats materialise along the visible edge of the screen; the view
# reports its visible field rectangle here (the default matches a 16:9 window).
var spawn_rect: Rect2 = Rect2(-250, -10, 1500, 640)
# Right after a scale jump the field is topped up one group at a time, so the
# new scale fills in as a stream instead of a sudden ring of threats.
var topup_clock: float = 0.0
# Seconds since a doomsday weapon's spawn hold ended: the field refills gradually.
var refill: float = 99.0
# Seconds of calm after a scale jump before the first threat may spawn.
var grace: float = 0.0
const STAGE_GRACE: float = 4.0
# Boss escorts: every boss brings its own retinue and keeps launching more.
# Main guns stay on the boss; turrets and celestial cannons clear escorts.
# An escort that reaches the core shortens the boss's impact countdown.
const ESCORT_OPENING: Array[int] = [10, 12, 13, 14, 15, 16, 18, 20, 22, 24]
const ESCORT_BATCH: Array[int] = [3, 4, 4, 5, 5, 5, 6, 6, 7, 7]
const ESCORT_PERIOD: Array[float] = [3.2, 3.0, 2.9, 2.8, 2.7, 2.6, 2.5, 2.4, 2.2, 2.1]
const ESCORT_PENALTY: float = 0.6
var escort_clock: float = 0.0
var boss_penalty: float = 0.0
signal boss_launched(point: Vector2, count: int)
# Boss skills: a readable wind-up, then a signature attack. Some can be broken
# by dealing enough damage during the wind-up. Below half HP the boss enrages.
signal boss_skill(event: String, kind: String, point: Vector2)
const BOSS_SKILLS: Array[String] = ["meteor_rain", "tidal_shield", "summon", "siege_beam", "meteor_rain", "corona", "magnetic_field", "summon", "devour", "siege_beam"]
const SKILL_NAMES: Dictionary = {"meteor_rain": "陨石雨", "tidal_shield": "潮汐护盾", "siege_beam": "攻城主炮", "corona": "日冕抛射", "summon": "召唤舰队", "devour": "吞噬", "magnetic_field": "磁场偏转"}
const SKILL_WINDUP: Dictionary = {"meteor_rain": 1.6, "tidal_shield": 1.2, "siege_beam": 2.4, "corona": 1.8, "summon": 1.8, "devour": 2.6, "magnetic_field": 1.4}
const SKILL_ACTIVE: Dictionary = {"meteor_rain": 1.2, "tidal_shield": 3.0, "siege_beam": 1.0, "corona": 1.4, "summon": 1.0, "devour": 1.2, "magnetic_field": 3.6}
# Magnetar: while its field is up, rounds flying at it are bent away and miss.
# Instant attacks (lances, beams, webs, waves, sweeps) are not deflected.
const MAGNET_FIELD: float = 2.6
const MAGNET_DEFLECT: float = 0.65
signal shot_deflected(point: Vector2, heading: Vector2, turned: float)
const SKILL_BREAKABLE: Array[String] = ["siege_beam", "devour"]
const SKILL_BREAK_SHARE: float = 0.04
var skill: Dictionary = {}
var skill_clock: float = 6.0
var enraged: bool = false
const TOPUP_GAP: float = 0.14
const FLOOD_GAP: float = 0.05
# Developer switches: no cooldown (always charged, re-fire mid-strike) and a
# forced weapon so any scale's doomsday weapon can be tested anywhere.
var ult_unlimited: bool = false
var ult_override: String = ""
var spawn_left: int = 0
var wave_total: int = 0
var wave_killed: int = 0
var kills: int = 0
var attempts: int = 0
var stage_bosses: int = 0
var serial: int = 0
var boss_remaining: float = 0.0
var transition_from: int = 0
var transition_length: float = 7.0
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var enemies: Array[Dictionary] = []
var enemies_by_id: Dictionary = {}
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var enemy_pool: Array[Dictionary] = []
var shot_pool: Array[Dictionary] = []
var effect_pool: Array[Dictionary] = []
var weapon_damage: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var last_reward: float = 0.0
var boss_spawned: int = 0

func _init() -> void:
	rng.seed = 4262026
	for i in range(200):
		enemy_pool.append({})
	for i in range(512):
		shot_pool.append({})
	for i in range(180):
		effect_pool.append({})

func stage_data() -> Resource:
	return catalog.stages[stage]

func start_new(seed_value: int = 4262026) -> void:
	Campaign.start_new(self, seed_value)

func defense_position() -> Vector2:
	return defense_position_at(stage)

func defense_position_at(view_stage: int) -> Vector2:
	return Vector2(500.0, 572.0) if view_stage == 0 else Vector2(500.0, 325.0)

func weapon_origin(index: int) -> Vector2:
	return weapon_origin_at(index, stage)

func weapon_origin_at(index: int, view_stage: int) -> Vector2:
	if view_stage == 0:
		return Vector2(380.0 + index * 48.0, 565.0)
	var angle: float = -PI * 0.15 + index * TAU / STAGE_COUNT
	var radius: float = 108.0 + index * 7.0
	return defense_position_at(view_stage) + Vector2(cos(angle), sin(angle)) * radius

func damage_multiplier() -> float:
	return Growth.damage_multiplier(self)

func launcher_count() -> int:
	return Growth.launcher_count(self)

func shot_interval(index: int) -> float:
	return Growth.shot_interval(self, index)

func salvo_packets(index: int) -> float:
	return Growth.salvo_packets(self, index)

func shot_damage(index: int) -> float:
	return Growth.shot_damage(self, index)

func coverage(index: int) -> int:
	return Growth.coverage(self, index)

func crit_chance() -> float:
	return Growth.crit_chance(self)

func crit_multiplier() -> float:
	return Growth.crit_multiplier(self)

func nominal_dps() -> float:
	return Growth.nominal_dps(self)

func upgrade_cost(index: int, count: int = 1) -> float:
	return Growth.upgrade_cost(self, index, count)

func buy_upgrade(index: int, requested: int = 1) -> int:
	return Growth.buy_upgrade(self, index, requested)

func automation_available() -> bool:
	return Growth.automation_available(self)

func buy_automation() -> bool:
	return Growth.buy_automation(self)

func buy_weapon() -> bool:
	return Growth.buy_weapon(self)

func clear_battle() -> void:
	pending_splits.clear()
	pending_minions.clear()
	enemies_by_id.clear()
	for e in enemies:
		enemy_pool.append(e)
	enemies.clear()
	for p in shots:
		shot_pool.append(p)
	shots.clear()
	wells.clear()
	sweeps.clear()
	ult = {}
	spawn_hold = 0.0
	priority_id = -1
	manual_held = false

func start_wave() -> void:
	Campaign.start_wave(self)

func hp_scale(at_wave: int = -1) -> float:
	var w: int = wave if at_wave < 0 else at_wave
	return float(stage_data().hp_base_scale) * pow(float(stage_data().hp_growth), w - 1)

func reward_scale() -> float:
	return pow(hp_scale(), REWARD_HP_EXPONENT)

func wave_seconds() -> float:
	if stage > 0:
		return 22.0 + 4.5 * (wave - 1)
	return 25.0 + 7.0 * (wave - 1)

func min_alive() -> int:
	# The manual city opening stays a gentle trickle; space scales flood the field.
	if stage == 0:
		return 0 if wave <= 5 else 3
	return 16 + wave * 2

func ramped_min_alive() -> int:
	# The first wave of a scale builds up over a few seconds after the zoom-out.
	var k: float = clampf(refill / 6.0, 0.0, 1.0)
	if wave == 1:
		k = minf(k, clampf(wave_elapsed / 6.0, 0.0, 1.0))
	return int(min_alive() * k)

func living_count() -> int:
	var n: int = 0
	for e in enemies:
		if not bool(e.dead):
			n += 1
	return n

# Money already earned from flood groups this wave (capped at the wave's budget).
var flood_paid: float = 0.0

func member_reward() -> float:
	return 10.0 * float(stage_data().reward_multiplier) / wave_density() / (WAVE_SCALE if stage > 0 else 1) * reward_scale()

func wave_size() -> int:
	return int(stage_data().wave_members[wave - 1]) * int(stage_data().count_multiplier) * wave_density() * (WAVE_SCALE * WAVE_VOLUME if stage > 0 else 1)

func group_size() -> int:
	if stage == 0:
		return 1
	return maxi(1, ceili(float(wave_total) / WAVE_GROUPS[wave - 1]))

func wave_density() -> int:
	return 1 if stage==0 else int(stage_data().wave_density[wave-1])

func spawn_interval(members: int) -> float:
	return wave_seconds() * members / maxf(1.0, float(wave_total))

func arch_weights(view_stage: int) -> Dictionary:
	# Swarm is the backbone; specials share SPECIAL_SHARE, the chapter's new one doubled.
	var roster: Dictionary = ROSTER[clampi(view_stage, 0, LAST_STAGE)]
	var specials: Dictionary = {}
	var total: float = 0.0
	for a in ARCHES:
		if a != "swarm" and roster.has(a):
			specials[a] = 2.0 if a == NEW_ARCH[clampi(view_stage, 0, LAST_STAGE)] else 1.0
			total += float(specials[a])
	var share: float = SPECIAL_SHARE[clampi(view_stage, 0, LAST_STAGE)] if total > 0.0 else 0.0
	var out: Dictionary = {"swarm": 1.0 - share}
	for a in specials:
		out[a] = share * float(specials[a]) / total
	return out

func arch_norm(view_stage: int) -> Array:
	# [hp, lifetime] multipliers that keep a wave's expected HP and arrival time unchanged.
	if not arch_norm_cache.has(view_stage):
		var w: Dictionary = arch_weights(view_stage)
		var hp: float = 0.0
		var life: float = 0.0
		for a in w:
			hp += float(w[a]) * (float(ARCH_HP[a]) + float(ARCH_EXTRA[a]))
			life += float(w[a]) * float(ARCH_LIFE[a])
		arch_norm_cache[view_stage] = [1.0 / hp, 1.0 / life]
	return arch_norm_cache[view_stage]

func pick_arch() -> String:
	var w: Dictionary = arch_weights(stage)
	var roll: float = rng.randf()
	for a in w:
		roll -= float(w[a])
		if roll <= 0.0:
			return a
	return "swarm"

func enemy_point(e: Dictionary, ratio: float) -> Vector2:
	# Every threat flies start -> end; darts swing out in an S that settles onto the core.
	var p: Vector2 = Vector2(e.start).lerp(e.end, ratio)
	if str(e.get("arch", "")) == "dart":
		var d: Vector2 = Vector2(e.end) - Vector2(e.start)
		var amp: float = minf(190.0, d.length() * .32) * float(e.get("swerve", 1.0))
		p += d.orthogonal().normalized() * amp * sin(ratio * TAU) * (1.0 - ratio)
	return p

func child_seed(e: Dictionary) -> Dictionary:
	# The few parent values a split piece or minion inherits, copied (never a live reference).
	return {"left": float(e.lifetime) - float(e.age), "base_hp": float(e.get("base_hp", e.unit_hp)), "mat": str(e.get("mat", "rock"))}

func spawn_child(parent: Dictionary, at: Vector2, members: int, hp_share: float, offset: Vector2) -> void:
	# Split pieces and launched minions: swarm-like, never split again, pay half.
	serial += 1
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.clear()
	var core: Vector2 = defense_position()
	var origin: Vector2 = (at + offset).clamp(spawn_rect.position, spawn_rect.end)
	var end: Vector2 = core + (origin - core).normalized() * 68.0
	var left: float = maxf(2.5, float(parent.left) * .85)
	var unit_hp: float = float(parent.base_hp) * hp_share
	var roster: Dictionary = ROSTER[clampi(stage, 0, LAST_STAGE)]
	e.merge({"id": serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": left, "members": members, "initial_members": members, "unit_hp": unit_hp, "hp": unit_hp, "kind": "ship" if str(parent.get("mat", "")) == "metal" else "rock", "elite": false, "seed": rng.randi_range(1, 99999), "reserved": 0.0, "radius": 9.0 + (minf(14.0, log(float(members)) * 2.5) if members > 1 else 0.0), "boss": false, "dead": false})
	e.merge({"arch": "swarm", "mat": str(parent.get("mat", "rock")), "title": str(roster.swarm[0]), "child": true, "base_hp": unit_hp, "art": "%d_swarm" % clampi(stage, 0, LAST_STAGE)})
	enemies.append(e)
	enemies_by_id[int(e.id)] = e

func process_offspring() -> void:
	for split in pending_splits:
		var members: int = maxi(1, int(split.members) / 2)
		for j in range(2):
			var side: Vector2 = Vector2.from_angle(float(split.heading) + PI * .5 + j * PI) * 14.0
			spawn_child(split.parent, split.pos, members, float(ARCH_EXTRA.splitter), side)
		enemy_split.emit(split.pos, 2)
	pending_splits.clear()
	for mother in pending_minions:
		if bool(mother.dead):
			continue
		var members: int = maxi(1, int(mother.members) / MOTHER_LAUNCHES)
		spawn_child(child_seed(mother), mother.pos, members, float(ARCH_EXTRA.mother), Vector2.from_angle(rng.randf() * TAU) * 10.0)
		minion_launched.emit(mother.pos)
	pending_minions.clear()

func spawn_enemy(members: int) -> void:
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.clear()
	serial += 1
	var elite: bool = stage >= 1 and serial % 9 == 0
	if elite:
		members=1
	var arch: String = "armored" if elite else pick_arch()
	var roster: Dictionary = ROSTER[clampi(stage, 0, LAST_STAGE)]
	var entry: Array = roster.get(arch, roster.swarm)
	var alien: bool = str(entry[1]) == "metal"
	var kind: String = "ship" if alien else "rock"
	if elite:
		kind = "elite_ship" if alien else "heavy"
	var origin: Vector2
	var end: Vector2
	if stage == 0:
		origin = Vector2(rng.randf_range(130.0, 870.0), minf(-20.0, spawn_rect.position.y))
		end = Vector2(origin.x + rng.randf_range(-70.0, 70.0), 570.0)
	else:
		origin = edge_point(rng.randf())
		end = defense_position() + (origin - defense_position()).normalized() * 68.0
	var lifetime: float = rng.randf_range(16.0, 22.0) if stage == 0 else rng.randf_range(17.0, 23.0)
	if stage > 0:
		# Same feel of speed from every edge: farther starts take a little longer.
		lifetime *= clampf(sqrt(origin.distance_to(defense_position()) / 480.0), 0.85, 1.6)
	if elite:
		lifetime *= 0.74
	var norm: Array = arch_norm(stage)
	if not elite:
		lifetime *= float(ARCH_LIFE[arch]) * float(norm[1])
	# Flood waves split the same total HP across WAVE_SCALE times the threats.
	var base_hp: float = (300.0 if elite else 100.0) * hp_scale() / (WAVE_SCALE if stage > 0 else 1)
	var unit_hp: float = base_hp if elite else base_hp * float(ARCH_HP[arch]) * float(norm[0])
	e.merge({"id": serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": lifetime, "members": members, "initial_members": members, "unit_hp": unit_hp, "hp": unit_hp, "kind": kind, "elite": elite, "seed": rng.randi_range(1, 99999), "reserved": 0.0, "radius": 12.0 + (8.0 if elite else 0.0) + (minf(22.0, log(float(members)) * 3.0) if members > 1 else 0.0), "boss": false, "dead": false})
	e.merge({"arch": arch, "mat": str(entry[1]), "title": str(entry[0]), "base_hp": base_hp * float(norm[0]), "art": "%d_%s" % [clampi(stage, 0, LAST_STAGE), arch]})
	match arch:
		"dart":
			e.radius = float(e.radius) - 2.0
			e["swerve"] = 1.0 if rng.randf() < .5 else -1.0
		"armored":
			e.radius = float(e.radius) + 5.0
		"shielded":
			e["shield"] = float(members) * unit_hp * float(ARCH_EXTRA.shielded) / float(ARCH_HP.shielded)
			e["shield_max"] = e.shield
		"mother":
			e.radius = float(e.radius) + 9.0
			e["launch_t"] = 2.0
			e["launched"] = 0
	enemies.append(e)
	if not elite and arch == NEW_ARCH[clampi(stage, 0, LAST_STAGE)] and not introduced.has(arch):
		introduced.append(arch)
		arch_introduced.emit(arch, str(entry[0]), int(e.id))
	enemies_by_id[int(e.id)] = e

func edge_point(u: float) -> Vector2:
	# A point on the perimeter of the spawn rectangle, uniform by length.
	var r: Rect2 = spawn_rect
	var d: float = u * 2.0 * (r.size.x + r.size.y)
	if d < r.size.x:
		return r.position + Vector2(d, 0)
	d -= r.size.x
	if d < r.size.y:
		return r.position + Vector2(r.size.x, d)
	d -= r.size.y
	if d < r.size.x:
		return r.end - Vector2(d, 0)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)

func start_boss() -> void:
	Campaign.start_boss(self)

func find_enemy(id: int) -> Dictionary:
	var e: Dictionary = enemies_by_id.get(id, {})
	if not e.is_empty() and not bool(e.dead):
		return e
	return {}

func select_target(point: Vector2) -> int:
	var nearest: float = INF
	var result: int = -1
	for e in enemies:
		if bool(e.dead):
			continue
		var distance: float = point.distance_to(e.pos)
		if distance < nearest and distance < maxf(60.0, float(e.radius) + 12.0):
			nearest = distance
			result = int(e.id)
	if result >= 0:
		priority_id = result
		focus_shots(find_enemy(result))
	return result

# Launch direction is immutable even after several focus changes or a save.
func shot_launch(p: Dictionary) -> float:
	if not p.has("launch_angle"):
		p.launch_angle = (Vector2(p.end) - Vector2(p.from)).angle()
	return float(p.launch_angle)

func shot_can_follow(p: Dictionary, target: Dictionary) -> bool:
	if bool(p.beam):
		return true
	var launch: float = shot_launch(p)
	var heading: Vector2 = (Vector2(p.end) - Vector2(p.from)).normalized()
	var here: Vector2 = p.pos
	var goal: Vector2 = target.pos
	return Guidance.accepts(here, Guidance.control(here, heading, goal), goal, launch, PROJECTILE_SPEED)

func focus_shots(target: Dictionary) -> void:
	if target.is_empty():
		return
	for p in shots:
		if int(p.target) == int(target.id) or bool(p.get("stray", false)) or int(p.get("turns", 0)) >= MAX_RETARGETS or not shot_can_follow(p, target):
			continue
		var old: Dictionary = find_enemy(int(p.target))
		if not old.is_empty():
			old.reserved = maxf(0.0, float(old.reserved) - float(p.effective))
		p.turns = int(p.get("turns", 0)) + 1
		p.target = int(target.id)
		p.from = p.pos
		p.age = minf(0.0, float(p.age))
		p.duration = 0.05 if bool(p.beam) else maxf(0.035, Vector2(p.pos).distance_to(target.pos) / PROJECTILE_SPEED)
		p.end = target.pos
		p.effective = float(p.damage) if bool(target.boss) else minf(float(p.damage), int(p.coverage) * float(target.unit_hp))
		target.reserved = float(target.reserved) + float(p.effective)
	focused.emit(int(target.id))

func pending_hp(e: Dictionary) -> float:
	return float(e.hp) + (int(e.members) - 1) * float(e.unit_hp) - float(e.reserved)

func boss_actor() -> Dictionary:
	for e in enemies:
		if bool(e.boss) and not bool(e.dead):
			return e
	return {}

func spawn_escorts(count: int, opening: bool) -> void:
	var boss: Dictionary = boss_actor()
	if boss.is_empty():
		return
	var at: Vector2 = boss.pos
	var core: Vector2 = defense_position()
	var r: float = float(boss.radius)
	for i in range(count):
		serial += 1
		var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
		e.clear()
		# Opening retinue fans out wide around the boss; later waves leave its flanks.
		var a: float = (i + .5) * TAU / count + rng.randf_range(-.25, .25) if opening else rng.randf_range(-PI, PI)
		var spread: float = r * (2.2 + rng.randf() * 1.6) if opening else r * (1.1 + rng.randf() * .6)
		var origin: Vector2 = at + Vector2(cos(a), sin(a) * (.55 if stage == 0 else .8)) * spread
		origin = origin.clamp(spawn_rect.position, spawn_rect.end)
		var end: Vector2 = core + (origin - core).normalized() * 68.0
		var life: float = rng.randf_range(10.0, 14.0) * (1.3 if opening else 1.0)
		var unit_hp: float = 220.0 * hp_scale(10) / (WAVE_SCALE if stage > 0 else 1)
		e.merge({"id": serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": life, "members": 1, "initial_members": 1, "unit_hp": unit_hp, "hp": unit_hp, "kind": "escort", "escort": stage, "elite": false, "seed": rng.randi_range(1, 99999), "reserved": 0.0, "radius": 13.0, "boss": false, "dead": false})
		enemies.append(e)
		enemies_by_id[int(e.id)] = e

func update_boss_skill(delta: float) -> void:
	var boss: Dictionary = boss_actor()
	if boss.is_empty():
		skill = {}
		return
	var max_hp: float = boss_max_hp()
	if not enraged and float(boss.hp) < max_hp * .5:
		enraged = true
		boss_skill.emit("enrage", "", boss.pos)
	if skill.is_empty():
		skill_clock -= delta
		if skill_clock <= 0.0:
			var kind: String = BOSS_SKILLS[mini(stage, BOSS_SKILLS.size() - 1)]
			skill = {"kind": kind, "phase": "windup", "age": 0.0, "hp": float(boss.hp)}
			boss_skill.emit("windup", kind, boss.pos)
		return
	skill.age = float(skill.age) + delta
	var kind: String = skill.kind
	if str(skill.phase) == "windup":
		if kind in SKILL_BREAKABLE and float(skill.hp) - float(boss.hp) >= max_hp * SKILL_BREAK_SHARE:
			boss_skill.emit("broken", kind, boss.pos)
			end_skill()
			return
		if float(skill.age) >= float(SKILL_WINDUP[kind]):
			skill.phase = "active"
			skill.age = 0.0
			fire_boss_skill(kind, boss)
			boss_skill.emit("fire", kind, boss.pos)
	elif float(skill.age) >= float(SKILL_ACTIVE[kind]):
		end_skill()

func end_skill() -> void:
	skill = {}
	skill_clock = rng.randf_range(8.0, 11.0) * (.7 if enraged else 1.0)

func fire_boss_skill(kind: String, boss: Dictionary) -> void:
	match kind:
		"meteor_rain":
			# Fast fragments drop from across the sky straight at the defenses.
			var core: Vector2 = defense_position()
			for i in range(10):
				spawn_escorts(1, false)
				var e: Dictionary = enemies.back()
				e.start = Vector2(lerpf(spawn_rect.position.x + 60, spawn_rect.end.x - 60, (i + .5) / 10.0), spawn_rect.position.y + 10)
				e.pos = e.start
				e.end = Vector2(core.x + (e.start.x - core.x) * .15, core.y)
				e.lifetime = rng.randf_range(4.5, 6.0)
				e["fast"] = true
		"siege_beam":
			boss_penalty += 2.5
		"corona":
			# The ejected shell erases rounds in flight and seeds plasma orbs.
			var at: Vector2 = boss.pos
			for i in range(shots.size() - 1, -1, -1):
				var p: Dictionary = shots[i]
				if Vector2(p.pos).distance_to(at) < 420.0 and not p.has("body"):
					var t: Dictionary = find_enemy(int(p.target))
					if not t.is_empty():
						t.reserved = maxf(0.0, float(t.reserved) - float(p.effective))
					shot_pool.append(p)
					shots.remove_at(i)
			spawn_escorts(6, false)
		"summon":
			spawn_escorts(12, true)
		"devour":
			boss.hp = minf(boss_max_hp(), float(boss.hp) + boss_max_hp() * .05)

func update_escorts(delta: float) -> void:
	if boss_actor().is_empty():
		return
	update_boss_skill(delta)
	escort_clock -= delta
	if escort_clock <= 0.0:
		var first: bool = escort_clock < -50.0
		var n: int = ESCORT_OPENING[stage] if first else ESCORT_BATCH[stage]
		escort_clock = ESCORT_PERIOD[stage]
		spawn_escorts(n, first)
		boss_launched.emit(boss_actor().pos, n)
	# Escorts that reach the core bring the impact closer.
	for e in enemies:
		if not bool(e.dead) and not bool(e.boss) and float(e.age) >= float(e.lifetime):
			e.dead = true
			boss_penalty += ESCORT_PENALTY
			add_effect(e.pos, "breach", 25.0)

func target_for_weapon() -> Dictionary:
	# A focus-fire target draws every gun while it lives (spare rounds swerve on).
	var explicit: Dictionary = find_enemy(priority_id)
	if not explicit.is_empty():
		return explicit
	# During a boss fight the heavy guns stay on the boss; escorts are for turrets.
	if mode == "boss":
		var boss: Dictionary = boss_actor()
		if not boss.is_empty():
			return boss
	var best: Dictionary = {}
	var remaining: float = INF
	for e in enemies:
		if bool(e.dead) or pending_hp(e) <= 0.0001:
			continue
		var t: float = float(e.lifetime) - float(e.age)
		if t < remaining:
			remaining = t
			best = e
	return best

# Every chapter's main weapon attacks in its own way. The primary target always
# takes the full volley; the geometry decides who else is caught and for how much.
const WEAPON_MODES: Array[String] = ["missile", "rod", "sweep", "well", "shotgun", "lance", "pulse", "jets", "web", "standing"]
const ROD_FALL: float = 0.34
const SWEEP_ARC: float = 0.3
const SWEEP_TIME: float = 0.22
const SWEEP_SHARE: float = 0.45
const WELL_RADIUS: float = 105.0
const WELL_SHARE: float = 0.5
const WELL_PUSH: float = 0.7
const SHARD_COUNT: int = 6
const SHARD_SHARE: float = 0.3
const LANCE_SHARE: float = 0.55
const BURN_SHARE: float = 0.12
# Pulsar beacon: a rhythmic train of light pulses straight at the target.
const PULSE_COUNT: int = 4
const PULSE_GAP: float = 0.07
const PULSE_SPLASH: float = 46.0
const PULSE_SHARE: float = 0.35
const JET_LENGTH: float = 430.0
const JET_SHARE: float = 0.5
const WEB_SHARE: float = 0.45
const STANDING_WAVELENGTH: float = 250.0
const STANDING_SHARE: float = 0.4
var sweeps: Array[Dictionary] = []

func make_shot(target: Dictionary, from: Vector2, duration: float, amount: float, critical: bool, cap: int, index: int, extra: Dictionary) -> void:
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	p.merge({"target": int(target.id), "from": from, "pos": from, "end": target.pos, "age": 0.0, "duration": maxf(0.035, duration), "damage": amount, "effective": effective, "coverage": cap, "weapon": index, "crit": critical, "beam": false})
	p.merge(extra)
	target.reserved = float(target.reserved) + effective
	shots.append(p)

func line_hits(a: Vector2, b: Vector2, width: float, skip: Dictionary, limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in enemies:
		if out.size() >= limit:
			break
		if e == skip or bool(e.dead):
			continue
		if Geometry2D.get_closest_point_to_segment(e.pos, a, b).distance_to(e.pos) <= width + float(e.radius) * .5:
			out.append(e)
	return out

func fire_weapon(index: int, target: Dictionary) -> void:
	var mode: String = WEAPON_MODES[index]
	if mode != "missile":
		fire_special(mode, index, target)
		return
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = shot_damage(index)
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = coverage(index)
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = weapon_origin(index)
	var destination: Vector2 = target.pos
	var speed: float = PROJECTILE_SPEED
	var duration: float = origin.distance_to(destination) / speed
	if bool(catalog.weapons[index].beam):
		duration = 0.12
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, duration), "damage": amount, "effective": effective, "coverage": cap, "weapon": index, "crit": critical, "beam": bool(catalog.weapons[index].beam)})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	fired.emit(index,origin,destination,critical)

func fire_special(mode: String, index: int, target: Dictionary) -> void:
	var amount: float = shot_damage(index)
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = coverage(index)
	var origin: Vector2 = weapon_origin(index)
	var destination: Vector2 = target.pos
	var aim: float = (destination - origin).angle()
	var points := PackedVector2Array()
	var dealt: float = 0.0
	fired.emit(index, origin, destination, critical)
	match mode:
		"rod":
			# A tungsten rod dropped from orbit straight down onto the target.
			var top := Vector2(destination.x + 24.0, spawn_rect.position.y - 40.0)
			make_shot(target, top, ROD_FALL, amount, critical, cap, index, {"mode": "rod"})
			return
		"well":
			make_shot(target, origin, origin.distance_to(destination) / BODY_SPEED, amount, critical, cap, index, {"mode": "well"})
			return
		"shotgun":
			# A cone of comet shards, each locked onto its own threat in the cone.
			var picks: Array[Dictionary] = []
			var reach: float = origin.distance_to(destination) * 1.35 + 60.0
			for e in enemies:
				if picks.size() >= SHARD_COUNT - 1:
					break
				if e == target or bool(e.dead):
					continue
				var rel: Vector2 = Vector2(e.pos) - origin
				if rel.length() <= reach and absf(angle_difference(aim, rel.angle())) <= .42:
					picks.append(e)
			make_shot(target, origin, origin.distance_to(destination) / SWARM_SPEED, amount, critical, cap, index, {"mode": "shard", "shard": 0})
			for j in range(picks.size()):
				var e: Dictionary = picks[j]
				make_shot(e, origin, origin.distance_to(e.pos) / SWARM_SPEED, amount * SHARD_SHARE, critical, cap, index, {"mode": "shard", "shard": j + 1})
			return
		"jets":
			make_shot(target, origin, origin.distance_to(destination) / PROJECTILE_SPEED, amount, critical, cap, index, {"mode": "jets"})
			return
		"sweep":
			# The planetary array slashes a short arc across the target and just past it.
			sweeps.append({"origin": origin, "from": aim - SWEEP_ARC, "to": aim + SWEEP_ARC, "age": 0.0, "dur": SWEEP_TIME, "reach": origin.distance_to(destination) + 120.0, "beams": [0.0], "amount": amount, "share": SWEEP_SHARE, "cap": cap, "weapon": index, "primary": int(target.id), "hit": {}, "crit": critical, "kind": "sweep"})
			return
		"pulse":
			# Tick, tick, tick, tick: pulses leave a beat apart and race to the target.
			for j in range(PULSE_COUNT):
				make_shot(target, origin, origin.distance_to(destination) / (PROJECTILE_SPEED * 2.4), amount / PULSE_COUNT, critical, cap, index, {"mode": "pulse", "age": -j * PULSE_GAP, "pulse": j})
			return
		"lance":
			var axis: Vector2 = (destination - origin).normalized()
			var reach_to: Vector2 = origin + axis * 1500.0
			# The lance burns through the whole line but its light stops just past
			# the last threat it pierced, so it never strikes across an empty screen.
			var farthest: float = origin.distance_to(destination)
			dealt += apply_damage(target, amount, cap, index, critical)
			for e in line_hits(origin, reach_to, 16.0, target, 30):
				points.append(e.pos)
				farthest = maxf(farthest, (Vector2(e.pos) - origin).dot(axis))
				dealt += apply_damage(e, amount * LANCE_SHARE, cap, index)
			reach_to = origin + axis * (farthest + 70.0)
			wells.append({"kind": "burn", "pos": origin, "to": reach_to, "age": 0.0, "dur": 1.2, "radius": 18.0, "tick": .3, "step": .3, "damage": amount * BURN_SHARE, "coverage": cap, "weapon": index, "stage": index, "slot": -1})
			weapon_strike.emit("lance", index, origin, reach_to, points, critical)
		"web":
			# Filaments branch out from the target: two generations of links.
			var visited: Array = [target]
			var frontier: Array = [target]
			dealt += apply_damage(target, amount, cap, index, critical)
			for depth in range(2):
				var next: Array = []
				for node in frontier:
					var links: int = 5 if depth == 0 else 2
					var near: Array = []
					for e in enemies:
						if bool(e.dead) or visited.has(e):
							continue
						var d: float = Vector2(e.pos).distance_to(node.pos)
						if d <= (250.0 if depth == 0 else 190.0):
							near.append([d, e])
					near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
					for pair in near.slice(0, links):
						var e: Dictionary = pair[1]
						visited.append(e)
						next.append(e)
						points.append(node.pos)
						points.append(e.pos)
				frontier = next
			for e in visited:
				if e != target:
					dealt += apply_damage(e, amount * WEB_SHARE, cap, index)
			weapon_strike.emit("web", index, origin, destination, points, critical)
		"standing":
			# A standing wave across the field: antinode bands, one locked on the target.
			var k: float = TAU / STANDING_WAVELENGTH
			var phase: float = PI * .5 - k * destination.x
			dealt += apply_damage(target, amount, cap, index, critical)
			var count: int = 0
			for e in enemies:
				if count >= 40:
					break
				if e == target or bool(e.dead):
					continue
				if absf(sin(k * float(e.pos.x) + phase)) > .82:
					points.append(e.pos)
					dealt += apply_damage(e, amount * STANDING_SHARE, cap, index)
					count += 1
			weapon_strike.emit("standing", index, origin, destination, PackedVector2Array([Vector2(phase, k)]) + points, critical)
	source_damage.main += dealt

func update_sweeps(delta: float) -> void:
	for i in range(sweeps.size() - 1, -1, -1):
		var sw: Dictionary = sweeps[i]
		var before: float = clampf(float(sw.age) / float(sw.dur), 0, 1)
		sw.age = float(sw.age) + delta
		var after: float = clampf(float(sw.age) / float(sw.dur), 0, 1)
		var a0: float = lerpf(float(sw.from), float(sw.to), before)
		var a1: float = lerpf(float(sw.from), float(sw.to), after)
		var at: Vector2 = sw.origin
		for e in enemies:
			if bool(e.dead) or sw.hit.has(int(e.id)):
				continue
			var rel: Vector2 = Vector2(e.pos) - at
			if rel.length() > float(sw.reach):
				continue
			for offset in sw.beams:
				var d0: float = angle_difference(a0 + float(offset), rel.angle())
				var d1: float = angle_difference(a1 + float(offset), rel.angle())
				# Crossed when the beam passes the threat's bearing this tick.
				if (d0 >= 0.0 and d1 <= 0.0) or (d0 <= 0.0 and d1 >= 0.0) or absf(d1) < .02:
					if absf(d0) < 1.0 and absf(d1) < 1.0:
						sw.hit[int(e.id)] = true
						var primary: bool = int(e.id) == int(sw.primary)
						source_damage.main += apply_damage(e, float(sw.amount) * (1.0 if primary else float(sw.share)), int(sw.cap), int(sw.weapon), bool(sw.crit) and primary)
						break
		if float(sw.age) >= float(sw.dur):
			# A primary the beam somehow missed (it moved) still takes the volley.
			var primary_e: Dictionary = find_enemy(int(sw.primary))
			if not primary_e.is_empty() and not sw.hit.has(int(sw.primary)):
				source_damage.main += apply_damage(primary_e, float(sw.amount), int(sw.cap), int(sw.weapon), bool(sw.crit))
			sweeps.remove_at(i)

func land_special(p: Dictionary, target: Dictionary, visuals: bool) -> float:
	# Arrival effects of the projectile-borne chapter weapons.
	var dealt: float = 0.0
	var at: Vector2 = target.pos
	var index: int = int(p.weapon)
	var points := PackedVector2Array()
	match str(p.mode):
		"rod":
			for e in enemies:
				if points.size() >= 12:
					break
				if e == target or bool(e.dead) or Vector2(e.pos).distance_to(at) > 70.0:
					continue
				points.append(e.pos)
				dealt += apply_damage(e, float(p.damage) * .4, int(p.coverage), index)
			if visuals:
				weapon_strike.emit("rod", index, p.from, at, points, bool(p.crit))
		"well":
			# Gravity first drags the swarm together, then flings it back outward.
			for e in enemies:
				if points.size() >= 16:
					break
				if e == target or bool(e.dead) or Vector2(e.pos).distance_to(at) > WELL_RADIUS:
					continue
				points.append(e.pos)
				dealt += apply_damage(e, float(p.damage) * WELL_SHARE, int(p.coverage), index)
				if not bool(e.dead) and not bool(e.boss):
					e.age = maxf(0.0, float(e.age) - WELL_PUSH)
			if visuals:
				weapon_strike.emit("well", index, p.from, at, points, bool(p.crit))
		"pulse":
			for e in enemies:
				if points.size() >= 6:
					break
				if e == target or bool(e.dead) or Vector2(e.pos).distance_to(at) > PULSE_SPLASH:
					continue
				points.append(e.pos)
				dealt += apply_damage(e, float(p.damage) * PULSE_SHARE, int(p.coverage), index)
			if visuals:
				weapon_strike.emit("pulse", index, p.from, at, points, bool(p.crit))
		"jets":
			var axis: Vector2 = (at - Vector2(p.from)).normalized().orthogonal()
			for side in [-1.0, 1.0]:
				for e in line_hits(at, at + axis * side * JET_LENGTH, 14.0, target, 15):
					points.append(e.pos)
					dealt += apply_damage(e, float(p.damage) * JET_SHARE, int(p.coverage), index)
			if visuals:
				weapon_strike.emit("jets", index, at - axis * JET_LENGTH, at + axis * JET_LENGTH, points, bool(p.crit))
	return dealt

# Damage actually landed per source (main arsenal / turret ring / bodies).
var source_damage: Dictionary = {"main": 0.0, "turret": 0.0, "body": 0.0}

func turret_count() -> int:
	return mini(TURRET_SLOTS, int(levels.get("turrets", 0)))

func turret_position(slot: int) -> Vector2:
	return turret_position_at(slot, stage)

func turret_position_at(slot: int, view_stage: int) -> Vector2:
	if view_stage == 0:
		var side: float = -1.0 if slot % 2 == 0 else 1.0
		return Vector2(500.0 + side * (56.0 + (slot / 2) * 24.0), 586.0)
	var count: int = turret_count()
	var placed: int = 0
	var radius: float = 74.0
	for ring in range(TURRET_RINGS.size()):
		var in_ring: int = mini(TURRET_RINGS[ring], count - placed)
		if slot < placed + in_ring:
			var a: float = (slot - placed) * TAU / in_ring + ring * 0.3
			return defense_position_at(view_stage) + Vector2(cos(a), sin(a)) * radius
		placed += in_ring
		radius += 12.0
	return defense_position_at(view_stage)

func arsenal_rate(value: Callable) -> float:
	var total: float = 0.0
	for i in range(STAGE_COUNT):
		if owned[i]:
			total += float(value.call(i)) / shot_interval(i)
	return total

func turret_shot_damage() -> float:
	return 0.05 * int(levels.get("turrets", 0)) * arsenal_rate(shot_damage) * TURRET_PERIOD / maxi(1, turret_count())

func turret_coverage() -> int:
	return maxi(1, int(0.05 * int(levels.get("turrets", 0)) * arsenal_rate(coverage) * TURRET_PERIOD / maxi(1, turret_count())))

func turret_lanes() -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	for e in enemies:
		if not bool(e.dead):
			lanes.append(e)
	lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.lifetime) - float(a.age) < float(b.lifetime) - float(b.age))
	return lanes

func body_converted_at(body_stage: int, slot: int) -> bool:
	return (bodies[body_stage] >> slot) & 1 == 1

func converted_count(body_stage: int) -> int:
	var n: int = 0
	for k in range(BODIES[body_stage].size()):
		if body_converted_at(body_stage, k):
			n += 1
	return n

func total_bodies() -> int:
	var n: int = 0
	for s in range(stage + 1):
		n += converted_count(s)
	return n

func body_cost() -> float:
	var base: float = 80.0 if stage == 0 else float(stage_data().weapon_price) * 2.0
	return base * pow(BODY_PRICE_GROWTH, converted_count(stage))

func convert_body(slot: int) -> bool:
	if slot < 0 or slot >= BODIES[stage].size() or body_converted_at(stage, slot) or mode in ["title", "transition", "victory"]:
		return false
	var price: float = body_cost()
	if money + 0.00001 < price:
		return false
	money -= price
	bodies[stage] |= 1 << slot
	body_converted.emit(stage, slot)
	notice.emit(TranslationServer.translate(str(BODIES[stage][slot].name)) + TranslationServer.translate("改造完成 · ") + TranslationServer.translate(str(BODIES[stage][slot].weapon)) + TranslationServer.translate("上线"))
	checkpoint.emit()
	return true

func scene_body_position(body_stage: int, slot: int) -> Vector2:
	# Where the body sits in its own scale's scene (orbits follow game time).
	var spec: Dictionary = BODIES[body_stage][slot]
	var c := Vector2(500.0, 325.0)
	if spec.has("at"):
		return spec.at
	if spec.has("node"):
		var i: int = int(spec.node)
		var r: float = sqrt(float(i) / 34.0) * 290.0
		return c + Vector2(cos(i * 2.399), sin(i * 2.399)) * r
	var a: float = float(spec.angle) + elapsed * float(spec.speed)
	return c + Vector2(cos(a), sin(a)) * float(spec.orbit)

func body_position(body_stage: int, slot: int) -> Vector2:
	if body_stage == stage:
		return scene_body_position(body_stage, slot)
	# Bodies from smaller scales have shrunk into an orbit round the core.
	var index: int = 0
	for s in range(body_stage):
		index += BODIES[s].size()
	index += slot
	var a: float = index * 0.71 + elapsed * 0.25
	var radius: float = 150.0 + (index % 3) * 14.0
	return defense_position() + Vector2(cos(a), sin(a) * (0.55 if stage == 0 else 1.0)) * radius

func body_shot_damage() -> float:
	return BODY_SHARE * arsenal_rate(shot_damage) * BODY_PERIOD

func body_coverage() -> int:
	return maxi(1, int(BODY_SHARE * arsenal_rate(coverage) * BODY_PERIOD))

func body_attack(body_stage: int, slot: int) -> String:
	return str(BODIES[body_stage][slot].get("attack", "shell"))

func fire_body(body_stage: int, slot: int, target: Dictionary, lanes: Array[Dictionary] = [], beat: int = 0) -> void:
	var attack: String = body_attack(body_stage, slot)
	if attack not in ["shell", "cluster"]:
		fire_body_special(attack, body_stage, slot, target, lanes, beat)
		return
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = body_shot_damage() * int(ATTACK_EVERY.get(attack, 1))
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = body_coverage()
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = body_position(body_stage, slot)
	var destination: Vector2 = target.pos
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, origin.distance_to(destination) / BODY_SPEED), "damage": amount, "effective": effective, "coverage": cap, "weapon": body_stage, "crit": critical, "beam": false, "body": slot, "body_stage": body_stage, "attack": attack})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	body_fired.emit(body_stage, slot, origin, destination, critical)

# A round may change target at most this many times; after that it flies on
# straight and leaves the screen instead of circling round the field.
const MAX_RETARGETS: int = 3

func magnet_field_radius() -> float:
	# The magnetar's deflecting field, or 0 when it is not up.
	if skill.is_empty() or str(skill.kind) != "magnetic_field" or str(skill.phase) != "active":
		return 0.0
	var boss: Dictionary = boss_actor()
	return 0.0 if boss.is_empty() else float(boss.radius) * MAGNET_FIELD

func make_stray(p: Dictionary, turn: float = 0.0) -> void:
	# No damage any more: keep the current heading and leave the visible field.
	var from: Vector2 = p.pos
	var heading: Vector2 = Vector2(p.end) - Vector2(p.from)
	if heading.length() < .01:
		heading = Vector2.UP
	var launch: float = shot_launch(p)
	heading = Vector2.from_angle(launch + clampf(wrapf(heading.angle() + turn - launch, -PI, PI), -Guidance.HALF_CONE, Guidance.HALF_CONE))
	var speed: float = maxf(PROJECTILE_SPEED * .6, Vector2(p.from).distance_to(p.end) / maxf(.01, float(p.duration)))
	p.stray = true
	p.target = -1
	p.from = from
	p.end = from + heading.normalized() * 1500.0
	p.age = 0.0
	p.duration = 1500.0 / speed

func retarget_shot(p: Dictionary) -> Dictionary:
	if int(p.get("turns", 0)) >= MAX_RETARGETS:
		return {}
	var here: Vector2 = p.pos
	var best: Dictionary = {}
	var nearest: float = INF
	for e in enemies:
		if bool(e.dead):
			continue
		var d: float = here.distance_to(e.pos)
		if d < nearest and shot_can_follow(p, e):
			nearest = d
			best = e
	if best.is_empty():
		return best
	var old: int = int(p.target)
	p.turns = int(p.get("turns", 0)) + 1
	p.target = int(best.id)
	p.from = here
	p.end = best.pos
	p.age = 0.0
	p.duration = 0.05 if bool(p.beam) else maxf(0.035, nearest / (SWARM_SPEED if p.has("swarm") else (BODY_SPEED if p.has("body") else PROJECTILE_SPEED)))
	p.effective = float(p.damage) if bool(best.boss) else minf(float(p.damage), int(p.coverage) * float(best.unit_hp))
	best.reserved = float(best.reserved) + float(p.effective)
	retargeted.emit(old, int(best.id))
	return best

func burst_at(here: Vector2, radius: float, share: float, p: Dictionary, skip: Dictionary, visuals: bool) -> float:
	var dealt: float = 0.0
	var count: int = 0
	for other in enemies:
		if count >= 12:
			break
		if other == skip or bool(other.dead) or Vector2(other.pos).distance_to(here) > radius:
			continue
		dealt += apply_damage(other, share, int(p.coverage), int(p.weapon))
		count += 1
	if visuals:
		shell_burst.emit(here, radius, int(p.get("body_stage", p.weapon)), bool(p.crit))
	return dealt

func fire_body_special(attack: String, body_stage: int, slot: int, target: Dictionary, lanes: Array[Dictionary], beat: int) -> void:
	var amount: float = body_shot_damage() * int(ATTACK_EVERY.get(attack, 1))
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = body_coverage()
	var weapon_index: int = body_stage
	var origin: Vector2 = body_position(body_stage, slot)
	var destination: Vector2 = target.pos
	body_fired.emit(body_stage, slot, origin, destination, critical)
	var points := PackedVector2Array()
	var dealt: float = 0.0
	match attack:
		"swarm":
			# A rack of micro-missiles, each on its own threat.
			for j in range(SWARM_COUNT):
				var aim: Dictionary = target if j == 0 or lanes.is_empty() else lanes[(beat * 5 + j * 3) % lanes.size()]
				var m: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
				m.clear()
				var each: float = amount * 0.3
				var eff: float = each if bool(aim.boss) else minf(each, cap * float(aim.unit_hp))
				m.merge({"target": int(aim.id), "from": origin, "pos": origin, "end": aim.pos, "age": 0.0, "duration": maxf(0.05, origin.distance_to(aim.pos) / SWARM_SPEED), "damage": each, "effective": eff, "coverage": cap, "weapon": weapon_index, "crit": critical, "beam": false, "body": slot, "body_stage": body_stage, "attack": "swarm", "swarm": j})
				aim.reserved = float(aim.reserved) + eff
				shots.append(m)
			return
		"beam", "rail":
			# Beam: a lance to the target that scorches anything along it.
			# Rail: an instant slug through the target to the edge of space.
			var reach: Vector2 = destination if attack == "beam" else origin + (destination - origin).normalized() * 1400.0
			var width: float = 18.0 if attack == "beam" else 12.0
			var share: float = 0.6 if attack == "beam" else 0.8
			dealt += apply_damage(target, amount, cap, weapon_index, critical)
			var count: int = 0
			for e in enemies:
				if count >= (24 if attack == "beam" else 40):
					break
				if e == target or bool(e.dead):
					continue
				if Geometry2D.get_closest_point_to_segment(e.pos, origin, reach).distance_to(e.pos) <= width + float(e.radius) * .5:
					dealt += apply_damage(e, amount * share, cap, weapon_index)
					points.append(e.pos)
					count += 1
			body_strike.emit(attack, body_stage, slot, origin, reach, points, critical)
		"chain":
			# Lightning hops from threat to threat, weakening a little each jump.
			var current: Dictionary = target
			var visited: Array = []
			points.append(origin)
			for hop in range(7):
				points.append(current.pos)
				visited.append(current)
				dealt += apply_damage(current, amount * pow(0.82, hop), cap, weapon_index, critical and hop == 0)
				var next: Dictionary = {}
				var best: float = 170.0
				for e in enemies:
					if bool(e.dead) or visited.has(e):
						continue
					var d: float = Vector2(e.pos).distance_to(current.pos)
					if d < best:
						best = d
						next = e
				if next.is_empty():
					break
				current = next
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"gravity":
			# A gravity well opens on the target and grinds everything nearby.
			wells.append({"kind": "gravity", "pos": destination, "age": 0.0, "dur": 1.6, "radius": 115.0, "tick": 0.0, "step": 0.2, "damage": amount / 8.0, "coverage": cap, "weapon": weapon_index, "stage": body_stage, "slot": slot})
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"quake":
			# Three seismic shocks on the same spot, each ring wider than the last.
			wells.append({"kind": "quake", "pos": destination, "age": 0.0, "dur": 0.9, "radius": 90.0, "tick": 0.0, "step": 0.3, "damage": amount * 0.45, "coverage": cap, "weapon": weapon_index, "stage": body_stage, "slot": slot})
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"meteor":
			# A meteor shower called down around the target: six delayed impacts.
			var spin: float = float(beat % 7)
			for j in range(6):
				var spot: Vector2 = destination + (Vector2.ZERO if j == 0 else Vector2.from_angle(spin + j * 1.3) * (40.0 + j * 14.0))
				wells.append({"kind": "meteor", "pos": spot, "age": -(0.06 + j * 0.08), "dur": 0.42, "radius": 48.0, "tick": 0.42, "step": 1.0, "damage": amount * 0.4, "coverage": cap, "weapon": weapon_index, "stage": body_stage, "slot": slot})
				points.append(spot)
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"wave":
			# A wavefront rolls out in a cone toward the target.
			var axis: float = (destination - origin).angle()
			var count: int = 0
			dealt += apply_damage(target, amount, cap, weapon_index, critical)
			for e in enemies:
				if count >= 40:
					break
				if e == target or bool(e.dead):
					continue
				var rel: Vector2 = Vector2(e.pos) - origin
				if rel.length() <= 560.0 and absf(angle_difference(axis, rel.angle())) <= 0.38:
					dealt += apply_damage(e, amount * 0.55, cap, weapon_index)
					points.append(e.pos)
					count += 1
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"prism":
			# A beam that refracts at the target into a fan of four more.
			dealt += apply_damage(target, amount, cap, weapon_index, critical)
			points.append(destination)
			var picked: Array = [target]
			for j in range(4):
				var next: Dictionary = {}
				var best: float = 260.0
				for e in enemies:
					if bool(e.dead) or picked.has(e):
						continue
					var d: float = Vector2(e.pos).distance_to(destination)
					if d < best:
						best = d
						next = e
				if next.is_empty():
					break
				picked.append(next)
				points.append(next.pos)
				dealt += apply_damage(next, amount * 0.5, cap, weapon_index)
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
		"ring":
			# A shock ring bursts out of the body itself.
			var radius: float = 240.0
			var count: int = 0
			dealt += apply_damage(target, amount, cap, weapon_index, critical)
			for e in enemies:
				if count >= 40:
					break
				if e == target or bool(e.dead) or Vector2(e.pos).distance_to(origin) > radius:
					continue
				dealt += apply_damage(e, amount * 0.5, cap, weapon_index)
				points.append(e.pos)
				count += 1
			body_strike.emit(attack, body_stage, slot, origin, destination, points, critical)
	source_damage.body += dealt

func update_wells(delta: float) -> void:
	for i in range(wells.size() - 1, -1, -1):
		var w: Dictionary = wells[i]
		w.age = float(w.age) + delta
		while float(w.tick) <= float(w.age) and float(w.tick) <= float(w.dur):
			var shock: int = int(round(float(w.tick) / float(w.step)))
			w.tick = float(w.tick) + float(w.step)
			# Quakes widen with every shock; gravity and meteors keep their radius.
			var radius: float = float(w.radius) + (40.0 * shock if str(w.kind) == "quake" else 0.0)
			var count: int = 0
			var burn: bool = str(w.kind) == "burn"
			for e in enemies:
				if count >= 30:
					break
				if bool(e.dead):
					continue
				if burn:
					if Geometry2D.get_closest_point_to_segment(e.pos, w.pos, w.to).distance_to(e.pos) > radius + float(e.radius) * .5:
						continue
				elif Vector2(e.pos).distance_to(w.pos) > radius:
					continue
				source_damage.body += apply_damage(e, float(w.damage), int(w.coverage), int(w.weapon))
				count += 1
		if float(w.age) >= float(w.dur):
			wells.remove_at(i)

# ---------------- Doomsday weapons ----------------
func ultimate_kind() -> String:
	return ult_override if ult_override != "" else ULT_KINDS[mini(stage, ULT_KINDS.size() - 1)]

func ultimate_name() -> String:
	return TranslationServer.translate(ULT_NAMES[ULT_KINDS.find(ultimate_kind())])

func ultimate_ready() -> bool:
	if ult_unlimited:
		return mode in ["wave", "boss"] and not paused
	return ult_charge >= 1.0 and ult.is_empty() and mode in ["wave", "boss"] and not paused

func enemy_time_rate() -> float:
	if ult.is_empty():
		return 1.0
	var age: float = float(ult.age)
	match str(ult.kind):
		"lightspeed":
			if age >= LIGHTSPEED_IMPACT:
				return 1.0
			# Sources keep moving as FTL wakes gradually seal the low-light-speed domain.
			return lerpf(1.0, .035, smoothstep(0.0, LIGHT_DOMAIN_SEAL, age))
		"droplet":
			# From the pass until the last detonation everything hangs still.
			if age < DROPLET_PASS:
				return 1.0 - .7 * smoothstep(.2, DROPLET_PASS, age)
			if age < float(ult.get("cascade_end", DROPLET_PASS + 1.5)):
				return 0.0
			return 1.0
		"fourier":
			# Sampled: the swarm holds still while the curve is drawn through it.
			var end: float = FOURIER_TRACE + float(ult.get("trace_dur", 3.0)) + .15
			if age >= end:
				return 1.0
			return 1.0 - smoothstep(0.0, FOURIER_SAMPLE, age)
		"strings":
			# Reduced to strings, threats crawl while the extra dimensions shake.
			if age >= STRINGS_IMPACT:
				return 1.0
			return lerpf(1.0, .18, smoothstep(.6, STRINGS_REVEAL + .4, age))
	return 1.0

func densest_point() -> Vector2:
	var best: Vector2 = defense_position() + Vector2(0, -170)
	var most: int = -1
	for e in enemies:
		if bool(e.dead):
			continue
		var n: int = 0
		for o in enemies:
			if not bool(o.dead) and Vector2(o.pos).distance_to(e.pos) < 150.0:
				n += int(o.members)
		if n > most:
			most = n
			best = e.pos
	return best

func fire_ultimate(point: Vector2 = Vector2.INF) -> bool:
	if not ultimate_ready():
		return false
	var kind: String = ultimate_kind()
	if kind in ["photoid", "prime", "lightspeed", "pi", "droplet", "fourier", "mandelbrot", "strings"]:
		point = defense_position()
	elif point == Vector2.INF:
		point = densest_point()
	ult_charge = 1.0 if ult_unlimited else 0.0
	ult = {"kind": kind, "age": 0.0, "point": point, "step": 0, "boss_hit": false}
	match kind:
		"photoid":
			spawn_hold = 5.0 + PHOTOID_IMPACT
		"foil":
			spawn_hold = 6.2
		"prime":
			spawn_hold = 3.6
		"lightspeed":
			spawn_hold = LIGHTSPEED_IMPACT + 1.6
		"pi":
			spawn_hold = 4.0
		"droplet":
			spawn_hold = 4.2
		"fourier":
			spawn_hold = 5.4
		"mandelbrot":
			spawn_hold = 4.6
		"strings":
			spawn_hold = 5.8
		_:
			spawn_hold = 1.6
	ultimate_fired.emit(kind, point)
	checkpoint.emit()
	return true

func foil_half(age: float) -> float:
	# The square opens unhurriedly until it covers the whole visible screen,
	# however close to an edge it landed (half-width to the farthest corner).
	if ult.is_empty() or age < FOIL_OPEN:
		return 0.0
	var at: Vector2 = ult.point
	var r: Rect2 = spawn_rect.grow(120)
	var need: float = maxf(maxf(absf(r.position.x - at.x), absf(r.end.x - at.x)), maxf(absf(r.position.y - at.y), absf(r.end.y - at.y)))
	var k: float = clampf((age - FOIL_OPEN) / FOIL_GROW, 0.0, 1.0)
	return need * (1.0 - pow(1.0 - k, 2.2))

func ult_strike(e: Dictionary, weapon_index: int) -> float:
	if bool(e.dead):
		return 0.0
	if bool(e.boss):
		return apply_damage(e, boss_max_hp() * ULT_BOSS_SHARE, 1, weapon_index, false, true)
	return apply_damage(e, float(e.hp) + (int(e.members) - 1) * float(e.unit_hp) + 1.0, int(e.members), weapon_index, false, true)

func queue_ultimate_reward(point: Vector2, members: int, reward: float) -> void:
	var batch: Dictionary = ult.get("loot", {})
	if batch.is_empty() or bool(batch.released):
		batch = {"age": 0.0, "released": false, "kind": ult.get("kind", ultimate_kind()), "reward": 0.0, "drops": []}
		reward_batches.append(batch)
		if not ult.is_empty():
			ult.loot = batch
	# All kills in the same clear burst together one second after the last kill.
	batch.age = 0.0
	batch.reward = float(batch.reward) + reward
	batch.drops.append({"pos": point, "members": members})

func update_rewards(delta: float) -> void:
	for i in range(reward_batches.size() - 1, -1, -1):
		var batch: Dictionary = reward_batches[i]
		batch.age = float(batch.age) + delta
		if not bool(batch.released) and float(batch.age) >= ULT_LOOT_DELAY:
			batch.released = true
			for drop in batch.drops:
				ultimate_loot.emit(drop.pos, int(drop.members), maxf(.01, ULT_LOOT_DELAY + ULT_LOOT_FLIGHT - float(batch.age)))
		if float(batch.age) >= ULT_LOOT_DELAY + ULT_LOOT_FLIGHT:
			money += float(batch.reward)
			notice.emit("%s · + $%s" % [TranslationServer.translate(ULT_NAMES[ULT_KINDS.find(str(batch.kind))]), Catalog.number(float(batch.reward))])
			reward_batches.remove_at(i)

func ult_sweep(center: Vector2, radius: float, include_boss: bool) -> void:
	var w: int = stage
	for e in enemies.duplicate():
		if bool(e.dead) or Vector2(e.pos).distance_to(center) > radius + float(e.radius):
			continue
		if bool(e.boss) and not include_boss:
			continue
		ult_strike(e, w)

func crossed(at: float, delta: float) -> bool:
	var age: float = float(ult.age)
	return age >= at and age - delta < at

func update_ultimate(delta: float) -> void:
	if mode in ["wave", "boss"] and ult.is_empty():
		var from_kills: float = minf(ult_deaths * ULT_PER_KILL, ULT_KILL_RATE_CAP * delta)
		ult_charge = minf(1.0, ult_charge + delta / ULT_TIME + from_kills)
	ult_deaths = 0
	update_wells(delta)
	if ult.is_empty():
		return
	ult.age = float(ult.age) + delta
	var kind: String = ult.kind
	var at: Vector2 = ult.point
	var w: int = stage
	match kind:
		"nuke":
			if crossed(NUKE_IMPACT, delta):
				ult_sweep(at, NUKE_RADIUS, true)
				ultimate_impact.emit(kind, at)
		"photoid":
			if crossed(PHOTOID_IMPACT, delta):
				ult_sweep(at, 5000.0, true)
				ultimate_impact.emit(kind, at)
		"foil":
			# The foil unfolds into a plane that flattens everything it reaches.
			if crossed(FOIL_OPEN, delta):
				ultimate_impact.emit(kind, at)
			if float(ult.age) >= FOIL_OPEN:
				# Square sheet: everything inside its half-width (on both axes) is reduced.
				var radius: float = foil_half(float(ult.age))
				for e in enemies.duplicate():
					var rel: Vector2 = Vector2(e.pos) - at
					if bool(e.dead) or maxf(absf(rel.x), absf(rel.y)) > radius:
						continue
					if bool(e.boss):
						if not bool(ult.boss_hit):
							ult.boss_hit = true
							ult_strike(e, w)
						continue
					var spot: Vector2 = e.pos
					var silhouette: int = 3 if str(e.kind).contains("ship") else 4
					var heading: float = (Vector2(e.end) - Vector2(e.start)).angle() if silhouette == 3 else int(e.seed)
					var radius_before: float = float(e.radius)
					var members_before: int = int(e.members)
					ult_strike(e, w)
					flattened.emit(spot, radius_before, silhouette, heading, members_before)
		"prime":
			# Ten pulses: the n-th prime p erases p threats at once.
			var step: int = int(ult.step)
			if step < PRIMES.size() and float(ult.age) >= 0.5 + step * 0.28:
				ult.step = step + 1
				var prime: int = PRIMES[step]
				var targets: Array[Dictionary] = turret_lanes()
				var points := PackedVector2Array()
				var taken: int = 0
				for e in targets:
					if taken >= prime:
						break
					if bool(e.boss):
						apply_damage(e, boss_max_hp() * ULT_BOSS_SHARE / PRIMES.size(), 1, w, false, true)
						points.append(e.pos)
						continue
					points.append(e.pos)
					ult_strike(e, w)
					taken += 1
				prime_strike.emit(prime, points)
		"lightspeed":
			if crossed(LIGHTSPEED_IMPACT, delta):
				ult_sweep(at, 5000.0, true)
				ultimate_impact.emit(kind, at)
		"pi":
			if crossed(PI_IMPACT, delta):
				ult_sweep(at, 5000.0, true)
				ultimate_impact.emit(kind, at)
		"droplet":
			update_droplet(delta, w)
		"fourier":
			update_fourier(delta, w)
		"mandelbrot":
			if float(ult.age) >= MANDEL_START:
				var reach: float = mandel_radius(float(ult.age))
				for e in enemies.duplicate():
					if bool(e.dead) or Vector2(e.pos).distance_to(at) > reach + float(e.radius) * .5:
						continue
					if bool(e.boss):
						if not bool(ult.boss_hit):
							ult.boss_hit = true
							ult_strike(e, w)
						continue
					ult_strike(e, w)
			if crossed(MANDEL_COVER, delta):
				ultimate_impact.emit(kind, at)
		"strings":
			if crossed(STRINGS_IMPACT, delta):
				var snapped := PackedVector2Array()
				for e in enemies:
					if not bool(e.dead):
						snapped.append(e.pos)
				string_snap.emit(snapped)
				ult_sweep(at, 5000.0, true)
				ultimate_impact.emit(kind, at)
	if float(ult.age) >= float(ULT_DURATION.get(kind, 3.0)):
		ult = {}

func droplet_travel(stops: int) -> float:
	return clampf(.1 + stops * .0015, .12, .22)

func update_droplet(delta: float, w: int) -> void:
	var at: Vector2 = ult.point
	if crossed(DROPLET_PASS, delta):
		# One unbroken thread: nearest-neighbour order from the core.
		var left: Array[Dictionary] = []
		for e in enemies:
			if not bool(e.dead):
				left.append(e)
		var path := PackedVector2Array([at])
		var ids: Array[int] = []
		var here: Vector2 = at
		while not left.is_empty() and ids.size() < 400:
			var best: int = 0
			var nearest: float = INF
			for i in range(left.size()):
				var d: float = here.distance_squared_to(left[i].pos)
				if d < nearest:
					nearest = d
					best = i
			var e: Dictionary = left[best]
			left.remove_at(best)
			ids.append(int(e.id))
			here = e.pos
			path.append(here)
		var travel: float = droplet_travel(ids.size())
		ult["threaded"] = ids
		ult["travel"] = travel
		ult["shatter_at"] = DROPLET_PASS + travel + DROPLET_HOLD
		ult["cascade_end"] = DROPLET_PASS + travel + DROPLET_HOLD + DROPLET_CASCADE + .05
		ult.step = 0
		droplet_pass.emit(path)
		ultimate_impact.emit("droplet", at)
	if ult.has("travel") and crossed(DROPLET_PASS + float(ult.travel), delta):
		var path_end: Dictionary = find_enemy(int(ult.threaded.back())) if not ult.threaded.is_empty() else {}
		droplet_arrive.emit(path_end.pos if not path_end.is_empty() else Vector2(ult.point))
	if not ult.has("shatter_at") or float(ult.age) < float(ult.shatter_at):
		return
	# Detonations run down the path in the order the drop passed through.
	var ids: Array = ult.threaded
	var made: int = int(ult.get("made", 0))
	var span: float = DROPLET_CASCADE / maxf(1.0, float(ids.size() - 1))
	while int(ult.step) < ids.size() and float(ult.age) >= float(ult.shatter_at) + int(ult.step) * span:
		var k: int = int(ult.step)
		ult.step = k + 1
		var e: Dictionary = find_enemy(int(ids[k]))
		if e.is_empty():
			continue
		var spot: Vector2 = e.pos
		var radius: float = float(e.radius)
		if bool(e.boss):
			ult_strike(e, w)
			droplet_shatter.emit(spot, radius, 10, true)
			for j in range(10):
				if made < DROPLET_FRAGMENT_CAP:
					spawn_fragment(spot, radius * 1.4, j * TAU / 10.0 + .3)
					made += 1
			continue
		if bool(e.get("fragment", false)):
			# Fragments break only once: hit again, they are simply gone.
			ult_strike(e, w)
			droplet_shatter.emit(spot, radius, 0, false)
			continue
		var pieces: int = clampi(2 + int(log(float(maxi(1, int(e.members)))) / log(4.0)), 2, 5)
		ult_strike(e, w)
		droplet_shatter.emit(spot, radius, pieces, false)
		var spin: float = float(int(e.seed) % 628) * .01
		for j in range(pieces):
			if made >= DROPLET_FRAGMENT_CAP:
				break
			spawn_fragment(spot, radius, spin + j * TAU / pieces)
			made += 1
	ult["made"] = made

func spawn_fragment(from: Vector2, radius: float, angle: float) -> void:
	# A small body thrown off a shattered threat: weak and worth a little, but it
	# never harms the defense if it gets through (the droplet must stay a clear win).
	serial += 1
	var e: Dictionary = enemy_pool.pop_back() if not enemy_pool.is_empty() else {}
	e.clear()
	var core: Vector2 = defense_position()
	var origin: Vector2 = (from + Vector2.from_angle(angle) * (radius + 6.0)).clamp(spawn_rect.position, spawn_rect.end)
	var end: Vector2 = core + (origin - core).normalized() * 68.0
	var unit_hp: float = 25.0 * hp_scale() / (WAVE_SCALE if stage > 0 else 1)
	e.merge({"id": serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": rng.randf_range(9.0, 12.0), "members": 1, "initial_members": 1, "unit_hp": unit_hp, "hp": unit_hp, "kind": "fragment", "fragment": true, "elite": false, "seed": rng.randi_range(1, 99999), "reserved": 0.0, "radius": 7.0, "boss": false, "dead": false, "shard_angle": angle})
	enemies.append(e)
	enemies_by_id[int(e.id)] = e

func update_fourier(delta: float, w: int) -> void:
	var at: Vector2 = ult.point
	if crossed(FOURIER_SAMPLE, delta):
		# The tour: nearest neighbour from the core through every living threat.
		var left: Array[Dictionary] = []
		for e in enemies:
			if not bool(e.dead):
				left.append(e)
		var points := PackedVector2Array([at])
		var ids: Array[int] = [-1]
		var here: Vector2 = at
		while not left.is_empty() and ids.size() <= FOURIER_TOUR_CAP:
			var best: int = 0
			var nearest: float = INF
			for i in range(left.size()):
				var d: float = here.distance_squared_to(left[i].pos)
				if d < nearest:
					nearest = d
					best = i
			var e: Dictionary = left[best]
			left.remove_at(best)
			ids.append(int(e.id))
			here = e.pos
			points.append(here)
		# Arc-length fraction at which the drawing tip reaches each stop (closed loop).
		var total: float = 0.0
		var lengths := PackedFloat32Array([0.0])
		for i in range(1, points.size()):
			total += points[i - 1].distance_to(points[i])
			lengths.append(total)
		total += points[points.size() - 1].distance_to(points[0])
		var fractions := PackedFloat32Array()
		for i in range(points.size()):
			fractions.append(lengths[i] / maxf(1.0, total))
		ult["tour"] = ids
		ult["fractions"] = fractions
		ult["trace_dur"] = clampf(1.4 + points.size() * .016, 1.6, 3.6)
		ult.step = 1
		fourier_tour.emit(points, fractions)
	if not ult.has("tour") or float(ult.age) < FOURIER_TRACE:
		return
	var progress: float = (float(ult.age) - FOURIER_TRACE) / float(ult.trace_dur)
	var ids: Array = ult.tour
	var fractions: PackedFloat32Array = ult.fractions
	while int(ult.step) < ids.size() and fractions[int(ult.step)] <= progress:
		var k: int = int(ult.step)
		ult.step = k + 1
		var e: Dictionary = find_enemy(int(ids[k]))
		if e.is_empty():
			continue
		fourier_hit.emit(e.pos, k, ids.size() - 1)
		ult_strike(e, w)
	if progress >= 1.0 and not bool(ult.get("closed", false)):
		ult.closed = true
		ultimate_impact.emit("fourier", at)

func mandel_radius(age: float) -> float:
	# Bloom from the core until the boundary has passed the farthest visible corner.
	if ult.is_empty() or age < MANDEL_START:
		return 0.0
	var at: Vector2 = ult.point
	var r: Rect2 = spawn_rect.grow(80)
	var need: float = 0.0
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		need = maxf(need, at.distance_to(corner))
	var k: float = clampf((age - MANDEL_START) / (MANDEL_COVER - MANDEL_START), 0.0, 1.0)
	return need * pow(k, 1.7)

func shell_burst_at(center: Dictionary, p: Dictionary, visuals: bool) -> float:
	# The heavy shell detonates: every other threat inside the blast takes a share.
	var share: float = float(p.damage) * BODY_SPLASH_SHARE
	var dealt: float = 0.0
	var count: int = 0
	var here: Vector2 = center.pos
	for other in enemies:
		if count >= BODY_SPLASH_LIMIT:
			break
		if other == center or bool(other.dead) or Vector2(other.pos).distance_to(here) > BODY_SPLASH:
			continue
		dealt += apply_damage(other, share, int(p.coverage), int(p.weapon))
		count += 1
	if visuals:
		shell_burst.emit(here, BODY_SPLASH, int(p.get("body_stage", p.weapon)), bool(p.crit))
	return dealt

func fire_turret(slot: int, target: Dictionary) -> void:
	var p: Dictionary = shot_pool.pop_back() if not shot_pool.is_empty() else {}
	p.clear()
	var amount: float = turret_shot_damage()
	var critical: bool = rng.randf() < crit_chance()
	if critical:
		amount *= crit_multiplier()
	var cap: int = turret_coverage()
	var effective: float = amount if bool(target.boss) else minf(amount, cap * float(target.unit_hp))
	var origin: Vector2 = turret_position(slot)
	var destination: Vector2 = target.pos
	var speed: float = PROJECTILE_SPEED
	p.merge({"target": int(target.id), "from": origin, "pos": origin, "end": destination, "age": 0.0, "duration": maxf(0.035, origin.distance_to(destination) / speed), "damage": amount, "effective": effective, "coverage": cap, "weapon": 0, "crit": critical, "beam": false, "turret": slot})
	target.reserved = float(target.reserved) + effective
	shots.append(p)
	turret_fired.emit(slot, origin, destination, critical)

func add_effect(point: Vector2, kind: String, amount: float = 0.0, weapon: int = 0) -> void:
	if effects.size() >= 160:
		return
	var f: Dictionary = effect_pool.pop_back() if not effect_pool.is_empty() else {}
	f.clear()
	f.merge({"pos": point, "kind": kind, "age": 0.0, "duration": 0.8 if kind != "reward" else 1.3, "amount": amount, "weapon": weapon})
	effects.append(f)

func apply_damage(e: Dictionary, amount: float, cap: int, weapon_index: int, critical: bool=false, defer_reward: bool=false) -> float:
	if bool(e.dead):
		return 0.0
	if bool(e.boss):
		if not skill.is_empty() and str(skill.kind) == "tidal_shield" and str(skill.phase) == "active":
			amount *= .3
		var used: float = minf(float(e.hp), amount)
		e.hp = maxf(0.0, float(e.hp) - amount)
		e["flash"]=.09
		hit.emit(e.pos,weapon_index,used,critical,true,str(e.kind))
		weapon_damage[weapon_index] += used
		if float(e.hp) <= 0.0:
			e.dead = true
			add_effect(e.pos,"boss_burst",e.radius,weapon_index)
			if defer_reward:
				queue_ultimate_reward(e.pos, 1, float(stage_data().boss_reward) * reward_scale())
				boss_reward_queued = true
			deferred_kill = defer_reward
			destroyed.emit(e.pos,weapon_index,1,true,str(e.kind))
			deferred_kill = false
		return used
	event_mat = str(e.get("mat", "metal" if str(e.kind).contains("ship") else "rock"))
	var shield: float = float(e.get("shield", 0.0))
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		e.shield = shield - absorbed
		amount -= absorbed
		e["flash"] = .12
		weapon_damage[weapon_index] += absorbed
		if float(e.shield) <= 0.0:
			shield_broken.emit(e.pos, float(e.radius))
		if amount <= 0.0:
			hit.emit(e.pos, weapon_index, absorbed, critical, false, str(e.kind))
			return absorbed
	var budget: float = minf(amount, float(cap) * float(e.unit_hp))
	var initial_budget: float = budget
	var old_count: int = int(e.members)
	# Compare total HP before division: at later scales, floor((total - hp) /
	# unit_hp) can round down and leave one member alive after a lethal strike.
	var full_clear: bool = cap >= old_count and amount >= float(e.hp) + (old_count - 1) * float(e.unit_hp)
	e["flash"]=.12
	hit.emit(e.pos,weapon_index,minf(amount,float(old_count)*float(e.unit_hp)),critical,false,str(e.kind))
	if budget < float(e.hp):
		e.hp = float(e.hp) - budget
		weapon_damage[weapon_index] += budget
		return budget
	budget -= float(e.hp)
	var removed: int = old_count if full_clear else mini(old_count, 1 + int(floor(budget / float(e.unit_hp))))
	removed = mini(removed, cap)
	e.members = old_count - removed
	var consumed: float = float(e.hp) + (removed - 1) * float(e.unit_hp)
	if int(e.members) > 0:
		var remainder: float = minf(maxf(0.0, budget - (removed - 1) * float(e.unit_hp)), float(e.unit_hp) - 0.00001)
		e.hp = float(e.unit_hp) - remainder
		consumed += remainder
	else:
		e.hp = 0.0
		e.dead = true
		ult_deaths += 1
	var reward: float = removed * member_reward() * (2.0 if bool(e.elite) else 1.0) * (FRAGMENT_REWARD if bool(e.get("fragment", false)) else 1.0) * (CHILD_REWARD if bool(e.get("child", false)) else 1.0)
	if bool(e.get("flood", false)):
		# Flood groups pay until they have matched the wave's own budget once.
		reward = minf(reward, maxf(0.0, wave_total * member_reward() - flood_paid))
		flood_paid += reward
	if defer_reward:
		queue_ultimate_reward(e.pos, removed, reward)
	else:
		money += reward
	last_reward = reward
	kills += removed
	if removed>1 and not bool(e.dead):members_removed.emit(e.pos,weapon_index,removed,str(e.kind))
	wave_killed += removed
	weapon_damage[weapon_index] += minf(initial_budget, consumed)
	if bool(e.dead):
		if str(e.get("arch", "")) == "splitter" and not defer_reward and not bool(e.get("child", false)):
			# Copy what the pieces need: the dead entity is recycled before they spawn.
			pending_splits.append({"parent": child_seed(e), "pos": e.pos, "members": int(e.initial_members), "heading": (Vector2(e.end) - Vector2(e.start)).angle()})
		deferred_kill = defer_reward
		destroyed.emit(e.pos,weapon_index,int(e.initial_members),false,str(e.kind))
		deferred_kill = false
		add_effect(e.pos, "burst", float(e.radius), weapon_index)
		if not defer_reward:
			add_effect(e.pos, "reward", reward, weapon_index)
	return minf(initial_budget, consumed)

func advance(delta: float, visuals: bool = true) -> void:
	if paused or mode == "title":
		return
	if not external_reward_clock:
		update_rewards(delta)
	if mode in ["failed", "victory"]:
		return
	elapsed += delta
	mode_time += delta
	for i in range(effects.size() - 1, -1, -1):
		var fx: Dictionary = effects[i]
		fx.age = float(fx.age) + delta
		if float(fx.age) >= float(fx.duration) or not visuals:
			effect_pool.append(fx)
			effects.remove_at(i)
	if Campaign.advance_phase(self):
		return
	if mode not in ["wave", "boss"]:
		return
	wave_elapsed += delta
	# A new scale opens with a quiet deployment window before any threat arrives.
	if grace > 0.0:
		grace = maxf(0.0, grace - delta)
		refill = 0.0
	if spawn_hold > 0.0:
		refill = 0.0
	else:
		refill += delta
	spawn_hold = maxf(0.0, spawn_hold - delta)
	update_ultimate(delta)
	if mode not in ["wave", "boss"]:
		return
	if mode == "boss":
		update_escorts(delta)
	if mode == "wave" and stage > 0 and spawn_left > 0 and spawn_hold <= 0.0 and grace <= 0.0:
		# Space chapters: the wave keeps its schedule however fast the defense is.
		# When the field thins, extra flood groups arrive on top of the budget, so a
		# stronger defense harvests more instead of skipping ahead.
		spawn_clock -= delta
		topup_clock -= delta
		var burst: int = 0
		while spawn_left > 0 and burst < 6 and spawn_clock <= 0.0:
			var members: int = mini(spawn_left, group_size())
			if (serial + 1) % 9 == 0:
				members = 1
			spawn_enemy(members)
			spawn_left -= members
			burst += 1
			spawn_clock = maxf(spawn_clock, 0.0) + spawn_interval(members)
		# The flood holds its numbers: every group destroyed is replaced at once, so
		# a stronger defense spreads its fire over a full screen instead of emptying it.
		# (While a scale or a cleared field ramps back up, groups arrive staggered.)
		# Replacement is capped (FLOOD_GAP) so an overwhelming defense does not churn
		# hundreds of spawns a second; the field then thins, which reads as power.
		var ramping: bool = (wave == 1 and wave_elapsed < 8.0) or refill < 8.0
		if topup_clock <= 0.0 and living_count() < ramped_min_alive():
			topup_clock = TOPUP_GAP if ramping else FLOOD_GAP
			spawn_enemy(1 if (serial + 1) % 9 == 0 else group_size())
			enemies.back()["flood"] = true
	elif mode == "wave" and spawn_left > 0 and spawn_hold <= 0.0 and grace <= 0.0:
		spawn_clock -= delta
		var burst: int = 0
		topup_clock -= delta
		while spawn_left > 0 and burst < 6 and (spawn_clock <= 0.0 or (living_count() < ramped_min_alive() and topup_clock <= 0.0)):
			if spawn_clock > 0.0 and ((wave == 1 and wave_elapsed < 8.0) or refill < 8.0):
				topup_clock = TOPUP_GAP
			var members: int = mini(spawn_left, group_size())
			if stage >= 1 and (serial + 1) % 9 == 0:
				members = 1
			spawn_enemy(members)
			spawn_left -= members
			burst += 1
			spawn_clock = maxf(spawn_clock, 0.0) + spawn_interval(members)
	for e in enemies:
		if bool(e.dead):
			continue
		e["flash"]=maxf(0,float(e.get("flash",0))-delta)
		e.age = float(e.age) + delta * enemy_time_rate()
		var ratio: float = clampf(float(e.age) / float(e.lifetime), 0.0, 1.0)
		e.pos = enemy_point(e, ratio)
		if str(e.get("arch", "")) == "mother" and int(e.get("launched", 0)) < MOTHER_LAUNCHES and ratio < .85:
			e.launch_t = float(e.launch_t) - delta * enemy_time_rate()
			if float(e.launch_t) <= 0.0:
				e.launch_t = MOTHER_GAP
				e.launched = int(e.launched) + 1
				pending_minions.append(e)
	if not pending_splits.is_empty() or not pending_minions.is_empty():
		process_offspring()
	# Ready heavy weapons reserve group damage first; fast legacy launchers fill gaps.
	for i in range(LAST_STAGE, -1, -1):
		cooldowns[i] -= delta
		if not owned[i] or cooldowns[i] > 0.0:
			continue
		if automation or manual_held or manual_queued:
			var target: Dictionary = target_for_weapon() if automation else find_enemy(priority_id)
			if not target.is_empty() and pending_hp(target)<=0:
				target={}
			if not target.is_empty():
				fire_weapon(i, target)
				cooldowns[i] = shot_interval(i)
				manual_queued = false
	# Stateless staggered beat: turret k fires when its phase crosses a period
	# boundary, so saves need no turret cooldowns and replay deterministically.
	# Turrets are automatic and always busy: turret k takes the k-th soonest
	# living threat (ignoring damage the main guns have already reserved), so
	# the whole array sweeps every group at once instead of idling.
	var turret_total: int = turret_count()
	if turret_total > 0:
		var lanes: Array[Dictionary] = []
		var lanes_built: bool = false
		for k in range(turret_total):
			var phase: float = TURRET_PERIOD * k / turret_total
			if floor((elapsed + phase) / TURRET_PERIOD) > floor((elapsed - delta + phase) / TURRET_PERIOD):
				var target: Dictionary = {}
				if not lanes_built:
					lanes = turret_lanes()
					lanes_built = true
				var explicit: Dictionary = find_enemy(priority_id)
				if not explicit.is_empty():
					target = explicit
				elif not lanes.is_empty():
					target = lanes[k % lanes.size()]
				if not target.is_empty():
					fire_turret(k, target)
	# Converted bodies keep a staggered beat of their own, fanned like turrets.
	var body_total: int = total_bodies()
	if body_total > 0:
		var body_lanes: Array[Dictionary] = []
		var body_lanes_built: bool = false
		var beat: int = 0
		for s in range(stage + 1):
			for k in range(BODIES[s].size()):
				if not body_converted_at(s, k):
					continue
				var phase: float = BODY_PERIOD * beat / body_total
				beat += 1
				var tick_now: float = floor((elapsed + phase) / BODY_PERIOD)
				var every: int = int(ATTACK_EVERY.get(body_attack(s, k), 1))
				if tick_now > floor((elapsed - delta + phase) / BODY_PERIOD) and int(tick_now) % every == 0:
					if not body_lanes_built:
						body_lanes = turret_lanes()
						body_lanes_built = true
					var focus: Dictionary = find_enemy(priority_id)
					if not focus.is_empty():
						fire_body(s, k, focus, body_lanes, beat)
					elif not body_lanes.is_empty():
						fire_body(s, k, body_lanes[(beat * 3) % body_lanes.size()], body_lanes, beat)
	update_sweeps(delta)
	for i in range(shots.size() - 1, -1, -1):
		var p: Dictionary = shots[i]
		if not bool(p.get("stray", false)) and not bool(p.beam):
			shot_launch(p)
		p.age = float(p.age) + delta
		if bool(p.get("stray", false)):
			var t_stray: float = clampf(float(p.age) / float(p.duration), 0.0, 1.0)
			p.pos = Vector2(p.from).lerp(p.end, t_stray)
			if t_stray >= 1.0 or not spawn_rect.grow(200).has_point(p.pos):
				shot_pool.append(p)
				shots.remove_at(i)
			continue
		var target: Dictionary = find_enemy(int(p.target))
		if target.is_empty():
			# A queued pulse waits at the muzzle until its turn to leave.
			if float(p.age) < 0.0:
				continue
			# Target died in flight: the round swerves onto the nearest living
			# threat and still deals its damage there (at most MAX_RETARGETS times).
			target = retarget_shot(p)
			if target.is_empty():
				make_stray(p)
				continue
		if not target.is_empty():
			if not bool(p.beam) and not Guidance.within(Vector2(target.pos) - Vector2(p.from), shot_launch(p)):
				target.reserved = maxf(0.0, float(target.reserved) - float(p.effective))
				make_stray(p)
				continue
			p.end = target.pos
			# Magnetar field: a round entering it is likely bent away from the boss.
			var field: float = magnet_field_radius() if bool(target.boss) else 0.0
			if field > 0.0 and not p.has("field_checked") and Vector2(p.pos).distance_to(target.pos) <= field:
				p["field_checked"] = true
				if rng.randf() < MAGNET_DEFLECT:
					target.reserved = maxf(0.0, float(target.reserved) - float(p.effective))
					var side: float = 1.0 if rng.randf() < .5 else -1.0
					var turn: float = side * rng.randf_range(.9, 1.5)
					shot_deflected.emit(p.pos, (Vector2(p.end) - Vector2(p.from)).normalized(), turn)
					make_stray(p, turn)
					continue
		var t: float = clampf(float(p.age) / float(p.duration), 0.0, 1.0)
		p.pos = Vector2(p.from).lerp(p.end, t)
		if t >= 1.0 or target.is_empty():
			if not target.is_empty():
				target.reserved = maxf(0.0, float(target.reserved) - float(p.effective))
				# Who landed this hit, for listeners of `hit` (turret rounds carry weapon 0).
				landing_source = "turret" if p.has("turret") else ("body" if p.has("body") else "main")
				var spent: float = apply_damage(target, float(p.damage), int(p.coverage), int(p.weapon),bool(p.crit))
				landing_source = "main"
				source_damage["turret" if p.has("turret") else ("body" if p.has("body") else "main")] += spent
				if p.has("mode"):
					source_damage.main += land_special(p, target, visuals)
				if p.has("body"):
					var attack_kind: String = str(p.get("attack", "shell"))
					if attack_kind == "shell":
						source_damage.body += shell_burst_at(target, p, visuals)
					elif attack_kind == "cluster":
						# The shell splits into four bomblets that land in a cross.
						var spin: float = float(int(p.target) % 7)
						for j in range(4):
							var at: Vector2 = Vector2(target.pos) + Vector2.from_angle(spin + j * TAU / 4) * 48.0
							source_damage.body += burst_at(at, 62.0, float(p.damage) * 0.45, p, target, visuals)
				if stage >= 3 and int(levels.pierce) > 0 and float(p.damage) > spent:
					var spare: float = float(p.damage) - spent
					var radius: float = 55.0 + int(levels.area) * 2.0
					var traced: int=0
					for other in enemies:
						if other != target and not bool(other.dead) and Vector2(other.pos).distance_to(target.pos) < radius:
							spare -= apply_damage(other, spare, int(p.coverage), int(p.weapon))
							if visuals and traced<3:
								pierced.emit(target.pos,other.pos,int(p.weapon))
								traced+=1
							if spare <= 0.0:
								break
				if visuals:
					add_effect(p.end, "impact", 10.0 if not bool(p.crit) else 20.0, int(p.weapon))
			shot_pool.append(p)
			shots.remove_at(i)
	if mode == "boss":
		boss_remaining = maxf(0.0, float(stage_data().boss_window) - wave_elapsed - boss_penalty)
		var defeated: bool = false
		for e in enemies:
			if bool(e.boss) and bool(e.dead):
				defeated = true
		if defeated:
			finish_boss()
			return
		if boss_remaining <= 0.0:
			fail_stage()
			return
	else:
		for e in enemies:
			if not bool(e.dead) and float(e.age) >= float(e.lifetime):
				if bool(e.get("fragment", false)):
					# Droplet debris is spent matter: it burns up on the shield, harmless.
					e.dead = true
					if visuals:
						add_effect(e.pos, "impact", 8.0)
					continue
				var fraction: float = float(e.members) / maxi(1, int(e.initial_members))
				var impact: float = (25.0 if int(e.initial_members) > 1 or bool(e.elite) else 10.0) * fraction
				health = maxf(0.0, health - maxf(1.0, impact))
				e.dead = true
				if visuals:
					add_effect(e.pos, "breach", 25.0)
				if health <= 0.0:
					fail_stage()
					return
	for i in range(enemies.size() - 1, -1, -1):
		if bool(enemies[i].dead):
			enemies_by_id.erase(int(enemies[i].id))
			enemy_pool.append(enemies[i])
			enemies.remove_at(i)
	if mode == "wave" and spawn_left == 0 and wave < 10:
		# No pause between waves: the next one keeps the flood going.
		Campaign.next_wave(self)
	elif mode == "wave" and spawn_left == 0 and enemies.is_empty():
		mode = "intermission"
		mode_time = 0.0
		# The field is empty and the sim stops ticking rounds until the boss: anything
		# still in flight would hang mid-air, so retire it now.
		for p in shots:
			shot_pool.append(p)
		shots.clear()
		wells.clear()
		sweeps.clear()
		health = 100.0
		manual_held = false
		notice.emit(TranslationServer.translate("第 %d 波完成 · 防线已恢复") % wave)
		checkpoint.emit()

func finish_boss() -> void:
	Campaign.finish_boss(self)

func fail_stage() -> void:
	Campaign.fail_stage(self)

func retry() -> void:
	Campaign.retry(self)

func progress() -> float:
	return Campaign.progress(self)

func encode_entity(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	for key in ["pos", "start", "end", "from"]:
		if out.has(key) and out[key] is Vector2:
			var p: Vector2 = out[key]
			out[key] = [p.x, p.y]
	return out

func decode_entity(e: Dictionary) -> Dictionary:
	var out: Dictionary = e.duplicate()
	for key in ["pos", "start", "end", "from"]:
		if out.has(key) and out[key] is Array:
			out[key] = Vector2(float(out[key][0]), float(out[key][1]))
	return out

func snapshot() -> Dictionary:
	var actors: Array = []
	var projectiles: Array = []
	var loot: Array = []
	for batch in reward_batches:
		var saved_batch: Dictionary = batch.duplicate(true)
		for i in range(saved_batch.drops.size()):
			saved_batch.drops[i] = encode_entity(saved_batch.drops[i])
		loot.append(saved_batch)
	for e in enemies:
		actors.append(encode_entity(e))
	for p in shots:
		projectiles.append(encode_entity(p))
	return {"reward_batches": loot, "boss_reward_queued": boss_reward_queued, "game": "skyguard", "version": SAVE_VERSION, "stage": stage, "wave": wave, "mode": mode, "money": money, "health": health, "levels": levels.duplicate(), "owned": owned.duplicate(), "automation": automation, "elapsed": elapsed, "wave_elapsed": wave_elapsed, "mode_time": mode_time, "spawn_clock": spawn_clock, "bodies": bodies.duplicate(), "ult_charge": ult_charge, "spawn_left": spawn_left, "wave_total": wave_total, "wave_killed": wave_killed, "kills": kills, "attempts": attempts, "stage_bosses": stage_bosses, "boss_spawned": boss_spawned, "serial": serial, "boss_remaining": boss_remaining, "boss_penalty": boss_penalty, "transition_from": transition_from, "priority_id": priority_id, "cooldowns": cooldowns.duplicate(), "weapon_damage": weapon_damage.duplicate(), "rng_state": str(rng.state), "flood_paid": flood_paid, "introduced": introduced.duplicate(), "enemies": actors, "shots": projectiles}

# Version 2: ten chapters. Version 1 saves (six chapters) are migrated on load.
const SAVE_VERSION: int = 2
const V1_STAGE: Array[int] = [0, 1, 2, 6, 7, 8]
const V1_WEAPON: Array[int] = [0, 1, 2, 5, 7, 8]
# Old chapter -> per body slot: [new chapter, new slot] (dropped bodies map to -1).
const V1_BODIES: Array = [
	[[0, 0], [0, 1], [0, 2]],
	[[1, 0], [1, 1], [1, 2]],
	[[2, 0], [2, 1], [2, 2], [3, 0], [3, 1], [2, 4]],
	[[5, 1], [6, 0], [5, 3], [5, 4], [6, 5]],
	[[7, 0], [7, 1], [6, 3], [6, 4], [-1, -1], [-1, -1], [-1, -1]],
	[[8, 0], [7, 2], [7, 3], [7, 4], [7, 5], [8, 5]],
]

func saved_stage(data: Dictionary) -> int:
	# The chapter a save will resume in (old six-chapter saves are mapped forward).
	var raw: int = int(data.get("stage", 0))
	if int(data.get("version", SAVE_VERSION)) == 1:
		var old_mode: String = str(data.get("mode", "wave"))
		if old_mode == "victory":
			return LAST_STAGE
		return V1_STAGE[clampi(raw + (1 if old_mode == "transition" else 0), 0, 5)]
	return clampi(raw, 0, LAST_STAGE)

static func migrate_v1(old: Dictionary) -> Dictionary:
	# Old six-chapter campaigns resume at the matching new chapter. Battle state is
	# dropped (the wave restarts) and every weapon of a passed chapter is granted.
	var data: Dictionary = old.duplicate(true)
	var old_stage: int = clampi(int(old.get("stage", 0)), 0, 5)
	var old_mode: String = str(old.get("mode", "wave"))
	var stage_now: int = V1_STAGE[old_stage]
	var wave_now: int = clampi(int(old.get("wave", 1)), 1, 10)
	var mode_now: String = "wave"
	match old_mode:
		"boss", "intermission":
			mode_now = "intermission"
			wave_now = 10
		"transition":
			stage_now = V1_STAGE[mini(old_stage + 1, 5)]
			wave_now = 1
		"victory":
			# The old ending was the observable universe: the brane awaits.
			stage_now = LAST_STAGE
			wave_now = 1
	var money: float = float(old.get("money", 0.0))
	for batch in old.get("reward_batches", []):
		if batch is Dictionary:
			money += maxf(0.0, float(batch.get("reward", 0.0)))
	var owned_now: Array = []
	var cool_now: Array = []
	var damage_now: Array = []
	for i in range(STAGE_COUNT):
		owned_now.append(i <= stage_now and i < stage_now)
		cool_now.append(0.0)
		damage_now.append(0.0)
	var old_owned: Array = old.get("owned", [])
	var old_damage: Array = old.get("weapon_damage", [])
	for i in range(mini(6, old_owned.size())):
		if bool(old_owned[i]):
			owned_now[V1_WEAPON[i]] = true
		if i < old_damage.size():
			damage_now[V1_WEAPON[i]] = float(old_damage[i])
	owned_now[0] = true
	var bodies_now: Array = []
	for i in range(STAGE_COUNT):
		bodies_now.append(0)
	var old_bodies: Array = old.get("bodies", [])
	for s in range(mini(6, old_bodies.size())):
		var mask: int = int(old_bodies[s])
		for k in range(V1_BODIES[s].size()):
			var to: Array = V1_BODIES[s][k]
			if (mask >> k) & 1 == 1 and int(to[0]) >= 0 and int(to[0]) <= stage_now:
				bodies_now[int(to[0])] |= 1 << int(to[1])
	data.merge({"version": SAVE_VERSION, "stage": stage_now, "wave": wave_now, "mode": mode_now, "money": money, "owned": owned_now, "cooldowns": cool_now, "weapon_damage": damage_now, "bodies": bodies_now, "reward_batches": [], "boss_reward_queued": false, "enemies": [], "shots": [], "mode_time": 0.0, "wave_elapsed": 0.0, "boss_remaining": 0.0, "boss_penalty": 0.0, "priority_id": -1, "transition_from": stage_now, "migrated": true}, true)
	return data

func restore(data: Dictionary) -> bool:
	if str(data.get("game", "")) != "skyguard" or int(data.get("version", 0)) not in [1, SAVE_VERSION]:
		return false
	if int(data.get("version", 0)) == 1:
		if int(data.get("stage", -1)) not in range(6) or not data.get("levels", {}) is Dictionary:
			return false
		data = migrate_v1(data)
	if int(data.get("stage", -1)) not in range(STAGE_COUNT) or int(data.get("wave", 0)) not in range(1, 11):
		return false
	if str(data.get("mode", "")) not in ["wave", "intermission", "boss", "transition", "failed", "victory"]:
		return false
	if not data.get("levels", {}) is Dictionary or not data.get("owned", []) is Array or data.get("owned", []).size() != STAGE_COUNT:
		return false
	for key in levels:
		# Saves from before the turret upgrade simply start it at zero.
		if key == "turrets" and not data.levels.has(key):
			continue
		if not data.levels.has(key) or int(data.levels[key]) < 0 or int(data.levels[key]) > 1000:
			return false
	var saved_money: float = float(data.get("money", -1))
	if not is_finite(saved_money) or saved_money < 0.0:
		return false
	var saved_loot: Variant = data.get("reward_batches", [])
	if not saved_loot is Array or saved_loot.size() > 10000:
		return false
	for batch in saved_loot:
		if not batch is Dictionary or not batch.get("drops") is Array or str(batch.get("kind", "")) not in ULT_KINDS:
			return false
		if not is_finite(float(batch.get("reward", -1))) or float(batch.get("reward", -1)) < 0 or not is_finite(float(batch.get("age", -1))) or float(batch.get("age", -1)) < 0:
			return false
		for drop in batch.drops:
			if not drop is Dictionary or not drop.get("pos") is Array or drop.pos.size() != 2 or int(drop.get("members", 0)) <= 0:
				return false
	for key in ["health","elapsed","wave_elapsed","mode_time","spawn_clock","spawn_left","wave_total","wave_killed","kills","attempts","stage_bosses","serial","boss_remaining","transition_from","priority_id","rng_state","automation"]:
		if not data.has(key):
			return false
	for key in ["cooldowns","weapon_damage"]:
		if not data.get(key) is Array or data[key].size()!=STAGE_COUNT:
			return false
	for key in ["enemies","shots"]:
		if not data.get(key) is Array or data[key].size()>10000:
			return false
		for entity in data[key]:
			if not entity is Dictionary:
				return false
			var required: Array = ["id","pos","start","end","age","lifetime","members","initial_members","unit_hp","hp","kind","elite","seed","reserved","radius","boss","dead"] if key=="enemies" else ["target","from","pos","end","age","duration","damage","effective","coverage","weapon","crit","beam"]
			for field_name in required:
				if not entity.has(field_name):
					return false
			for vector_key in (["pos","start","end"] if key=="enemies" else ["from","pos","end"]):
				if not entity[vector_key] is Array or entity[vector_key].size()!=2:
					return false
			if key=="shots" and int(entity.weapon) not in range(STAGE_COUNT):
				return false
			if key=="enemies" and (float(entity.lifetime)<=0 or int(entity.members)<0):
				return false
	clear_battle()
	reward_batches.clear()
	for batch in saved_loot:
		var restored_batch: Dictionary = batch.duplicate(true)
		restored_batch.released = false
		for i in range(restored_batch.drops.size()):
			restored_batch.drops[i] = decode_entity(restored_batch.drops[i])
		reward_batches.append(restored_batch)
	boss_reward_queued = bool(data.get("boss_reward_queued", false))
	stage = int(data.stage)
	wave = int(data.wave)
	mode = str(data.mode)
	money = saved_money
	health = clampf(float(data.health), 0.0, 100.0)
	for key in levels:
		levels[key] = int(data.levels.get(key, 0))
	for i in range(STAGE_COUNT):
		owned[i] = bool(data.owned[i])
		cooldowns[i] = float(data.cooldowns[i])
		weapon_damage[i] = float(data.weapon_damage[i])
	owned[0] = true
	automation = bool(data.automation)
	elapsed = float(data.elapsed)
	wave_elapsed = float(data.wave_elapsed)
	mode_time = float(data.mode_time)
	spawn_clock = float(data.spawn_clock)
	spawn_left = int(data.spawn_left)
	var saved_bodies: Variant = data.get("bodies", [])
	for s in range(STAGE_COUNT):
		bodies[s] = int(saved_bodies[s]) if saved_bodies is Array and saved_bodies.size() == STAGE_COUNT else 0
	ult_charge = clampf(float(data.get("ult_charge", 0.0)), 0.0, 1.0)
	wave_total = int(data.wave_total)
	wave_killed = int(data.wave_killed)
	kills = int(data.kills)
	attempts = int(data.attempts)
	stage_bosses = int(data.stage_bosses)
	boss_spawned = int(data.get("boss_spawned", 0))
	flood_paid = maxf(0.0, float(data.get("flood_paid", 0.0)))
	introduced = Array(data.get("introduced", []))
	serial = int(data.serial)
	boss_remaining = float(data.boss_remaining)
	boss_penalty = float(data.get("boss_penalty", 0.0))
	escort_clock = 1.0
	transition_from = int(data.transition_from)
	priority_id = int(data.priority_id)
	rng.state = int(str(data.rng_state))
	for e in data.get("enemies", []):
		var restored_enemy: Dictionary = decode_entity(e)
		enemies.append(restored_enemy)
		enemies_by_id[int(restored_enemy.id)] = restored_enemy
	for p in data.get("shots", []):
		shots.append(decode_entity(p))
	paused = false
	manual_held = false
	if bool(data.get("migrated", false)):
		if mode == "wave":
			start_wave()
		else:
			clear_battle()
	return true

func boss_max_hp() -> float:
	return float(stage_data().boss_hp) * hp_scale(10)
