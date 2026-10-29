extends Node2D
class_name EchoPuzzle

# Echo Grotto: four crystals, each with its own note and colour. The echo stone in the
# middle plays a melody (F on it, or the first time you walk in); strike the crystals (F)
# in the same order. Two melodies, the second longer. A wrong note rings sour, stings, and
# the stone plays the melody again.

signal solved

const NOTES := ["res://assets/audio/sfx/puzzle/chime_0.wav", "res://assets/audio/sfx/puzzle/chime_1.wav",
	"res://assets/audio/sfx/puzzle/chime_2.wav", "res://assets/audio/sfx/puzzle/chime_3.wav"]
const WRONG := "res://assets/audio/sfx/puzzle/chime_wrong.wav"
const COLORS: Array[Color] = [Color(0.45, 0.8, 1.0), Color(0.55, 1.0, 0.7), Color(1.0, 0.85, 0.45), Color(0.9, 0.6, 1.0)]
const ROUNDS := [3, 5]
const GAP := 0.55

var crystals: Array = []
var stone_pos := Vector2.ZERO
var melody: Array[int] = []
var _round := 0
var _input := 0
var _playing := false
var done := false
var _heard := false
var _stone: EchoStone

static func build(level: Node, spots: Array, stone_at: Vector2) -> EchoPuzzle:
	var p := EchoPuzzle.new()
	p.name = "EchoPuzzle"
	level.add_child(p)
	p.stone_pos = stone_at
	# Crystals in reading order (top-left first) so the notes rise around the room.
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y - 4.0 or (absf(a.y - b.y) <= 4.0 and a.x < b.x))
	for i in spots.size():
		var c := Crystal.new()
		c.puzzle = p
		c.note = i % NOTES.size()
		level.add_child(c)
		c.global_position = spots[i]
		p.crystals.append(c)
	p._stone = EchoStone.new()
	p._stone.puzzle = p
	level.add_child(p._stone)
	p._stone.global_position = stone_at
	p._new_melody()
	return p

func _new_melody() -> void:
	melody.clear()
	var last := -1
	for i in ROUNDS[_round]:
		var n := randi() % crystals.size()
		while n == last:
			n = randi() % crystals.size()
		melody.append(n)
		last = n
	_input = 0

func play_melody() -> void:
	if _playing or done:
		return
	_playing = true
	_input = 0
	_stone.glow = 1.0
	await get_tree().create_timer(0.5).timeout
	for n in melody:
		if not is_instance_valid(self):
			return
		crystals[n].ring(false)
		await get_tree().create_timer(GAP).timeout
	_stone.glow = 0.0
	_playing = false

func strike(c: Crystal) -> void:
	if done or _playing:
		return
	if c.note == melody[_input]:
		c.ring(true)
		_input += 1
		if _input < melody.size():
			return
		_round += 1
		if _round >= ROUNDS.size():
			_solve()
			return
		AudioManager.play_bank("gem", -6.0, 1.2)
		CombatFX.floating_label(stone_pos + Vector2(0, -14), "AGAIN, LONGER", Color(0.8, 0.9, 1.0), 1.0)
		_new_melody()
		await get_tree().create_timer(1.0).timeout
		play_melody()
		return
	# A sour note: every crystal flares red, the grotto stings, and the melody repeats.
	AudioManager.play_sfx(WRONG, -2.0)
	for k in crystals:
		k.sour()
	CombatFX.shockwave(c.global_position, Color(1.0, 0.4, 0.45), 30.0, 0.35, 2.0)
	var pl := get_tree().get_first_node_in_group("player")
	if pl is Player and pl.global_position.distance_to(c.global_position) < 40.0:
		pl.receive_damage(maxi(4, roundi(pl.max_health * 0.08)))
	_input = 0
	await get_tree().create_timer(1.2).timeout
	play_melody()

func _solve() -> void:
	done = true
	for k in crystals:
		k.lit = true
	_stone.glow = 1.0
	for i in 4:
		crystals[i % crystals.size()].ring(false)
		await get_tree().create_timer(0.12).timeout
	CombatFX.shake(2.5, 0.3)
	AudioManager.play_bank("chain", 0.0, 0.8)
	ItemBanner.show_item("The grotto sings", "The grate rises: the echoes keep their treasure no more.", Color(0.6, 0.85, 1.0))
	solved.emit()

func _process(_delta: float) -> void:
	if _heard or done:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl and pl.global_position.distance_to(stone_pos) < 80.0:
		_heard = true
		ItemBanner.show_item("Echo Grotto", "Listen to the echo stone (F), then strike the crystals (F) in the same order.", Color(0.6, 0.85, 1.0))
		play_melody()


