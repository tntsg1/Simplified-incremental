extends RefCounted

const HALF_CONE: float = PI / 6.0
const MAX_ANGULAR_SPEED: float = PI * 2.0 / 3.0

static func within(direction: Vector2, launch: float) -> bool:
	return direction.length_squared() > 0.000001 and absf(wrapf(direction.angle() - launch, -PI, PI)) <= HALF_CONE + 0.000001

static func control(from: Vector2, heading: Vector2, to: Vector2) -> Vector2:
	return from + heading.normalized() * from.distance_to(to) * 0.5

static func accepts(from: Vector2, ctrl: Vector2, to: Vector2, launch: float, speed: float) -> bool:
	var a: Vector2 = 2.0 * (ctrl - from)
	var b: Vector2 = 2.0 * (to - 2.0 * ctrl + from)
	# The derivative is a convex combination of the end tangents. Checking both
	# bounds the entire curve, including every subsequent retarget, to +/-30 deg.
	if not within(a, launch) or not within(a + b, launch):
		return false
	var t: float = clampf(-a.dot(b) / b.length_squared(), 0.0, 1.0) if b.length_squared() > 0.000001 else 0.0
	var minimum: float = (a + b * t).length()
	return minimum > 0.001 and absf(a.cross(b)) * speed / pow(minimum, 3.0) <= MAX_ANGULAR_SPEED + 0.000001
