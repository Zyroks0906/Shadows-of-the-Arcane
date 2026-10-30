extends StaticBody2D
class_name LoreStone

# A stone tablet with a page of the story cut into it (Lore). F reads it: a panel shows the
# page and, if it is new, it goes into the Journal (kept across runs). While it still holds
# a page the player has never read, a rune at its top glows.
# Art: assets/sprites/props/lore_stone.png (tools/gen_props_art.py), 16 x 20.

const ART := "res://assets/sprites/props/lore_stone.png"
const RUNE := Vector2(-0.5, -16.0)   # the socket in the art, from the origin (bottom centre)
const GLOW := Color(0.6, 0.8, 1.0)

var map := 0
var _t := 0.0

func _ready() -> void:
	collision_layer = 1
	add_to_group("interactable")
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 5)
	shape.shape = r
	shape.position = Vector2(0, -2)
	add_child(shape)
	var spr := Sprite2D.new()
	spr.texture = load(ART)
	spr.centered = false
	spr.offset = Vector2(-8, -20)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.show_behind_parent = true
	add_child(spr)
	GroundShadow.attach(self, 0.0, 0.8)
	map = _find_map()

func _find_map() -> int:
	var n: Node = get_parent()
	while n:
		var i := GameManager.level_index(n.scene_file_path)
		if i >= 0:
			return i
		n = n.get_parent()
	return maxi(GameManager.level_index(GameManager.current_map), 0)

func _unread() -> bool:
	for i in Lore.PAGES[map].size():
		if not Lore.is_found(map, i):
			return true
	return false

func interact(_body: Node2D = null) -> void:
	var page := Lore.next_page(map)
	var is_new := Lore.find(map, page)
	AudioManager.play_bank("item", -6.0, 0.7)
	LorePage.open(map, page, is_new)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if not _unread():
		return
	var a := 0.55 + 0.45 * sin(_t * 3.0)
	draw_rect(Rect2(RUNE + Vector2(-0.5, -1.5), Vector2(2, 3)), Color(GLOW, a))
	draw_rect(Rect2(RUNE + Vector2(-1.5, -2.5), Vector2(4, 5)), Color(GLOW, 0.18 * a))


# The page, read on a dark plate (pauses the game). Esc or F closes it.
class LorePage extends CanvasLayer:
	const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
	const GOLD := Color(0.95, 0.78, 0.35)
	const TEXT := Color(0.9, 0.87, 0.8)
	const DIM := Color(0.62, 0.58, 0.54)
	const W := 620.0

	static var _open: CanvasLayer

	static func is_open() -> bool:
		return is_instance_valid(_open)

	static func open(map: int, page: int, is_new: bool) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if is_open() or not tree or not tree.current_scene:
			return
		var p := LorePage.new()
		p._map = map
		p._page = page
		p._new = is_new
		tree.current_scene.add_child(p)
		_open = p

	var _map := 0
	var _page := 0
	var _new := false
	var _opened_ms := 0

	func _ready() -> void:
		layer = 70
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		_opened_ms = Time.get_ticks_msec()
		var f: FontFile = FONT
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		var vp := get_viewport().get_visible_rect().size
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.04, 0.65)
		dim.size = vp
		add_child(dim)
		var data: Dictionary = Lore.PAGES[_map][_page]
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.09, 0.97)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 22
		sb.content_margin_bottom = 20
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 12
		panel.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		panel.add_child(col)
		col.add_child(_label(data["title"].to_upper(), 33, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var body := _label(data["text"], 22, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.custom_minimum_size = Vector2(W - 68, 0)
		col.add_child(body)
		var foot := "New page in your Journal  -  %d of %d found" % [Lore.found_count(), Lore.total()] if _new else "Already in your Journal  -  %d of %d found" % [Lore.found_count(), Lore.total()]
		col.add_child(_label(foot, 22, GOLD if _new else DIM, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(_label("[F] / [Esc]  close", 22, DIM, HORIZONTAL_ALIGNMENT_CENTER))
		add_child(panel)
		panel.size = Vector2(W, 0)
		await get_tree().process_frame
		panel.position = ((vp - panel.size) / 2.0).round()
		if _new:
			AudioManager.play_bank("magic_shield", -8.0, 1.3)

	func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", color)
		l.add_theme_constant_override("outline_size", 0)
		l.horizontal_alignment = align
		return l

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			# F opened it: ignore the same key for a moment so it is not closed at once.
			if event.keycode in [KEY_ESCAPE, KEY_F, KEY_ENTER] and Time.get_ticks_msec() - _opened_ms > 300:
				get_tree().paused = false
				_open = null
				queue_free()
			get_viewport().set_input_as_handled()