class Crystal extends StaticBody2D:
	var puzzle: EchoPuzzle
	var note := 0
	var lit := false
	var _flash := 0.0
	var _sour := 0.0
	var _t := randf() * 10.0
	var _light: PointLight2D

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(10, 6)
		shape.shape = r
		shape.position = Vector2(0, -1)
		add_child(shape)
		GroundShadow.attach(self, 0.0, 1.0)
		_light = PointLight2D.new()
		_light.texture = LevelAmbience.light_texture()
		_light.color = EchoPuzzle.COLORS[note]
		_light.energy = 0.25
		_light.texture_scale = 0.5
		_light.position = Vector2(0, -10)
		add_child(_light)

	func interact(_body: Node2D = null) -> void:
		puzzle.strike(self)

	func ring(by_player: bool) -> void:
		_flash = 1.0
		AudioManager.play_sfx(EchoPuzzle.NOTES[note], -3.0 if by_player else -1.0)
		CombatFX.burst(global_position + Vector2(0, -12), EchoPuzzle.COLORS[note], 8, 40.0, 0.45, -30.0, 1.5)

	func sour() -> void:
		_sour = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(_flash - delta * 1.6, 0.0)
		_sour = maxf(_sour - delta * 1.4, 0.0)
		_light.energy = 0.25 + 1.1 * _flash + (0.4 if lit else 0.0)
		_light.color = EchoPuzzle.COLORS[note].lerp(Color(1, 0.3, 0.35), _sour)
		queue_redraw()

	func _draw() -> void:
		var base: Color = EchoPuzzle.COLORS[note].lerp(Color(1, 0.35, 0.4), _sour)
		var body := base.darkened(0.45).lerp(base.lightened(0.3), _flash + (0.35 if lit else 0.0))
		var bob := sin(_t * 2.0) * 0.5
		# Rock socket.
		draw_rect(Rect2(-6, -2, 12, 4), Color(0.17, 0.19, 0.24))
		draw_rect(Rect2(-6, -2, 12, 1), Color(0.3, 0.33, 0.4))
		# Three-spire crystal: a tall centre shard and two short ones, faceted.
		var spires := [[Vector2(0, -1), 6.0, 18.0], [Vector2(-4, 0), 3.5, 9.0], [Vector2(4, 0), 3.5, 11.0]]
		for s in spires:
			var o: Vector2 = s[0] + Vector2(0, bob * 0.0)
			var w: float = s[1]
			var h: float = s[2]
			var pts := PackedVector2Array([o + Vector2(-w / 2.0, 0), o + Vector2(-w / 2.0, -h * 0.7), o + Vector2(0, -h), o + Vector2(w / 2.0, -h * 0.7), o + Vector2(w / 2.0, 0)])
			draw_colored_polygon(pts, body)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, 0), o + Vector2(0, -h), o + Vector2(w / 2.0, -h * 0.7), o + Vector2(w / 2.0, 0)]), body.darkened(0.25))
			draw_line(o + Vector2(-w / 2.0 + 1, -1), o + Vector2(-w / 2.0 + 1, -h * 0.65), Color(1, 1, 1, 0.35 + 0.5 * _flash), 1.0)
		if _flash > 0.0:
			draw_circle(Vector2(0, -10), 9.0 * _flash, Color(base, 0.18 * _flash))


class EchoStone extends StaticBody2D:
	var puzzle: EchoPuzzle
	var glow := 0.0
	var _t := 0.0

	func _ready() -> void:
		add_to_group("interactable")
		collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 6)
		shape.shape = r
		add_child(shape)
		GroundShadow.attach(self, 0.0, 1.0)

	func interact(_body: Node2D = null) -> void:
		puzzle.play_melody()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# A squat standing stone carved with concentric sound rings.
		draw_rect(Rect2(-8, -14, 16, 16), Color(0.2, 0.22, 0.28))
		draw_rect(Rect2(-8, -14, 16, 1), Color(0.38, 0.4, 0.48))
		draw_rect(Rect2(-8, 1, 16, 1), Color(0.08, 0.08, 0.1))
		draw_rect(Rect2(7, -14, 1, 16), Color(0.12, 0.13, 0.17))
		var on := 0.35 + 0.65 * glow
		for k in 3:
			var rr := 1.5 + k * 2.0 + (fmod(_t * 3.0, 2.0) if glow > 0.0 else 0.0)
			draw_arc(Vector2(0, -6), rr, 0.0, TAU, 16, Color(0.7, 0.85, 1.0, on * (1.0 - k * 0.25)), 1.0)
