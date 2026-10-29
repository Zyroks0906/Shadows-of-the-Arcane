extends RefCounted
class_name ExitGlow

# The "this is the way out" light, drawn by ladders, stairways and level exits: a shaft of
# light standing on a soft pool on the floor, motes drifting along it, a few glints turning
# round the pool and chevrons pulsing in the direction you will travel. `strength` fades
# the whole thing (0 = off, 1 = full).

static func draw(ci: CanvasItem, t: float, col: Color, strength: float, up: bool, height: float = 44.0) -> void:
	if strength <= 0.0:
		return
	var warm := col.lerp(Color.WHITE, 0.35)
	var breathe := 0.85 + 0.15 * sin(t * 2.2)
	var k := strength * breathe
	# Pool of light on the floor (flattened, it lies on the ground).
	ci.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.42))
	for i in 4:
		ci.draw_circle(Vector2.ZERO, 20.0 - i * 4.5, Color(col, (0.06 + i * 0.05) * k))
	ci.draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 40, Color(warm, 0.35 * k), 1.0)
	# Glints turning round the pool.
	for i in 4:
		var a := t * 0.9 + TAU * i / 4.0
		var p := Vector2.from_angle(a) * 19.0
		var tw := 0.5 + 0.5 * sin(t * 5.0 + i * 1.7)
		ci.draw_rect(Rect2(p - Vector2(0.5, 1.5), Vector2(1, 3)), Color(1, 1, 1, 0.7 * tw * k))
		ci.draw_rect(Rect2(p - Vector2(1.5, 0.5), Vector2(3, 1)), Color(1, 1, 1, 0.7 * tw * k))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The shaft: stacked translucent wedges, brightest in the core, fading towards the top.
	for i in 5:
		var top_w := 3.0 + i * 2.2
		var bot_w := 7.0 + i * 3.2
		var pts := PackedVector2Array([Vector2(-top_w, -height), Vector2(top_w, -height), Vector2(bot_w, 2), Vector2(-bot_w, 2)])
		var cols := PackedColorArray([Color(warm, 0.0), Color(warm, 0.0), Color(col, 0.07 * k), Color(col, 0.07 * k)])
		ci.draw_polygon(pts, cols)
	ci.draw_polygon(PackedVector2Array([Vector2(-1, -height * 0.8), Vector2(1, -height * 0.8), Vector2(2.5, 2), Vector2(-2.5, 2)]),
		PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22 * k), Color(1, 1, 1, 0.22 * k)]))
	# Motes drifting along the shaft (up or down with the travel direction).
	for i in 12:
		var ph := fposmod(t * 0.32 + i * 0.137, 1.0)
		var y := -2.0 - (ph if up else 1.0 - ph) * height * 0.9
		var x := sin(i * 12.9 + t * 1.3) * (3.0 + (i % 3) * 2.5) * (1.0 - absf(y) / height * 0.5)
		var a := sin(ph * PI) * 0.9 * k
		ci.draw_rect(Rect2(Vector2(x, y) - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1.0, 0.97, 0.85, a))
	# Chevrons pulsing one after another in the travel direction.
	var d := -1.0 if up else 1.0 # screen direction of travel
	for i in 3:
		var phase := fposmod(t * 1.4 - i * 0.33, 1.0)
		var a := (1.0 - phase) * 0.85 * k
		var cy := -height * 0.55 + d * i * 5.0
		ci.draw_polyline(PackedVector2Array([Vector2(-3, cy - d * 1.5), Vector2(0, cy + d * 1.5), Vector2(3, cy - d * 1.5)]), Color(warm.lightened(0.3), a), 1.0)

# A warm light that breathes with the glow; the caller adds it once and updates it.
static func light(col: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = LevelAmbience.light_texture()
	l.color = col
	l.energy = 0.0
	l.texture_scale = 0.9
	l.position = Vector2(0, -8)
	return l
