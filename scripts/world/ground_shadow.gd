extends Node2D
class_name GroundShadow

# A soft pixel shadow on the floor under a character, item or projectile: the cheapest way to
# give a top-down 2D game depth. Whatever is above the floor (a flying bat, an arrow in
# flight, a potion popping out of a chest) keeps its shadow on the ground, so height reads.
#
# GroundShadow.attach(node) finds the node's sprite, measures where its opaque pixels end
# (the feet) and how wide they are, and puts the shadow there, behind everything else.

const COLOR := Color(0.0, 0.0, 0.02, 0.6)

var radius := Vector2(6, 2)
var hover := 0.0 # how far above the floor the owner floats (px); the shadow shrinks with it
var _owner_char: Node = null
var _fade := 1.0

var _in_flight := false # projectiles: stays straight below, whatever the owner's rotation

static var _foot_cache: Dictionary = {}

# For projectiles: a small shadow `height` px below, kept upright and on the floor layer.
static func attach_flying(owner: Node2D, height: float = 8.0, size: float = 4.0) -> GroundShadow:
	var s := GroundShadow.new()
	s.name = "GroundShadow"
	s._in_flight = true
	s.hover = height
	s.radius = Vector2(size, size * 0.4)
	s.z_as_relative = false
	s.z_index = 1
	owner.add_child(s)
	return s

# `hover` > 0 for things that fly; `width_mult` to tweak the measured width.
static func attach(owner: Node2D, hover_px: float = 0.0, width_mult: float = 1.0) -> GroundShadow:
	var s := GroundShadow.new()
	s.name = "GroundShadow"
	s.hover = hover_px
	var sprite := _find_sprite(owner)
	var foot := Vector2.ZERO
	var w := 10.0
	if sprite:
		var m := _measure(sprite)
		foot = m["foot"]
		w = m["width"]
	s.position = foot + Vector2(0, hover_px)
	s.radius = Vector2(maxf(w * 0.5 * width_mult, 3.5), maxf(w * 0.17 * width_mult, 1.8))
	if owner is BaseCharacter:
		s._owner_char = owner
	owner.add_child(s)
	owner.move_child(s, 0) # drawn before (under) the sprite
	return s

static func _find_sprite(owner: Node) -> Node2D:
	for c in owner.get_children():
		if c is AnimatedSprite2D or c is Sprite2D:
			return c
	return null

# Bottom-centre of the sprite's opaque pixels, in the owner's space, and their width.
static func _measure(sprite: Node2D) -> Dictionary:
	var tex: Texture2D = null
	var centered := true
	var offset := Vector2.ZERO
	if sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames:
			var anim := a.animation if a.sprite_frames.has_animation(a.animation) else &"default"
			for cand in [&"idle", &"Idle", &"idle_down", anim]:
				if a.sprite_frames.has_animation(cand) and a.sprite_frames.get_frame_count(cand) > 0:
					tex = a.sprite_frames.get_frame_texture(cand, 0)
					break
		centered = a.centered
		offset = a.offset
	elif sprite is Sprite2D:
		var sp := sprite as Sprite2D
		tex = sp.texture
		centered = sp.centered
		offset = sp.offset
		if tex and (sp.hframes > 1 or sp.vframes > 1 or sp.region_enabled):
			tex = null # sheets: fall back to the frame box below
	var used := Rect2(Vector2.ZERO, Vector2(16, 16))
	var size := Vector2(16, 16)
	if tex:
		size = tex.get_size()
		var key := str(tex.get_rid().get_id()) if not (tex is AtlasTexture) else "%s:%s" % [tex.atlas.resource_path, str(tex.region)]
		if _foot_cache.has(key):
			used = _foot_cache[key]
		else:
			var img := tex.get_image()
			if img:
				if img.is_compressed():
					img.decompress()
				var r := img.get_used_rect()
				if r.size.x > 0:
					used = Rect2(r)
			_foot_cache[key] = used
	var top_left := offset - (size / 2.0 if centered else Vector2.ZERO)
	var bottom := Vector2(used.position.x + used.size.x / 2.0, used.end.y) + top_left
	var xf := sprite.transform
	var top := Vector2(bottom.x, used.position.y + top_left.y)
	return {"foot": xf * bottom - Vector2(0, 1), "top": (xf * top).y, "width": used.size.x * absf(sprite.scale.x)}

func _process(delta: float) -> void:
	if _in_flight:
		var p := get_parent() as Node2D
		global_rotation = 0.0
		global_position = p.global_position + Vector2(0, hover)
		return
	if _owner_char and not _owner_char.is_alive:
		_fade = maxf(_fade - delta * 1.2, 0.0)
		queue_redraw()
	elif hover > 0.0:
		queue_redraw()

func _draw() -> void:
	if _fade <= 0.0:
		return
	# Flyers bob: the higher they are, the smaller and fainter the shadow.
	var k := 1.0
	if hover > 0.0 and not _in_flight:
		k = 0.8 + 0.12 * sin(Time.get_ticks_msec() / 160.0)
	var r := radius * k
	var col := Color(COLOR, COLOR.a * _fade * (0.75 if hover > 0.0 else 1.0))
	# Two stacked ellipses: a faint wide rim and a darker core.
	_ellipse(r + Vector2(1, 0.5), Color(col, col.a * 0.5))
	_ellipse(r * 0.7, col)

# A circle squashed vertically (no polygon to triangulate, so no degenerate cases).
func _ellipse(r: Vector2, col: Color) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, r.y / maxf(r.x, 0.01)))
	draw_circle(Vector2.ZERO, r.x, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
