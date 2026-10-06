extends SceneTree
const Combat = preload("res://scripts/combat.gd")

func _initialize() -> void:
	var path: String = "user://skyguard_save_v1.json"
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var c = Combat.new()
	if not c.restore(saved):
		push_error("Cannot restore current save for read-only probe")
		quit(1)
		return
	var result: Dictionary = {"source": ProjectSettings.globalize_path(path), "snapshot_stage": c.stage, "snapshot_wave": c.wave, "levels": c.levels.duplicate(), "money": c.money, "owned": c.owned.duplicate(), "converted_bodies": c.total_bodies(), "nominal_dps": c.nominal_dps(), "boss_hp": c.boss_max_hp(), "boss_window": c.stage_data().boss_window, "main_weapon_price": c.stage_data().weapon_price, "damage10_cost": c.upgrade_cost(0, 10), "reload_next_milestone_cost": c.upgrade_cost(2, 10 - int(c.levels.reload) % 10), "waves": []}
	for w in range(c.wave, 11):
		c.wave = w
		var total_hp: float = float(c.stage_data().wave_members[w - 1]) * float(c.stage_data().count_multiplier) * c.wave_density() * 100.0 * c.hp_scale(w)
		result.waves.append({"wave": w, "regular_hp_reference": total_hp, "nominal_wave_seconds": c.wave_seconds(), "dps_reference": total_hp / c.wave_seconds(), "coverage_per_second": c.arsenal_rate(c.coverage) * (1.0 + .05 * int(c.levels.turrets) + c.BODY_SHARE * c.total_bodies()), "nominal_dps_ratio": c.nominal_dps() / (total_hp / c.wave_seconds())})
	c.restore(saved)
	var start: float = c.elapsed
	var kills: int = c.kills
	var money: float = c.money
	for tick in range(100000):
		if c.mode in ["failed", "transition", "victory"]:
			break
		c.advance(1.0 / 60.0, false)
	result["unchanged_upgrades_probe"] = {"mode": c.mode, "wave": c.wave, "elapsed": c.elapsed - start, "kills": c.kills - kills, "income": c.money - money, "health": c.health}
	var file = FileAccess.open("res://proofs/player_dps_probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("PLAYER_DPS_PROBE ", JSON.stringify(result))
	quit()
