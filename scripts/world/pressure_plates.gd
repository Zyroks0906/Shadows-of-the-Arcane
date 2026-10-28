extends Node2D
class_name PressurePlates

# A trapped floor (Indiana Jones style): rows of pressure tiles across a corridor. In each
# row one tile is safe, marked with a faint carved ring; stepping on any other tile clicks
# and the wall trap on that row fires a quick burst of arrows across the corridor. Read the
# floor, or time a dodge through the volley.

const BURST := 3
const BURST_GAP := 0.12
const WARN := 0.15

var _plates: Array = [] # {pos, safe, trap, down_t, cooldown}

# rows: [{"y": world y, "xs": [x...], "safe": index, "trap": ArrowTrap}]
static func build(parent: Node, rows: Array) -> PressurePlates:
	var p := PressurePlates.new()
	p.name = "PressurePlates"
	p.z_index = 0
	parent.add_child(p)
	for r in rows:
		for i in r["xs"].size():
			p._plates.append({"pos": Vector2(r["xs"][i], r["y"]), "safe": i == r["safe"], "trap": r["trap"], "down": 0.0, "cd": 0.0})
	return p

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for pl in _plates:
		pl["down"] = maxf(pl["down"] - delta, 0.0)
		pl["cd"] = maxf(pl["cd"] - delta, 0.0)
		if not player or player.global_position.distance_to(pl["pos"]) > 6.0:
			continue
		pl["down"] = 0.25
		if pl["safe"] or pl["cd"] > 0.0 or not is_instance_valid(pl["trap"]):
			continue
		pl["cd"] = 1.2
		_trigger(pl)
	queue_redraw()

func _trigger(pl: Dictionary) -> void:
	AudioManager.play_bank_at("ui_click", pl["pos"], -2.0, 0.6)
	await get_tree().create_timer(WARN).timeout
	for i in BURST:
		if is_instance_valid(pl["trap"]):
			pl["trap"]._fire_arrow()
		await get_tree().create_timer(BURST_GAP).timeout

func _draw() -> void:
	for pl in _plates:
		var c: Vector2 = to_local(pl["pos"])
		var sink := 1.0 if pl["down"] > 0.0 else 0.0
		var r := Rect2(c - Vector2(6, 6) + Vector2(0, sink), Vector2(12, 12))
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.22))
		draw_rect(r, Color(0.55, 0.5, 0.6, 0.35), false, 1.0)
		if pl["safe"]:
			draw_arc(c + Vector2(0, sink), 3.0, 0.0, TAU, 12, Color(0.75, 0.7, 0.55, 0.22), 1.0)
		else:
			# hairline cracks around the tile edge
			draw_line(r.position + Vector2(2, 2), r.position + Vector2(5, 4), Color(0, 0, 0, 0.35), 1.0)
			draw_line(r.end - Vector2(2, 3), r.end - Vector2(5, 5), Color(0, 0, 0, 0.35), 1.0)
