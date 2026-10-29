extends Node2D
class_name BurningGround

# Where the necromancer's meteor lands the floor keeps burning for a while. All pixel art
# (tools/gen_burn_art.py), no drawn shapes: a charred patch with soot fading onto the
# stone, ember cracks pulsing through the char (additive), and flames that keep springing
# up somewhere, burning a moment and dying down while another catches elsewhere; sparks
# rise off it. Any enemy standing in it, or
# walking through, catches fire (Burn), refreshed while they stay. Dies down at the end.

const DECAL: Texture2D = preload("res://assets/VFX/Burn/burn_decal.png")
const GLOW: Texture2D = preload("res://assets/VFX/Burn/burn_glow.png")
const FLAME: Texture2D = preload("res://assets/VFX/Burn/small_flame.png")
const CHECK := 0.4 # seconds between burn checks
const BURN_TICKS := 4

var radius := 40.0
var duration := 6.0
var owner_player: Player
var _t := 0.0
var _check := 0.0
var _decal: Sprite2D
var _glow: Sprite2D
var _flames: Array[AnimatedSprite2D] = []
var _light: PointLight2D
var _embers: CPUParticles2D
var _life: Array = [] # per flame: [age, lifetime]

static func spawn(parent: Node, at: Vector2, r: float, seconds: float, by: Player) -> BurningGround:
	var g := BurningGround.new()
	g.radius = r
	g.duration = seconds
	g.owner_player = by
	parent.add_child(g)
	g.global_position = at
	return g

func _ready() -> void:
	var k := radius * 2.0 / DECAL.get_width()
	# The charred patch and its ember cracks, drawn with the floor (under the characters).
	var floor := CombatFX._floor_near_player(get_tree().current_scene)
	_decal = _sprite(DECAL, k)
	_glow = _sprite(GLOW, k)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = add
	for s in [_decal, _glow]:
		floor.add_child(s)
	_place_decal.call_deferred() # spawn() sets our position right after adding us
	# Flames dotted over the char, each at its own pace and size.
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 12.0)
	for i in 6:
		var a := AtlasTexture.new()
		a.atlas = FLAME
		a.region = Rect2(i * 10, 0, 10, 16)
		sf.add_frame("default", a)
	for i in int(radius / 3.5):
		var f := AnimatedSprite2D.new()
		f.sprite_frames = sf
		f.centered = false
		f.offset = Vector2(-5, -15)
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		f.speed_scale = randf_range(0.8, 1.3)
		f.frame = randi() % 6
		add_child(f)
		f.play("default")
		_flames.append(f)
		# Staggered start: some are already burning, others catch a little later.
		_life.append([randf_range(-0.8, 0.6), 0.0])
		_rekindle(i)
	_embers = _particles(Color(1.0, 0.6, 0.2), 14, -26.0, 1.3, 1.2)
	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = Color(1.0, 0.5, 0.2)
	_light.texture_scale = radius / 30.0
	add_child(_light)

# A flame catches somewhere new, for a random while, at a random size.
func _rekindle(i: int) -> void:
	var f := _flames[i]
	f.position = _random_point(0.75)
	f.flip_h = randf() < 0.5
	f.set_meta("size", randf_range(0.55, 1.05))
	_life[i][1] = randf_range(0.7, 1.6)

func _place_decal() -> void:
	for s in [_decal, _glow]:
		if is_instance_valid(s):
			s.global_position = global_position

func _sprite(tex: Texture2D, k: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(k, k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s

# Soft round motes drifting up out of the patch (embers) or floating away (ash).
func _particles(col: Color, amount: int, rise: float, life: float, size: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.texture = CombatFX._streak_tex() # sparks: little streaks flying up, not dots
	p.particle_flag_align_y = true
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(radius * 0.6, radius * 0.3)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(4.0, rise)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = size * 0.15
	p.scale_amount_max = size * 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.lightened(0.3), 0.0))
	ramp.add_point(0.15, col)
	ramp.set_color(ramp.get_point_count() - 1, Color(col.darkened(0.4), 0.0))
	p.color_ramp = ramp
	add_child(p)
	return p

func _random_point(k: float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius * k * Vector2(1.0, 0.6)

func _process(delta: float) -> void:
	_t += delta
	var fade := clampf((duration - _t) / 1.0, 0.0, 1.0)
	if _t >= duration:
		_decal.queue_free()
		_glow.queue_free()
		queue_free()
		return
	# The cracks breathe; the flames shrink away as the fire dies.
	_glow.modulate.a = (0.55 + 0.25 * sin(_t * 4.0)) * fade
	_decal.modulate.a = clampf((duration + 2.0 - _t) / 2.0, 0.0, 1.0)
	# Each flame grows in, burns, dies down, and catches again elsewhere.
	for i in _flames.size():
		var f := _flames[i]
		_life[i][0] += delta
		var age: float = _life[i][0]
		var span: float = _life[i][1]
		if age >= span and _t < duration - 1.0:
			_life[i][0] = randf_range(-0.25, 0.0) # a short gap before it catches again
			_rekindle(i)
			age = _life[i][0]
		var grow := clampf(age / 0.18, 0.0, 1.0) * clampf((span - age) / 0.3, 0.0, 1.0)
		f.visible = age > 0.0
		f.scale = Vector2.ONE * float(f.get_meta("size", 1.0)) * grow * fade
	_embers.emitting = fade > 0.3
	_light.energy = (0.6 + 0.15 * sin(_t * 9.0)) * fade
	_check -= delta
	if _check <= 0.0:
		_check = CHECK
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is BaseCharacter and e.is_alive:
				var off: Vector2 = (e.global_position - global_position) / Vector2(1.0, 0.6)
				if off.length() <= radius:
					Burn.apply(e, owner_player, BURN_TICKS)
