extends CanvasLayer
class_name DeathScreen

# Shown when the hero falls: "You Died", who did it, a summary of the run (time, kills,
# elites, damage dealt and taken, coins) and the perk build so far, then TRY AGAIN (reloads
# the level, as death always did) or MAIN MENU. The game is paused behind it.

const TITLE_FONT: FontFile = preload("res://assets/fonts/JacquardaBastarda9-Regular.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
const MENU := "res://scenes/Screens/initial_screen.tscn"
const GOLD := Color(0.95, 0.78, 0.35)
const BLOOD := Color(0.75, 0.08, 0.1)

static var _open: DeathScreen

static func is_open() -> bool:
	return is_instance_valid(_open)

static func show_for(level_path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene or is_open():
		return
	var d := DeathScreen.new()
	d._level = level_path
	tree.current_scene.add_child(d)
	_open = d

var _level: String
var _leaving := false

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	for f: FontFile in [TITLE_FONT, BODY_FONT]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var vp := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.size = vp
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.01, 0.0)
	dim.size = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.93, 0.6)
	var content := Control.new()
	content.size = vp
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.modulate.a = 0.0
	root.add_child(content)

	var title := _label("YOU DIED", 66, BLOOD) # Pixelify at 6x its grid: crisp and readable
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.size = Vector2(vp.x, 64)
	title.position = Vector2(0, 54)
	content.add_child(title)
	var s: Dictionary = Progression.stats
	var killer := String(s.get("killer", ""))
	var sub := _label(("Slain by %s" % _article(killer)) if killer != "" else "Your light went out", 22, Color(0.85, 0.75, 0.7))
	sub.size = Vector2(vp.x, 26)
	sub.position = Vector2(0, 126)
	content.add_child(sub)

	# Run summary: two columns of label + value on a dark plate with a gold rule.
	var rows := Progression.summary_rows()
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.05, 0.92)
	sb.border_color = Color(GOLD, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	var pw := 520.0
	var ph := 4.0 * 30.0 + 36.0
	panel.size = Vector2(pw, ph)
	panel.position = Vector2((vp.x - pw) / 2.0, 172)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(panel)
	for i in rows.size():
		var col := i / 4
		var row := i % 4
		var x := 24.0 + col * (pw / 2.0)
		var name_l := _label(rows[i][0], 22, Color(0.7, 0.66, 0.62))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.position = Vector2(x, 18 + row * 30)
		name_l.size = Vector2(pw / 2.0 - 60, 26)
		panel.add_child(name_l)
		var val := _label(rows[i][1], 22, GOLD)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.position = Vector2(x, 18 + row * 30)
		val.size = Vector2(pw / 2.0 - 48, 26)
		panel.add_child(val)

	# The build: one icon per perk owned, with its stack.
	var owned: Dictionary = s.get("build", Progression.perks)
	var build := _label("Your build" if not owned.is_empty() else "No blessings taken yet", 22, Color(0.7, 0.66, 0.62))
	build.size = Vector2(vp.x, 26)
	build.position = Vector2(0, panel.position.y + ph + 14)
	content.add_child(build)
	var ids: Array = owned.keys()
	var icon := 32.0
	var gap := 10.0
	var total := ids.size() * icon + maxf(ids.size() - 1, 0) * gap
	for i in ids.size():
		var path := "res://assets/ui/perks/icon_%s.png" % ids[i]
		if not ResourceLoader.exists(path):
			continue
		var t := TextureRect.new()
		t.texture = load(path)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2(icon, icon)
		t.position = Vector2((vp.x - total) / 2.0 + i * (icon + gap), build.position.y + 30)
		t.tooltip_text = String(Progression.PERKS[ids[i]]["name"])
		content.add_child(t)

	var by := build.position.y + 30 + icon + 22
	_button(content, "TRY AGAIN  [R]", Vector2(vp.x / 2.0 - 230, by), _retry)
	_button(content, "MAIN MENU  [Esc]", Vector2(vp.x / 2.0 + 10, by), _menu)

	var tw := content.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(content, "modulate:a", 1.0, 0.6)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(1.25, 1.25)
	title.create_tween().tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	AudioManager.play_bank("roar", -14.0, 0.5)

func _article(n: String) -> String:
	return ("an " if n.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + n

func _label(text: String, size: int, color: Color, font: Font = BODY_FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(parent: Control, text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(220, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", BODY_FONT)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_constant_override("outline_size", 0)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.05, 0.07, 0.95) if state == "normal" else Color(0.25, 0.08, 0.1, 0.98)
		sb.border_color = GOLD if state != "normal" else Color(GOLD, 0.6)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): AudioManager.play_bank("ui_select", -12.0))
	parent.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_retry()
		elif event.keycode == KEY_ESCAPE:
			_menu()
		get_viewport().set_input_as_handled()

func _retry() -> void:
	_leave(_level)

func _menu() -> void:
	_leave(MENU)

func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play_bank("ui_confirm", -4.0)
	get_tree().paused = false
	_open = null
	if SceneManager:
		SceneManager.load_scene(path)
	else:
		get_tree().change_scene_to_file(path)
