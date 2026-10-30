extends StaticBody2D
class_name Merchant

# The wandering peddler: one sits in an out-of-the-way room on every level and trades coins
# for what a run is short of - health and mana potions and, once per level, a sealed scroll
# that grants a random perk. Prices climb a little with each level; stock is per peddler.
#
# Art: assets/sprites/props/merchant.png (tools/gen_props_art.py), 30 x 22, origin at its
# bottom centre. Drawn here on top: the lantern's flicker, the eyes glinting under the hood.

const ART := "res://assets/sprites/props/merchant.png"
const SIZE := Vector2(30, 22)
const LANTERN := Vector2(-15 + 5.5, -22 + 5) # the flame inside the lantern
const EYES := [Vector2(-15 + 10.5, -22 + 6.5), Vector2(-15 + 12.5, -22 + 6.5)]
const HEALTH := "res://scenes/world/HealthPotion.tscn"
const MANA := "res://scenes/world/ManaPotion.tscn"
const LANTERN_COL := Color(1.0, 0.88, 0.66)
const GREET_RANGE := 48.0

# What he carries. Prices are base + per_level * level index (0 on the first level).
const WARES := [
	{"id": "health", "name": "Health Potion", "info": "Into your bag.", "base": 5, "per_level": 2, "stock": 3},
	{"id": "mana", "name": "Mana Potion", "info": "Into your bag.", "base": 4, "per_level": 2, "stock": 2},
	{"id": "perk", "name": "Sealed Scroll", "info": "A random perk.", "base": 14, "per_level": 6, "stock": 1},
]

var stock: Dictionary = {}
var sold: int = 0 # items sold so far (tests)
var _t := 0.0
var _blink := 3.0
var _greeted := false
var _light: PointLight2D

var level_index := 0 # which map he is on (0 = the first): prices go up with it

func price(ware: Dictionary) -> int:
	return int(ware["base"]) + int(ware["per_level"]) * level_index

# The map is the nearest ancestor saved as one of GameManager.MAPS.
func _find_level_index() -> int:
	var n: Node = get_parent()
	while n:
		var i := GameManager.MAPS.find(n.scene_file_path)
		if i >= 0:
			return i
		n = n.get_parent()
	return maxi(GameManager.MAPS.find(GameManager.current_map), 0)

func _ready() -> void:
	collision_layer = 1
	add_to_group("interactable")
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(24, 6)
	shape.shape = r
	shape.position = Vector2(0, -3)
	add_child(shape)
	# A soft stepped shadow along the rug's front edge, drawn under everything (the eyes and
	# the flame are drawn by this node, over the sprite).
	var shadow := Node2D.new()
	shadow.show_behind_parent = true
	shadow.draw.connect(func():
		for i in 3:
			var half := 15.0 - i * 2.0
			shadow.draw_rect(Rect2(-half, -1.0 + i, half * 2.0, 1.0), Color(0, 0, 0, 0.32 - i * 0.08)))
	add_child(shadow)
	var spr := Sprite2D.new()
	spr.show_behind_parent = true
	spr.texture = load(ART)
	spr.centered = false
	spr.offset = Vector2(-SIZE.x / 2.0, -SIZE.y)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = LANTERN_COL
	_light.energy = 0.25
	_light.texture_scale = 0.7
	_light.position = LANTERN
	add_child(_light)
	for w in WARES:
		stock[w["id"]] = w["stock"]
	level_index = _find_level_index()

func ware(id: String) -> Dictionary:
	for w in WARES:
		if w["id"] == id:
			return w
	return {}

func interact(_body: Node2D = null) -> void:
	AudioManager.play_bank("coin", -10.0, 0.8)
	MerchantMenu.open(self)

# Sells one of a ware if it is in stock and the purse allows it.
func buy(id: String) -> bool:
	var w := ware(id)
	if w.is_empty() or int(stock[id]) <= 0 or GameManager.total_coins < price(w):
		AudioManager.play_bank("ui_error", -8.0)
		return false
	GameManager.total_coins -= price(w)
	stock[id] = int(stock[id]) - 1
	sold += 1
	AudioManager.play_bank("coin", -6.0, 1.0 + sold * 0.05)
	match id:
		"health":
			GameManager.add_health_potion(1)
			AudioManager.play_bank("bottle", -6.0, 1.0)
		"mana":
			GameManager.add_mana_potion(1)
			AudioManager.play_bank("bottle", -6.0, 1.1)
		"perk":
			# The scroll is opened outside the shop, so the perk reveal has the screen.
			MerchantMenu.close_open()
			PerkPicker.offer.call_deferred("PEDDLER'S SCROLL", Progression.roll(1))
	return true

