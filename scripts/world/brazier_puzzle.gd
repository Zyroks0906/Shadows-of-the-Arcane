extends Node2D
class_name BrazierPuzzle

# A timed-torch puzzle (Genshin style). Ancient braziers burn only for a few seconds once lit
# (F); when all of them burn at once, the iron cage around the reward chests rusts away.
# Put the braziers on either side of a hazard and the puzzle becomes a race through it.
#
# Usage: BrazierPuzzle.build(parent, [brazier world positions], [chests], burn_seconds)

signal solved

var braziers: Array[Brazier] = []
var chests: Array = []
var cages: Array[Node2D] = []
var done := false

static func build(parent: Node, spots: Array, guarded: Array, burn: float = 7.0) -> BrazierPuzzle:
	var p := BrazierPuzzle.new()
	p.name = "BrazierPuzzle"
	parent.add_child(p)
	for at in spots:
		var b := Brazier.new()
		b.burn_time = burn
		b.puzzle = p
		parent.add_child(b)
		b.global_position = at
		p.braziers.append(b)
	for c in guarded:
		p.chests.append(c)
		c.locked_reason = "An iron cage holds it shut. The braziers nearby are cold..."
		var cage := _Cage.new()
		c.add_child(cage)
		p.cages.append(cage)
	return p

func check() -> void:
	if done:
		return
	for b in braziers:
		if not b.lit:
			return
	done = true
	for b in braziers:
		b.keep_lit()
	for c in chests:
		if is_instance_valid(c):
			c.locked_reason = ""
	for cage in cages:
		if is_instance_valid(cage):
			cage.open()
	AudioManager.play_bank("chain", 0.0, 0.8)
	AudioManager.play_bank("door_open", -2.0, 1.1)
	CombatFX.shake(2.0, 0.3)
	ItemBanner.show_item("Puzzle solved", "The cage gives way: the treasure is yours.", Color(1.0, 0.75, 0.35))
	solved.emit()


# --- An ancient brazier ------------------------------------------------------------------
class Brazier extends StaticBody2D:
	var burn_time := 7.0
	var puzzle: BrazierPuzzle
	var lit := false
	var _left := 0.0
	var _forever := false
	var _t := 0.0
	var _light: PointLight2D

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(8, 4)
		shape.shape = r
		shape.position = Vector2(0, -1)
		add_child(shape)
		_light = PointLight2D.new()
		_light.texture = LevelAmbience.light_texture()
		_light.color = Color(1.0, 0.6, 0.25)
		_light.energy = 0.0
		_light.texture_scale = 0.9
		_light.position = Vector2(0, -12)
		add_child(_light)
		GroundShadow.attach(self, 0.0, 1.0)

	func interact(_body: Node2D = null) -> void:
		if lit:
			return
		lit = true
		_left = burn_time
		AudioManager.play_bank_at("fire_launch", global_position, -4.0, 1.2)
		CombatFX.burst(global_position + Vector2(0, -12), Color(1.0, 0.6, 0.2), 14, 50.0, 0.4, -60.0, 2.0)
		puzzle.check()

	func keep_lit() -> void:
		_forever = true

	func _process(delta: float) -> void:
		_t += delta
		if lit and not _forever:
			_left -= delta
			if _left <= 0.0:
				lit = false
				CombatFX.burst(global_position + Vector2(0, -12), Color(0.4, 0.4, 0.45), 8, 20.0, 0.5, -30.0, 2.0)
				AudioManager.play_bank_at("fire_small", global_position, -10.0, 0.6)
		var k := 0.0 if not lit else (1.0 if _forever else clampf(_left / burn_time, 0.0, 1.0))
		_light.energy = 0.25 + 0.9 * k if lit else 0.0
		queue_redraw()

	func _draw() -> void:
		var outline := Color(0.08, 0.05, 0.08)
		var stone := Color(0.42, 0.38, 0.46)
		var dark := Color(0.26, 0.23, 0.3)
		# A stone pedestal with an iron bowl.
		draw_rect(Rect2(-4, -2, 8, 3), outline)
		draw_rect(Rect2(-3, -2, 6, 2), stone)
		draw_rect(Rect2(-2, -9, 4, 8), outline)
		draw_rect(Rect2(-1, -9, 2, 7), dark)
		draw_rect(Rect2(-5, -12, 10, 3), outline)
		draw_rect(Rect2(-4, -12, 8, 2), Color(0.3, 0.28, 0.32))
		draw_rect(Rect2(-1, -6, 1, 1), Color(0.9, 0.55, 0.2, 0.4 + 0.4 * sin(_t * 3.0))) # rune
		if not lit:
			draw_rect(Rect2(-3, -13, 6, 1), Color(0.2, 0.18, 0.2)) # cold ash
			return
		# The flame shrinks as its time runs out; burning for good once the puzzle is solved.
		var k := 1.0 if _forever else clampf(_left / burn_time, 0.15, 1.0)
		var h := 4.0 + 6.0 * k + sin(_t * 14.0) * 0.8
		var w := 2.5 + 1.5 * k
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -12), Vector2(w, -12), Vector2(0, -12 - h)]), Color(1.0, 0.45, 0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, -12), Vector2(w * 0.5, -12), Vector2(0, -12 - h * 0.6)]), Color(1.0, 0.85, 0.3))


# --- The cage drawn around a guarded chest -------------------------------------------------
class _Cage extends Node2D:
	var _open_t := -1.0

	func _ready() -> void:
		z_index = 2
		# Drawn in world pixels whatever the chest's own scale, a little wider than the chest.
		var p := get_parent() as Node2D
		if p and p.scale.x != 0.0:
			scale = Vector2.ONE / p.scale

	func open() -> void:
		_open_t = 0.0
		CombatFX.burst(global_position, Color(0.5, 0.45, 0.4), 16, 40.0, 0.5, 60.0, 1.5)

	func _process(delta: float) -> void:
		if _open_t >= 0.0:
			_open_t += delta
			if _open_t > 0.6:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _open_t < 0.0 else 1.0 - _open_t / 0.6
		var sink := 0.0 if _open_t < 0.0 else _open_t * 30.0 # the bars sink into the floor
		var iron := Color(0.22, 0.22, 0.26, a)
		var hi := Color(0.45, 0.45, 0.52, a)
		# The chest is ~12 px wide and ~12 px tall around its centre: bars from -10 to +10.
		for i in 7:
			var x := -10.0 + i * 3.3
			draw_rect(Rect2(x, -12 + sink, 1.4, 21 - sink), iron)
			draw_rect(Rect2(x, -12 + sink, 0.6, 21 - sink), hi)
		draw_rect(Rect2(-11, -13 + sink, 22.4, 2), iron)
		draw_rect(Rect2(-11, 8, 22.4, 1.5), Color(iron, a * 0.8))
