extends Node

# Game feel helpers: hit-stop, screen shake, damage numbers and procedural particles.
# Everything here is fire-and-forget so gameplay code can call it without bookkeeping.

const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _shake_strength: float = 0.0
var _shake_decay: float = 0.0
var _hitstop_until_ms: int = 0
var _hitstop_token: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Safety net: a hit-stop must never outlive its window (e.g. scene change mid-stop).
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() > _hitstop_until_ms + 100:
		Engine.time_scale = 1.0
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	if _shake_strength > 0.05:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, _shake_decay * delta)
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
		_shake_strength = 0.0

func shake(strength: float, duration: float = 0.2) -> void:
	if not SettingsManager.screen_shake:
		return
	if strength >= _shake_strength:
		_shake_strength = strength
		_shake_decay = strength / maxf(duration, 0.01)

func hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if until <= _hitstop_until_ms:
		return
	_hitstop_until_ms = until
	# Only the most recent hit-stop restores the time scale. Comparing timestamps
	# instead is fragile: the timer can fire a millisecond early and never reset.
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0

func damage_number(world_pos: Vector2, amount: int, color: Color = Color.WHITE, big: bool = false) -> void:
	floating_label(world_pos, str(amount), color, 1.6 if big else 1.0)

# Floating text lives on its own layer that follows the camera: the level's darkness
# (CanvasModulate) never dims damage numbers or labels.
var _labels: CanvasLayer

func _text_layer(scene: Node) -> Node:
	if not is_instance_valid(_labels) or _labels.get_parent() != scene:
		_labels = CanvasLayer.new()
		_labels.name = "FloatingText"
		_labels.layer = 4
		_labels.follow_viewport_enabled = true
		scene.add_child(_labels)
	return _labels

func floating_label(world_pos: Vector2, text: String, color: Color, size_mult: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var root := Node2D.new()
	root.z_index = 100
	root.global_position = world_pos + Vector2(randf_range(-6, 6), -18)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", int(16 * size_mult))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 30)
	label.position = Vector2(-100, -15)
	root.add_child(label)
	root.scale = Vector2(0.25, 0.25)
	_text_layer(scene).add_child(root)

	var drift := Vector2(randf_range(-10, 10), -22)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(0.45, 0.45) * size_mult, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector2(0.3, 0.3) * size_mult, 0.12)
	tw.parallel().tween_property(root, "position", root.position + drift, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(root.queue_free)

func burst(world_pos: Vector2, color: Color, amount: int = 16, speed: float = 90.0, lifetime: float = 0.45, gravity: float = 0.0, size: float = 2.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var p := CPUParticles2D.new()
	p.z_index = 50
	p.global_position = world_pos
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.5))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# A small, directional spurt at the point of impact: a handful of 1-2 px drops thrown
# away from the attacker, falling and fading in ~0.3 s. No lingering mess.
func blood(world_pos: Vector2, dir: Vector2, color: Color, amount: int = 9) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var p := CPUParticles2D.new()
	p.z_index = 50
	p.global_position = world_pos
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.32
	p.explosiveness = 0.95
	p.direction = dir.normalized() if dir != Vector2.ZERO else Vector2.UP
	p.spread = 28.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 85.0
	p.gravity = Vector2(0, 260.0)
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.15))
	ramp.set_color(1, Color(color.darkened(0.3), 0.0))
	p.color_ramp = ramp
	scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

const SPIKE_DIR := "res://assets/VFX/Elemental_Spikes/%s Spike From Ground Tier %d/"
var _spike_cache: Dictionary = {}

