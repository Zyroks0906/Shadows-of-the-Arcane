extends Node

# Measures the opaque bounding box of every frame of every player SpriteFrames, so
# sprite scales can be normalised to a common on-screen character height.
# Usage: Godot_console.exe --headless --path . res://tools/measure_sprites.tscn

const CLASSES := ["archer", "assassin", "cleric", "gladiator", "knight", "mage", "necromancer", "samurai", "warrior"]

func _ready() -> void:
	_measure_enemies()
	for c in CLASSES:
		var sf: SpriteFrames = load("res://assets/sprites/sprite_frames/%s.tres" % c)
		print("== ", c)
		for anim in sf.get_animation_names():
			var hs := []
			var ws := []
			var canvas := Vector2i.ZERO
			var bottoms := []
			for i in sf.get_frame_count(anim):
				var tex := sf.get_frame_texture(anim, i)
				if not tex:
					continue
				var img := tex.get_image()
				if not img:
					continue
				if img.is_compressed():
					img.decompress()
				var r := img.get_used_rect()
				canvas = img.get_size()
				hs.append(r.size.y)
				ws.append(r.size.x)
				bottoms.append(r.end.y - canvas.y / 2)
			hs.sort()
			ws.sort()
			if hs.is_empty():
				continue
			print("  %-8s n=%3d canvas=%s  h[min/med/max]=%d/%d/%d  w med=%d  feet(from centre) med=%d" % [anim, hs.size(), canvas, hs[0], hs[hs.size() / 2], hs[-1], ws[ws.size() / 2], bottoms[bottoms.size() / 2]])
	get_tree().quit()

# World-space height (opaque pixels x sprite scale) of every enemy's idle/walk frame.
func _measure_enemies() -> void:
	print("== enemies (world px)")
	for f in DirAccess.get_files_at("res://scenes/entities/Enemies"):
		if not f.ends_with(".tscn"):
			continue
		var e: Node = load("res://scenes/entities/Enemies/" + f).instantiate()
		var spr := e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if not spr or not spr.sprite_frames:
			print("  %-20s no AnimatedSprite2D" % f)
			e.free()
			continue
		var out := []
		for anim in spr.sprite_frames.get_animation_names():
			if not (anim in ["idle", "walk", "run", "Idle", "Walk", "attack", "Attack"]):
				continue
			var tex := spr.sprite_frames.get_frame_texture(anim, 0)
			if not tex:
				continue
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			var r := img.get_used_rect()
			out.append("%s %.1fx%.1f" % [anim, r.size.x * absf(spr.scale.x) * absf(e.scale.x), r.size.y * absf(spr.scale.y) * absf(e.scale.y)])
		print("  %-20s scale %s/%s  %s" % [f, spr.scale, e.scale, ", ".join(out)])
		e.free()
