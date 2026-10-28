extends CanvasLayer
class_name ControlsMenu

# Options > Controls: two keys per action (primary and secondary, both work at once), like
# most PC games. Click a slot and press a key or mouse button (Esc cancels, Backspace
# clears it). A key used by two actions is flagged in red, and saving with clashes asks
# first. Leaving with unsaved changes asks too. Also holds the gameplay toggles (aim assist,
# screen shake). Everything lives in SettingsManager (user://settings.cfg).

const GOLD := Color(0.95, 0.78, 0.35)
const VIOLET := Color(0.62, 0.42, 0.9)
const TEXT := Color(0.92, 0.88, 0.8)
const DIM := Color(0.62, 0.58, 0.54)
const CLASH := Color(1.0, 0.4, 0.35)
const W := 760.0
const ROW_H := 28.0
const AIM_STEPS := [[0.0, "Off"], [0.5, "Low"], [0.75, "Normal"], [0.9, "High"]]

static var _open: ControlsMenu

static func is_open() -> bool:
	return is_instance_valid(_open)

# `on_closed` runs when the menu closes (Settings uses it to show its AUDIO page again).
static func open_menu(on_closed: Callable = Callable()) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if is_open() or not tree:
		return
	var m := ControlsMenu.new()
	m._on_closed = on_closed
	tree.root.add_child.call_deferred(m) # safe even while the tree is setting up
	_open = m

