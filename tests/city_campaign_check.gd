extends SceneTree
const Combat = preload("res://scripts/combat.gd")
const Route = preload("res://tests/purchase_route.gd")
func _initialize() -> void:
	var c = Combat.new()
	c.start_new(4262026)
	for tick in range(120000):
		if tick % 120 == 0: Route.buy(c,"balanced")
		c.manual_held = not c.automation
		if not c.automation:
			var aim: Dictionary = c.target_for_weapon()
			if not aim.is_empty(): c.priority_id = int(aim.id)
		c.advance(1.0/60.0,false)
		if c.mode == "failed":
			push_error("Balanced city route failed before boss")
			quit(1); return
		if c.mode == "boss": break
	if c.mode != "boss":
		push_error("City route did not reach boss"); quit(1); return
	# Compare both decisions from the same earned build, RNG and boss entrance.
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(c.snapshot()))
	var result: Array = []
	var failed: bool = false
	for parts in [false,true]:
		var battle = Combat.new()
		battle.restore(snapshot)
		battle.automation = true
		battle.select_city_part(parts)
		for tick in range(3000):
			battle.advance(1.0/60.0,false)
			if battle.mode != "boss": break
		var row: Dictionary = {"attack_fissure":parts,"result":battle.mode,"boss_seconds":battle.wave_elapsed,"defense":battle.health,"impact_penalty":battle.boss_penalty,"levels":battle.levels.duplicate()}
		result.append(row)
		if battle.mode != "transition": failed=true
		if battle.mode == "transition":
			for tick in range(2000):
				battle.advance(1.0/60.0,false)
				if battle.stage == 1: break
			if battle.stage != 1 or battle.mode != "wave": failed=true
	var file := FileAccess.open("res://build/city-boss/campaign.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CITY_CAMPAIGN ",JSON.stringify(result)," failures=",1 if failed else 0)
	quit(1 if failed else 0)
