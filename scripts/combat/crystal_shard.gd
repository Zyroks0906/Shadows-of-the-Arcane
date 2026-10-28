extends Node2D
class_name CrystalShard

# Dropped by the Crystallize reaction. Drifts towards a nearby player and grants a shield.

const SHIELD_AMOUNT := 25
const SHIELD_DURATION := 12.0
const LIFETIME := 10.0
const MAGNET_RADIUS := 60.0
const PICKUP_RADIUS := 10.0

var element: ElementalSystem.Element = ElementalSystem.Element.GEO
var _age: float = 0.0
var _color: Color

func _ready() -> void:
	z_index = 5
	_color = ElementalSystem.get_element_color(element).lerp(Color.GOLDENROD, 0.35)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# Blink during the last two seconds so the player knows it is about to vanish.
	visible = _age < LIFETIME - 2.0 or int(_age * 10.0) % 2 == 0
	queue_redraw()

	var player := get_tree().get_first_node_in_group("player") as Player
	if not player or not player.is_alive:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist <= PICKUP_RADIUS:
		player.add_shield(SHIELD_AMOUNT, SHIELD_DURATION, _color)
		CombatFX.burst(global_position, _color, 14, 60.0, 0.35)
		AudioManager.play_bank("magic_shield", -4.0, 1.1)
		queue_free()
	elif dist <= MAGNET_RADIUS:
		global_position = global_position.move_toward(player.global_position, delta * lerpf(220.0, 60.0, dist / MAGNET_RADIUS))

func _draw() -> void:
	var bob := sin(_age * 5.0) * 1.5
	var pts := PackedVector2Array([Vector2(0, -6 + bob), Vector2(4, bob), Vector2(0, 6 + bob), Vector2(-4, bob)])
	draw_circle(Vector2(0, bob), 7.0, Color(_color, 0.18))
	draw_colored_polygon(pts, _color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), _color.darkened(0.5), 1.0)
	draw_line(Vector2(-1, -3 + bob), Vector2(1, -1 + bob), Color(1, 1, 1, 0.9), 1.0)
