extends Node2D
class_name MirrorPuzzle

# Sun Sanctum: a shaft of sunlight falls through the broken roof and runs along the floor.
# Standing mirrors turn it by 90 degrees; F flips a mirror between its two diagonals. Lead
# the beam onto the sun sigil and the reliquary opens. The beam is always visible, so the
# room reads at a glance: follow the light, see where it goes wrong.

signal solved

const T := 16
const SUN := Color(1.0, 0.88, 0.55)

var source := Vector2.ZERO
var sigil := Vector2.ZERO
var mirrors: Dictionary = {} # Vector2i cell -> Mirror
var path: PackedVector2Array = []
var hit := false
var done := false
var _t := 0.0
var _retrace := 0.0
var _told := false
var _sigil_light: PointLight2D

static func build(level: Node, sun_at: Vector2, mirror_spots: Array, sigil_at: Vector2) -> MirrorPuzzle:
	var p := MirrorPuzzle.new()
	p.name = "MirrorPuzzle"
	p.z_index = -5 # light on the floor: over tiles and decor, under props and characters
	level.add_child(p)
	p.source = sun_at
	p.sigil = sigil_at
	for s in mirror_spots:
		var m := Mirror.new()
		m.puzzle = p
		level.add_child(m)
		m.global_position = s
		p.mirrors[_cell(s)] = m
	p._scramble()
	var sun_light := PointLight2D.new()
	sun_light.texture = LevelAmbience.light_texture()
	sun_light.color = SUN
	sun_light.energy = 0.7
	sun_light.texture_scale = 0.9
	sun_light.position = sun_at
	p.add_child(sun_light)
	p._sigil_light = PointLight2D.new()
	p._sigil_light.texture = LevelAmbience.light_texture()
	p._sigil_light.color = SUN
	p._sigil_light.energy = 0.0
	p._sigil_light.texture_scale = 0.8
	p._sigil_light.position = sigil_at
	p.add_child(p._sigil_light)
	p.trace()
	return p

static func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / T), floori(at.y / T))

# Start with every mirror set at random but never already solved.
func _scramble() -> void:
	for i in 20:
		for m in mirrors.values():
			m.slash = randf() < 0.5
		trace()
		if not hit:
			return

func turned() -> void:
	trace()
	if hit and not done:
		done = true
		for m in mirrors.values():
			m.locked = true
		CombatFX.shockwave(sigil, SUN, 40.0, 0.5, 3.0)
		CombatFX.shake(2.5, 0.3)
		AudioManager.play_bank("gem", -2.0, 0.6)
		ItemBanner.show_item("The sigil blazes", "Sunlight wakes the reliquary: its grate is rising.", SUN)
		solved.emit()

# Follow the beam cell by cell from the sun: mirrors turn it, walls and pillars stop it.
func trace() -> void:
	path = PackedVector2Array([source])
	hit = false
	var cell := _cell(source)
	var dir := Vector2i.DOWN
	var space := get_world_2d().direct_space_state if is_inside_tree() else null
	for step in 80:
		cell += dir
		var c := Vector2(cell * T) + Vector2(T, T) * 0.5
		if mirrors.has(cell):
			path.append(c)
			var m: Mirror = mirrors[cell]
			dir = Vector2i(-dir.y, -dir.x) if m.slash else Vector2i(dir.y, dir.x)
			continue
		if cell == _cell(sigil):
			path.append(c)
			hit = true
			break
		if space and _blocked(space, c):
			path.append(c - Vector2(dir) * T * 0.5)
			break
	if path.size() == 1:
		path.append(source)
	queue_redraw()

