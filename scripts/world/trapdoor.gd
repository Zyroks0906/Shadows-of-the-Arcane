extends Node2D
class_name Trapdoor

# The hatch in the Golem's chamber. While the Golem lives it won't budge; once it falls it
# can be pried open (F): the lid swings up and the player climbs down into the Undercroft
# (scenes/levels/crypt.tscn, placed far away inside level_1). The dead rise there in two
# waves; clearing them grants a rare-or-better perk and lights the ladder back up.

@export var guarded_by: String = "Golem"

enum State { SEALED, READY, OPENING, BELOW, DONE }
var state: State = State.SEALED
var crypt: Node2D # set by level1_extras
var _lid: float = 0.0
var _ladder: _LadderExit

func _ready() -> void:
	# A floor hatch: walkable, but the player's interaction area can find it.
	var area := Area2D.new()
	area.collision_layer = 64
	area.collision_mask = 0
	area.add_to_group("interactable")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	GameManager.boss_defeated.connect(func(n: String):
		if n == guarded_by and state == State.SEALED:
			state = State.READY)

func interact(_body: Node2D = null) -> void:
	match state:
		State.SEALED:
			_say("The hatch is held shut. The guardian of this room still stands.")
		State.READY:
			_open()
		State.DONE:
			_say("The Undercroft below is silent now.")

func _say(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(text, 3.0)

func _open() -> void:
	state = State.OPENING
	AudioManager.play_bank_at("creak", global_position, 2.0, 0.7)
	AudioManager.play_bank_at("chain", global_position, -2.0, 0.6)
	var tw := create_tween()
	tw.tween_method(func(v): _lid = v; queue_redraw(), 0.0, 1.0, 0.7).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(0.3).timeout
	if not crypt:
		state = State.DONE
		return
	var room := crypt.get_node_or_null("Arenas").get_child(0) as ArenaRoom
	room.cleared.connect(_on_crypt_cleared, CONNECT_ONE_SHOT)
	var ladder_pos := (crypt.get_node("Ladder") as Node2D).global_position
	_ladder = _LadderExit.new()
	_ladder.hatch = self
	crypt.add_child(_ladder)
	_ladder.global_position = ladder_pos
	state = State.BELOW
	await _travel((crypt.get_node("Entry") as Node2D).global_position + Vector2(0, -10))
	AudioManager.play_bank("roar", -4.0, 0.8)

func _on_crypt_cleared() -> void:
	await get_tree().create_timer(0.8).timeout
	if Progression.auto_pick:
		Progression.take(Progression.roll(3, Progression.Rarity.RARE)[0])
	else:
		PerkPicker.offer("FROM THE DEPTHS", Progression.roll(3, Progression.Rarity.RARE))
	if _ladder:
		_ladder.active = true

func climb_back() -> void:
	if state != State.BELOW:
		return
	state = State.DONE
	await _travel(global_position + Vector2(0, 14))

# Fade to black, move the player, fade back in (camera snaps instead of panning across).
func _travel(to: Vector2) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if not p:
		return
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
	p.global_position = to
	p.velocity = Vector2.ZERO
	if p._camera_node:
		p._camera_node.reset_smoothing()
	await get_tree().create_timer(0.15).timeout
	var tw2 := black.create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.4)
	await tw2.finished
	layer.queue_free()

func _draw() -> void:
	if _lid <= 0.0:
		return
	# The open pit...
	draw_rect(Rect2(-7, -6, 14, 13), Color(0.02, 0.01, 0.03))
	draw_rect(Rect2(-6, -5, 12, 11), Color(0.0, 0.0, 0.0))
	# ...a ladder going down...
	draw_line(Vector2(-3, -4), Vector2(-3, 5), Color(0.45, 0.3, 0.18), 1.0)
	draw_line(Vector2(3, -4), Vector2(3, 5), Color(0.45, 0.3, 0.18), 1.0)
	for y in [-2, 1, 4]:
		draw_line(Vector2(-3, y), Vector2(3, y), Color(0.38, 0.25, 0.15), 1.0)
	# ...and the lid swinging up on its top hinge: it foreshortens as it rises, then rests
	# open above the hole.
	var lid_h := maxf(12.0 * absf(cos(_lid * PI * 0.5)), 4.0)
	var y0 := -6.0 - lid_h * _lid
	draw_rect(Rect2(-7, y0, 14, lid_h), Color(0.2, 0.12, 0.08))
	draw_rect(Rect2(-6, y0 + 1, 12, lid_h - 2), Color(0.5, 0.32, 0.18))
	draw_line(Vector2(-6, y0 + lid_h * 0.5), Vector2(6, y0 + lid_h * 0.5), Color(0.62, 0.62, 0.68), 1.0)

# The ladder back up in the crypt: dark until the room is clear, then it glows and F climbs.
class _LadderExit extends Node2D:
	var hatch: Trapdoor
	var active: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		var area := Area2D.new()
		area.collision_layer = 64
		area.collision_mask = 0
		area.add_to_group("interactable")
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 18)
		shape.shape = rect
		area.add_child(shape)
		add_child(area)

	func interact(_body: Node2D = null) -> void:
		if not active:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_message"):
				hud.show_message("The dead won't let you leave yet.", 2.5)
			return
		hatch.climb_back()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if active:
			var a := 0.35 + 0.25 * sin(_t * 4.0)
			draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.85, 0.45, a * 0.4))
			draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, Color(1.0, 0.85, 0.45, a), 1.0)
