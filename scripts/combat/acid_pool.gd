extends Node2D
class_name AcidPool

# A glob of acid lobbed in an arc; where it lands, a pool hisses for a while and burns the
# player standing in it (enemies are fine: it is theirs). Drawn as stepped pixel rows with
# rising bubbles, shrinking as it dries.

const TICK := 0.5
const HALF := Vector2(12, 5)  # pool half-size in px
const COL := Color(0.45, 0.85, 0.2)
const DARK := Color(0.2, 0.45, 0.1)

var damage := 4
var seconds := 4.0
var source: Node
var _t := 0.0
var _tick := 0.0
var _landed := false
var _bubbles: Array = []

static func lob(parent: Node, from: Vector2, to: Vector2, damage: int, seconds: float, source: Node) -> AcidPool:
	var p := AcidPool.new()
	p.damage = damage
	p.seconds = seconds
	p.source = source
	parent.add_child(p)
	p.global_position = from
	p.z_index = -1
	var glob := Node2D.new()
	glob.z_index = 5
	glob.draw.connect(func():
		glob.draw_rect(Rect2(-2, -2, 4, 4), DARK)
		glob.draw_rect(Rect2(-1, -2, 3, 3), COL)
		glob.draw_rect(Rect2(0, -2, 1, 1), Color(0.85, 1.0, 0.6)))
	p.add_child(glob)
	var tw := p.create_tween()
	tw.tween_method(func(t: float):
		p.global_position = from.lerp(to, t)
		glob.position = Vector2(0, -28.0 * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.55)
	tw.tween_callback(func():
		glob.queue_free()
		p._land())
	return p

func _land() -> void:
	_landed = true
	AudioManager.play_bank_at("slime", global_position, -6.0, 0.8)
	AudioManager.play_bank_at("fire_small", global_position, -14.0, 1.6)
	CombatFX.burst(global_position, COL, 10, 40.0, 0.35, 30.0, 1.5)

func _process(delta: float) -> void:
	if not _landed:
		return
	_t += delta
	if _t >= seconds:
		queue_free()
		return
	if randf() < delta * 6.0:
		_bubbles.append([Vector2(randf_range(-HALF.x + 2, HALF.x - 2), randf_range(-HALF.y + 1, HALF.y - 1)), 0.0])
	for b in _bubbles:
		b[1] += delta
	_bubbles = _bubbles.filter(func(b): return b[1] < 0.6)
	_tick -= delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.is_alive and _tick <= 0.0 and _inside(pl.global_position):
		_tick = TICK
		pl.take_elemental_hit(damage, ElementalSystem.Element.NONE, source if is_instance_valid(source) else null)
	queue_redraw()

func _inside(p: Vector2) -> bool:
	var d := (p - global_position) * _size()
	return (d.x / HALF.x) ** 2 + (d.y / HALF.y) ** 2 <= 1.0

func _size() -> float:
	return 1.0 / clampf(1.0 - maxf(_t - seconds + 1.0, 0.0), 0.3, 1.0)

func _draw() -> void:
	if not _landed:
		return
	var k := clampf(1.0 - maxf(_t - seconds + 1.0, 0.0), 0.3, 1.0) # dries in the last second
	var a := minf(_t * 6.0, 1.0)
	var hy := int(HALF.y * k)
	for y in range(-hy, hy + 1):
		var w := int(HALF.x * k * sqrt(1.0 - float(y * y) / float(max(hy * hy, 1)))) if hy > 0 else int(HALF.x * k)
		draw_rect(Rect2(-w, y, w * 2 + 1, 1), Color(DARK, 0.85 * a))
		if w > 1:
			draw_rect(Rect2(-w + 1, y, w * 2 - 1, 1), Color(COL, 0.7 * a) if y < 0 else Color(COL.darkened(0.15), 0.7 * a))
	for b in _bubbles:
		var p: Vector2 = b[0] * k
		var r := 1.0 if b[1] < 0.4 else 0.0
		draw_rect(Rect2(p.round() - Vector2(r, r + b[1] * 3.0), Vector2(1 + r * 2, 1 + r * 2)), Color(0.8, 1.0, 0.55, 0.9 - b[1]))