# One-shot "spike from the ground" (kinds: Earth, Ice, Fire, Water, Wind, Crystal, Metal,
# Bone, Aether) about `height` world px tall, played once at `world_pos` (its base).
func spike(kind: String, world_pos: Vector2, height: float = 18.0, tier: int = 1, fps: float = 28.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var sf := _spike_frames(kind, tier)
	if not sf:
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := sf.get_frame_texture("default", 0)
	var sc := height / float(tex.get_height())
	a.scale = Vector2(sc, sc)
	a.offset = Vector2(0, -tex.get_height() * 0.5)
	a.global_position = world_pos + Vector2(0, 4)
	a.z_index = 3
	a.speed_scale = fps / 24.0
	scene.add_child(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)

func _spike_frames(kind: String, tier: int) -> SpriteFrames:
	var key := "%s%d" % [kind, tier]
	if _spike_cache.has(key):
		return _spike_cache[key]
	var base := SPIKE_DIR % [kind, tier]
	var dir := ""
	for d in DirAccess.get_directories_at(base):
		if d.ends_with("_Frames"):
			dir = base + d + "/"
	var files := []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	if files.is_empty():
		_spike_cache[key] = null
		return null
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 24.0)
	for f in files:
		sf.add_frame("default", load(dir + f))
	_spike_cache[key] = sf
	return sf

# A ring of spikes, e.g. an earthquake: `count` spikes on a circle of `radius`.
func spike_ring(kind: String, center: Vector2, radius: float, count: int = 8, height: float = 18.0, tier: int = 1) -> void:
	for i in count:
		var a := TAU * i / count + randf_range(-0.15, 0.15)
		spike(kind, center + Vector2(cos(a), sin(a) * 0.75) * radius, height * randf_range(0.85, 1.15), tier)

# The visible swing of a melee attack: a crescent along the real attack direction, so a
# side-view sprite can still hit up, down or diagonally and read correctly.
func slash(world_pos: Vector2, dir: Vector2, reach: float, arc_deg: float, color: Color = Color(1, 1, 1), width: float = 4.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	# The hand-painted crescent (PVFX "crescent-slash", which points up at rotation 0) sized
	# to the swing's reach, tinted with the attack's colour; a faint drawn arc underneath
	# keeps the exact hit area readable.
	var d := dir.normalized()
	var fx := pvfx("crescent-slash", world_pos, reach / 34.0, d.angle() + PI / 2.0, color.lightened(0.2), 1.3, 45)
	var s := _Slash.new()
	s.dir = d
	s.reach = reach
	s.half = deg_to_rad(arc_deg * 0.5)
	s.color = Color(color, 0.35) if fx else color
	s.width = width * (0.5 if fx else 1.0)
	s.z_index = 44
	s.global_position = world_pos
	scene.add_child(s)

func shockwave(world_pos: Vector2, color: Color, radius: float, duration: float = 0.3, width: float = 3.0) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var ring := _Ring.new()
	ring.color = color
	ring.width = width
	ring.z_index = 40
	ring.global_position = world_pos
	scene.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "radius", radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(ring.queue_free)

func lightning(from: Vector2, to: Vector2, color: Color, duration: float = 0.18) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color.lightened(0.4)
	line.z_index = 45
	var segments := 7
	var normal := (to - from).orthogonal().normalized()
	for i in range(segments + 1):
		var t := float(i) / segments
		var jitter := 0.0 if i == 0 or i == segments else randf_range(-7, 7)
		line.add_point(from.lerp(to, t) + normal * jitter)
	scene.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, duration)
	tw.tween_callback(line.queue_free)

func flash(sprite: CanvasItem, duration: float = 0.12) -> void:
	if not is_instance_valid(sprite):
		return
	var mat := sprite.material as ShaderMaterial
	if mat and mat.shader and _shader_has_param(mat, "flash_amount"):
		mat.set_shader_parameter("flash_amount", 1.0)
		var tw := sprite.create_tween()
		tw.tween_method(func(v: float): mat.set_shader_parameter("flash_amount", v), 1.0, 0.0, duration)
	else:
		sprite.modulate = Color(3, 3, 3)
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, duration)

func _shader_has_param(mat: ShaderMaterial, param: String) -> bool:
	for u in mat.shader.get_shader_uniform_list():
		if u["name"] == param:
			return true
	return false

