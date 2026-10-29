extends Node2D

# Builds the optional puzzle rooms of a generated level from the markers the level builder
# leaves under PuzzleMarks (see the legend in tools/level_builder.gd):
#   W / lever      -> SluicePuzzle (canals of water, levers that drain them)
#   K / Q          -> EchoPuzzle (singing crystals, the echo stone)
#   S / M / N      -> MirrorPuzzle (a sunbeam, mirrors, the sun sigil)
# Each puzzle that guards a room raises the puzzle gate nearest to it.

func _ready() -> void:
	await get_tree().process_frame # doors and gates finish their own _ready first
	var level := get_parent()
	var marks := level.get_node_or_null("PuzzleMarks")
	if not marks:
		return
	var by := {}
	for m in marks.get_children():
		var kind := String(m.name).get_slice("_", 0)
		if not by.has(kind):
			by[kind] = []
		by[kind].append((m as Node2D).global_position)
	if by.has("W"):
		SluicePuzzle.build(level, by["W"], by.get("lever", []))
	if by.has("K"):
		var echo := EchoPuzzle.build(level, by["K"], by.get("Q", [by["K"][0]])[0])
		var gate := _gate_near(echo.stone_pos)
		if gate:
			echo.solved.connect(gate.open)
	if by.has("M") and by.has("S") and by.has("N"):
		var mirrors := MirrorPuzzle.build(level, by["S"][0], by["M"], by["N"][0])
		var gate := _gate_near(by["N"][0])
		if gate:
			mirrors.solved.connect(gate.open)

func _gate_near(at: Vector2) -> Door:
	var best: Door = null
	for g in get_tree().get_nodes_in_group("puzzle_gates"):
		if g is Door and (best == null or g.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = g
	return best
