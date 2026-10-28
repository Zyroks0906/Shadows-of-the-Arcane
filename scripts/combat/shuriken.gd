extends Node2D
class_name Shuriken

# A thrown ninja star: flies straight, spins, cuts the first enemies it meets (pierces one)
# and sticks into walls with a spark.

var source: Player
var direction := Vector2.RIGHT
var speed := 330.0
var damage := 10
var pierce := 1
var _life := 0.55
var _spin := 0.0
var _hit: Array = []

static func throw(from: Player, at: Vector2, dir: Vector2, dmg: int) -> Shuriken:
	var s := Shuriken.new()
	s.source = from
	s.direction = dir.normalized()
	s.damage = dmg
	s.z_index = 5
	from.get_parent().add_child(s)
	s.global_position = at
	GroundShadow.attach_flying(s, 8.0, 2.5)
	return s

func _physics_process(delta: float) -> void:
	_life -= delta
	_spin += delta * 28.0
	var step := direction * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
	if get_world_2d().direct_space_state.intersect_ray(q):
		CombatFX.burst(global_position, Color(0.9, 0.9, 1.0), 6, 40.0, 0.2)
		AudioManager.play_bank_at("dagger_swing", global_position, -10.0, 1.8)
		queue_free()
		return
	global_position += step
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in _hit or not e.is_alive or e.global_position.distance_to(global_position) > 9.0:
			continue
		_hit.append(e)
		e.take_elemental_hit(damage, ElementalSystem.Element.NONE, source)
		if is_instance_valid(source):
			source.on_hit_landed("skill")
		CombatFX.blood(e.global_position, direction, Color(0.6, 0.05, 0.08), 5)
		AudioManager.play_bank_at("blade_flesh", global_position, -6.0, 1.3)
		pierce -= 1
		if pierce < 0:
			queue_free()
			return
	if _life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	# Four-pointed steel star with a dark hub, spinning; a faint motion streak behind.
	draw_line(-direction * 8.0, Vector2.ZERO, Color(0.8, 0.85, 1.0, 0.25), 2.0)
	var pts := PackedVector2Array()
	for i in 8:
		var r := 4.5 if i % 2 == 0 else 1.6
		pts.append(Vector2.RIGHT.rotated(_spin + TAU * i / 8.0) * r)
	draw_colored_polygon(pts, Color(0.82, 0.86, 0.95))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.2, 0.28), 1.0)
	draw_circle(Vector2.ZERO, 1.0, Color(0.15, 0.12, 0.2))