func _blocked(space: PhysicsDirectSpaceState2D, at: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collision_mask = 1
	for r in space.intersect_point(q, 8):
		var col = r["collider"]
		if col is StaticBody2D and not (col is Mirror):
			return true
	return false

func _process(delta: float) -> void:
	_t += delta
	_retrace -= delta
	if _retrace <= 0.0:
		_retrace = 0.5 # pushed blocks or opened gates change the room now and then
		trace()
	_sigil_light.energy = lerpf(_sigil_light.energy, 1.1 if hit else 0.0, delta * 4.0)
	queue_redraw()
	if not _told and not done:
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl and pl.global_position.distance_to(source) < 110.0:
			_told = true
			ItemBanner.show_item("Sun Sanctum", "Turn the mirrors (F) to lead the sunlight onto the sun sigil.", SUN)

func _draw() -> void:
	# Light falling through the roof: a soft wedge widening towards the floor.
	var top := source + Vector2(-3, -T * 0.9)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(6, 0), source + Vector2(7, 4), source + Vector2(-7, 4)]), Color(SUN, 0.22))
	draw_set_transform(source + Vector2(0, 3), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(SUN, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 4:
		var y := fposmod(_t * 6.0 + k * 4.0, 16.0)
		draw_rect(Rect2(source + Vector2(-3 + (k * 3) % 7, -T * 0.9 + y), Vector2(1, 1)), Color(1, 1, 0.9, 0.6))
	# The sun sigil carved in the floor: a ring with rays, blazing when the beam lands.
	var s := sigil
	var on := 1.0 if hit else 0.0
	draw_circle(s, 7.0, Color(0.12, 0.1, 0.12, 0.7))
	draw_arc(s, 6.5, 0.0, TAU, 24, Color(0.75, 0.6, 0.35).lerp(Color(1, 0.95, 0.7), on), 1.0)
	draw_circle(s, 2.5, Color(0.6, 0.45, 0.25).lerp(Color(1, 0.95, 0.75), on))
	for k in 8:
		var a := TAU * k / 8.0 + (_t * 0.8 if hit else 0.0)
		draw_line(s + Vector2.from_angle(a) * 3.8, s + Vector2.from_angle(a) * 5.4, Color(0.75, 0.6, 0.35).lerp(Color(1, 0.95, 0.7), on), 1.0)
	if hit:
		draw_circle(s, 10.0 + sin(_t * 5.0), Color(SUN, 0.16))
	# The beam: a wide soft glow, a bright core, and motes running along it.
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		draw_line(a, b, Color(SUN, 0.16), 6.0)
		draw_line(a, b, Color(SUN, 0.45), 3.0)
		draw_line(a, b, Color(1.0, 0.98, 0.88, 0.95), 1.0)
		var seg := a.distance_to(b)
		if seg > 0.0:
			var k := 0.0
			while k < seg:
				var at := a.lerp(b, fposmod(k + _t * 40.0, seg) / seg)
				draw_rect(Rect2(at - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 1, 1, 0.8))
				k += 12.0
	for i in range(1, path.size() - 1):
		draw_circle(path[i], 3.0 + sin(_t * 8.0 + i) * 0.5, Color(1, 0.97, 0.85, 0.55))


class Mirror extends StaticBody2D:
	var puzzle: MirrorPuzzle
	var slash := true # "/" or "\"
	var locked := false
	var _spin := 0.0

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(10, 6)
		shape.shape = r
		shape.position = Vector2(0, 2)
		add_child(shape)
		GroundShadow.attach(self, 0.0, 1.0)

	func interact(_body: Node2D = null) -> void:
		if locked:
			return
		slash = not slash
		_spin = 1.0
		AudioManager.play_bank_at("creak", global_position, -4.0, 1.5)
		AudioManager.play_bank_at("stomp", global_position, -14.0, 1.6)
		puzzle.turned()

	func _process(delta: float) -> void:
		_spin = maxf(_spin - delta * 5.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		# A round stone pedestal with a bronze-framed mirror standing on it at 45 degrees.
		draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 6.0, Color(0.22, 0.2, 0.26))
		draw_arc(Vector2.ZERO, 6.0, PI, TAU, 12, Color(0.4, 0.38, 0.46), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var d := Vector2(1, -1) if slash else Vector2(1, 1)
		d = d.normalized().rotated(_spin * 0.6)
		var c := Vector2(0, -4)
		var a := c - d * 6.5
		var b := c + d * 6.5
		draw_line(a + Vector2(0, 7), a, Color(0.42, 0.3, 0.18), 1.0) # frame posts down to the pedestal
		draw_line(b + Vector2(0, 7), b, Color(0.42, 0.3, 0.18), 1.0)
		draw_line(a, b, Color(0.55, 0.4, 0.22), 3.0)                # bronze frame
		draw_line(a, b, Color(0.82, 0.88, 0.95), 1.0)               # silvered glass
		draw_line(c - d * 2.0 + Vector2(0, -1), c + d * 1.0 + Vector2(0, -1), Color(1, 1, 1, 0.9), 1.0)
		if locked:
			draw_circle(c, 2.0, Color(1.0, 0.9, 0.6, 0.6))