var _table: Dictionary = {} # working copy: action -> [primary, secondary]
var _aim: float
var _shake: bool
var _slots: Dictionary = {} # "action:i" -> Button
var _waiting: String = "" # slot waiting for a key
var _warning: Label
var _aim_btn: Button
var _shake_btn: Button
var _dialog: Control
var _on_closed: Callable

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_table = SettingsManager.bindings.duplicate(true)
	_aim = SettingsManager.aim_assist
	_shake = SettingsManager.screen_shake
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.75)
	dim.size = vp
	add_child(dim)
	var rows := SettingsManager.REBINDABLE.size()
	var h := 124.0 + ROW_H * (rows + 1) + 120.0
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.08, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(W, h)
	panel.position = ((vp - panel.size) / 2.0).round()
	add_child(panel)
	_text(panel, "SETTINGS", 16, GOLD, Vector2(0, 16), W, HORIZONTAL_ALIGNMENT_CENTER)
	# Same tabs as the AUDIO page: AUDIO goes back (asking first if there are changes).
	var audio_tab := _button(panel, "AUDIO", Vector2(W / 2.0 - 190, 40), Vector2(180, 26))
	audio_tab.pressed.connect(_try_close)
	var controls_tab := _button(panel, "CONTROLS", Vector2(W / 2.0 + 10, 40), Vector2(180, 26))
	ControlsMenu.style_tab(controls_tab, true)
	_text(panel, "Click a slot and press a key. Esc cancels, Backspace clears.", 8, DIM, Vector2(0, 74), W, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 94.0
	_text(panel, "ACTION", 8, DIM, Vector2(40, y), 220, HORIZONTAL_ALIGNMENT_LEFT)
	_text(panel, "PRIMARY", 8, DIM, Vector2(300, y), 200, HORIZONTAL_ALIGNMENT_CENTER)
	_text(panel, "SECONDARY", 8, DIM, Vector2(520, y), 200, HORIZONTAL_ALIGNMENT_CENTER)
	y += 18.0
	for a in SettingsManager.REBINDABLE:
		_text(panel, String(a[1]).to_upper(), 8, TEXT, Vector2(40, y + 9), 240, HORIZONTAL_ALIGNMENT_LEFT)
		for i in 2:
			var b := _button(panel, "", Vector2(300 + i * 220, y + 2), Vector2(200, ROW_H - 6))
			b.pressed.connect(_listen.bind(a[0], i))
			_slots["%s:%d" % [a[0], i]] = b
		y += ROW_H
	y += 8.0
	_text(panel, "AIM ASSIST", 8, TEXT, Vector2(40, y + 9), 240, HORIZONTAL_ALIGNMENT_LEFT)
	_aim_btn = _button(panel, "", Vector2(300, y + 2), Vector2(200, ROW_H - 6))
	_aim_btn.pressed.connect(_cycle_aim)
	_text(panel, "SCREEN SHAKE", 8, TEXT, Vector2(40, y + 9 + ROW_H), 240, HORIZONTAL_ALIGNMENT_LEFT)
	_shake_btn = _button(panel, "", Vector2(300, y + 2 + ROW_H), Vector2(200, ROW_H - 6))
	_shake_btn.pressed.connect(func(): _shake = not _shake; _refresh())
	y += ROW_H * 2 + 6.0
	_warning = _text(panel, "", 8, CLASH, Vector2(0, y), W, HORIZONTAL_ALIGNMENT_CENTER)
	y += 20.0
	var reset := _button(panel, "RESET DEFAULTS", Vector2(40, y), Vector2(220, 30))
	reset.pressed.connect(func(): _table = SettingsManager.default_bindings.duplicate(true); _refresh())
	var back := _button(panel, "BACK", Vector2(W - 440, y), Vector2(180, 30))
	back.pressed.connect(_try_close)
	var save := _button(panel, "SAVE & EXIT", Vector2(W - 240, y), Vector2(200, 30))
	save.pressed.connect(_try_save)
	_refresh()

func _text(parent: Control, text: String, size: int, color: Color, pos: Vector2, width: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	# Sized once in the tree: before that it measures with the default font size and grows.
	l.position = pos
	l.size = Vector2(width, size + 6)
	return l

func _button(parent: Control, text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	for state in ["normal", "hover", "pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.2, 0.1, 0.24) if state != "normal" else Color(0.12, 0.07, 0.14)
		st.border_color = GOLD if state != "normal" else VIOLET
		st.set_border_width_all(2)
		b.add_theme_stylebox_override(state, st)
	b.mouse_entered.connect(func(): AudioManager.play_bank("ui_select", -14.0))
	parent.add_child(b)
	return b

# Tabs: the page you are on is gold and can't be clicked; the other one is a normal button.
static func style_tab(b: Button, active: bool) -> void:
	b.disabled = active
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.22, 0.14, 0.08)
	st.border_color = GOLD
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("disabled", st)
	b.add_theme_color_override("font_disabled_color", GOLD)

# Gives a Settings page (the AUDIO page is a scene) the same look as this one.
static func style_panel(panel: Control, title: Label) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.08, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	if title:
		title.add_theme_color_override("font_color", GOLD)

func _dirty() -> bool:
	return _table != SettingsManager.bindings or _aim != SettingsManager.aim_assist or _shake != SettingsManager.screen_shake

# Every pair of actions sharing a key, as text.
func _clashes() -> Array:
	var out := []
	for a in _table:
		for code in _table[a]:
			for other in SettingsManager.conflicts(_table, a, code):
				var line := "%s is used by %s and %s" % [SettingsManager.code_name(code), SettingsManager.action_label(a), SettingsManager.action_label(other)]
				var mirror := "%s is used by %s and %s" % [SettingsManager.code_name(code), SettingsManager.action_label(other), SettingsManager.action_label(a)]
				if not (line in out or mirror in out):
					out.append(line)
	return out

func _refresh() -> void:
	for a in _table:
		for i in 2:
			var b: Button = _slots["%s:%d" % [a, i]]
			var code: String = _table[a][i]
			var key := "%s:%d" % [a, i]
			b.text = "PRESS A KEY..." if key == _waiting else SettingsManager.code_name(code).to_upper()
			var clash := not SettingsManager.conflicts(_table, a, code).is_empty()
			b.add_theme_color_override("font_color", CLASH if clash else (GOLD if key == _waiting else TEXT))
	var aim_name := "Normal"
	for s in AIM_STEPS:
		if is_equal_approx(s[0], _aim):
			aim_name = s[1]
	_aim_btn.text = aim_name.to_upper()
	_shake_btn.text = "ON" if _shake else "OFF"
	var c := _clashes()
	_warning.text = ("Warning: " + c[0] + (" (+%d more)" % (c.size() - 1) if c.size() > 1 else "")) if not c.is_empty() else ""

func _cycle_aim() -> void:
	var i := 0
	for j in AIM_STEPS.size():
		if is_equal_approx(AIM_STEPS[j][0], _aim):
			i = j
	_aim = AIM_STEPS[(i + 1) % AIM_STEPS.size()][0]
	_refresh()

func _listen(action: String, slot: int) -> void:
	if _dialog:
		return
	_waiting = "%s:%d" % [action, slot]
	_refresh()

func _input(event: InputEvent) -> void:
	if _dialog:
		return
	if _waiting != "":
		var code := ""
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_waiting = ""
				_refresh()
				get_viewport().set_input_as_handled()
				return
			code = "" if event.keycode == KEY_BACKSPACE else SettingsManager.event_to_code(event)
		elif event is InputEventMouseButton and event.pressed:
			code = SettingsManager.event_to_code(event)
		else:
			return
		var parts := _waiting.split(":")
		_table[parts[0]][int(parts[1])] = code
		_waiting = ""
		var clash := SettingsManager.conflicts(_table, parts[0], code)
		AudioManager.play_bank("ui_error" if not clash.is_empty() else "ui_confirm", -8.0)
		_refresh()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_try_close()
		get_viewport().set_input_as_handled()

func _try_save() -> void:
	var c := _clashes()
	if c.is_empty():
		_save_and_close()
	else:
		_confirm("Some keys do two things:\n%s\nSave anyway?" % "\n".join(c.slice(0, 3)), "SAVE", _save_and_close)

func _try_close() -> void:
	if _dirty():
		_confirm("You have unsaved changes.\nLeave without saving?", "LEAVE", _close)
	else:
		_close()

func _save_and_close() -> void:
	SettingsManager.bindings = _table.duplicate(true)
	SettingsManager.aim_assist = _aim
	SettingsManager.screen_shake = _shake
	SettingsManager.apply_bindings()
	SettingsManager.save_settings()
	AudioManager.play_bank("ui_confirm", -4.0)
	_close()

func _close() -> void:
	_open = null
	queue_free()
	if _on_closed.is_valid():
		_on_closed.call()

# A small yes/no box over the menu.
func _confirm(message: String, yes_text: String, on_yes: Callable) -> void:
	var vp := get_viewport().get_visible_rect().size
	_dialog = Control.new()
	_dialog.size = vp
	add_child(_dialog)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.size = vp
	_dialog.add_child(shade)
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.1, 0.99)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.size = Vector2(480, 170)
	box.position = ((vp - box.size) / 2.0).round()
	_dialog.add_child(box)
	var l := _text(box, message, 8, TEXT, Vector2(20, 24), 440, HORIZONTAL_ALIGNMENT_CENTER)
	l.size.y = 80
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := _button(box, yes_text, Vector2(40, 116), Vector2(180, 32))
	var no := _button(box, "STAY", Vector2(260, 116), Vector2(180, 32))
	yes.pressed.connect(func(): _dialog.queue_free(); _dialog = null; on_yes.call())
	no.pressed.connect(func(): _dialog.queue_free(); _dialog = null)
