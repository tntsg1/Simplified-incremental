# sim_test.gd — 数值内核无头回归测试
# 运行: "E:/godot/godot47/Godot_v4.7-stable_win64_console.exe" --headless --path "E:/godot/zengliang" --script res://tests/sim_test.gd
extends SceneTree

var fails := 0
var total := 0


func check(cond: bool, name: String) -> void:
	total += 1
	if cond:
		print("  PASS  ", name)
	else:
		fails += 1
		print("  FAIL  ", name)


func _init() -> void:
	print("== zengliang · sim_core 回归 ==")
	var sim = load("res://scripts/sim_core.gd").new()
	check(is_equal_approx(float(sim.minerals), 140.0) and is_equal_approx(float(sim.credits), 90.0), "初始资源")
	check(is_equal_approx(float(sim.rates()["minerals"]), 0.0), "无矿机时产出为 0")
	var d0: Vector2i = sim.deposits[0]
	check(sim.build("miner", d0), "在矿点上建矿机")
	check(is_equal_approx(float(sim.minerals), 100.0), "建造扣矿物 40")
	check(is_equal_approx(float(sim.rates()["minerals"]), 5.0), "单矿机产出 5/s")
	check(not sim.can_build("miner", Vector2i(3, 1)), "普通地块不能建矿机")
	check(not sim.can_build("solar", d0), "矿点上不能建太阳能")
	# 能源不足：5 台矿机需求 10 > 供给 8
	sim.minerals = 500.0
	sim.credits = 500.0
	for i in range(1, 5):
		check(sim.build("miner", sim.deposits[i]), "批量建矿机 %d" % i)
	check(is_equal_approx(sim.efficiency(), 0.8), "能源不足时效率 = 供给/需求")
	check(is_equal_approx(float(sim.rates()["minerals"]), 20.0), "产出按效率折算 5×5×0.8")
	check(sim.build("solar", Vector2i(3, 1)), "建太阳能")
	check(is_equal_approx(sim.efficiency(), 1.0), "补能源后效率恢复")
	# 升级曲线
	var b: Dictionary = sim.building_at(d0)
	var c1: Dictionary = sim.upgrade_cost(b)
	check(int(c1["minerals"]) == 88 and int(c1["credits"]) == 44, "Lv1→2 成本 ×2.2 = 88/44")
	sim.minerals = 5000.0
	sim.credits = 5000.0
	check(sim.upgrade(d0), "升级矿机")
	var b2: Dictionary = sim.building_at(d0)
	check(int(b2["level"]) == 2, "等级 = 2")
	check(is_equal_approx(sim.output_for(b2), 8.0), "产出 ×1.6 → 8/s")
	# 拆除全额返还
	var m_before: float = sim.minerals
	check(sim.remove(d0), "拆除矿机")
	check(is_equal_approx(float(sim.minerals), m_before + float(b2["spent_m"])), "全额返还建造+升级投入")
	# 结算一致性
	var r: Dictionary = sim.rates()
	var m0: float = sim.minerals
	sim.advance(10.0)
	check(absf(float(sim.minerals) - (m0 + float(r["minerals"]) * 10.0)) < 0.01, "advance 与速率一致")
	# 存档 + 离线（用测试专用路径，避免污染游戏存档）
	sim.save_path = "user://sim_test_save.json"
	sim.save_now()
	var sim2 = load("res://scripts/sim_core.gd").new()
	sim2.save_path = "user://sim_test_save.json"
	var off = sim2.load_and_advance()
	check(float(off) >= 0.0, "读档 + 离线结算")
	check(sim2.buildings.size() == sim.buildings.size(), "建筑数一致")
	print("== 结果: %d/%d 通过 ==" % [total - fails, total])
	quit(1 if fails > 0 else 0)