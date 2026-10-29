extends Node2D
class_name SluicePuzzle

# Sluice Hall: canals of deep water cut the room, a grotto waits on the far bank. Each
# lever opens or shuts the sluices of some canals (its plate shows their colours, and each
# canal is edged in its colour); a canal drains while its sluice is open. Drain them all
# to walk across. Levers toggle, so the order does not matter, only which ones are pulled.

signal solved

const T := 16
const COLORS: Array[Color] = [Color(0.45, 0.78, 1.0), Color(0.5, 1.0, 0.62), Color(0.88, 0.58, 1.0), Color(1.0, 0.8, 0.4)]

var channels: Array = [] # {cells: Array[Vector2i] (water map cells), rect: Rect2 (world), tiles: Dictionary, body: StaticBody2D, full: bool}
var levers: Array = []
var water: TileMapLayer
var done := false
var _told := false
var _hint_at := Vector2.ZERO

static func build(level: Node, cells: Array, lever_spots: Array) -> SluicePuzzle:
	var p := SluicePuzzle.new()
	p.name = "SluicePuzzle"
	p.z_index = -8 # over the water, under walls and characters
	level.add_child(p)
	p.water = level.get_node_or_null("Water") as TileMapLayer
	p._make_channels(cells)
	lever_spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var n := p.channels.size()
	for i in lever_spots.size():
		# Three canals: lever 1 drives A+B, lever 2 drives B+C, lever 3 drives A. The answer
		# is levers 2 and 3; pulling all three leaves C dry and A, B flooded again... and so on.
		var drives: Array = [[0, 1], [1, 2], [0]][i] if n == 3 and i < 3 else [i % n, (i + 1) % n]
		var lv := Lever.new()
		lv.puzzle = p
		lv.drives = drives
		level.add_child(lv)
		lv.global_position = lever_spots[i]
		p.levers.append(lv)
		p._hint_at += lever_spots[i] / lever_spots.size()
	return p

func _make_channels(cells: Array) -> void:
	# Group the canal cells into connected canals, then order them from the entrance side
	# (east, the levers' side) to the grotto: A, B, C.
	var todo := {}
	for c in cells:
		todo[Vector2i(floori(c.x / T), floori(c.y / T))] = true
	while not todo.is_empty():
		var start: Vector2i = todo.keys()[0]
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		todo.erase(start)
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			group.append(c)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if todo.has(c + d):
					todo.erase(c + d)
					stack.append(c + d)
		var lo := group[0]
		var hi := group[0]
		for c in group:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var rect := Rect2(Vector2(lo * T), Vector2((hi - lo + Vector2i.ONE) * T))
		var tiles := {}
		for c in group:
			tiles[c] = [water.get_cell_source_id(c), water.get_cell_atlas_coords(c)] if water else [-1, Vector2i(-1, -1)]
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = rect.size
		shape.shape = r
		shape.position = rect.get_center()
		body.add_child(shape)
		add_child(body)
		channels.append({"cells": group, "rect": rect, "tiles": tiles, "body": body, "shape": shape, "full": true})
	channels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rect"].position.x > b["rect"].position.x)

func pull(lever: Lever) -> void:
	if done:
		return
	for i in lever.drives:
		if i < channels.size():
			_set_full(channels[i], not channels[i]["full"])
	await get_tree().create_timer(0.9).timeout
	for ch in channels:
		if ch["full"]:
			return
	if done:
		return
	done = true
	for lv in levers:
		lv.locked = true
	CombatFX.shake(2.0, 0.3)
	AudioManager.play_bank("gem", -2.0, 0.7)
	ItemBanner.show_item("The canals run dry", "The far bank is yours to walk to.", Color(0.5, 0.85, 1.0))
	solved.emit()

