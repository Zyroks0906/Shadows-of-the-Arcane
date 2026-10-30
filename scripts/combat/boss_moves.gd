extends RefCounted
class_name BossMoves

# Telegraphed boss attacks, shared by the bosses. Every move shows where it will land first
# (red cone, aiming line, ground circles, closing ring) so a careful player can always read
# and dodge it; then it lands hard. All are coroutines: `await BossMoves.slam(...)`.

const WARN := Color(1.0, 0.25, 0.2)

static func _alive(b) -> bool: # untyped: after an await the boss may already be freed
	return is_instance_valid(b) and b.is_alive

static func _wait(b: Node, t: float) -> void:
	await b.get_tree().create_timer(t, false).timeout

static func _hurt(b: BossBase, dmg: int, element: ElementalSystem.Element, knock_from: Vector2, knock: float) -> void:
	var p := b.player
	if is_instance_valid(p) and p.is_alive:
		p.take_elemental_hit(dmg, element, b)
		if knock > 0.0:
			p.apply_knockback((p.global_position - knock_from).normalized() * knock)

# Plain warnings, for bosses with their own attack code: a red cone or circle that fills
# up over `time` seconds where the blow will land.
static func warn_cone(b: Node2D, dir: Vector2, reach: float, arc_deg: float, time: float) -> void:
	var t := _Cone.new()
	t.dir = dir.normalized()
	t.reach = reach
	t.half = deg_to_rad(arc_deg * 0.5)
	t.life = time
	b.get_parent().add_child(t)
	t.global_position = b.global_position

static func warn_circle(parent: Node, at: Vector2, radius: float, time: float) -> void:
	var c := _Circle.new()
	c.radius = radius
	c.life = time
	parent.add_child(c)
	c.global_position = at

# Arm slam: a red cone towards the player fills up, then the blow lands in it.
static func slam(b: BossBase, reach: float, arc_deg: float, dmg: int, windup: float = 0.7) -> void:
	if not _alive(b) or not is_instance_valid(b.player):
		return
	var dir := (b.player.global_position - b.global_position).normalized()
	var t := _Cone.new()
	t.dir = dir
	t.reach = reach
	t.half = deg_to_rad(arc_deg * 0.5)
	t.life = windup
	b.get_parent().add_child(t)
	t.global_position = b.global_position
	AudioManager.play_bank_at("monster_growl", b.global_position, -4.0, 0.6)
	await _wait(b, windup)
	if not _alive(b):
		return
	CombatFX.pvfx("earth-rupture", b.global_position + dir * reach * 0.6, reach / 60.0, 0.0)
	CombatFX.shake(4.0, 0.25)
	AudioManager.play_bank_at("stomp", b.global_position, 2.0, 0.6)
	var p := b.player
	if is_instance_valid(p):
		var to := p.global_position - b.global_position
		if to.length() <= reach + 5.0 and absf(dir.angle_to(to)) <= deg_to_rad(arc_deg * 0.5) + 0.2:
			_hurt(b, dmg, b.base_element, b.global_position, 300.0)

# Eye laser: an aiming line tracks the player, then a beam fires from the eye and slowly
# sweeps after them; it stops at walls. Damage every 0.25 s while it touches the player.
static func laser(b: BossBase, eye: Vector2, aim_time: float, beam_time: float, tick_dmg: int, turn_speed: float = 0.9, color: Color = Color(0.4, 0.9, 1.0)) -> void:
	if not _alive(b) or not is_instance_valid(b.player):
		return
	var beam := _Beam.new()
	beam.boss = b
	beam.eye_offset = eye
	beam.color = color
	beam.dir = (b.player.global_position - (b.global_position + eye)).normalized()
	b.get_parent().add_child(beam)
	AudioManager.play_bank_at("electric_launch", b.global_position, -6.0, 0.5)
	# Aiming: thin red line that follows the player closely.
	var t := 0.0
	while t < aim_time:
		if not _alive(b) or not is_instance_valid(b.player):
			if is_instance_valid(beam): beam.queue_free()
			return
		var want := (b.player.global_position - (b.global_position + eye)).normalized()
		beam.dir = beam.dir.slerp(want, 0.25)
		await b.get_tree().process_frame
		t += b.get_process_delta_time()
	beam.firing = true
	CombatFX.shake(3.0, 0.2)
	AudioManager.play_bank_at("electric_hit", b.global_position, 2.0, 0.6)
	t = 0.0
	var tick := 0.0
	while t < beam_time:
		if not _alive(b) or not is_instance_valid(b.player):
			break
		var dt := b.get_process_delta_time()
		var want := (b.player.global_position - (b.global_position + eye)).normalized()
		beam.dir = beam.dir.rotated(clampf(beam.dir.angle_to(want), -turn_speed * dt, turn_speed * dt))
		tick -= dt
		if tick <= 0.0 and beam.touches(b.player.global_position, 7.0):
			tick = 0.25
			_hurt(b, tick_dmg, ElementalSystem.Element.ELECTRO, beam.global_position, 0.0)
		await b.get_tree().process_frame
		t += dt
	if is_instance_valid(beam): beam.queue_free()

