extends SceneTree
# Measures how far cosmetic barrage rounds land from their (moving) target.
var game: Control
var pending: Array[Dictionary] = []
var errors: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func on_fired(_index: int, _origin: Vector2, _destination: Vector2, _critical: bool) -> void:
	var field = game.field
	var sim = game.sim
	if sim.shots.is_empty():
		return
	var id: int = int(sim.shots.back().target)
	var n: int = field.b_age.size()
	# Rounds from this volley were appended just now by the field's own handler.
	for i in range(maxi(0, n - field.barrage_size(_index)), n):
		pending.append({"id": id, "to": field.b_to[i], "at": sim.elapsed - field.b_age[i] + field.b_dur[i]})

func run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.store.enabled = false
	root.add_child(game)
	await process_frame
	game.saved = {}
	game.start_game()
	var sim = game.sim
	sim.stage = 2
	sim.wave = 6
	sim.automation = true
	sim.owned[1] = true
	sim.owned[2] = true
	sim.levels.damage = 30
	sim.levels.reload = 30
	sim.start_wave()
	sim.fired.connect(on_fired)
	for frame in range(1800):
		sim.advance(1.0 / 60)
		game.field.animate(1.0 / 60)
		for i in range(pending.size() - 1, -1, -1):
			if sim.elapsed >= float(pending[i].at):
				var target: Dictionary = sim.find_enemy(int(pending[i].id))
				if not target.is_empty():
					errors.append(Vector2(pending[i].to).distance_to(target.pos))
				pending.remove_at(i)
	errors.sort()
	var total: float = 0
	for e in errors:
		total += e
	print("AIM rounds=", errors.size(), " mean_px=", snappedf(total / maxi(1, errors.size()), .01), " p90_px=", snappedf(errors[int(errors.size() * .9)] if not errors.is_empty() else 0.0, .01))
	quit()
