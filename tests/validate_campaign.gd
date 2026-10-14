extends SceneTree
# Full-campaign validation with the shipped data: the balanced purchase route,
# firing the doomsday weapon when charged. Reports per-chapter time, boss kill
# time against its window, retries, and the total.
# Usage: -- [no-ult]   (no-ult: never fires the ultimate, a weaker player)
const Combat = preload("res://scripts/combat.gd")
const Route = preload("res://tests/purchase_route.gd")

func _initialize() -> void:
	var ultimates: bool = "no-ult" not in OS.get_cmdline_user_args()
	var c = Combat.new()
	c.start_new(4262026)
	var stage_start: float = 0.0
	var boss_start: float = -1.0
	var stage_fails: int = 0
	var last_stage: int = 0
	var last_mode: String = c.mode
	for tick in range(20000000):
		if tick % 120 == 0 and c.mode != "transition":
			Route.buy(c, "balanced")
		c.manual_held = not c.automation
		if not c.automation:
			var t: Dictionary = c.target_for_weapon()
			if not t.is_empty():
				c.priority_id = int(t.id)
		if ultimates and c.ultimate_ready():
			c.fire_ultimate()
		if c.mode == "failed":
			print("  FAIL stage=%d wave=%s" % [c.stage, "boss" if last_mode == "boss" else str(c.wave)])
			stage_fails += 1
			c.retry()
		c.advance(1.0 / 60, false)
		if c.mode == "boss" and last_mode != "boss":
			boss_start = c.elapsed
		if last_mode == "boss" and c.mode in ["transition", "victory"]:
			var window: float = float(c.stage_data().boss_window)
			print("CHAPTER %d minutes=%.1f boss=%.0fs/%.0fs retries=%d" % [c.stage + 1, (c.elapsed - stage_start) / 60.0, c.elapsed - boss_start, window, stage_fails])
			stage_start = c.elapsed
			stage_fails = 0
		last_mode = c.mode
		if c.mode == "victory":
			break
	print("VALIDATE ultimates=%s total_minutes=%.1f retries=%d mode=%s" % [ultimates, c.elapsed / 60.0, c.attempts, c.mode])
	quit()
