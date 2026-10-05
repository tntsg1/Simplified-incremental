extends SceneTree
const Combat=preload("res://scripts/combat.gd")
func sample(stage: int, area: int, pierce: int) -> Dictionary:
	var c=Combat.new()
	c.start_new(543)
	c.stage=stage
	c.mode="wave"
	c.spawn_left=0
	c.levels.damage=60
	c.levels.reload=stage*10
	c.levels.area=area
	c.levels.pierce=pierce
	c.clear_battle()
	for i in range(3):
		c.spawn_enemy(1000000)
		var e: Dictionary=c.enemies.back()
		e.pos=Vector2(480+i*18,250)
		e.start=e.pos
		e.end=e.pos
		e.lifetime=100.0
	c.fire_weapon(stage,c.enemies[0])
	for i in range(40):c.advance(1.0/60,false)
	return {"kills":c.kills,"coverage":c.coverage(stage),"remaining":3000000-c.kills,"neighbor_losses":(1000000-int(c.enemies[1].members))+(1000000-int(c.enemies[2].members))}
func _initialize() -> void:
	var failures: int=0
	for stage in range(2,6):
		var before: Dictionary=sample(stage,0,0)
		var area10: Dictionary=sample(stage,10,0)
		var area25: Dictionary=sample(stage,25,0)
		var piercing: Dictionary=sample(stage,10,10 if stage>=3 else 0)
		var passed: bool=int(area10.kills)>int(before.kills) and int(area25.kills)>int(area10.kills)
		if stage>=3:passed=passed and int(piercing.neighbor_losses)>0
		if not passed:failures+=1
		print("COVERAGE stage=",stage," baseline=",before," area10=",area10," area25=",area25," pierce10=",piercing," pass=",passed)
	print("COVERAGE failures=",failures)
	quit(1 if failures else 0)
