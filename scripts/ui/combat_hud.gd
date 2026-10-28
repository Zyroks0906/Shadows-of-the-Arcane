extends CanvasLayer
class_name CombatHud

# Combat readouts that the original HUD lacks: the guard (block stamina) meter, dodge and
# special readiness, and a controls panel shown at the start of a level, while paused, or
# on H. Everything is drawn in code so it scales with the pixel font.

const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HELP_SECONDS := 9.0
const CONTROLS := [
	["MOVE", "WASD"],
	["ATTACK", "L-CLICK"],
	["BLOCK", "R-CLICK (PARRY ON HIT)"],
	["SKILL", "E"],
	["ULTIMATE", "Q"],
	["DODGE", "SPACE"],
	["USE / POTIONS", "F  C  V"],
	["HIDE", "H"],
]

var player: Player
var _meters: _Meters
var _help: PanelContainer
var _help_left: float = HELP_SECONDS
var _help_forced: bool = false

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_meters = _Meters.new()
	_meters.hud = self
	add_child(_meters)
	var boss_bar := BossBar.new()
	boss_bar.player = player
	add_child(boss_bar)
	_help = _build_help()
	add_child(_help)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_H:
		_help_forced = not _help_forced
		_help_left = 0.0

func _process(delta: float) -> void:
	_help_left = maxf(_help_left - delta, 0.0)
	var show_help := _help_forced or get_tree().paused or _help_left > 0.0
	var target := 1.0 if show_help else 0.0
	_help.modulate.a = move_toward(_help.modulate.a, target, delta * 3.0)
	_help.visible = _help.modulate.a > 0.01
	_meters.queue_redraw()

