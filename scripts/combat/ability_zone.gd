extends Node2D
class_name AbilityZone

# An area left by an ability: a vortex that drags enemies in, a blizzard that ticks frost,
# or a meteor that is telegraphed on the ground and then explodes. Damage goes through the
# owner's _aoe so energy, reactions and knockback behave like any other player hit.

var owner_player: Player
var radius: float = 40.0
var duration: float = 2.0
var delay: float = 0.0 # telegraph before it becomes active
var tick: float = 0.4
var damage: int = 10
var element: ElementalSystem.Element = ElementalSystem.Element.NONE
var pull: float = 0.0 # px/s towards the centre
var style: String = "wind" # wind | ice | fire
var explode_once: bool = false
var stun: float = 0.0
var burn_ground: float = 0.0 # fire: seconds the floor keeps burning after the blast

# Preloaded: textures first loaded inside _draw() came out as solid white quads.
const METEOR_TRAIL: Texture2D = preload("res://assets/VFX/Spells/fireball.png")
const METEOR_ROCK: Texture2D = preload("res://assets/VFX/Spells/rock.png")

var _t: float = 0.0
var _tick_t: float = 0.0
var _active: bool = false
var _color: Color

static func spawn(player: Player, pos: Vector2, cfg: Dictionary) -> AbilityZone:
	var z := AbilityZone.new()
	z.owner_player = player
	for k in cfg:
		z.set(k, cfg[k])
	player.get_parent().add_child(z)
	z.global_position = pos
	return z

func _ready() -> void:
	z_index = 1 # above the floor tiles (level_1 floors are at z 0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art (meteor, tornado) stays crisp
	_color = ElementalSystem.get_element_color(element) if element != ElementalSystem.Element.NONE else Color(1, 0.6, 0.3)
	if delay <= 0.0:
		_activate()

# The storm lights its own patch of the dark levels, so its colours read.
func _add_glow() -> void:
	var col := {"ice": Color(0.6, 0.85, 1.0), "wind": Color(0.6, 1.0, 0.8), "fire": Color(1.0, 0.55, 0.25)}.get(style, Color.WHITE) as Color
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = col
	light.energy = 0.35 # tints the ground only: stronger burned the hero out to white
	light.texture_scale = radius / 28.0
	light.position = Vector2(0, -radius * 0.3)
	add_child(light)
	var tw := light.create_tween()
	tw.tween_interval(maxf(duration - 0.4, 0.1))
	tw.tween_property(light, "energy", 0.0, 0.4)

func _activate() -> void:
	if not explode_once:
		_add_glow()
		if style == "wind":
			_add_funnel()
	_active = true
	match style:
		"wind":
			CombatFX.spike_ring("Wind", global_position, radius * 0.7, 6, 16.0)
			AudioManager.play_bank_at("teleport", global_position, -2.0, 0.7)
		"ice":
			CombatFX.spike_ring("Ice", global_position, radius * 0.6, 9, 24.0)
			CombatFX.spike("Ice", global_position, 30.0, 2)
			CombatFX.shockwave(global_position, _color, radius, 0.4, 2.5)
			AudioManager.play_bank_at("ice_impact", global_position, 0.0, 0.8)
		"fire":
			CombatFX.spike_ring("Fire", global_position, radius * 0.55, 10, 26.0)
			CombatFX.spike("Fire", global_position, 42.0, 2)
			CombatFX.shake(5.0, 0.35)
			CombatFX.hit_stop(0.06)
			AudioManager.play_bank_at("fire_impact", global_position, 4.0, 0.6)
			AudioManager.play_bank_at("stomp", global_position, 0.0, 0.6)
	if explode_once and is_instance_valid(owner_player):
		owner_player._aoe(global_position, radius, damage, element, 220.0, stun, "burst")
		if style != "fire":
			CombatFX.shockwave(global_position, _color, radius, 0.4, 3.0)
		if style == "fire":
			# The meteor: a painted blast at the hero's scale (no flat ring); the burning
			# ground it leaves carries the rest.
			CombatFX.pvfx("warm-explosion", global_position, radius / 55.0)
			if burn_ground > 0.0:
				BurningGround.spawn(get_parent(), global_position, radius * 0.8, burn_ground, owner_player)
			CombatFX.pvfx("solar-shrapnel", global_position, radius / 60.0)

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _active:
		if _t >= delay:
			_t = 0.0
			_activate()
		return
	if _t >= duration:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
		set_physics_process(false)
		return
	if explode_once or not is_instance_valid(owner_player):
		return
	if pull > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and e.is_alive:
				var to: Vector2 = global_position - e.global_position
				if to.length() < radius * 1.4 and to.length() > 4.0:
					e.move_and_collide(to.normalized() * pull * delta)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = tick
		owner_player._aoe(global_position, radius, damage, element, 0.0, 0.0, "burst")
		# Wind: leaves torn off and flung round the funnel.
		if style == "wind":
			CombatFX.pvfx("leaf-gust", global_position + Vector2(randf_range(-radius, radius) * 0.5, -randf() * radius), 0.4, randf() * TAU, Color(0.85, 1.0, 0.85))
		# Blizzard: sleet sheets and frost novas across the storm with every tick.
		if style == "ice":
			CombatFX.pvfx("rain-field", global_position + Vector2(randf_range(-0.4, 0.4) * radius, 0), radius / 50.0, 0.0, Color(0.85, 0.95, 1.0))
			for i in 2:
				var at := global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, radius * 0.8)
				CombatFX.pvfx("frost-nova", at, randf_range(0.35, 0.5))

