extends Node
## 全局游戏状态单例 (阶段1骨架)
## 数值模型来源: design/balance.md (阶段0 拟合产物, tools/simulate.py)
##
## 设计稿对照:
## - 四资源: Minerals / Energy(容量) / Science / Credits  (§11)
## - 基础建筑无持续消耗, Energy = 供给/需求效率系数        (§12)
## - Minerals 每星球独立库存, 自动运输                      (§23)
## - 升级产出 ×1.65/级                                      (§14)

signal resources_changed
signal speed_changed(new_speed: int)

# ============ 数值常量 (阶段0 拟合, 见 design/balance.md) ============
# TODO(balance): 拟合完成后填入最终 fitted 值
const DRILL_OUT := 5.0        # Mining Drill Lv1 产出 /s
const LAB_OUT := 4.0          # Research Lab Lv1 产出 /s
const HUB_OUT := 10.0         # Commercial Hub Lv1 产出 /s
const GEN_OUT := 15.0         # 每座发电机 Energy 供给
const UPG_MULT := 1.65        # 每级升级产出倍率 (§14: 5/8/13/21)

const DRILL_BASE := 36.62     # 矿机基础造价 (Minerals) — 拟合值
const DRILL_GROWTH := 1.13    # 每座涨价倍数 — 拟合值
const GEN_BASE := 18.0
const GEN_GROWTH := 1.12
const LAB_BASE := 915.0
const LAB_GROWTH := 1.14
const HUB_BASE := 70.0
const HUB_GROWTH := 1.14
const UPG_BASE := 305.18      # 升级成本基准系数 (回本节奏主旋钮) — 拟合值
const UPG_RATIO := 1.9537     # 升级每级涨价 (与 1.65 产出比共同决定 τ) — 拟合值

const SHIP_BASE := 12207.0    # 殖民船基础造价 — 拟合值 (阶段2用)
const SHIP_GROWTH := 1.5608   # 殖民船每艘涨价 — 拟合值 (节拍闸门)
const DEP_HOME := 8           # 母星矿点数 (§10)
const EFF_PREF := 0.95        # 能量效率优先补机阈值 (§12)

# ============ 时间 ============
var speed: int = 1            # 1× / 2× / 4× (§40)
var elapsed: float = 0.0      # 游戏秒

# ============ 四资源 ============
var minerals: float = 20.0
var credits: float = 0.0
var science: float = 0.0
# Energy 不累积, 每帧算 demand/supply → efficiency

# ============ 帝国数据 (结构对齐 simulate.py) ============
# 每星球: d=矿机数 dl=矿机等级 l=实验室 ll=等级 h=商业中心 hl=等级
#          dep=矿点总数 sys=所属恒星系 minerals_stock=本星球矿物库存
var planets: Array[Dictionary] = []
var generators: int = 4       # 发电机全局计数 (阶段1单星系近似)
var tech_mult: float = 1.0    # 科技全局产量倍率
var tech_index: int = 0
var has_spaceport := false
var has_elevator := false


func _ready() -> void:
	if planets.is_empty():
		planets.append({
			"d": 1, "dl": 1, "l": 0, "ll": 1, "h": 0, "hl": 1,
			"dep": DEP_HOME, "sys": 0, "minerals_stock": 0.0,
		})


# ============ 生产 ============
func energy_demand() -> float:
	var d := 0.0
	for x in planets:
		d += 2.0 * x["d"] + x["l"] + x["h"]
	return d


func energy_efficiency() -> float:
	var d := energy_demand()
	if d <= 0.0:
		return 1.0
	return minf(1.0, generators * GEN_OUT / d)


func mineral_income() -> float:
	var s := 0.0
	for x in planets:
		s += x["d"] * DRILL_OUT * pow(UPG_MULT, x["dl"] - 1)
	return s * tech_mult * energy_efficiency()


func science_income() -> float:
	var s := 0.0
	for x in planets:
		s += x["l"] * LAB_OUT * pow(UPG_MULT, x["ll"] - 1)
	return s * energy_efficiency()


func credit_income() -> float:
	var s := 2.0 * planets.size()
	for x in planets:
		s += x["h"] * HUB_OUT * pow(UPG_MULT, x["hl"] - 1)
	return s * energy_efficiency()


## 主循环每帧调用 (main scene / 后台摘要模拟共用入口)
func tick(delta: float) -> void:
	var d := delta * speed
	elapsed += d
	minerals += mineral_income() * d
	science += science_income() * d
	credits += credit_income() * d
	resources_changed.emit()


# ============ 购买 ============
func drill_cost(planet_i: int) -> float:
	return DRILL_BASE * pow(DRILL_GROWTH, planets[planet_i]["d"])


func drill_upgrade_cost(planet_i: int) -> float:
	return drill_cost(planet_i) * UPG_BASE * pow(UPG_RATIO, planets[planet_i]["dl"])


func can_afford(mc: float, cc: float = 0.0) -> bool:
	return minerals >= mc and credits >= cc


func pay(mc: float, cc: float = 0.0) -> bool:
	if not can_afford(mc, cc):
		return false
	minerals -= mc
	credits -= cc
	return true


func buy_drill(planet_i: int) -> bool:
	var c := drill_cost(planet_i)
	if planets[planet_i]["d"] >= planets[planet_i]["dep"]:
		return false
	if not pay(c):
		return false
	planets[planet_i]["d"] += 1
	return true


func upgrade_drill(planet_i: int) -> bool:
	if planets[planet_i]["d"] < 1:
		return false
	var c := drill_upgrade_cost(planet_i)
	if not pay(c):
		return false
	planets[planet_i]["dl"] += 1
	return true


# ============ 存档 (阶段1: 结构先行) ============
func save_game() -> void:
	var data := {
		"version": 1,
		"elapsed": elapsed,
		"minerals": minerals,
		"credits": credits,
		"science": science,
		"planets": planets,
		"generators": generators,
		"tech_mult": tech_mult,
		"tech_index": tech_index,
		"has_spaceport": has_spaceport,
		"has_elevator": has_elevator,
		"speed": speed,
	}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func load_game() -> bool:
	if not FileAccess.file_exists("user://save.json"):
		return false
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		return false
	elapsed = parsed.get("elapsed", 0.0)
	minerals = parsed.get("minerals", 20.0)
	credits = parsed.get("credits", 0.0)
	science = parsed.get("science", 0.0)
	planets = parsed.get("planets", planets)
	generators = parsed.get("generators", 4)
	tech_mult = parsed.get("tech_mult", 1.0)
	tech_index = parsed.get("tech_index", 0)
	has_spaceport = parsed.get("has_spaceport", false)
	has_elevator = parsed.get("has_elevator", false)
	speed = parsed.get("speed", 1)
	return true
