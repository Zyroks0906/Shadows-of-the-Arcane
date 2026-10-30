extends StaticBody2D
class_name CrackedWall

# A cracked stretch of wall ('Z' in a layout) hiding a secret room: a block of stone bricks
# in the colours of the walls around it (the builder passes them), split by cracks. Three
# blows (any attack that breaks pots) bring it down and open the passage. The builder puts
# floor under it and leaves this cell out of the wall collision: this body blocks it until
# it falls.

const HITS := 3

var cell := Vector2i.ZERO      # its cell in the level grid
var brick := Color(0.55, 0.42, 0.38)
var _hits := HITS
var _shake := 0.0

func _ready() -> void:
	collision_layer = 1
	add_to_group("breakables")
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	shape.shape = r
	add_child(shape)
	z_index = 1

# Called like a pot's: by melee swings, projectiles and blasts.
func break_open(from_dir: Vector2 = Vector2.ZERO) -> void:
	if _hits <= 0:
		return
	_hits -= 1
	_shake = 1.0
	CombatFX.burst(global_position, Color(0.6, 0.56, 0.5), 8, 50.0, 0.35, 60.0, 1.5)
	AudioManager.play_bank_at("stomp", global_position, -6.0, 1.3 - _hits * 0.1)
	queue_redraw()
	if _hits > 0:
		return
	CombatFX.burst(global_position, Color(0.55, 0.5, 0.45), 26, 80.0, 0.6, 90.0, 2.2)
	CombatFX.shake(3.0, 0.25)
	AudioManager.play_bank_at("heavy_clash", global_position, -4.0, 0.6)
	AudioManager.play_bank("magic_shield", -8.0, 1.4)
	CombatFX.floating_label(global_position + Vector2(0, -12), "A HIDDEN PASSAGE", Color(1.0, 0.85, 0.5), 1.2)
	queue_free()

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		position.x = round(position.x) + (randf() - 0.5) * 2.0 * _shake
		queue_redraw()

# Stone bricks in the wall's colours, then the cracks: one more branch with every blow.
func _draw() -> void:
	var mortar := brick.darkened(0.55)
	var lit := brick.lightened(0.18)
	draw_rect(Rect2(-8, -8, 16, 16), mortar)
	for row in 4:
		var y := -8 + row * 4
		var shift := 4 if row % 2 else 0
		for k in 3:
			var x := -8 + shift + k * 8 - (8 if shift and k == 0 else 0)
			var r := Rect2(x + 0.0, y, 7, 3).intersection(Rect2(-8, -8, 16, 16))
			if r.size.x <= 0:
				continue
			draw_rect(r, brick)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), lit)
	var dark := Color(0.05, 0.04, 0.06, 0.9)
	var chip := Color(0.85, 0.8, 0.72, 0.6)
	var lines := [
		[Vector2(-1, -7), Vector2(1, -3), Vector2(-1, 0), Vector2(2, 3), Vector2(0, 7)],
		[Vector2(1, -3), Vector2(5, -1), Vector2(7, -3)],
		[Vector2(-1, 0), Vector2(-5, 2), Vector2(-7, 1)],
		[Vector2(2, 3), Vector2(5, 6)],
	]
	var shown := 2 + (HITS - _hits)
	for i in mini(shown, lines.size()):
		var pts: Array = lines[i]
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
			for s in steps + 1:
				var q := a.lerp(b, float(s) / maxf(steps, 1)).round()
				draw_rect(Rect2(q, Vector2(1, 1)), dark)
	for c in [Vector2(-4, -5), Vector2(4, 4), Vector2(-3, 5)]:
		draw_rect(Rect2(c, Vector2(1, 1)), chip)
