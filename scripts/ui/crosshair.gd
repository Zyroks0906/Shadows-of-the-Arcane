extends CanvasLayer
class_name Crosshair

# Pixel-art crosshair that replaces the mouse cursor during gameplay. It closes in and
# turns red when an enemy is inside the current weapon's reach, and draws a charge ring
# for weapons that charge (the Archer's bow). The system cursor comes back while paused.

const PIXEL := 2.0 # screen pixels per art pixel (the camera zooms the world x2)
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_LOCK := Color(1.0, 0.32, 0.25, 1.0)
const COLOR_CHARGED := Color(1.0, 0.85, 0.3, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.7)

var player: Node = null
var _reticle: _Reticle

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reticle = _Reticle.new()
	_reticle.owner_crosshair = self
	add_child(_reticle)

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	var alive: bool = player != null and is_instance_valid(player) and player.is_alive
	var shown: bool = alive and not paused
	_reticle.visible = shown
	var pad: bool = alive and player.using_gamepad
	if shown and not pad:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not shown:
		return
	if pad:
		var world_pt: Vector2 = player.global_position + player.aim_direction * 40.0
		_reticle.position = player.get_viewport().get_canvas_transform() * world_pt
	else:
		_reticle.position = get_viewport().get_mouse_position()
	_reticle.locked = player.aim_locked
	_reticle.charge = player.aim_charge
	_reticle.queue_redraw()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

class _Reticle extends Node2D:
	var owner_crosshair: Crosshair
	var locked := false
	var charge := -1.0 # < 0: no charge ring
	var _gap := 4.0

	func _process(delta: float) -> void:
		# Ease the gap so locking on reads as the sight closing, not a pop.
		var target_gap := 2.0 if locked else 4.0
		_gap = move_toward(_gap, target_gap, delta * 24.0)

	func _draw() -> void:
		var px := Crosshair.PIXEL
		var col := Crosshair.COLOR_LOCK if locked else Crosshair.COLOR_IDLE
		if charge >= 1.0:
			col = Crosshair.COLOR_CHARGED
		var g := roundf(_gap) * px
		var l := 3.0 * px
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var a: Vector2 = d * g
			var b: Vector2 = d * (g + l)
			draw_line(a, b, Crosshair.OUTLINE, px * 2.0)
			draw_line(a, b, col, px)
		draw_rect(Rect2(Vector2(-px, -px), Vector2(px, px) * 2.0), Crosshair.OUTLINE)
		draw_rect(Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), col)
		if charge >= 0.0:
			var r := 9.0 * px
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0, 0, 0, 0.35), px)
			if charge > 0.0:
				var ring_col := Crosshair.COLOR_CHARGED if charge >= 1.0 else Color(1, 1, 1, 0.85)
				draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(charge, 0.0, 1.0), 32, ring_col, px)
