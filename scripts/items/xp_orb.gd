extends Node2D
class_name XpOrb

# Experience dropped by defeated enemies. Orbs pop out, settle, and once the player is
# close they are pulled in and collected. Picking several in a row climbs in pitch.

const MAGNET := 56.0
const COLLECT := 7.0

var value: int = 1
var _vel: Vector2
var _t: float = 0.0
var _pulled: bool = false
static var _chain: int = 0
static var _chain_ms: int = 0

static func drop(at: Vector2, total: int, parent: Node) -> void:
	var count := clampi(ceili(total / 4.0), 1, 6)
	var each := maxi(total / count, 1)
	for i in count:
		var o := XpOrb.new()
		o.value = each + (total - each * count if i == 0 else 0)
		o._vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 70)
		parent.add_child(o)
		o.global_position = at

func _ready() -> void:
	z_index = 4

func _physics_process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and _t > 0.35:
		var to := p.global_position - global_position
		if to.length() < MAGNET or _pulled:
			_pulled = true
			_vel = _vel.lerp(to.normalized() * (120.0 + _t * 60.0), clampf(delta * 8.0, 0, 1))
		if to.length() < COLLECT:
			_collect()
			return
	if not _pulled:
		_vel = _vel.move_toward(Vector2.ZERO, 160.0 * delta)
	global_position += _vel * delta
	queue_redraw()

func _collect() -> void:
	var now := Time.get_ticks_msec()
	_chain = _chain + 1 if now - _chain_ms < 600 else 0
	_chain_ms = now
	AudioManager.play_bank("gem", -10.0, 1.0 + minf(_chain, 10) * 0.05, 0.0)
	Progression.add_xp(value)
	queue_free()

func _draw() -> void:
	var bob := sin(_t * 6.0) * 1.0 if not _pulled else 0.0
	var c := Color(0.45, 1.0, 0.8)
	# Small: a 3 x 4 px gem (characters are only ~14 px tall).
	var pts := PackedVector2Array([Vector2(0, -2 + bob), Vector2(1.5, bob), Vector2(0, 2 + bob), Vector2(-1.5, bob)])
	draw_circle(Vector2(0, bob), 2.8, Color(c, 0.15))
	draw_colored_polygon(pts, c)
	draw_rect(Rect2(Vector2(-0.5, -1.5 + bob), Vector2(1, 1)), Color(1, 1, 1, 0.9))
