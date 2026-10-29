extends CanvasLayer
class_name DifficultyPopup

# Shown when a run starts (CONFIRM on the character screen, or picking a map in Select
# Chamber): choose the run's difficulty, optionally open Settings (audio, controls), then
# START. The difficulty is fixed for the whole run: it can't be changed from Settings
# mid-run, so nobody plays the last level on Easy after the rest on Hard.

const GOLD := Color(0.95, 0.78, 0.35)
const VIOLET := Color(0.62, 0.42, 0.9)
const TEXT := Color(0.92, 0.88, 0.8)
const DIM := Color(0.62, 0.58, 0.54)
const HINT := {
	0: "Gentler foes, more coins.",
	1: "The intended challenge.",
	2: "Stronger foes, fewer potions.",
	3: "No potions at all. Every hit hurts.",
}

static var _open: DifficultyPopup

static func is_open() -> bool:
	return is_instance_valid(_open)

# `on_start` runs after START (it loads the level).
static func ask(on_start: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if is_open() or not tree:
		return
	var p := DifficultyPopup.new()
	p._on_start = on_start
	tree.root.add_child.call_deferred(p)
	_open = p

var _on_start: Callable
var _choice: int
var _buttons: Array[Button] = []
var _hint: Label
var _panel: Control

func _ready() -> void:
	layer = 90
	_choice = SettingsManager.difficulty
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.7)
	dim.size = vp
	add_child(dim)
	var w := 520.0
	var h := 290.0
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.08, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size = Vector2(w, h)
	_panel.position = ((vp - _panel.size) / 2.0).round()
	add_child(_panel)
	_label("CHOOSE DIFFICULTY", 16, GOLD, Vector2(0, 20), w)
	_label("It stays the same for the whole run.", 8, DIM, Vector2(0, 46), w)
	for i in SettingsManager.DIFFICULTY.size():
		var b := _button(String(SettingsManager.DIFFICULTY[i]["name"]).to_upper(), Vector2(30 + i * 118, 76), Vector2(108, 40))
		b.pressed.connect(func(): _choice = i; _refresh())
		_buttons.append(b)
	_hint = _label("", 8, TEXT, Vector2(0, 130), w)
	_hint.size.y = 70
	var settings := _button("SETTINGS", Vector2(30, 232), Vector2(140, 40))
	settings.pressed.connect(_open_settings)
	var back := _button("BACK", Vector2(190, 232), Vector2(140, 40))
	back.pressed.connect(_close)
	var start := _button("START", Vector2(350, 232), Vector2(140, 40))
	start.pressed.connect(_start)
	_refresh()

func _label(text: String, size: int, color: Color, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(l)
	l.position = pos
	l.size = Vector2(width, size + 8)
	return l

func _button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", GOLD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.22, 0.14, 0.08) if state == "disabled" else (Color(0.2, 0.1, 0.24) if state != "normal" else Color(0.12, 0.07, 0.14))
		st.border_color = GOLD if state in ["hover", "disabled"] else VIOLET
		st.set_border_width_all(2)
		b.add_theme_stylebox_override(state, st)
	b.mouse_entered.connect(func(): AudioManager.play_bank("ui_select", -14.0))
	_panel.add_child(b)
	b.position = pos
	b.size = size
	return b

func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].disabled = i == _choice # the chosen one shows gold
	_hint.text = HINT[_choice] + "

" + _describe(_choice)

# What actually changes, read from the same numbers the game uses (SettingsManager).
func _describe(i: int) -> String:
	var d: Dictionary = SettingsManager.DIFFICULTY[i]
	var parts := []
	parts.append("Enemy health %s" % _pct(d["enemy_hp"]))
	parts.append("Enemy damage %s" % _pct(d["enemy_dmg"]))
	parts.append("Coins %s" % _pct(d["coins"]))
	if d["potions"] <= 0.0:
		parts.append("No potions")
	elif d["potions"] < 1.0:
		parts.append("Only %d%% of potions appear" % roundi(d["potions"] * 100.0))
	else:
		parts.append("All potions")
	return "   ".join(PackedStringArray(parts.slice(0, 2))) + "
" + "   ".join(PackedStringArray(parts.slice(2)))

func _pct(m: float) -> String:
	if is_equal_approx(m, 1.0):
		return "normal"
	return ("+%d%%" if m > 1.0 else "-%d%%") % roundi(absf(m - 1.0) * 100.0)

func _open_settings() -> void:
	var o: Node = load("res://scenes/ui/OptionsOverlay.tscn").instantiate()
	add_child(o)
	o.layer = layer + 1
	o.show_options()

func _start() -> void:
	SettingsManager.difficulty = _choice as SettingsManager.Difficulty
	SettingsManager.save_settings()
	AudioManager.play_bank("ui_confirm", -4.0)
	_open = null
	queue_free()
	if _on_start.is_valid():
		_on_start.call()

func _close() -> void:
	_open = null
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
