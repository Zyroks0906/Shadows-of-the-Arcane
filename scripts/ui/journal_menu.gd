extends CanvasLayer
class_name JournalMenu

# The Journal (from the pause menu): every page of the story found so far, in story order,
# map by map. Pages not found yet show as "? ? ?". Pick one on the left to read it.

const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
const GOLD := Color(0.95, 0.78, 0.35)
const TEXT := Color(0.9, 0.87, 0.8)
const DIM := Color(0.5, 0.47, 0.44)
const MAPS := ["THE FORGOTTEN CRYPT", "THE WHISPERING CAVERNS", "THE SKYHOLD"]
const W := 900.0
const H := 520.0

static var _open: CanvasLayer

static func is_open() -> bool:
	return is_instance_valid(_open)

static func open_menu() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if is_open() or not tree or not tree.current_scene:
		return
	var m := JournalMenu.new()
	tree.current_scene.add_child(m)
	_open = m

var _title: Label
var _body: Label

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f: FontFile = FONT
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.75)
	dim.size = vp
	add_child(dim)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.09, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(W, H)
	panel.position = ((vp - panel.size) / 2.0).round()
	add_child(panel)
	var head := _label("JOURNAL  -  %d of %d pages" % [Lore.found_count(), Lore.total()], 33, GOLD)
	head.position = Vector2(0, 14)
	head.size = Vector2(W, 40)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(head)
	# The list of pages.
	# Three maps of five pages don't fit at once: the list scrolls (mouse wheel).
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 70)
	scroll.size = Vector2(336, H - 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(320, 0)
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	var first_found := Vector2i(-1, -1)
	for m in Lore.PAGES.size():
		list.add_child(_label(MAPS[m], 22, GOLD))
		for i in Lore.PAGES[m].size():
			var found := Lore.is_found(m, i)
			var b := Button.new()
			b.text = ("  " + Lore.PAGES[m][i]["title"]) if found else "  ? ? ?"
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.flat = true
			b.disabled = not found
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", FONT)
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_color_override("font_color", TEXT)
			b.add_theme_color_override("font_hover_color", GOLD)
			b.add_theme_color_override("font_disabled_color", DIM)
			b.pressed.connect(_show.bind(m, i))
			list.add_child(b)
			if found and first_found.x < 0:
				first_found = Vector2i(m, i)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.3)
	rule.position = Vector2(372, 70)
	rule.size = Vector2(2, H - 100)
	panel.add_child(rule)
	_title = _label("", 33, GOLD)
	_title.position = Vector2(396, 70)
	_title.size = Vector2(W - 424, 40)
	panel.add_child(_title)
	_body = _label("", 22, TEXT)
	_body.position = Vector2(396, 122)
	_body.size = Vector2(W - 424, H - 180)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(_body)
	var hint := _label("[Esc] back", 22, DIM)
	hint.position = Vector2(396, H - 44)
	panel.add_child(hint)
	if first_found.x >= 0:
		_show(first_found.x, first_found.y)
	else:
		_body.text = "No pages yet. Look for stone tablets in the dungeon: some hide behind cracked walls."

func _show(m: int, i: int) -> void:
	_title.text = Lore.PAGES[m][i]["title"].to_upper()
	_body.text = Lore.PAGES[m][i]["text"]
	AudioManager.play_bank("ui_select", -12.0)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_J]:
		_open = null
		queue_free()
		get_viewport().set_input_as_handled()