# Rock rain: circles appear around (and under) the player; a moment later rocks crash down
# in each one.
static func rock_rain(b: BossBase, count: int, dmg: int, delay: float = 1.0) -> void:
	if not _alive(b) or not is_instance_valid(b.player):
		return
	var spots: Array[Vector2] = [b.player.global_position]
	for i in count - 1:
		spots.append(b.player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 52.0))
	for s in spots:
		var c := _Circle.new()
		c.radius = 15.0
		c.life = delay
		b.get_parent().add_child(c)
		c.global_position = s
	AudioManager.play_bank_at("stomp", b.global_position, 0.0, 0.4)
	await _wait(b, delay)
	if not _alive(b):
		return
	for s in spots:
		CombatFX.pvfx("earth-rupture", s, 0.35)
		CombatFX.burst(s, Color(0.5, 0.42, 0.35), 10, 60.0, 0.4, 120.0, 2.0)
		var p := b.player
		if is_instance_valid(p) and p.global_position.distance_to(s) <= 15.0:
			_hurt(b, dmg, ElementalSystem.Element.GEO, s, 160.0)
	CombatFX.shake(4.0, 0.3)
	AudioManager.play_bank_at("stomp", b.global_position, 3.0, 0.7)

# Shockwave: a ring closes in on the boss as it gathers power, then bursts out.
static func shockwave(b: BossBase, radius: float, dmg: int, windup: float = 0.9, color: Color = Color(0.5, 0.9, 1.0)) -> void:
	if not _alive(b):
		return
	var r := _Ring.new()
	r.radius = radius
	r.life = windup
	r.color = color
	b.add_child(r)
	await _wait(b, windup)
	if not _alive(b):
		return
	CombatFX.shockwave(b.global_position, color, radius, 0.45, 5.0)
	CombatFX.pvfx("frost-nova" if color.b > 0.8 else "warm-explosion", b.global_position, radius / 60.0)
	CombatFX.shake(6.0, 0.4)
	AudioManager.play_bank_at("stomp", b.global_position, 4.0, 0.5)
	var p := b.player
	if is_instance_valid(p) and b.global_position.distance_to(p.global_position) < radius:
		_hurt(b, dmg, b.base_element, b.global_position, 420.0)


class _Cone extends Node2D:
	var dir := Vector2.RIGHT
	var reach := 50.0
	var half := 0.8
	var life := 0.7
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		var pts2 := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := dir.angle() - half + 2.0 * half * i / 12.0
			pts.append(Vector2.RIGHT.rotated(a) * reach)
			pts2.append(Vector2.RIGHT.rotated(a) * reach * k)
		draw_colored_polygon(pts, Color(BossMoves.WARN, 0.15))
		draw_colored_polygon(pts2, Color(BossMoves.WARN, 0.3))
		draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(BossMoves.WARN, 0.8), 1.0)

class _Circle extends Node2D:
	var radius := 15.0
	var life := 1.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(BossMoves.WARN, 0.15))
		draw_circle(Vector2.ZERO, radius * k, Color(BossMoves.WARN, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(BossMoves.WARN, 0.9), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the falling rock's shadow grows as it comes
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, radius * 0.6 * k, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class _Ring extends Node2D:
	var radius := 100.0
	var life := 0.9
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(BossMoves.WARN, 0.7), 1.5)
		draw_arc(Vector2.ZERO, radius * (1.0 - k) + 6.0, 0.0, TAU, 40, Color(color, 0.8), 2.0)
		draw_circle(Vector2.ZERO, radius, Color(BossMoves.WARN, 0.06 + 0.1 * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class _Beam extends Node2D:
	var boss: BossBase
	var eye_offset := Vector2.ZERO
	var dir := Vector2.RIGHT
	var firing := false
	var color := Color(0.4, 0.9, 1.0)
	var _end := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		z_index = 40

	func _process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(boss):
			queue_free()
			return
		global_position = boss.global_position + eye_offset
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 260.0, 1, [boss.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		_end = to_local(hit["position"]) if hit else dir * 260.0
		if firing and int(_t * 20.0) % 3 == 0:
			CombatFX.burst(global_position + _end, color, 3, 40.0, 0.2)
		queue_redraw()

	func touches(p: Vector2, width: float) -> bool:
		var a := global_position
		var b := global_position + _end
		var ab := b - a
		var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
		return (a + ab * k).distance_to(p) <= width

	func _draw() -> void:
		if not firing:
			draw_line(Vector2.ZERO, _end, Color(BossMoves.WARN, 0.5 + 0.3 * sin(_t * 30.0)), 1.0)
			draw_circle(Vector2.ZERO, 2.0 + sin(_t * 20.0), Color(color, 0.9))
			return
		var w := 5.0 + sin(_t * 40.0) * 1.0
		draw_line(Vector2.ZERO, _end, Color(color, 0.25), w * 2.4)
		draw_line(Vector2.ZERO, _end, Color(color, 0.7), w)
		draw_line(Vector2.ZERO, _end, Color(1, 1, 1, 0.95), w * 0.35)
		draw_circle(Vector2.ZERO, w * 0.9, Color(1, 1, 1, 0.9))
		draw_circle(_end, w * 1.2, Color(color, 0.6))


# Where something may appear or land: the line from a place known to be inside the map
# (`from`) to the wanted spot (`to`) is traced against the walls; if a wall is in the way it
# stops short of it, and it backs off until a small circle fits there. Nothing can be sent
# into a wall or out past the map's edge this way.
static func safe_spot(world: World2D, from: Vector2, to: Vector2, exclude: Array = [], radius: float = 6.0) -> Vector2:
	var space := world.direct_space_state
	var dir := (to - from).normalized() if to != from else Vector2.ZERO
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, exclude)
	var hit := space.intersect_ray(q)
	var at := to
	if hit:
		at = (hit["position"] as Vector2) - dir * (radius + 2.0)
	var probe := CircleShape2D.new()
	probe.radius = radius
	var sq := PhysicsShapeQueryParameters2D.new()
	sq.shape = probe
	sq.collision_mask = 1
	sq.exclude = exclude
	for i in 8:
		sq.transform = Transform2D(0.0, at)
		if space.intersect_shape(sq, 1).is_empty():
			return at
		at = at.move_toward(from, 4.0)
	return from
