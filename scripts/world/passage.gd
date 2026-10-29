extends Node2D
class_name Passage

# A stairway (or ladder) between two places of the same level: F fades out and back in at
# `target`. It can be sealed by an iron grate until something (a puzzle) opens it.

var target: Node2D
var going_down := true
var locked := false
var locked_text := "A heavy grate seals the stairway."
var _t := 0.0
var _busy := false

func _ready() -> void:
	add_to_group("interactable")
	var area := Area2D.new()
	area.collision_layer = 64 # found by the player's interaction area
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 12)
	shape.shape = r
	area.add_child(shape)
	add_child(area)

func unlock() -> void:
	if not locked:
		return
	locked = false
	CombatFX.burst(global_position, Color(0.5, 0.45, 0.4), 14, 40.0, 0.5, 60.0, 1.5)
	AudioManager.play_bank_at("chain", global_position, 0.0, 0.8)
	AudioManager.play_bank_at("door_open", global_position, -2.0, 0.9)

func interact(_body: Node2D = null) -> void:
	if _busy or not is_instance_valid(target):
		return
	if locked:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.show_message(locked_text, 2.5)
		AudioManager.play_bank("ui_error", -8.0)
		return
	_busy = true
	var p := get_tree().get_first_node_in_group("player") as Player
	var layer := CanvasLayer.new()
	layer.layer = 60
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	get_tree().current_scene.add_child(layer)
	AudioManager.play_bank("footstep", -6.0, 0.8)
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.35)
	await tw.finished
	if p:
		p.global_position = target.global_position
		p.velocity = Vector2.ZERO
		if p._camera_node:
			p._camera_node.reset_smoothing()
	await get_tree().create_timer(0.15).timeout
	var tw2 := black.create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.4)
	await tw2.finished
	layer.queue_free()
	_busy = false

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var stone := Color(0.36, 0.33, 0.4)
	if going_down:
		# A stone frame around steps going down into the dark.
		draw_rect(Rect2(-9, -8, 18, 15), Color(0.12, 0.1, 0.14))
		for i in 4:
			var w := 14.0 - i * 2.0
			draw_rect(Rect2(-w / 2.0, -6 + i * 3.5, w, 2), stone.darkened(i * 0.18))
		draw_rect(Rect2(-9, -8, 18, 15), Color(0.5, 0.46, 0.52), false, 1.0)
	else:
		# A wooden ladder going up.
		draw_rect(Rect2(-5, -12, 2, 16), Color(0.45, 0.3, 0.18))
		draw_rect(Rect2(3, -12, 2, 16), Color(0.45, 0.3, 0.18))
		for i in 4:
			draw_rect(Rect2(-4, -10 + i * 4, 8, 1), Color(0.6, 0.42, 0.25))
	if locked:
		for i in 5:
			draw_rect(Rect2(-8 + i * 3.6, -8, 1.2, 15), Color(0.25, 0.25, 0.3))
		draw_rect(Rect2(-9, -2, 18, 1.5), Color(0.25, 0.25, 0.3))
	else:
		draw_circle(Vector2(0, -2), 2.0 + sin(_t * 3.0) * 0.5, Color(0.75, 0.6, 1.0, 0.15))
