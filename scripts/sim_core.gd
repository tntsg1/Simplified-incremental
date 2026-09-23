# sim_core.gd —《星际拓荒者》重做版 · 模拟内核
# 数值与规则层，与视图完全分离（无头可测、可被模拟器批量调用）。
# 设计依据: G:/CODE/星际拓荒者_重设计稿.md（§3 经济 / §4 能源 / §5 建造升级拆除 / §7 节奏）
# 参数以 res://data/balance.json 为准；本文件不含任何渲染代码。
extends RefCounted

const BALANCE_PATH := "res://data/balance.json"
const DEFAULT_SAVE_PATH := "user://zengliang_save.json"
var save_path := DEFAULT_SAVE_PATH
const OFFLINE_CAP := 12.0 * 3600.0   # 离线结算上限 12 小时

var grid_w := 9
var grid_h := 7
var deposits: Array = [Vector2i(1, 1), Vector2i(6, 1), Vector2i(2, 3), Vector2i(7, 3), Vector2i(1, 5), Vector2i(6, 5)]
var colony_tile := Vector2i(4, 3)

var upgrade_out_mult := 1.6
var upgrade_cost_mult := 2.2
var max_level := 5

var building_defs: Dictionary = {}
var milestone_defs: Dictionary = {}

var minerals := 140.0
var credits := 90.0
var science := 0.0
var elapsed := 0.0

# "x,y" -> {"type": String, "level": int, "spent_m": float, "spent_c": float}
var buildings: Dictionary = {}

func _init() -> void:
	_load_balance()

func _load_balance() -> void:
	building_defs = {
		"miner":    {"name": "矿机", "cost_minerals": 40.0, "cost_credits": 20.0, "energy": 2.0, "output": 5.0, "needs_deposit": true},
		"solar":    {"name": "太阳能阵列", "cost_minerals": 50.0, "cost_credits": 25.0, "energy": 0.0, "output": 15.0, "gen": true},
		"fusion":   {"name": "聚变堆", "cost_minerals": 800.0, "cost_credits": 400.0, "energy": 0.0, "output": 120.0, "gen": true},
		"lab":      {"name": "科研站", "cost_minerals": 120.0, "cost_credits": 60.0, "energy": 3.0, "output": 2.0, "kind": "science"},
		"commerce": {"name": "商业中心", "cost_minerals": 90.0, "cost_credits": 40.0, "energy": 2.0, "output": 3.0, "kind": "credits"},
	}
	milestone_defs = {
		"spaceport": {"name": "星港", "cost_minerals": 1500.0, "cost_credits": 800.0},
		"elevator":  {"name": "太空电梯", "cost_minerals": 6000.0, "cost_credits": 3000.0},
	}
	var f := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var root: Dictionary = parsed
	if root.has("start") and root["start"] is Dictionary:
		var s: Dictionary = root["start"]
		minerals = float(s.get("minerals", minerals))
		credits = float(s.get("credits", credits))
		science = float(s.get("science", science))
	if root.has("upgrade") and root["upgrade"] is Dictionary:
		var u: Dictionary = root["upgrade"]
		upgrade_out_mult = float(u.get("output_mult", upgrade_out_mult))
		upgrade_cost_mult = float(u.get("cost_mult", upgrade_cost_mult))
		max_level = int(u.get("max_level", max_level))
	if root.has("buildings") and root["buildings"] is Dictionary:
		var d: Dictionary = root["buildings"]
		for k in d.keys():
			building_defs[String(k)] = d[k]
	if root.has("milestones") and root["milestones"] is Dictionary:
		var m: Dictionary = root["milestones"]
		for k in m.keys():
			milestone_defs[String(k)] = m[k]

# ---------- 地块 ----------

