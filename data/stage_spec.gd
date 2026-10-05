extends Resource
@export var wave_members: PackedInt32Array = PackedInt32Array([1,2,3,5,8,12,18,27,40,60])
@export var wave_density: PackedInt32Array = PackedInt32Array([1,1,2,4,8,16,24,32,48,64])

@export var title: String = ""
@export var subtitle: String = ""
@export var scale_label: String = ""
@export var accent: Color = Color.WHITE
@export var count_multiplier: int = 1
@export var reward_multiplier: float = 1.0
@export var regular_seconds: float = 480.0
@export var boss_hp: float = 50000.0
@export var boss_window: float = 45.0
@export var boss_title: String = ""
@export var boss_kind: String = "asteroid"
@export var weapon_price: float = 0.0
@export var boss_reward: float = 400.0
@export var briefing: String = ""
