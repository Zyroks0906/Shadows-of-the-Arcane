extends StaticBody2D
class_name TutorialStone

# The first room teaches by doing: a row of carved stones, one lesson each. Only the next
# stone glows; walk up to it and a stone plaque at the bottom of the screen names the key
# (read from the player's own bindings) and what it does. Do it and the rune turns green
# with a chime, and the next stone wakes. Once every lesson is done it is remembered
# (user://tutorial.cfg) and later runs start without the stones.
# Art: assets/sprites/props/tutorial_stone.png (tools/gen_props_art.py).

const ART: Texture2D = preload("res://assets/sprites/props/tutorial_stone.png")
const SAVE := "user://tutorial.cfg"
const NEAR := 36.0
const LESSONS := [
	{"actions": ["move_left", "move_right", "move_up", "move_down"], "keys": "move", "text": "Walk. Explore every room: not all of them are on the way."},
	{"actions": ["attack_1"], "keys": "attack_1", "text": "Attack towards your aim. Hold it to keep swinging."},
	{"actions": ["dodge"], "keys": "dodge", "text": "Dodge: a quick roll that slips through attacks."},
	{"actions": ["block"], "keys": "block", "text": "Block. Raise it just as a blow lands to parry and stagger."},
	{"actions": ["skill", "burst"], "keys": "skill", "text": "E is your skill. Q, your ultimate, charges as you fight."},
]

var lesson: Dictionary = {}
var path: TutorialPath
var index := 0
var active := false
var done := false
var _t := 0.0
var _glow := 0.0
var _flash := 0.0

static var force_show := false # tests: show the stones whatever the player's save says

static func finished() -> bool:
	if force_show:
		return false
	var cfg := ConfigFile.new()
	return cfg.load(SAVE) == OK and cfg.get_value("tutorial", "done", false)

static func remember_finished() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(SAVE)

# The key (or keys) bound to an action, as the player set them.
static func key_text(keys: String) -> String:
	if keys == "move":
		return "%s %s %s %s" % [_key("move_up"), _key("move_left"), _key("move_down"), _key("move_right")]
	if keys == "skill":
		return "%s / %s" % [_key("skill"), _key("burst")]
	return _key(keys)

static func _key(action: String) -> String:
	var slots: Array = SettingsManager.bindings.get(action, [])
	for code in slots:
		if code != "":
			return SettingsManager.code_name(code).to_upper()
	return "?"

func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 5)
	shape.shape = r
	shape.position = Vector2(0, -2)
	add_child(shape)
	GroundShadow.attach(self, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	_glow = move_toward(_glow, 1.0 if active or done else 0.0, delta * 2.0)
	_flash = maxf(_flash - delta * 1.5, 0.0)
	queue_redraw()

func complete() -> void:
	done = true
	active = false
	_flash = 1.0
	AudioManager.play_sfx("res://assets/audio/sfx/puzzle/chime_%d.wav" % mini(index, 3), -6.0)
	CombatFX.burst(global_position + Vector2(0, -12), Color(0.55, 1.0, 0.65), 10, 30.0, 0.5, -30.0, 1.6)

func _draw() -> void:
	draw_texture(ART, Vector2(-7, -18))
	# The rune in the socket: dim until it is this stone's turn, violet while it waits,
	# green once the lesson is done.
	var col := Color(0.55, 1.0, 0.6) if done else Color(0.8, 0.6, 1.0)
	var a := 0.25 + 0.75 * _glow * (0.75 + 0.25 * sin(_t * 4.0) if active else 1.0)
	var c := Vector2(0, -9.5)
	draw_line(c + Vector2(0, -3), c + Vector2(0, 3), Color(col, a), 1.0)
	draw_line(c + Vector2(-2, -1), c + Vector2(2, 1), Color(col, a), 1.0)
	draw_line(c + Vector2(-2, 2), c + Vector2(0, 3), Color(col, a), 1.0)
	if _glow > 0.0:
		draw_circle(c, 5.0, Color(col, 0.12 * _glow + 0.3 * _flash))


# Runs the lessons in order and shows the plaque for the current one.
class TutorialPath extends Node:
	var stones: Array[TutorialStone] = []
	var current := 0
	var _moved_from := Vector2.INF
	var _plaque: CanvasLayer
	var _key_label: Label
	var _text_label: Label

	static func build(parent: Node, spots: Array) -> TutorialPath:
		var tp := TutorialPath.new()
		tp.name = "TutorialPath"
		parent.add_child(tp)
		for i in mini(spots.size(), TutorialStone.LESSONS.size()):
			var s := TutorialStone.new()
			s.lesson = TutorialStone.LESSONS[i]
			s.path = tp
			s.index = i
			parent.add_child(s)
			s.global_position = spots[i]
			tp.stones.append(s)
		tp.stones[0].active = true
		return tp

	func _ready() -> void:
		_plaque = CanvasLayer.new()
		_plaque.layer = 15
		add_child(_plaque)
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.1, 0.13, 0.93)
		sb.border_color = Color(0.52, 0.48, 0.58)
		sb.set_border_width_all(2)
		sb.border_width_top = 3
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 6
		panel.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		_key_label = _label(16, Color(0.85, 0.7, 1.0))
		_text_label = _label(11, Color(0.9, 0.88, 0.84))
		row.add_child(_key_label)
		row.add_child(_text_label)
		_plaque.add_child(panel)
		panel.modulate.a = 0.0
		_plaque.set_meta("panel", panel)

	func _label(size: int, col: Color) -> Label:
		var l := Label.new()
		l.add_theme_font_override("font", CombatFX.FONT)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return l

	func _process(delta: float) -> void:
		var panel: PanelContainer = _plaque.get_meta("panel")
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if current >= stones.size() or not pl:
			panel.modulate.a = move_toward(panel.modulate.a, 0.0, delta * 3.0)
			return
		var stone := stones[current]
		var near := pl.global_position.distance_to(stone.global_position) < TutorialStone.NEAR
		if near:
			_key_label.text = TutorialStone.key_text(stone.lesson["keys"])
			_text_label.text = stone.lesson["text"]
		var vp := panel.get_viewport().get_visible_rect().size
		var size := panel.get_combined_minimum_size()
		panel.size = size
		panel.position = Vector2((vp.x - size.x) / 2.0, vp.y - size.y - 118.0).round() # above the ability slots and the controls panel
		panel.modulate.a = move_toward(panel.modulate.a, 1.0 if near else 0.0, delta * 4.0)
		if not near:
			return
		# The lesson counts once the player has read it (is at the stone) and does it.
		var did := false
		if stone.index == 0:
			if _moved_from == Vector2.INF:
				_moved_from = pl.global_position
			did = pl.global_position.distance_to(_moved_from) > 10.0
		else:
			for a in stone.lesson["actions"]:
				did = did or Input.is_action_pressed(a)
		if did:
			stone.complete()
			current += 1
			if current < stones.size():
				stones[current].active = true
			else:
				TutorialStone.remember_finished()
				ItemBanner.show_item("You are ready", "The crypt is waiting. Good luck.", Color(0.55, 1.0, 0.65))
