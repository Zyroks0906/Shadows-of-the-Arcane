extends RefCounted
class_name MapBounds

# What counts as "on the map": a cell that holds a tile in one of the ground layers of the
# area a node belongs to - floor, water or walls. Generated levels (and the crypt and vault
# inside level_1) keep floor in "Floor" and deep water in "Water"; level_1 keeps its floor
# and walls together in "Tileset". Beyond the walls all of them are empty.

const GROUND := ["Floor", "Water", "Tileset"]

# The ground layers of the nearest ancestor that has any (so the crypt's skeletons use the
# crypt's floor, not level_1's).
static func ground_layers(from: Node) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	var n: Node = from.get_parent()
	while n and out.is_empty():
		for holder in [n, n.get_node_or_null("Background")]:
			if holder == null:
				continue
			for name in GROUND:
				var l: Node = holder.get_node_or_null(name)
				if l is TileMapLayer:
					out.append(l)
		n = n.get_parent()
	return out

static func on_map(layers: Array[TileMapLayer], at: Vector2) -> bool:
	for l in layers:
		if is_instance_valid(l) and l.get_cell_source_id(l.local_to_map(l.to_local(at))) != -1:
			return true
	return false

# The closest point on the map to `at` (cell centres, searched outwards ring by ring).
static func nearest_on_map(layers: Array[TileMapLayer], at: Vector2) -> Vector2:
	for r in range(1, 16):
		var best := Vector2.INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := at + Vector2(dx, dy) * 8.0
				if on_map(layers, p) and (best == Vector2.INF or p.distance_to(at) < best.distance_to(at)):
					best = p
		if best != Vector2.INF:
			return best
	return at


# A safety net attached to every enemy (bosses too), whatever its own movement code does:
# every so often it checks the ground under the enemy's feet; off the map (a blink, a leap
# or a shove that went too far) it puts it straight back on the last spot that was on it.
class Guard extends Node:
	const EVERY := 0.25
	var _t := 0.0
	var _last := Vector2.INF
	var _ground: Array[TileMapLayer] = []

	static func attach(body: Node2D) -> void:
		var g := Guard.new()
		g.name = "BoundsGuard"
		body.add_child(g)

	func _physics_process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = EVERY
		var body := get_parent() as Node2D
		if not body:
			return
		if _ground.is_empty():
			_ground = MapBounds.ground_layers(body)
			if _ground.is_empty():
				return
		if MapBounds.on_map(_ground, body.global_position):
			_last = body.global_position
		else:
			# Back to the last spot it stood on; one that was put outside from the start
			# (a spawn behind a wall) goes to the nearest ground instead.
			body.global_position = _last if _last != Vector2.INF else MapBounds.nearest_on_map(_ground, body.global_position)
			if body is CharacterBody2D:
				body.velocity = Vector2.ZERO
			if "knockback" in body:
				body.knockback = Vector2.ZERO
