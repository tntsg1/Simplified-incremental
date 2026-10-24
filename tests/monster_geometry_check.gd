extends SceneTree
const Art = preload("res://scripts/monster_art.gd")
var failures: int = 0
var checks: int = 0
func original_ring(c: Vector2, r: float, n: int, rot: float, jitter: float, seed_value: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var k: float = 1.0 + (jitter * sin(i * 2.7 + seed_value * .37) if jitter > 0.0 else 0.0)
		out.append(c + Vector2.from_angle(rot + i * TAU / n) * r * k)
	return out
func original_oval(c: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a: float = i * TAU / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out
func compare(actual: PackedVector2Array, expected: PackedVector2Array) -> void:
	checks += 1
	if actual.size() != expected.size():
		failures += 1
		return
	for i in range(actual.size()):
		if actual[i].distance_to(expected[i]) > .002:
			failures += 1
			push_error("Geometry moved at vertex %d: %s vs %s" % [i, actual[i], expected[i]])
			return
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4262026
	for n in [-1, 0, 3, 4, 5, 6, 7, 9, 10, 12, 20, 40, 128, 129]:
		for j in range(50):
			var at := Vector2(rng.randf_range(-120, 1200), rng.randf_range(-100, 700))
			var radius: float = rng.randf_range(.1, 200)
			var angle: float = rng.randf_range(-128, 128) if j % 2 == 0 else rng.randf_range(-100000, 100000)
			for jitter in [0.0, .14, .35]:
				compare(Art.ring_pts(at, radius, n, angle, jitter, j), original_ring(at, radius, n, angle, jitter, j))
			compare(Art.oval(at, radius, radius * .4, angle, n), original_oval(at, radius, radius * .4, angle, n))
	# A caller may edit its returned array without corrupting cached unit vertices.
	var ring: PackedVector2Array = Art.ring_pts(Vector2.ZERO, 5, 12)
	ring[0] = Vector2(100, 100)
	compare(Art.ring_pts(Vector2.ZERO, 5, 12), original_ring(Vector2.ZERO, 5, 12, 0, 0, 0))
	for optimized in [false, true]:
		var start: int = Time.get_ticks_usec()
		for i in range(20000):
			if optimized:
				Art.ring_pts(Vector2(500, 320), 20, 12, i * .01)
				Art.ring_pts(Vector2(500, 320), 20, 9, i * .01, .14, i % 100)
				Art.oval(Vector2(500, 320), 20, 12, i * .01)
			else:
				original_ring(Vector2(500, 320), 20, 12, i * .01, 0, 0)
				original_ring(Vector2(500, 320), 20, 9, i * .01, .14, i % 100)
				original_oval(Vector2(500, 320), 20, 12, i * .01, 20)
		print("GEOMETRY_BENCH optimized=", optimized, " ms=", (Time.get_ticks_usec() - start) / 1000.0)
	print("MONSTER_GEOMETRY checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
