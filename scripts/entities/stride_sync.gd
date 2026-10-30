extends Node
class_name StrideSync

# Feet that stay planted. A walk or run cycle was drawn for one pace; played at a fixed
# rate the body glides over the floor whenever it moves faster than that pace. While the
# parent's walk/run animation plays, this sets its playback speed from how fast the body
# really moves and how far the cycle's feet actually travel in the art.
#
# The ground the animation covers is measured on the frames themselves: the feet are the
# lowest opaque rows of each frame, and from one frame to the next the planted foot slides
# back by as much as the body should move forward. Adding those slides up over the whole
# animation gives its stride, however many steps it holds. (Estimating it from the body
# height was badly off: some packs' walks are drawn almost on the spot.) Playback is capped at MAX_FPS: faster than that the legs flicker,
# and the hero would rather slide a little than strobe.

const MAX_FPS := 40.0
const MIN_SCALE := 0.15
const STILL := 3.0            # px/s: below this the animation is left alone
const FALLBACK_STRIDE := 2.2  # body heights per cycle, when the feet cannot be measured
const WALK_NAMES := ["walk", "run", "Walk", "Run", "Walk_Right", "Run_Right"]

var _sprite: AnimatedSprite2D
var _cycle := {}              # animation -> distance one cycle covers, in sprite pixels
var _touched := false

static func attach(body: Node2D) -> StrideSync:
	var s := StrideSync.new()
	s.name = "StrideSync"
	body.add_child(s)
	return s

func _ready() -> void:
	_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not _sprite:
		_sprite = get_parent().find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	process_priority = 100 # after the body has picked its animation this frame

func _process(_delta: float) -> void:
	if not is_instance_valid(_sprite) or not _sprite.sprite_frames:
		return
	var body := get_parent() as CharacterBody2D
	var anim := String(_sprite.animation)
	# The body's own pace (a hero's _move_vel), not what a wind or a current adds to it.
	var own = body.get("_move_vel") if body else null
	var speed: float = (own as Vector2).length() if own is Vector2 else (body.velocity.length() if body else 0.0)
	# A creature that floats (the necromancer's robe hovers) glides: nothing to plant.
	if body and body.get_meta("hovers", false):
		return
	if anim in WALK_NAMES and _sprite.is_playing() and speed < STILL:
		_sprite.speed_scale = MIN_SCALE # just starting or stopping: barely moving legs
		_touched = true
		return
	if not (anim in WALK_NAMES and _sprite.is_playing()):
		if _touched:
			_sprite.speed_scale = 1.0
			_touched = false
		return
	var frames := _sprite.sprite_frames.get_frame_count(anim)
	var fps := _sprite.sprite_frames.get_animation_speed(anim)
	var cycle := cycle_px(anim) * absf(_sprite.global_scale.x)
	if frames <= 0 or fps <= 0.0 or cycle < 2.0:
		return
	# The pace the cycle shows at speed 1: one cycle per (frames / fps) seconds.
	var drawn_pace := cycle * fps / float(frames)
	_sprite.speed_scale = clampf(speed / drawn_pace, MIN_SCALE, MAX_FPS / fps)
	_touched = true

# How far one play of `anim` carries the body, in the sprite's own pixels.
func cycle_px(anim: String) -> float:
	if _cycle.has(anim):
		return _cycle[anim]
	var sf := _sprite.sprite_frames
	var feet: Array[Vector2] = []
	var tallest := 0.0
	for i in sf.get_frame_count(anim):
		var tex := sf.get_frame_texture(anim, i)
		var img := tex.get_image() if tex else null
		if not img:
			continue
		var used := img.get_used_rect()
		tallest = maxf(tallest, used.size.y)
		var f := _feet(img, used)
		if f.x <= f.y:
			feet.append(f)
	# Facing right, a planted foot moves left: count the larger of the two edges' moves.
	var back := 0.0
	for i in feet.size():
		var a: Vector2 = feet[i]
		var b: Vector2 = feet[(i + 1) % feet.size()]
		back += maxf(0.0, maxf(a.x - b.x, a.y - b.y))
	# Nothing measurable (a floating creature, a one-frame cycle): fall back to the body.
	if back < tallest * 0.25:
		back = FALLBACK_STRIDE * tallest
	_cycle[anim] = back
	return back

# The leftmost and rightmost opaque pixel of the two lowest rows of a frame (the feet).
static func _feet(img: Image, used: Rect2i) -> Vector2:
	var bottom := used.position.y + used.size.y - 1
	var left := INF
	var right := -INF
	for y in range(maxi(bottom - 1, used.position.y), bottom + 1):
		for x in range(used.position.x, used.position.x + used.size.x):
			if img.get_pixel(x, y).a > 0.1:
				left = minf(left, x)
				right = maxf(right, x)
	return Vector2(left, right)