func key_for(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func is_valid(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < grid_w and tile.y >= 0 and tile.y < grid_h

func is_deposit(tile: Vector2i) -> bool:
	return deposits.has(tile)

func building_at(tile: Vector2i) -> Dictionary:
	if buildings.has(key_for(tile)):
		var b: Dictionary = buildings[key_for(tile)]
		return b
	return {}

# ---------- 能源与产出 ----------

func output_for(b: Dictionary) -> float:
	var def: Dictionary = building_defs[String(b["type"])]
	return float(def["output"]) * pow(upgrade_out_mult, float(int(b["level"]) - 1))

func energy_supply() -> float:
	var total := 8.0   # 殖民中心基础供电
	for k in buildings.keys():
		var b: Dictionary = buildings[k]
		var def: Dictionary = building_defs[String(b["type"])]
		if def.get("gen", false):
			total += output_for(b)
	return total

func energy_demand() -> float:
	var total := 0.0
	for k in buildings.keys():
		var b: Dictionary = buildings[k]
		var def: Dictionary = building_defs[String(b["type"])]
		total += float(def["energy"]) * float(int(b["level"]))   # 需求随等级缩放（待校准）
	return total

func efficiency() -> float:
	var d := energy_demand()
	if d <= 0.0:
		return 1.0
	return minf(1.0, energy_supply() / d)

func rates() -> Dictionary:
	var eff := efficiency()
	var r := {"minerals": 0.0, "science": 0.0, "credits": 0.5}
	for k in buildings.keys():
		var b: Dictionary = buildings[k]
		var kind := String(b["type"])
		if kind == "miner":
			r["minerals"] = float(r["minerals"]) + output_for(b) * eff
		elif kind == "lab":
			r["science"] = float(r["science"]) + output_for(b) * eff
		elif kind == "commerce":
			r["credits"] = float(r["credits"]) + output_for(b) * eff
	return r

func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var r := rates()
	minerals += float(r["minerals"]) * seconds
	science += float(r["science"]) * seconds
	credits += float(r["credits"]) * seconds
	elapsed += seconds

# ---------- 建造 / 升级 / 拆除 ----------

func can_afford(cost: Dictionary) -> bool:
	return minerals >= float(cost["minerals"]) and credits >= float(cost["credits"])

func build_cost(kind: String) -> Dictionary:
	var def: Dictionary = building_defs[kind]
	return {"minerals": float(def["cost_minerals"]), "credits": float(def["cost_credits"])}

func can_build(kind: String, tile: Vector2i) -> bool:
	if not building_defs.has(kind) or not is_valid(tile) or tile == colony_tile:
		return false
	if not building_at(tile).is_empty():
		return false
	var def: Dictionary = building_defs[kind]
	var needs_deposit := bool(def.get("needs_deposit", false))
	if needs_deposit != is_deposit(tile):
		return false
	return can_afford(build_cost(kind))

func build(kind: String, tile: Vector2i) -> bool:
	if not can_build(kind, tile):
		return false
	var cost := build_cost(kind)
	minerals -= float(cost["minerals"])
	credits -= float(cost["credits"])
	buildings[key_for(tile)] = {
		"type": kind, "level": 1,
		"spent_m": float(cost["minerals"]), "spent_c": float(cost["credits"]),
	}
	return true

func upgrade_cost(b: Dictionary) -> Dictionary:
	var def: Dictionary = building_defs[String(b["type"])]
	var mult := pow(upgrade_cost_mult, float(int(b["level"])))
	return {
		"minerals": ceilf(float(def["cost_minerals"]) * mult),
		"credits": ceilf(float(def["cost_credits"]) * mult),
	}

func can_upgrade(tile: Vector2i) -> bool:
	var b := building_at(tile)
	if b.is_empty() or int(b["level"]) >= max_level:
		return false
	return can_afford(upgrade_cost(b))

func upgrade(tile: Vector2i) -> bool:
	if not can_upgrade(tile):
		return false
	var b: Dictionary = buildings[key_for(tile)]
	var cost := upgrade_cost(b)
	minerals -= float(cost["minerals"])
	credits -= float(cost["credits"])
	b["level"] = int(b["level"]) + 1
	b["spent_m"] = float(b["spent_m"]) + float(cost["minerals"])
	b["spent_c"] = float(b["spent_c"]) + float(cost["credits"])
	return true

func remove(tile: Vector2i) -> bool:
	var b := building_at(tile)
	if b.is_empty():
		return false
	# §5: 拆除全额返还建造与升级投入
	minerals += float(b["spent_m"])
	credits += float(b["spent_c"])
	buildings.erase(key_for(tile))
	return true

# ---------- 辅助 ----------

# 回本时间（秒）：以矿物成本对新增矿物产出估算；gain<=0 返回 -1
func payback(cost_minerals: float, gain_per_s: float) -> float:
	if gain_per_s <= 0.0:
		return -1.0
	return cost_minerals / gain_per_s

func fmt_num(v: float) -> String:
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 1000.0:
		return "%.1fK" % (v / 1000.0)
	return "%.1f" % v

# ---------- 存档 / 离线 ----------

func to_dict() -> Dictionary:
	return {
		"version": 2, "elapsed": elapsed,
		"minerals": minerals, "credits": credits, "science": science,
		"buildings": buildings, "saved_at": Time.get_unix_time_from_system(),
	}

func save_now() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()

func save_exists() -> bool:
	return FileAccess.file_exists(save_path)

# 读取存档并结算离线收益；返回离线秒数（-1 = 无存档）
func load_and_advance() -> float:
	if not save_exists():
		return -1.0
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return -1.0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return -1.0
	var d: Dictionary = parsed
	elapsed = float(d.get("elapsed", 0.0))
	minerals = float(d.get("minerals", minerals))
	credits = float(d.get("credits", credits))
	science = float(d.get("science", science))
	if d.has("buildings") and d["buildings"] is Dictionary:
		buildings = d["buildings"]
	var offline := float(Time.get_unix_time_from_system()) - float(d.get("saved_at", 0.0))
	offline = clampf(offline, 0.0, OFFLINE_CAP)
	advance(offline)
	return offline