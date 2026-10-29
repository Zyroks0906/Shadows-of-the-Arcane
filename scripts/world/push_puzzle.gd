extends Node2D
class_name PushPuzzle

# Push the carved stone blocks onto the rune plates (F pushes a block one tile away from
# you, if the tile beyond is free). When every plate holds a block, `solved` fires.

signal solved

const TILE := 16.0
const PLATE: Texture2D = preload("res://assets/sprites/props/rune_plate.png")
const BLOCK: Texture2D = preload("res://assets/sprites/props/push_block.png")
var plates: Array[Vector2] = []
var blocks: Array = []
var done := false
var _t := 0.0

static func build(parent: Node, block_spots: Array, plate_spots: Array) -> PushPuzzle:
	var p := PushPuzzle.new()
	p.name = "PushPuzzle"
	_floor_of(parent).add_child(p) # drawn with the floor, under the characters
	for s in plate_spots:
		p.plates.append(s)
	for s in block_spots:
		var b := Block.new()
		b.puzzle = p
		parent.add_child(b)
		b.global_position = s
		p.blocks.append(b)
	return p

static func _floor_of(parent: Node) -> Node:
	# "Floor" first: in builder levels "Background" is a backdrop drawn beneath the floor
	# (z -10), so decals parented to it vanished (level_1 only has "Background").
	# The parent's own layers first: level_1 holds the vault scene, whose "Floor" (z -9)
	# would otherwise be found and hide level_1's puzzle decals under its floor.
	for recursive in [false, true]:
		for name in ["Floor", "Background"]:
			var f := parent.find_child(name, recursive, false)
			if f is TileMapLayer:
				return f
	return parent

var _told := false

func check() -> void:
	if done:
		return
	for pl in plates:
		var held := false
		for b in blocks:
			if b.global_position.distance_to(pl) < 3.0:
				held = true
		if not held:
			return
	done = true
	for b in blocks:
		b.locked = true
	CombatFX.shake(2.5, 0.3)
	AudioManager.play_bank("gem", -2.0, 0.7)
	ItemBanner.show_item("The runes awaken", "Something heavy shifts nearby: the way down is open.", Color(0.75, 0.6, 1.0))
	solved.emit()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# The first time the player comes near, say what this is.
	if not _told and not done:
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl:
			for c in plates:
				if pl.global_position.distance_to(c) < 70.0:
					_told = true
					ItemBanner.show_item("Ancient mechanism", "Push the stone blocks onto the rune plates (F next to a block).", Color(0.75, 0.6, 1.0))
					break

func _draw() -> void:
	for pl in plates:
		var c := to_local(pl)
		var on := false
		for b in blocks:
			on = on or b.global_position.distance_to(pl) < 3.0
		var glow := Color(0.8, 0.65, 1.0)
		draw_texture(PLATE, c - Vector2(8, 8))
		draw_arc(c + Vector2(0.5, 0.5), 5.0, 0.0, TAU, 16, Color(glow, 0.9 if on else 0.25 + 0.2 * sin(_t * 3.0)), 1.0)
		if on:
			draw_circle(c + Vector2(0.5, 0.5), 7.0, Color(glow, 0.18))


class Block extends StaticBody2D:
	var puzzle: PushPuzzle
	var locked := false
	var _moving := false

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 12)
		shape.shape = r
		add_child(shape)
		GroundShadow.attach(self, 0.0, 1.0)

	func interact(body: Node2D = null) -> void:
		if locked or _moving or not body:
			return
		var away := global_position - body.global_position
		var dir := Vector2(signf(away.x), 0) if absf(away.x) > absf(away.y) else Vector2(0, signf(away.y))
		var to := global_position + dir * PushPuzzle.TILE
		# The tile beyond must be free of walls, props and other blocks.
		var q := PhysicsShapeQueryParameters2D.new()
		var probe := RectangleShape2D.new()
		probe.size = Vector2(12, 10)
		q.shape = probe
		q.transform = Transform2D(0.0, to)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			AudioManager.play_bank_at("ui_error", global_position, -10.0, 0.7)
			return
		_moving = true
		AudioManager.play_bank_at("stomp", global_position, -8.0, 1.3)
		CombatFX.burst(global_position + Vector2(0, 5), Color(0.5, 0.45, 0.42), 6, 25.0, 0.3, 40.0, 1.5)
		var tw := create_tween()
		tw.tween_property(self, "global_position", to, 0.18).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		_moving = false
		puzzle.check()

	func _draw() -> void:
		# The carved stone block (tools/gen_props_art.py); its rune lights once it's in place.
		draw_texture(PushPuzzle.BLOCK, Vector2(-8, -11))
		if locked:
			draw_arc(Vector2(-0.5, -0.5), 3.0, 0.0, TAU, 12, Color(0.8, 0.65, 1.0, 0.9), 1.0)
			draw_circle(Vector2(-0.5, -0.5), 5.0, Color(0.8, 0.65, 1.0, 0.15))