func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.5, 5.0)
	_light.energy = 0.23 + 0.04 * sin(_t * 9.0) + 0.03 * sin(_t * 23.0)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl and not _greeted and pl.global_position.distance_to(global_position) < GREET_RANGE:
		_greeted = true
		CombatFX.floating_label(global_position + Vector2(0, -28), "Coin for wares, wanderer.", Color(0.95, 0.85, 0.6), 1.0)
	queue_redraw()

func _draw() -> void:
	# Two pale pinpricks under the hood, blinking now and then.
	if _blink > 0.0:
		for e in EYES:
			draw_rect(Rect2(e - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1.0, 0.86, 0.55, 0.9))
	# The lantern's flame breathes.
	var f := 0.75 + 0.25 * sin(_t * 9.0)
	draw_rect(Rect2(LANTERN + Vector2(-0.5, -1.0), Vector2(1, 2)), Color(1.0, 0.95, 0.7, f))


class MerchantMenu extends CanvasLayer:
	const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
	const GOLD := Color(0.95, 0.78, 0.35)
	const EDGE := Color(0.42, 0.56, 0.44)
	const TEXT := Color(0.92, 0.88, 0.8)
	const DIM := Color(0.62, 0.58, 0.54)
	const W := 640.0
	const ROW_H := 60.0
	const TOP := 104.0

	static var _open: CanvasLayer

	static func is_open() -> bool:
		return is_instance_valid(_open)

	static func open(m: Merchant) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if is_open() or not tree or not tree.current_scene:
			return
		var menu := MerchantMenu.new()
		menu._merchant = m
		tree.current_scene.add_child(menu)
		_open = menu

	static func close_open() -> void:
		if is_open():
			(_open as MerchantMenu)._close()

	var _merchant: Merchant
	var _rows: Array = []
	var _coins: Label

	func _ready() -> void:
		layer = 70
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var f: FontFile = FONT
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		var vp := get_viewport().get_visible_rect().size
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.04, 0.6)
		dim.size = vp
		add_child(dim)
		var h := TOP + ROW_H * Merchant.WARES.size() + 96.0
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.06, 0.06, 0.97)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.shadow_color = Color(EDGE, 0.35)
		sb.shadow_size = 14
		panel.add_theme_stylebox_override("panel", sb)
		panel.size = Vector2(W, h)
		panel.position = ((vp - panel.size) / 2.0).round()
		add_child(panel)
		_text(panel, "THE PEDDLER", 33, GOLD, Vector2(0, 18), W, HORIZONTAL_ALIGNMENT_CENTER)
		_text(panel, "\"Everything has a price down here.\"", 22, DIM, Vector2(0, 58), W, HORIZONTAL_ALIGNMENT_CENTER)
		var rule := ColorRect.new()
		rule.color = Color(GOLD, 0.35)
		rule.position = Vector2(32, 92)
		rule.size = Vector2(W - 64, 2)
		panel.add_child(rule)
		for i in Merchant.WARES.size():
			_rows.append(_row(panel, TOP + ROW_H * i, i))
		_coins = _text(panel, "", 22, GOLD, Vector2(0, h - 70), W, HORIZONTAL_ALIGNMENT_CENTER)
		_text(panel, "[1] [2] [3] buy    Esc: leave", 22, DIM, Vector2(0, h - 38), W, HORIZONTAL_ALIGNMENT_CENTER)
		var leave := _button(panel, "LEAVE", Vector2(W - 112, 14), Vector2(92, 36))
		leave.pressed.connect(_close)
		_refresh()

	func _row(panel: Control, y: float, i: int) -> Dictionary:
		var w: Dictionary = Merchant.WARES[i]
		var cy := y + ROW_H / 2.0
		var ic := _icon(w["id"])
		if ic:
			var tr := TextureRect.new()
			tr.texture = ic
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(36, 36)
			tr.position = Vector2(40, cy - 18)
			panel.add_child(tr)
		_text(panel, "[%d]  %s" % [i + 1, w["name"]], 22, TEXT, Vector2(100, cy - 26), 300, HORIZONTAL_ALIGNMENT_LEFT)
		var info := _text(panel, "", 22, DIM, Vector2(100, cy), 300, HORIZONTAL_ALIGNMENT_LEFT)
		var cost := _text(panel, "", 22, GOLD, Vector2(350, cy - 13), 130, HORIZONTAL_ALIGNMENT_RIGHT)
		var b := _button(panel, "BUY", Vector2(500, cy - 20), Vector2(108, 40))
		b.pressed.connect(_buy.bind(w["id"]))
		return {"id": w["id"], "info": info, "cost": cost, "buy": b}

	# Potions show their own sprite; the scroll gets a small drawn one.
	func _icon(id: String) -> Texture2D:
		if id == "perk":
			var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
			var paper := Color8(226, 210, 168)
			img.fill_rect(Rect2i(1, 3, 10, 6), paper)
			img.fill_rect(Rect2i(1, 3, 10, 1), Color8(250, 240, 210))
			img.fill_rect(Rect2i(0, 2, 2, 8), Color8(176, 150, 110))
			img.fill_rect(Rect2i(10, 2, 2, 8), Color8(176, 150, 110))
			img.fill_rect(Rect2i(5, 5, 2, 2), Color8(214, 64, 70))
			img.set_pixel(5, 7, Color8(120, 24, 34))
			return ImageTexture.create_from_image(img)
		var n: Node = load(Merchant.HEALTH if id == "health" else Merchant.MANA).instantiate()
		var spr := n.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, 0) if spr and spr.sprite_frames else null
		n.free()
		# Trimmed to the bottle itself, so it fills the icon box like the scroll does.
		if tex:
			var img := tex.get_image()
			var used := img.get_used_rect()
			if used.size.x > 0:
				return ImageTexture.create_from_image(img.get_region(used))
		return tex

	func _button(panel: Control, text: String, pos: Vector2, size: Vector2) -> Button:
		var b := Button.new()
		b.text = text
		b.position = pos
		b.size = size
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_constant_override("outline_size", 0)
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", GOLD)
		b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.14, 0.17, 0.13) if state in ["hover", "pressed"] else Color(0.09, 0.1, 0.09)
			st.border_color = GOLD if state == "hover" else (Color(EDGE, 0.3) if state == "disabled" else EDGE)
			st.set_border_width_all(2)
			b.add_theme_stylebox_override(state, st)
		b.mouse_entered.connect(func(): AudioManager.play_bank("ui_select", -12.0))
		panel.add_child(b)
		return b

	func _text(panel: Control, text: String, size: int, color: Color, pos: Vector2, width: float, align: HorizontalAlignment) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", color)
		l.add_theme_constant_override("outline_size", 0)
		l.horizontal_alignment = align
		l.position = pos
		l.size = Vector2(width, 26)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(l)
		return l

	func _refresh() -> void:
		if not is_instance_valid(_merchant):
			return
		var coins := GameManager.total_coins
		for r in _rows:
			var w := _merchant.ware(r["id"])
			var left: int = _merchant.stock[r["id"]]
			var p := _merchant.price(w)
			r["info"].text = "Sold out." if left <= 0 else "%s  %d left" % [w["info"], left]
			r["cost"].text = "%d coins" % p
			r["buy"].disabled = left <= 0 or coins < p
			r["buy"].text = "SOLD" if left <= 0 else "BUY"
		_coins.text = "Coins: %d" % coins

	func _buy(id: String) -> void:
		if is_instance_valid(_merchant):
			_merchant.buy(id)
		if is_instance_valid(self) and not is_queued_for_deletion():
			_refresh()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_1, KEY_KP_1: _buy(Merchant.WARES[0]["id"])
				KEY_2, KEY_KP_2: _buy(Merchant.WARES[1]["id"])
				KEY_3, KEY_KP_3: _buy(Merchant.WARES[2]["id"])
				KEY_ESCAPE: _close()
			get_viewport().set_input_as_handled()

	func _close() -> void:
		if is_queued_for_deletion():
			return
		get_tree().paused = false
		_open = null
		AudioManager.play_bank("ui_select", -10.0)
		queue_free()
