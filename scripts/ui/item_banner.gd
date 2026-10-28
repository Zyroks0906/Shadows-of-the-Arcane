extends CanvasLayer
class_name ItemBanner

# Isaac-style pickup banner: the item's icon, its name and one line saying what it does,
# sliding in at the top of the screen for a couple of seconds. A new pickup replaces the
# one on screen instead of stacking.

const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HOLD := 2.2

static var _current: ItemBanner

static func show_item(title: String, description: String, accent: Color, icon: Texture2D = null) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return
	if is_instance_valid(_current):
		_current.queue_free()
	var b := ItemBanner.new()
	b._build(title, description, accent, icon)
	tree.current_scene.add_child(b)
	_current = b

var _panel: PanelContainer

func _build(title: String, description: String, accent: Color, icon: Texture2D) -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.1, 0.9)
	sb.border_color = accent
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(row)
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(tr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	col.add_child(_label(title.to_upper(), 16, accent.lightened(0.35)))
	col.add_child(_label(description, 9, Color(0.9, 0.88, 0.95)))
	add_child(_panel)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _ready() -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	var x := (vp.x - size.x) / 2.0
	_panel.position = Vector2(x, -size.y - 10)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", 70.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_panel, "position:y", 50.0, 0.4)
	tw.tween_callback(queue_free)