func _draw() -> void:
	if not _active:
		# Telegraph: a filling circle on the ground so enemies (and the player) see it coming.
		var k := clampf(_t / maxf(delay, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(_color, 0.12))
		draw_circle(Vector2.ZERO, radius * k, Color(_color, 0.22))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(_color, 0.8), 1.5)
		if style == "fire":
			# The meteor itself, falling from above the screen onto the mark.
			var m := Vector2(-40.0, -160.0) * (1.0 - k)
			# Smoke trail, then the pixel-art fireball (StarsteelGaming) pointing down its path.
			for i in 6:
				var tail := m - Vector2(40.0, 160.0).normalized() * (8.0 + i * 6.0)
				draw_circle(tail, 3.0 + i * 0.8, Color(0.25, 0.2, 0.22, 0.35 - i * 0.05))
			# A burning rock: the fireball (StarsteelGaming) as its flaming trail, the rock
			# (DevWizard) at its head, spinning as it falls.
			var tex := METEOR_TRAIL
			# Only the three clean comet frames: the later ones break into loose dashes that
			# read as a glitched texture. Pixel-exact scale, the ball's head (x=48) on the rock.
			var frame := 1 + int(_t * 14.0) % 3
			draw_set_transform(m, Vector2(40.0, 160.0).angle(), Vector2.ONE)
			draw_texture_rect_region(tex, Rect2(-48, -16, 64, 32), Rect2(frame * 64, 0, 64, 32))
			# The rock tumbles in quarter turns: free rotation smears the pixel art.
			draw_set_transform(m, floorf(_t * 10.0) * PI * 0.5, Vector2.ONE)
			draw_texture(METEOR_ROCK, Vector2(-8, -8), Color(1.0, 0.85, 0.75))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if explode_once:
		return
	match style:
		"ice":
			_draw_blizzard()
		"wind":
			_draw_tornado()
		_:
			draw_circle(Vector2.ZERO, radius, Color(_color, 0.16))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(_color, 0.5), 1.0)

const FLAT := 0.6 # ground circles are seen from above at an angle: squashed ellipses

