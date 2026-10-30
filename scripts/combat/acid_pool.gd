extends Node2D
class_name AcidPool

# A spore ball lobbed in an arc (the Sporecap's own projectile art, LuizMelo's Mushroom);
# where it lands it bursts and a pool of red spores lingers for a while, hurting the player
# standing in it (enemies are fine: it is theirs). The pool is drawn as stepped pixel rows
# with rising motes, shrinking as it fades.

const TICK := 0.5
const HALF := Vector2(18, 8)  # pool half-size in px (the hurting area is a little smaller)
const COL := Color(0.78, 0.18, 0.24)
const DARK := Color(0.36, 0.06, 0.1)
const MOTE := Color(1.0, 0.6, 0.6)
const BALL := "res://assets/sprites/enemies/LuizMelo/Mushroom/Projectile_sprite.png"
const BALL_FRAME := 50
const BALL_SCALE := 0.6

var damage := 4
var seconds := 4.0
var source: Node
var _t := 0.0
var _tick := 0.0
var _landed := false
var _bubbles: Array = []
var _rows: Array = []        # [y, left, right] of the stain, irregular, fixed when it lands
var _spots: Array = []

static func lob(parent: Node, from: Vector2, to: Vector2, damage: int, seconds: float, source: Node) -> AcidPool:
	var p := AcidPool.new()
	p.damage = damage
	p.seconds = seconds
	p.source = source
	parent.add_child(p)
	p.global_position = from
	p.z_index = -1
	var glob := _ball(0, 4, true)
	glob.z_index = 5
	p.add_child(glob)
	var tw := p.create_tween()
	tw.tween_method(func(t: float):
		p.global_position = from.lerp(to, t)
		glob.position = Vector2(0, -28.0 * 4.0 * t * (1.0 - t)), 0.0, 1.0, 0.55)
	tw.tween_callback(func():
		glob.queue_free()
		p._land())
	return p

# The projectile strip: frames 0-3 spin in flight, 4-7 burst.
static func _ball(first: int, count: int, loop: bool) -> AnimatedSprite2D:
	var tex: Texture2D = load(BALL)
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", loop)
	sf.set_animation_speed("default", 12.0)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((first + i) * BALL_FRAME, 0, BALL_FRAME, BALL_FRAME)
		sf.add_frame("default", at)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.scale = Vector2.ONE * BALL_SCALE
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.play()
	return a

func _land() -> void:
	_landed = true
	# An irregular stain, not a perfect ellipse: each row's edges wander a little.
	var hy := int(HALF.y)
	for y in range(-hy, hy + 1):
		var w := HALF.x * sqrt(maxf(1.0 - float(y * y) / float(hy * hy + 1), 0.0))
		_rows.append([y, -int(w + randf_range(-1.5, 1.0)), int(w + randf_range(-1.5, 1.0))])
	for i in 5:
		_spots.append(Vector2(randf_range(-HALF.x * 0.6, HALF.x * 0.6), randf_range(-HALF.y * 0.5, HALF.y * 0.5)).round())
	var burst := _ball(4, 4, false)
	burst.z_index = 5
	add_child(burst)
	burst.animation_finished.connect(burst.queue_free)
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
	_bubbles = _bubbles.filter(func(b): return b[1] < 0.8)
	_tick -= delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.is_alive and _tick <= 0.0 and _inside(pl.global_position):
		_tick = TICK
		pl.take_elemental_hit(damage, ElementalSystem.Element.NONE, source if is_instance_valid(source) else null)
	queue_redraw()

func _inside(p: Vector2) -> bool:
	var d := (p - global_position) / _scale()
	return (d.x / (HALF.x - 3.0)) ** 2 + (d.y / (HALF.y - 1.0)) ** 2 <= 1.0

# Spreads out in 0.25 s when it lands, shrinks away over its last second.
func _scale() -> float:
	return clampf(minf(_t / 0.25, 1.0), 0.2, 1.0) * clampf(seconds - _t, 0.25, 1.0)

func _draw() -> void:
	if not _landed:
		return
	var k := _scale()
	var a := clampf(seconds - _t, 0.0, 1.0)
	var mid := Color(COL, 0.75 * a)
	var low := Color(COL.darkened(0.25), 0.75 * a)
	var rim := Color(DARK, 0.9 * a)
	for r in _rows:
		var y := roundi(r[0] * k)
		var l := roundi(r[1] * k)
		var rr := roundi(r[2] * k)
		if rr - l < 1:
			continue
		draw_rect(Rect2(l, y, rr - l + 1, 1), rim)
		if rr - l > 2:
			draw_rect(Rect2(l + 1, y, rr - l - 1, 1), mid if y < 0 else low)
	for sp in _spots:
		draw_rect(Rect2((sp * k).round(), Vector2(2, 1)), Color(DARK, 0.6 * a))
	# Wet glints on the near side.
	draw_rect(Rect2(Vector2(-HALF.x * 0.4, -HALF.y * 0.45) * k, Vector2(3, 1)), Color(MOTE, 0.7 * a))
	draw_rect(Rect2(Vector2(HALF.x * 0.25, -HALF.y * 0.2) * k, Vector2(1, 1)), Color(MOTE, 0.6 * a))
	# Spores drifting up out of it.
	for b in _bubbles:
		var p: Vector2 = b[0] * k
		draw_rect(Rect2(p.round() - Vector2(0, roundi(b[1] * 10.0)), Vector2(1, 1)), Color(MOTE, (0.9 - b[1]) * a))
