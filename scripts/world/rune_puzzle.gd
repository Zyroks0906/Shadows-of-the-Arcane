extends Node2D
class_name RunePuzzle

# The Rune Vault's lock: a stone tablet keeps showing four runes lighting up one after
# another; step on the floor runes in that order. A wrong rune makes the floor spike up
# under you and the order starts again. When the sequence is complete the cages around the
# treasure sink into the floor.

signal solved

const STEP := 7.0
const STONE: Texture2D = preload("res://assets/sprites/props/rune_stone.png")
const TABLET: Texture2D = preload("res://assets/sprites/props/rune_tablet.png") # how close you must stand on a rune
var stones: Array[Vector2] = []
var order: Array[int] = []
var chests: Array = []
var cages: Array = []
var _progress := 0
var _lit: Array[bool] = []
var _on := -1
var _t := 0.0
var done := false
var tablet_pos := Vector2.ZERO

static func build(parent: Node, stone_spots: Array, tablet: Vector2, guarded: Array) -> RunePuzzle:
	var p := RunePuzzle.new()
	p.name = "RunePuzzle"
	PushPuzzle._floor_of(parent).add_child(p) # floor runes: under the characters
	for s in stone_spots:
		p.stones.append(s)
		p._lit.append(false)
	p.order.assign(range(p.stones.size()))
	p.order.shuffle()
	p.tablet_pos = tablet
	for c in guarded:
		p.chests.append(c)
		c.locked_reason = "Iron bars hold it. The runes on the floor must be woken in the right order."
		var cage = BrazierPuzzle._Cage.new()
		c.add_child(cage)
		p.cages.append(cage)
	return p

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if done:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var standing := -1
	if player:
		for i in stones.size():
			if player.global_position.distance_to(stones[i]) <= STEP:
				standing = i
	if standing != _on:
		_on = standing
		if standing >= 0:
			_step(standing, player)

func _step(i: int, player: Node2D) -> void:
	if _lit[i]:
		return
	if order[_progress] == i:
		_lit[i] = true
		_progress += 1
		AudioManager.play_bank_at("gem", stones[i], -4.0, 0.8 + _progress * 0.15)
		CombatFX.burst(stones[i], Color(0.7, 0.55, 1.0), 12, 40.0, 0.4, -40.0, 1.5)
		if _progress >= order.size():
			_solve()
		return
	# Wrong rune: the floor bites back and every rune goes dark.
	CombatFX.spike_ring("Bone", stones[i], 8.0, 6, 16.0)
	AudioManager.play_bank_at("ui_error", stones[i], -2.0, 0.7)
	if player is Player:
		player.receive_damage(maxi(4, roundi(player.max_health * 0.1)))
	for k in _lit.size():
		_lit[k] = false
	_progress = 0

func _solve() -> void:
	done = true
	for c in chests:
		if is_instance_valid(c):
			c.locked_reason = ""
	for cage in cages:
		if is_instance_valid(cage):
			cage.open()
	CombatFX.shake(2.5, 0.3)
	AudioManager.play_bank("chain", 0.0, 0.8)
	ItemBanner.show_item("The vault opens", "The runes answer: the treasure is yours.", Color(0.75, 0.6, 1.0))
	solved.emit()

func _glyph(c: Vector2, idx: int, col: Color, s: float = 1.0) -> void:
	# Four distinct runes: a triangle, a diamond, a cross and a ring with a bar.
	match idx % 4:
		0:
			draw_polyline(PackedVector2Array([c + Vector2(0, -3) * s, c + Vector2(3, 2) * s, c + Vector2(-3, 2) * s, c + Vector2(0, -3) * s]), col, 1.0)
		1:
			draw_polyline(PackedVector2Array([c + Vector2(0, -3) * s, c + Vector2(3, 0) * s, c + Vector2(0, 3) * s, c + Vector2(-3, 0) * s, c + Vector2(0, -3) * s]), col, 1.0)
		2:
			draw_line(c + Vector2(-3, 0) * s, c + Vector2(3, 0) * s, col, 1.0)
			draw_line(c + Vector2(0, -3) * s, c + Vector2(0, 3) * s, col, 1.0)
			draw_line(c + Vector2(-2, -2) * s, c + Vector2(2, 2) * s, col, 1.0)
		3:
			draw_arc(c, 2.5 * s, 0.0, TAU, 12, col, 1.0)
			draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 4) * s, col, 1.0)

func _draw() -> void:
	var dim := Color(0.45, 0.4, 0.55, 0.8)
	var glow := Color(0.8, 0.65, 1.0)
	# Floor runes: a stone disc with its glyph; lit ones glow.
	for i in stones.size():
		var c := to_local(stones[i])
		draw_texture(STONE, c - Vector2(9, 6))
		if _lit[i] or done:
			draw_set_transform(c, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 8.0, Color(glow, 0.22 + 0.1 * sin(_t * 4.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_glyph(c + Vector2(0, -0.5), i, glow if (_lit[i] or done) else dim)
	# The tablet: a standing stone showing the runes lighting up in order, again and again.
	var tc := to_local(tablet_pos)
	draw_texture(TABLET, tc + Vector2(-15, -24))
	var showing := int(_t / 0.8) % (order.size() + 2) # 4 runes, then a pause
	for k in order.size():
		var gc := tc + Vector2(-9 + k * 6, -11)
		var on := done or k == showing
		_glyph(gc, order[k], glow if on else Color(0.2, 0.17, 0.24), 0.8)
		if on and not done:
			draw_circle(gc, 3.5, Color(glow, 0.15))
