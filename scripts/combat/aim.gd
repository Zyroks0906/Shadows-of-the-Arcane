extends RefCounted
class_name Aim

# Soft aim assist. The player always aims with the cursor (or right stick); when an
# enemy sits inside a cone around that line and within the weapon's range, the shot is
# bent part of the way towards it. Bending only part of the way (strength < 1) keeps
# aiming a skill: a sloppy aim still misses.

# Assist strength options shown in Settings (No / Low / Normal / High).
const STRENGTHS := [0.0, 0.5, 0.75, 0.9]
const MOUSE_CONE_DEG := 25.0
const PAD_CONE_DEG := 35.0
const PAD_STRENGTH_BONUS := 0.1

# Returns the enemy closest to the aim line (not to the player) inside the cone, or null.
static func find_target(origin: Vector2, dir: Vector2, max_range: float, cone_deg: float, candidates: Array) -> Node2D:
	if dir == Vector2.ZERO:
		return null
	var cone := deg_to_rad(cone_deg)
	var best: Node2D = null
	var best_score := INF
	for c in candidates:
		var e := c as Node2D
		if not e or not is_instance_valid(e) or not e.is_inside_tree():
			continue
		if "is_alive" in e and not e.is_alive:
			continue
		var to := e.global_position - origin
		var dist := to.length()
		if dist < 0.001 or dist > max_range:
			continue
		var ang := absf(dir.angle_to(to))
		if ang > cone:
			continue
		# Perpendicular distance to the aim line: what "closest to where I'm pointing" means.
		var score := dist * sin(ang)
		if score < best_score:
			best_score = score
			best = e
	return best

static func assist(origin: Vector2, dir: Vector2, max_range: float, cone_deg: float, strength: float, candidates: Array) -> Vector2:
	dir = dir.normalized()
	if strength <= 0.0:
		return dir
	var target := find_target(origin, dir, max_range, cone_deg, candidates)
	if not target:
		return dir
	var to := (target.global_position - origin).normalized()
	return dir.slerp(to, clampf(strength, 0.0, 1.0)).normalized()

# Nearest living enemy within range, used when there is no aim input at all (gamepad idle).
static func nearest(origin: Vector2, max_range: float, candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_d := max_range
	for c in candidates:
		var e := c as Node2D
		if not e or not is_instance_valid(e) or ("is_alive" in e and not e.is_alive):
			continue
		var d := origin.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best
