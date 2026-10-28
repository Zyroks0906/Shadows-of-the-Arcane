extends Node2D
class_name BossBar

# The boss health bar across the top of the screen. It appears only while a boss fight is
# on (the boss has noticed the player or been hurt, and the player is near), shows the name,
# the health as a bar with a "recent damage" trail and as numbers, and fades out on defeat.

const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const WIDTH := 380.0
const HEIGHT := 12.0
const NEAR := 320.0

var player: Player
var _boss: Node2D
var _alpha: float = 0.0
var _fill: float = 1.0
var _chip: float = 1.0
var _hold: float = 0.0
var _defeated_t: float = -1.0
var _name: String = ""

func _process(delta: float) -> void:
	var b := _find_boss()
	if b and b != _boss:
		_boss = b
		_name = _display_name(b)
		_fill = float(b.current_health) / maxf(b.max_health, 1)
		_chip = _fill
		_defeated_t = -1.0
	var want := 0.0
	if is_instance_valid(_boss):
		if _boss.is_alive:
			var f := float(_boss.current_health) / maxf(_boss.max_health, 1)
			if f < _fill - 0.0005:
				_hold = 0.5
			_fill = move_toward(_fill, f, delta * 1.5)
			want = 1.0 if _engaged(_boss) else 0.0
		elif _defeated_t < 0.0:
			_defeated_t = 0.0
			_fill = 0.0
	if _defeated_t >= 0.0:
		_defeated_t += delta
		want = 1.0 if _defeated_t < 2.2 else 0.0
		if _defeated_t > 3.0:
			_boss = null
			_defeated_t = -1.0
	_hold -= delta
	if _hold <= 0.0:
		_chip = move_toward(_chip, _fill, delta * 0.6)
	_chip = maxf(_chip, _fill)
	_alpha = move_toward(_alpha, want, delta * 3.0)
	queue_redraw()

func _find_boss() -> Node2D:
	if is_instance_valid(_boss) and (_boss.is_alive or _defeated_t >= 0.0):
		return _boss
	if not player or not is_instance_valid(player):
		return null
	var best: Node2D = null
	var best_d := NEAR
	for e in get_tree().get_nodes_in_group("bosses"):
		if e is Node2D and e.is_alive and _engaged(e):
			var d := player.global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func _engaged(b: Node2D) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if player.global_position.distance_to(b.global_position) > NEAR:
		return false
	return b.has_method("is_engaged") and b.is_engaged()

func _display_name(b: Node2D) -> String:
	var n: String = b.character_name if b.character_name != "" else String(b.name)
	return "THE " + n.to_upper()

func _draw() -> void:
	if _alpha <= 0.01 or _name == "":
		return
	var vp := get_viewport().get_visible_rect().size
	var pos := Vector2((vp.x - WIDTH) / 2.0, 50.0)
	var a := _alpha
	var gold := Color(0.95, 0.78, 0.35, a)
	var dark := Color(0.04, 0.02, 0.05, 0.92 * a)
	# Name plate.
	var title := _name if _defeated_t < 0.0 else _name + "  -  DEFEATED"
	var tw := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var tp := Vector2(vp.x / 2.0 - tw / 2.0, pos.y - 8)
	draw_string_outline(FONT, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 6, Color(0, 0, 0, a))
	draw_string(FONT, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, gold)
	# Frame: dark plate, gold border, little end caps like a sword guard.
	draw_rect(Rect2(pos - Vector2(5, 4), Vector2(WIDTH + 10, HEIGHT + 8)), dark)
	draw_rect(Rect2(pos - Vector2(3, 2), Vector2(WIDTH + 6, HEIGHT + 4)), gold, false, 1.0)
	for x in [pos.x - 9, pos.x + WIDTH + 9]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, pos.y + HEIGHT / 2.0), Vector2(x + (5 if x < pos.x else -5), pos.y - 2), Vector2(x + (5 if x < pos.x else -5), pos.y + HEIGHT + 2)]), gold)
	draw_rect(Rect2(pos, Vector2(WIDTH, HEIGHT)), Color(0.15, 0.05, 0.06, a))
	draw_rect(Rect2(pos, Vector2(WIDTH * _chip, HEIGHT)), Color(1.0, 0.9, 0.7, 0.8 * a))
	var red := Color(0.78, 0.1, 0.12, a)
	draw_rect(Rect2(pos, Vector2(WIDTH * _fill, HEIGHT)), red)
	draw_rect(Rect2(pos, Vector2(WIDTH * _fill, 3)), Color(1.0, 0.35, 0.3, a))
	for i in range(1, 4):
		var x := pos.x + WIDTH * i / 4.0
		draw_line(Vector2(x, pos.y), Vector2(x, pos.y + HEIGHT), Color(0, 0, 0, 0.35 * a), 1.0)
	if is_instance_valid(_boss):
		var hp := "%d / %d" % [maxi(_boss.current_health, 0), _boss.max_health]
		var hw := FONT.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var hpp := Vector2(vp.x / 2.0 - hw / 2.0, pos.y + HEIGHT - 2)
		draw_string_outline(FONT, hpp, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, Color(0, 0, 0, a))
		draw_string(FONT, hpp, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a))