func _ellipse(r: float, col: Color) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, FLAT))
	draw_circle(Vector2.ZERO, r, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _ellipse_arc(r: float, from: float, to: float, col: Color, w: float = 1.0, y: float = 0.0) -> void:
	draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, FLAT))
	draw_arc(Vector2.ZERO, r, from, to, 24, col, w / FLAT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# A cheap stable pseudo-random number in [0, 1) per index (no visible patterns).
static func _hash(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)

func _fade() -> float:
	return clampf(minf(_t / 0.3, (duration - _t) / 0.4), 0.0, 1.0)

# Blizzard: frost spreading on the ground with an icy rim of crystals, a storm cloud
# overhead, snow driven sideways by the wind, gusts circling and hail streaking down.
func _draw_blizzard() -> void:
	var f := _fade()
	var r := radius
	var wind := Vector2(14.0, 0.0) # snow drifts right as it falls
	# Frosted ground.
	_ellipse(r, Color(0.2, 0.5, 1.0, 0.28 * f))
	_ellipse(r * 0.7, Color(0.35, 0.65, 1.0, 0.22 * f))
	_ellipse(r * 0.35, Color(0.6, 0.85, 1.0, 0.2 * f))
	# Ice crystals growing around the rim.
	for i in 16:
		var a := TAU * i / 16.0 + 0.2 * sin(i * 1.7)
		var p := Vector2(cos(a) * r, sin(a) * r * FLAT)
		var h := (3.0 + 2.5 * fposmod(i * 0.61, 1.0)) * f
		draw_colored_polygon(PackedVector2Array([p + Vector2(-1.5, 0), p + Vector2(1.5, 0), p + Vector2(0.4, -h)]), Color(0.85, 0.95, 1.0, 0.85 * f))
		draw_line(p + Vector2(0, 0), p + Vector2(0.4, -h), Color(1, 1, 1, 0.6 * f), 1.0)
	# Gusts: arcs of wind circling the storm at different heights and speeds.
	for k in 5:
		var spd := 2.2 + k * 0.5
		var a0 := _t * spd + k * 1.3
		_ellipse_arc(r * (0.45 + 0.12 * k), a0, a0 + 1.1, Color(0.9, 0.97, 1.0, 0.35 * f), 1.0, -4.0 - k * 2.0)
	# The storm cloud overhead: many soft, drifting puffs (lighter on top, darker below).
	var cloud_y := -r * 0.95
	for i in 16:
		var cx := (_hash(i) * 2.0 - 1.0) * r * 0.85 + sin(_t * 0.7 + i) * 3.0
		var cy := cloud_y + (_hash(i + 50) - 0.5) * r * 0.25
		var cr := r * (0.1 + 0.1 * _hash(i + 90))
		draw_circle(Vector2(cx, cy), cr, Color(0.7, 0.8, 1.0, 0.1 * f))
		draw_circle(Vector2(cx, cy + cr * 0.4), cr * 0.8, Color(0.35, 0.45, 0.7, 0.12 * f))
	# Snow: flakes fall from the cloud to the frost, pushed sideways, wrapping round.
	var fall := r * 0.95 + r * FLAT
	for i in 120:
		var seed := _hash(i)
		var speed := 30.0 + 40.0 * _hash(i + 977)
		var h := fposmod(_t * speed + seed * fall, fall)
		var x := (_hash(i + 311) * 2.0 - 1.0) * r * 0.95 + wind.x * (h / fall) + sin(_t * 3.0 + i) * 1.5
		var p := Vector2(x, cloud_y + h)
		if absf(x) > r:
			continue
		var big := i % 3 == 0
		var col := Color(1, 1, 1, (0.95 if big else 0.7) * f)
		if big:
			draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), col)
			draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), col)
		else:
			draw_rect(Rect2(p, Vector2(1, 1)), col)
	# Hail: a few fast streaks.
	for i in 8:
		var seed := fposmod(i * 0.754877, 1.0)
		var h := fposmod(_t * 160.0 + seed * fall, fall)
		var p := Vector2((seed * 2.0 - 1.0) * r * 0.8 + h * 0.2, cloud_y + h)
		draw_line(p, p - Vector2(2.0, 6.0), Color(0.8, 0.92, 1.0, 0.6 * f), 1.0)
	_ellipse_arc(r, 0.0, TAU, Color(0.8, 0.93, 1.0, 0.55 * f), 1.0)

# Tornado: an animated pixel-art funnel (tools/gen_tornado.py, added in _add_funnel) over
# churned ground.
func _draw_tornado() -> void:
	var f := _fade()
	var r := radius
	_ellipse(r * 0.8, Color(0.55, 0.9, 0.7, 0.07 * f))
	for k in 3:
		var a0 := -_t * 7.0 * (0.6 + 0.2 * k) + k * 2.0
		_ellipse_arc(r * (0.55 + 0.18 * k), a0, a0 + 1.6, Color(0.8, 0.9, 0.8, 0.3 * f), 1.5)

const TORNADO_SHEET := "res://assets/VFX/Tornado/tornado.png"
const TORNADO_FRAME := Vector2(66, 88)

func _add_funnel() -> void:
	var tex: Texture2D = load(TORNADO_SHEET)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 16.0)
	for i in int(tex.get_width() / TORNADO_FRAME.x):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * TORNADO_FRAME.x, 0, TORNADO_FRAME.x, TORNADO_FRAME.y)
		sf.add_frame("default", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.centered = false
	spr.offset = Vector2(-TORNADO_FRAME.x / 2.0, -TORNADO_FRAME.y + 4.0) # base on the ground
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * (radius / 55.0) # ~4-5 times the hero's height
	spr.z_index = 2
	add_child(spr)
	spr.play("default")
	spr.modulate.a = 0.0
	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate:a", 0.95, 0.25)
	tw.tween_interval(maxf(duration - 0.65, 0.1))
	tw.tween_property(spr, "modulate:a", 0.0, 0.4)
