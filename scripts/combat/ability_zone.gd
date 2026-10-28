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
	_color = ElementalSystem.get_element_color(element) if element != ElementalSystem.Element.NONE else Color(1, 0.6, 0.3)
	if delay <= 0.0:
		_activate()

# The storm lights its own patch of the dark levels, so its colours read.
func _add_glow() -> void:
	var col := {"ice": Color(0.6, 0.85, 1.0), "wind": Color(0.6, 1.0, 0.8), "fire": Color(1.0, 0.55, 0.25)}.get(style, Color.WHITE) as Color
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = col
	light.energy = 0.9
	light.texture_scale = radius / 28.0
	light.position = Vector2(0, -radius * 0.3)
	add_child(light)
	var tw := light.create_tween()
	tw.tween_interval(maxf(duration - 0.4, 0.1))
	tw.tween_property(light, "energy", 0.0, 0.4)

func _activate() -> void:
	if not explode_once:
		_add_glow()
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
		CombatFX.shockwave(global_position, _color, radius, 0.4, 3.0)
		if style == "fire":
			CombatFX.pvfx("warm-explosion", global_position, radius / 30.0)
			CombatFX.pvfx("solar-shrapnel", global_position, radius / 40.0)

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
		# Blizzard: frost novas burst across the storm with every tick.
		if style == "ice":
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
			var tex: Texture2D = load("res://assets/VFX/Spells/fireball.png")
			var frame := int(_t * 16.0) % 9
			draw_set_transform(m, Vector2(40.0, 160.0).angle(), Vector2(0.9, 0.9))
			draw_texture_rect_region(tex, Rect2(-48, -16, 64, 32), Rect2(frame * 64, 0, 64, 32))
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

# Tornado: a funnel of spinning wind rings rising from a dust storm on the ground, with
# leaves and grit whirling round it and climbing.
func _draw_tornado() -> void:
	var f := _fade()
	var r := radius
	var spin := _t * 7.0
	# Dust on the ground, swirling.
	_ellipse(r, Color(0.35, 0.8, 0.55, 0.18 * f))
	for k in 3:
		var a0 := -spin * (0.6 + 0.2 * k) + k * 2.0
		_ellipse_arc(r * (0.55 + 0.18 * k), a0, a0 + 1.6, Color(0.8, 0.9, 0.8, 0.35 * f), 1.5)
	# The funnel: rings from narrow at the ground to wide at the top, each one wobbling and
	# spinning; the back half is dimmer than the front so it reads as a solid column.
	var height := r * 1.6
	var rings := 11
	# The funnel's body: a faint green column behind the rings.
	var body := PackedVector2Array()
	for k in 12:
		var t := float(k) / 11.0
		body.append(Vector2(r * (0.12 + 0.55 * t * t + 0.1 * t) + sin(_t * 3.0 + t * 4.0) * (2.0 + 5.0 * t), -t * height))
	for k in range(11, -1, -1):
		var t := float(k) / 11.0
		body.append(Vector2(-r * (0.12 + 0.55 * t * t + 0.1 * t) + sin(_t * 3.0 + t * 4.0) * (2.0 + 5.0 * t), -t * height))
	draw_colored_polygon(body, Color(0.45, 0.9, 0.65, 0.12 * f))
	for k in rings:
		var t := float(k) / (rings - 1)
		var y := -t * height
		var rr := r * (0.12 + 0.55 * t * t + 0.1 * t)
		var wob := sin(_t * 3.0 + t * 4.0) * (2.0 + 5.0 * t)
		var a0 := spin * (1.2 - t * 0.5) + k * 0.7
		draw_set_transform(Vector2(wob, y), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, rr, a0 + PI, a0 + TAU, 16, Color(0.35, 0.75, 0.55, 0.3 * f), 2.5)
		draw_arc(Vector2.ZERO, rr, a0, a0 + PI, 16, Color(0.7, 1.0, 0.82, 0.7 * f), 2.0)
		draw_arc(Vector2.ZERO, rr * 0.8, a0 + 1.0, a0 + 2.2, 10, Color(1, 1, 1, 0.5 * f), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Debris climbing the funnel: leaves (green), grit (grey).
	for i in 22:
		var seed := fposmod(i * 0.618034, 1.0)
		var t := fposmod(_t * (0.35 + 0.3 * seed) + seed, 1.0)
		var a := _t * (5.0 + 3.0 * seed) + i
		var rr := r * (0.15 + 0.6 * t * t) + 3.0
		var p := Vector2(cos(a) * rr + sin(_t * 3.0 + t * 4.0) * (2.0 + 5.0 * t), -t * height + sin(a) * rr * 0.35)
		var col := Color(0.45, 0.75, 0.35, 0.9 * f) if i % 3 == 0 else Color(0.7, 0.68, 0.6, 0.8 * f)
		draw_rect(Rect2(p, Vector2(2, 1) if i % 3 == 0 else Vector2(1, 1)), col)
	_ellipse_arc(r, 0.0, TAU, Color(0.8, 1.0, 0.9, 0.4 * f), 1.0)