func _set_full(ch: Dictionary, full: bool) -> void:
	ch["full"] = full
	var rect: Rect2 = ch["rect"]
	var cells: Array = ch["cells"].duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	AudioManager.play_bank_at("slime", rect.get_center(), -4.0, 0.6 if full else 0.8)
	AudioManager.play_bank_at("chain", rect.get_center(), -10.0, 0.8)
	if full:
		# The water comes back: the canal is solid again, so nobody may stand in it.
		(ch["shape"] as CollisionShape2D).set_deferred("disabled", false)
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl and rect.grow(2.0).has_point(pl.global_position):
			var left := pl.global_position.x - rect.position.x < rect.end.x - pl.global_position.x
			pl.global_position.x = rect.position.x - 8.0 if left else rect.end.x + 8.0
			CombatFX.burst(pl.global_position, Color(0.5, 0.8, 1.0), 10, 50.0, 0.4, 60.0, 1.5)
	# Row by row, top to bottom: the canal fills or empties like water would.
	var row := -1
	for c in cells:
		if c.y != row:
			row = c.y
			CombatFX.burst(Vector2(c * T) + Vector2(T, T) * 0.5, Color(0.55, 0.8, 1.0, 0.8), 3, 30.0, 0.35, 40.0, 1.2)
			await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(water):
			return
		if full:
			water.set_cell(c, ch["tiles"][c][0], ch["tiles"][c][1])
		else:
			water.erase_cell(c)
	if not full:
		(ch["shape"] as CollisionShape2D).set_deferred("disabled", true)
	queue_redraw()

func _process(_delta: float) -> void:
	if _told or done:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl and pl.global_position.distance_to(_hint_at) < 90.0:
		_told = true
		ItemBanner.show_item("Sluice Hall", "Each lever opens the sluices of the canals painted on its plate. Drain them all.", Color(0.5, 0.85, 1.0))

func _draw() -> void:
	# Each canal is edged with a curb of its colour; a drained canal shows its wet bed.
	for i in channels.size():
		var ch: Dictionary = channels[i]
		var r: Rect2 = ch["rect"]
		var col: Color = COLORS[i % COLORS.size()]
		if not ch["full"]:
			draw_rect(r, Color(0.05, 0.08, 0.12, 0.45))
			for k in int(r.size.y / 8.0):
				draw_rect(Rect2(r.position + Vector2(3 + (k * 5) % int(r.size.x - 6), 4 + k * 8), Vector2(2, 1)), Color(0.5, 0.7, 0.85, 0.35))
		for x in [r.position.x, r.end.x - 2.0]:
			draw_rect(Rect2(Vector2(x, r.position.y), Vector2(2, r.size.y)), Color(0.15, 0.17, 0.22))
			draw_rect(Rect2(Vector2(x + 0.5, r.position.y), Vector2(1, r.size.y)), Color(col, 0.85))


class Lever extends StaticBody2D:
	var puzzle: SluicePuzzle
	var drives: Array = []
	var on := false
	var locked := false
	var _angle := -0.7 # handle: leaning left = shut, right = open

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 6)
		shape.shape = r
		shape.position = Vector2(0, 2)
		add_child(shape)
		GroundShadow.attach(self, 0.0, 1.0)

	func interact(_body: Node2D = null) -> void:
		if locked:
			return
		on = not on
		AudioManager.play_bank_at("creak", global_position, -4.0, 1.2)
		var tw := create_tween()
		tw.tween_method(func(a: float) -> void:
			_angle = a
			queue_redraw(), _angle, 0.7 if on else -0.7, 0.2).set_trans(Tween.TRANS_BACK)
		puzzle.pull(self)

	func _draw() -> void:
		# Stone base plate with the colour pips of the canals it drives.
		draw_rect(Rect2(-7, -1, 14, 6), Color(0.16, 0.17, 0.22))
		draw_rect(Rect2(-7, -1, 14, 1), Color(0.34, 0.36, 0.44))
		draw_rect(Rect2(-7, 4, 14, 1), Color(0.08, 0.08, 0.1))
		for k in drives.size():
			var col: Color = SluicePuzzle.COLORS[int(drives[k]) % SluicePuzzle.COLORS.size()]
			var x := -2.0 * drives.size() + 1.0 + k * 4.0
			draw_rect(Rect2(x - 1, 1, 3, 2), col)
		# The handle: an iron bar with a worn wooden grip.
		var tip := Vector2(0, 0) + Vector2.from_angle(-PI / 2.0 + _angle) * 11.0
		draw_line(Vector2(0, 0), tip, Color(0.3, 0.3, 0.34), 2.0)
		draw_line(Vector2(0, 0), tip, Color(0.55, 0.55, 0.6), 1.0)
		draw_circle(tip, 2.0, Color(0.55, 0.36, 0.2))
		draw_circle(tip + Vector2(-0.5, -0.5), 0.8, Color(0.8, 0.6, 0.4))
		draw_circle(Vector2(0, 0), 1.5, Color(0.2, 0.2, 0.24))
