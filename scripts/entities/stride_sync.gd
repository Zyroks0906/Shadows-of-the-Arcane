extends Node
class_name StrideSync

# Feet that stay planted. A walk cycle was drawn for one pace; played at a fixed rate the
# body glides over the floor whenever it moves faster or slower than that pace (the knight's
# 8-frame walk at 5 fps covered ~7 body lengths per stride: it skated). While the parent's
# walk animation plays, this sets its playback speed from how fast the body really moves:
# one full cycle (two steps) per STRIDE body heights travelled.

const STRIDE := 2.2           # distance per cycle (two steps), in body heights: a brisk walk
const MIN_SCALE := 0.35
const MAX_SCALE := 4.0
const STILL := 3.0            # px/s: below this the animation is left alone
const WALK_NAMES := ["walk", "run", "Walk", "Run", "Walk_Right", "Run_Right"]

var _sprite: AnimatedSprite2D
var _heights := {}            # animation -> body height in sprite pixels (measured once)
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
	var speed := body.velocity.length() if body else 0.0
	if not (anim in WALK_NAMES and _sprite.is_playing()) or speed < STILL:
		if _touched:
			_sprite.speed_scale = 1.0
			_touched = false
		return
	var frames := _sprite.sprite_frames.get_frame_count(anim)
	var fps := _sprite.sprite_frames.get_animation_speed(anim)
	var height := _height(anim) * absf(_sprite.global_scale.y)
	if frames <= 0 or fps <= 0.0 or height < 2.0:
		return
	# The pace the cycle shows at speed 1: one stride per (frames / fps) seconds.
	var drawn_pace := STRIDE * height * fps / float(frames)
	_sprite.speed_scale = clampf(speed / drawn_pace, MIN_SCALE, MAX_SCALE)
	_touched = true

# The tallest opaque extent over the cycle's frames, in the sprite's own pixels.
func _height(anim: String) -> float:
	if _heights.has(anim):
		return _heights[anim]
	var h := 0.0
	var sf := _sprite.sprite_frames
	for i in sf.get_frame_count(anim):
		var tex := sf.get_frame_texture(anim, i)
		if tex:
			var img := tex.get_image()
			if img:
				h = maxf(h, float(img.get_used_rect().size.y))
	_heights[anim] = h
	return h
