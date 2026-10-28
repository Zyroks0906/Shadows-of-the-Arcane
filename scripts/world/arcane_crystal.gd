extends StaticBody2D
class_name ArcaneCrystal

# Environmental hazard and light source. Charges up, then releases an elemental nova
# that hits everyone in range: the player and enemies. Pull enemies into it.

@export var element: ElementalSystem.Element = ElementalSystem.Element.CRYO
@export var radius: float = 44.0
@export var period: float = 4.5
@export var damage: int = 8
@export var crystal_scale: float = 1.0
## Dormant crystals only glow: scenery and light sources.
@export var pulses: bool = true

const CHARGE_TIME := 1.0

var _timer: float = 0.0
var _t: float = 0.0
var _color: Color
var _light: PointLight2D

func _ready() -> void:
	_color = ElementalSystem.get_element_color(element)
	_timer = randf_range(0.0, period)
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6) * crystal_scale
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = _color
	_light.energy = 0.9
	_light.texture_scale = 1.3 * crystal_scale
	add_child(_light)

func _physics_process(delta: float) -> void:
	_t += delta
	if not pulses:
		_light.energy = 0.8 + sin(_t * 1.5) * 0.15
		queue_redraw()
		return
	_timer += delta
	var charge := clampf((_timer - (period - CHARGE_TIME)) / CHARGE_TIME, 0.0, 1.0)
	_light.energy = 0.9 + charge * 1.6 + sin(_t * 3.0) * 0.1
	queue_redraw()
	if _timer >= period:
		_timer = 0.0
		_release()

func _release() -> void:
	CombatFX.shockwave(global_position, _color, radius, 0.35, 2.5)
	CombatFX.burst(global_position, _color, 16, 90.0, 0.4)
	AudioManager.play_bank_at("gem", global_position, -10.0, 0.8)
	for node in get_tree().get_nodes_in_group("base_character"):
		var c := node as BaseCharacter
		if c and c.is_alive and c.global_position.distance_to(global_position) <= radius:
			c.take_elemental_hit(damage, element, self)

func _draw() -> void:
	var charge := clampf((_timer - (period - CHARGE_TIME)) / CHARGE_TIME, 0.0, 1.0) if pulses else 0.0
	if charge > 0.0:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(_color, 0.15 + charge * 0.35), 1.0)
		draw_circle(Vector2.ZERO, radius * charge, Color(_color, 0.08))
	var s := crystal_scale
	var dark := _color.darkened(0.55)
	var light := _color.lightened(0.45 + charge * 0.4)
	# Three faceted shards on a rock base.
	draw_colored_polygon(Transform2D().scaled(Vector2(s, s)) * PackedVector2Array([Vector2(-7, 4), Vector2(7, 4), Vector2(5, 7), Vector2(-5, 7)]), Color(0.18, 0.17, 0.22))
	for shard in [[Vector2(-4, 4), 11.0, 3.0], [Vector2(3, 4), 8.0, 2.5], [Vector2(0, 4), 16.0, 3.5]]:
		var base: Vector2 = shard[0] * s
		var h: float = shard[1] * s
		var w: float = shard[2] * s
		var poly := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.8, -h * 0.75), base + Vector2(0, -h), base + Vector2(w * 0.8, -h * 0.75), base + Vector2(w, 0)])
		draw_colored_polygon(poly, _color)
		draw_colored_polygon(PackedVector2Array([base + Vector2(0, 0), base + Vector2(0, -h), base + Vector2(w * 0.8, -h * 0.75), base + Vector2(w, 0)]), _color.darkened(0.25))
		draw_line(base + Vector2(-w * 0.5, -h * 0.2), base + Vector2(-w * 0.3, -h * 0.75), light, 1.0)
		draw_polyline(poly, dark, 1.0)
