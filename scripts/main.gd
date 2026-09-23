extends Node
## 阶段1 占位主场景: 验证 GameState tick 管线 (headless 可跑)
## 正式版此场景被 母星地表 / 恒星系 / 银河 三层视图替换

@onready var info: Label = $UI/Info


func _process(delta: float) -> void:
	GameState.tick(delta)
	_refresh()


func _refresh() -> void:
	var eff := GameState.energy_efficiency()
	info.text = "Stellar Ascension — 骨架验证\n" \
		+ "时间: %.0fs (×%d)\n" % [GameState.elapsed, GameState.speed] \
		+ "MINERALS  %.2f   +%.1f/s\n" % [GameState.minerals, GameState.mineral_income()] \
		+ "ENERGY    %.0f / %.0f  (效率 %.0f%%)\n" % [
			GameState.generators * GameState.GEN_OUT,
			GameState.energy_demand(), eff * 100.0] \
		+ "SCIENCE   %.2f   +%.2f/s\n" % [GameState.science, GameState.science_income()] \
		+ "CREDITS   %.2f   +%.2f/s\n" % [GameState.credits, GameState.credit_income()] \
		+ "星球: %d  矿机: %d  等级: Lv.%d" % [
			GameState.planets.size(),
			GameState.planets[0]["d"], GameState.planets[0]["dl"]]
