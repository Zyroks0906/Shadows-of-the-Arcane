extends Node2D
class_name PressurePlates

# A trapped corridor floor. The corridor is split into a grid of hidden cells covering its
# whole width (no slipping past along a wall). Some cells are pressure plates, a few per
# row, never side by side; stepping on one clicks and the wall trap of that row fires a
# burst of arrows across the corridor. The plates are invisible: one only shows (a sunken,
# cracked slab) after it has been triggered, so a careful player learns the safe path.

const BURST := 3
const BURST_GAP := 0.12
const WARN := 0.15

var _cells: Array = [] # {rect: Rect2, trap: bool, arrow_trap, revealed, down, cd}

# rows: [{"y": world y, "xs": [cell centre x...], "trapped": [bool...], "trap": ArrowTrap}]
static func build(parent: Node, rows: Array, cell: Vector2 = Vector2(14, 16)) -> PressurePlates:
	var p := PressurePlates.new()
	p.name = "PressurePlates"
	PushPuzzle._floor_of(parent).add_child(p) # floor decals: under the characters
	for r in rows:
		for i in r["xs"].size():
			p._cells.append({"rect": Rect2(Vector2(r["xs"][i], r["y"]) - cell / 2.0, cell), "trap": r["trapped"][i],
				"arrow_trap": r["trap"], "revealed": false, "down": 0.0, "cd": 0.0})
	return p

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for c in _cells:
		c["down"] = maxf(c["down"] - delta, 0.0)
		c["cd"] = maxf(c["cd"] - delta, 0.0)
		if not c["trap"] or not player or not (c["rect"] as Rect2).has_point(player.global_position):
			continue
		c["down"] = 0.25
		if c["cd"] > 0.0 or not is_instance_valid(c["arrow_trap"]):
			continue
		c["cd"] = 1.4
		c["revealed"] = true
		_trigger(c)
	queue_redraw()

func _trigger(c: Dictionary) -> void:
	var at: Vector2 = (c["rect"] as Rect2).get_center()
	AudioManager.play_bank_at("ui_click", at, -2.0, 0.6)
	AudioManager.play_bank_at("chain", at, -12.0, 1.6)
	await get_tree().create_timer(WARN).timeout
	for i in BURST:
		if is_instance_valid(c["arrow_trap"]):
			c["arrow_trap"]._fire_arrow()
		await get_tree().create_timer(BURST_GAP).timeout

func _draw() -> void:
	# Only plates that have already been stepped on show: sunken, cracked slabs.
	for c in _cells:
		if not c["revealed"]:
			continue
		var r: Rect2 = c["rect"]
		r.position = to_local(r.position) + Vector2(1, 1 + (1.0 if c["down"] > 0.0 else 0.0))
		r.size -= Vector2(2, 2)
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.25))
		draw_rect(r, Color(0.5, 0.42, 0.45, 0.45), false, 1.0)
		draw_line(r.position + Vector2(2, 3), r.position + Vector2(6, 6), Color(0, 0, 0, 0.45), 1.0)
		draw_line(r.position + Vector2(6, 6), r.position + Vector2(4, 10), Color(0, 0, 0, 0.45), 1.0)
		draw_line(r.end - Vector2(3, 4), r.end - Vector2(6, 7), Color(0, 0, 0, 0.45), 1.0)