func _build_help() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.82)
	sb.border_color = Color(0.55, 0.45, 0.75, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	panel.add_child(grid)
	for row in CONTROLS:
		grid.add_child(_label(row[0], Color(0.75, 0.68, 0.95)))
		grid.add_child(_label(row[1], Color(1, 1, 1)))
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	# Sits 12 px above the bottom edge and grows upwards to fit its rows exactly.
	panel.offset_top = -12
	panel.offset_bottom = -12
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.modulate.a = 0.0
	return panel

func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l

class _Meters extends Node2D:
	var hud: CombatHud
	var _guard_alpha: float = 0.0
	# Health shown smoothly: the fill follows quickly, the pale "recent damage" chip waits a
	# moment and then drains, and healing flashes green.
	var _hp_fill: float = -1.0
	var _hp_chip: float = -1.0
	var _chip_hold: float = 0.0
	var _heal_flash: float = 0.0
	var _mp_fill: float = -1.0
	var _xp_fill: float = 0.0
	var _lvl_flash: float = 0.0
	var _last_level: int = -1

	func _process(delta: float) -> void:
		var p := hud.player
		if not p or not is_instance_valid(p):
			return
		var hp := float(p.current_health) / maxf(p.max_health, 1)
		if _hp_fill < 0.0:
			_hp_fill = hp
			_hp_chip = hp
		if hp > _hp_fill + 0.001:
			_heal_flash = 1.0
			_hp_chip = hp
		elif hp < _hp_fill - 0.001:
			_chip_hold = 0.45
		_hp_fill = move_toward(_hp_fill, hp, delta * 2.5)
		_chip_hold -= delta
		if _chip_hold <= 0.0:
			_hp_chip = move_toward(_hp_chip, _hp_fill, delta * 0.8)
		_hp_chip = maxf(_hp_chip, _hp_fill)
		_heal_flash = maxf(_heal_flash - delta * 2.5, 0.0)
		var mp := float(p.current_mana) / maxf(p.max_mana, 1)
		_mp_fill = mp if _mp_fill < 0.0 else move_toward(_mp_fill, mp, delta * 3.0)
		if _last_level != -1 and Progression.level > _last_level:
			_lvl_flash = 1.0
		_last_level = Progression.level
		_lvl_flash = maxf(_lvl_flash - delta * 1.5, 0.0)

	# Character level: a gold medallion left of the bars with the level number; it flashes on
	# level-up and fills its rim with the experience to the next level.
	func _level_badge(c: Vector2) -> void:
		var gold := Color(0.95, 0.78, 0.35).lerp(Color.WHITE, _lvl_flash)
		draw_circle(c, 19.0, Color(0.04, 0.03, 0.07, 0.95))
		draw_circle(c, 16.0, Color(0.16, 0.1, 0.18))
		draw_arc(c, 17.5, -PI / 2.0, -PI / 2.0 + TAU * _xp_fill, 32, Color(0.45, 1.0, 0.8), 2.5)
		draw_arc(c, 15.5, 0, TAU, 32, gold, 1.5)
		var lv := str(Progression.level)
		var fs := 14 if lv.length() < 3 else 10
		var w := CombatHud.FONT.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(CombatHud.FONT, c + Vector2(-w / 2.0, fs / 2.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0))
		draw_string(CombatHud.FONT, c + Vector2(-w / 2.0, fs / 2.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)
		var tag := "LV"
		var tw := CombatHud.FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string_outline(CombatHud.FONT, c + Vector2(-tw / 2.0, 24), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 4, Color(0, 0, 0))
		draw_string(CombatHud.FONT, c + Vector2(-tw / 2.0, 24), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, gold)

	func _bar(pos: Vector2, size: Vector2, fill: float, col: Color, chip: float = -1.0, text: String = "") -> void:
		draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), Color(0.04, 0.03, 0.07, 0.92))
		draw_rect(Rect2(pos - Vector2(1, 1), size + Vector2(2, 2)), Color(0.55, 0.5, 0.65))
		draw_rect(Rect2(pos, size), Color(0.12, 0.08, 0.12))
		if chip > fill:
			draw_rect(Rect2(pos, Vector2(size.x * chip, size.y)), Color(1.0, 0.92, 0.75, 0.85))
		draw_rect(Rect2(pos, Vector2(size.x * fill, size.y)), col)
		# Top highlight and bottom shade give the bar some volume.
		draw_rect(Rect2(pos, Vector2(size.x * fill, 2)), col.lightened(0.35))
		draw_rect(Rect2(pos + Vector2(0, size.y - 2), Vector2(size.x * fill, 2)), col.darkened(0.3))
		# Tick marks every 10% so small losses are readable.
		for i in range(1, 10):
			var x := pos.x + size.x * i / 10.0
			draw_line(Vector2(x, pos.y + size.y - 3), Vector2(x, pos.y + size.y), Color(0, 0, 0, 0.35), 1.0)
		if text != "":
			var tp := pos + Vector2(size.x + 10, size.y - 1)
			draw_string_outline(CombatHud.FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 5, Color(0, 0, 0))
			draw_string(CombatHud.FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))

	func _draw() -> void:
		var p := hud.player
		if not p or not is_instance_valid(p) or not p.is_alive or not p._guard:
			return
		var hp_col := Color(0.85, 0.16, 0.16).lerp(Color(0.4, 1.0, 0.45), _heal_flash)
		_level_badge(Vector2(32, 40))
		_bar(Vector2(60, 26), Vector2(190, 14), _hp_fill, hp_col, _hp_chip, "%d/%d" % [p.current_health, p.max_health])
		# Experience: a thin bar under the health with the character level.
		var xp_frac := float(Progression.xp) / maxf(Progression.xp_needed(), 1)
		_xp_fill = move_toward(_xp_fill, xp_frac, 0.03) if xp_frac >= _xp_fill else xp_frac
		draw_rect(Rect2(Vector2(57, 43), Vector2(196, 7)), Color(0.04, 0.03, 0.07, 0.92))
		draw_rect(Rect2(Vector2(60, 45), Vector2(190, 3)), Color(0.1, 0.16, 0.14))
		draw_rect(Rect2(Vector2(60, 45), Vector2(190 * _xp_fill, 3)), Color(0.45, 1.0, 0.8).lerp(Color.WHITE, _lvl_flash))
		var guard_y := 58.0
		if p.uses_mana:
			_bar(Vector2(60, 56), Vector2(190, 9), _mp_fill, Color(0.25, 0.5, 1.0), -1.0, "%d/%d" % [p.current_mana, p.max_mana])
			guard_y = 74.0
		var g: PlayerGuard = p._guard
		var frac := g.stamina / maxf(g.max_stamina, 1.0)
		# Guard meter: fades in when used, under the mana bar.
		var want := 1.0 if (g.blocking or frac < 0.999 or g.is_broken()) else 0.0
		_guard_alpha = move_toward(_guard_alpha, want, 0.06)
		if _guard_alpha > 0.01:
			var pos := Vector2(60, guard_y)
			var size := Vector2(120, 5)
			var fill := Color(0.95, 0.8, 0.35) if not g.is_broken() else Color(0.9, 0.35, 0.2)
			if g.in_parry_window():
				fill = Color(1, 1, 0.8)
			draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0, 0, 0, 0.7 * _guard_alpha))
			draw_rect(Rect2(pos, size), Color(0.2, 0.17, 0.12, 0.9 * _guard_alpha))
			draw_rect(Rect2(pos, Vector2(size.x * frac, size.y)), Color(fill, _guard_alpha))
			draw_string(CombatHud.FONT, pos + Vector2(size.x + 8, 6), "GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.9, 0.6, _guard_alpha))
		# Dodge and special readiness, bottom left.
		var vp := hud.get_viewport().get_visible_rect().size
		var base := Vector2(vp.x / 2.0 - 46, vp.y - 30)
		_pip(base, "SPC", p.dodge_ready_fraction(), Color(0.55, 0.8, 1.0))
		_pip(base + Vector2(46, 0), "E", p.skill_ready_fraction(), Color(0.6, 0.95, 0.8))
		_pip(base + Vector2(92, 0), "Q", p.burst_fraction(), Color(1.0, 0.82, 0.3), true)

	func _pip(center: Vector2, key: String, ready: float, color: Color, glow: bool = false) -> void:
		var r := 16.0
		if glow and ready >= 1.0:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_circle(center, r + 5 + pulse * 2.0, Color(color, 0.25 + 0.2 * pulse))
		draw_circle(center, r + 2, Color(0, 0, 0, 0.6))
		draw_circle(center, r, Color(0.12, 0.1, 0.16, 0.9))
		if ready < 1.0:
			draw_arc(center, r - 2, -PI / 2, -PI / 2 + TAU * ready, 24, Color(color, 0.5), 3.0)
		else:
			draw_circle(center, r - 2, Color(color, 0.35))
			draw_arc(center, r - 1, 0, TAU, 24, color, 2.0)
		var w := CombatHud.FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(CombatHud.FONT, center + Vector2(-w / 2.0, 4), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 1.0 if ready >= 1.0 else 0.5))
