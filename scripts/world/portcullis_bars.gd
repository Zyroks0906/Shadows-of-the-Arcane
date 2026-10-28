extends Node2D
class_name PortcullisBars

# Iron bars for arena gates, drawn in code so they read in both orientations: across a
# passage in a horizontal wall they are a row of vertical bars; in a side wall (seen
# edge-on in the 3/4 view) they are a thin barred post. They slam down when the fight
# starts and slide back up into the wall when it is won.

const T := 16.0
const IRON := Color(0.22, 0.2, 0.24)
const IRON_LIGHT := Color(0.55, 0.52, 0.58)
const OUTLINE := Color(0.05, 0.04, 0.07)

var closed: float = 0.0 # 0 = raised into the wall, 1 = fully down
var side: bool = false

func _ready() -> void:
	z_index = 2
	# Draw in world orientation even when the door node was rotated for a side wall.
	var parent_rot: float = get_parent().rotation
	side = absf(sin(parent_rot)) > 0.5
	rotation = -parent_rot

func set_closed(on: bool, animate: bool = true) -> void:
	var target := 1.0 if on else 0.0
	if not animate:
		closed = target
		queue_redraw()
		return
	var tw := create_tween()
	if on:
		tw.tween_method(_set_amount, closed, 1.0, 0.16).set_ease(Tween.EASE_IN)
	else:
		tw.tween_method(_set_amount, closed, 0.0, 0.5).set_ease(Tween.EASE_OUT)

func _set_amount(v: float) -> void:
	closed = v
	queue_redraw()

func _draw() -> void:
	if closed <= 0.01:
		return
	if side:
		_draw_side()
	else:
		_draw_front()

# Facing the camera: four bars hanging from the lintel, spiked tips at the bottom.
func _draw_front() -> void:
	var top := -T / 2.0 - 4.0
	var length := (T + 2.0) * closed
	draw_rect(Rect2(-T / 2.0, top - 2.0, T, 3.0), OUTLINE)
	draw_rect(Rect2(-T / 2.0 + 0.5, top - 1.5, T - 1.0, 2.0), IRON_LIGHT)
	for i in 4:
		var x := -T / 2.0 + 2.0 + i * 4.0
		draw_rect(Rect2(x - 1.0, top, 3.0, length), OUTLINE)
		draw_rect(Rect2(x - 0.5, top, 2.0, length), IRON)
		draw_rect(Rect2(x - 0.5, top, 1.0, length), IRON_LIGHT)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.0, top + length), Vector2(x + 2.0, top + length), Vector2(x + 0.5, top + length + 2.0)]), IRON_LIGHT)
	if closed > 0.6:
		var y := top + length * 0.55
		draw_rect(Rect2(-T / 2.0, y - 1.0, T, 2.5), OUTLINE)
		draw_rect(Rect2(-T / 2.0, y - 0.5, T, 1.5), IRON)

# Edge-on: the gate is a narrow barred frame standing across the corridor.
func _draw_side() -> void:
	var h := T * closed
	var top := T / 2.0 - h
	draw_rect(Rect2(-2.5, top - 1.0, 5.0, h + 2.0), OUTLINE)
	draw_rect(Rect2(-1.5, top, 3.0, h), IRON)
	draw_rect(Rect2(-1.5, top, 1.0, h), IRON_LIGHT)
	var y := top + 2.0
	while y < T / 2.0:
		draw_rect(Rect2(-3.0, y, 6.0, 1.5), OUTLINE)
		draw_rect(Rect2(-2.5, y, 5.0, 1.0), IRON_LIGHT)
		y += 4.0