class _Ring extends Node2D:
	var color: Color = Color.WHITE
	var width: float = 3.0
	var radius: float = 2.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, width, false)
		draw_circle(Vector2.ZERO, radius * 0.9, Color(color, 0.12))

class _Slash extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var reach: float = 20.0
	var half: float = 0.8
	var color: Color = Color.WHITE
	var width: float = 4.0
	var _t: float = 0.0
	const LIFE := 0.16

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		# The edge sweeps across the arc while the tail fades.
		var a0 := dir.angle() - half
		var sweep := half * 2.0 * minf(k * 2.2, 1.0)
		# Drawn as a strip of triangles: the crescent thins to nothing at its ends and at the
		# end of its life, which a single polygon can't triangulate.
		var col := Color(color, 1.0 - k * 0.85)
		var cols := PackedColorArray([col, col, col])
		var n := 12
		var prev_o := Vector2.ZERO
		var prev_i := Vector2.ZERO
		for i in n + 1:
			var a := a0 + sweep * i / n
			var w := width * sin(float(i) / n * PI) * (1.0 - k)
			var o := Vector2.RIGHT.rotated(a) * reach
			var inn := Vector2.RIGHT.rotated(a) * (reach - w)
			if i > 0:
				draw_primitive(PackedVector2Array([prev_o, o, inn]), cols, PackedVector2Array())
				draw_primitive(PackedVector2Array([prev_o, inn, prev_i]), cols, PackedVector2Array())
			prev_o = o
			prev_i = inn

# --- PVFX Foundry effects (assets/VFX/PVFX/<name>/sheet.png + manifest.json, CC0) --------
# Hand-drawn pixel-art one-shots at 96 x 96, top-down. `pvfx` plays one at a world point:
# its pivot lands on `world_pos`; `rot` turns it (crescent-slash points up at 0), `size`
# scales it, `tint` recolours it, `speed` changes its pace. Frames are cached per effect.
var _pvfx_cache: Dictionary = {}

func pvfx(effect: String, world_pos: Vector2, size: float = 1.0, rot: float = 0.0, tint: Color = Color.WHITE, speed: float = 1.0, z: int = 30, parent: Node = null) -> AnimatedSprite2D:
	var data: Dictionary = _pvfx_frames(effect)
	if data.is_empty():
		return null
	var host: Node = parent if parent else get_tree().current_scene
	if not host:
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = data["frames"]
	spr.centered = false
	spr.offset = -data["pivot"]
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(size, size)
	spr.rotation = rot
	spr.modulate = tint
	spr.speed_scale = speed
	spr.z_index = z
	host.add_child(spr)
	spr.global_position = world_pos
	spr.play("default")
	spr.animation_finished.connect(spr.queue_free)
	return spr

func _pvfx_frames(effect: String) -> Dictionary:
	if _pvfx_cache.has(effect):
		return _pvfx_cache[effect]
	var dir := "res://assets/VFX/PVFX/%s/" % effect
	if not ResourceLoader.exists(dir + "sheet.png"):
		_pvfx_cache[effect] = {}
		return {}
	var f := FileAccess.open(dir + "manifest.json", FileAccess.READ)
	var m: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	var tex: Texture2D = load(dir + "sheet.png")
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	var frames: Array = m.get("frames", [])
	var ms := 50.0
	if not frames.is_empty():
		var d: Dictionary = frames[0].get("duration", {})
		ms = float(d.get("numerator_ms", 1000)) / float(d.get("denominator", 20))
	sf.set_animation_speed("default", 1000.0 / maxf(ms, 1.0))
	for fr in frames:
		var sh: Dictionary = fr["sheet"]
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(sh["x"], sh["y"], sh["width"], sh["height"])
		sf.add_frame("default", at)
	var piv: Array = m.get("pivot", [48, 48])
	var out := {"frames": sf, "pivot": Vector2(piv[0], piv[1])}
	_pvfx_cache[effect] = out
	return out
