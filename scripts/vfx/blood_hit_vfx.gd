extends AnimatedSprite2D

func _ready() -> void:
	if sprite_frames:
		for anim in sprite_frames.get_animation_names():
			sprite_frames.set_animation_loop(anim, false)

func setup(attacker_pos: Vector2) -> void:
	var dir := (global_position - attacker_pos).normalized()
	var anim := _pick_anim(dir)

	if not sprite_frames or not sprite_frames.has_animation(anim):
		queue_free()
		return

	play(anim)
	animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	, CONNECT_ONE_SHOT)

func _pick_anim(dir: Vector2) -> String:
	var candidate: String
	if abs(dir.x) >= abs(dir.y):
		candidate = "hit_right" if dir.x > 0 else "hit_left"
	else:
		candidate = "hit_down" if dir.y > 0 else "hit_up"

	if sprite_frames and sprite_frames.has_animation(candidate):
		return candidate

	rotation = dir.angle()
	return "default"
