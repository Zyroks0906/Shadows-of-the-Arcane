extends StaticBody2D
class_name Transmuter

# The Alchemist's Crucible: for two coins it remakes a potion, mana into health or health
# into mana, and spits the new potion out onto the floor.
#
# Placed inside an arena room it lies buried: the room's waves bring elites, and only once
# the room is cleared does the crucible rise out of the floor. Anywhere else it simply
# stands there.
#
# Art: assets/sprites/props/transmuter.png (tools/gen_props_art.py). The liquids are drawn
# here: the flasks fill with the potions you carry (red health on the left, blue mana on the
# right) and the basin swirls between the two colours.

const COST := 2 # coins per potion
const ART := "res://assets/sprites/props/transmuter.png"
const HEALTH := "res://scenes/world/HealthPotion.tscn"
const MANA := "res://scenes/world/ManaPotion.tscn"
const RED := Color(0.86, 0.16, 0.24)
const BLUE := Color(0.22, 0.45, 0.98)
const GLOW := Color(0.75, 0.45, 1.0)
# Sprite anchors (art is 40 x 34, origin at its bottom centre).
const SIZE := Vector2(40, 34)
const BASIN := Vector2(0, -22.5)
const FLASK_L := Vector2(-15, -19.5)
const FLASK_R := Vector2(14, -19.5)
const RUNE := Vector2(-0.5, -1.5)
const ELITES_IN_ROOM := 2

enum State { ACTIVE, DORMANT, RISING }

var state: State = State.ACTIVE
var dropped: int = 0 # potions made so far (tests)
var _t: float = 0.0
var _flash: float = 0.0
var _sprite: Sprite2D
var _light: PointLight2D
var _shape: CollisionShape2D
var _bubbles: Array = []
var _over: _Overlay

func _ready() -> void:
	collision_layer = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 6)
	_shape.shape = rect
	_shape.position = Vector2(0, -3)
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load(ART)
	_sprite.centered = false
	_sprite.offset = Vector2(-SIZE.x / 2.0, -SIZE.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Its own glow lights the floor around it, not the crucible (that washed the stone and
	# bone out to pink): the sprite sits on light layer 2, the glow only reaches layer 1.
	_sprite.light_mask = 2
	add_child(_sprite)
	_over = _Overlay.new()
	_over.owner_t = self
	add_child(_over)
	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = GLOW
	_light.energy = 0.7
	_light.texture_scale = 1.1
	_light.position = BASIN
	add_child(_light)
	GroundShadow.attach(self, 0.0, 0.62)
	_link_room.call_deferred()
	_set_active(true)

# Buried inside an arena until it is cleared.
func _link_room() -> void:
	for room in get_tree().get_nodes_in_group("arena_rooms"):
		if room.contains(global_position) and room.state != ArenaRoom.State.CLEARED:
			state = State.DORMANT
			_set_active(false)
			room.elite_spawns = maxi(room.elite_spawns, ELITES_IN_ROOM)
			room.cleared.connect(_rise)
			return

func _set_active(on: bool) -> void:
	visible = on
	_shape.set_deferred("disabled", not on)
	if on:
		add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")

func _rise() -> void:
	if state != State.DORMANT:
		return
	state = State.RISING
	await get_tree().create_timer(1.4).timeout
	visible = true
	scale = Vector2(1.0, 0.0)
	_light.energy = 0.0
	CombatFX.shake(3.0, 0.9)
	AudioManager.play_bank_at("stomp", global_position, 0.0, 0.6)
	AudioManager.play_bank_at("chain", global_position, -4.0, 0.7)
	for i in 6:
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			CombatFX.burst(global_position + Vector2(randf_range(-14, 14), -1), Color(0.45, 0.4, 0.4), 6, 30.0, 0.5, 40.0, 1.5))
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "energy", 0.7, 1.0)
	await tw.finished
	CombatFX.burst(global_position + BASIN, GLOW, 22, 60.0, 0.6, -30.0, 1.5)
	AudioManager.play_bank_at("teleport", global_position, -4.0, 0.8)
	state = State.ACTIVE
	_set_active(true)
	ItemBanner.show_item("Alchemist's Crucible", "For %d coins it remakes a potion: mana into health, or health into mana. Press F." % COST, GLOW)

func interact(_body: Node2D = null) -> void:
	if state != State.ACTIVE:
		return
	AudioManager.play_bank_at("bottle", global_position, -6.0, 0.8)
	TransmuteMenu.open(self)

# One potion remade: pays, takes the potion from the bag and throws the new one out.
func transmute(to_health: bool) -> bool:
	var have := GameManager.mana_potions if to_health else GameManager.health_potions
	if have <= 0 or GameManager.total_coins < COST:
		AudioManager.play_bank("ui_error", -8.0)
		return false
	GameManager.total_coins -= COST
	if to_health:
		GameManager.mana_potions -= 1
	else:
		GameManager.health_potions -= 1
	dropped += 1
	_flash = 1.0
	AudioManager.play_bank("coin", -8.0, 1.0 + dropped * 0.04)
	AudioManager.play_bank_at("bottle", global_position, -4.0, 0.9 + randf() * 0.2)
	CombatFX.burst(global_position + BASIN, RED if to_health else BLUE, 12, 50.0, 0.4, -40.0, 1.5)
	_spit(HEALTH if to_health else MANA)
	return true

# As many as the bag and the purse allow; returns how many were made.
func transmute_all(to_health: bool) -> int:
	var n := 0
	while GameManager.total_coins >= COST and (GameManager.mana_potions if to_health else GameManager.health_potions) > 0:
		transmute(to_health)
		n += 1
	return n

# The new potion arcs out of the basin and lands in front of the crucible.
func _spit(path: String) -> void:
	var item: Node2D = load(path).instantiate()
	get_parent().add_child(item)
	var c := item if item.has_method("pop_out") else item.get_node_or_null("Area2D")
	var from := global_position + BASIN
	var angle := randf_range(0.25, PI - 0.25)
	var to := global_position + Vector2(cos(angle) * randf_range(14.0, 22.0), 8.0 + sin(angle) * 8.0)
	if c and c.has_method("pop_out"):
		c.pop_out(from, to, 0.0, global_position + Vector2(0, 6)) # lands where its foot can reach
	else:
		item.global_position = to

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 2.5, 0.0)
	# Bubbles rise in the basin now and then.
	if randf() < delta * 3.0:
		_bubbles.append({"x": randf_range(-7.0, 7.0), "t": 0.0, "c": RED if randf() < 0.5 else BLUE})
	for b in _bubbles:
		b["t"] += delta
	_bubbles = _bubbles.filter(func(b): return b["t"] < 0.9)
	queue_redraw()
	_over.queue_redraw()

func _liquid_color() -> Color:
	return RED.lerp(BLUE, 0.5 + 0.5 * sin(_t * 1.3)).lerp(GLOW, 0.25)

# Under the sprite: the flasks' liquid (the glass is translucent and draws over it).
func _draw() -> void:
	_flask(FLASK_L, RED, GameManager.health_potions)
	_flask(FLASK_R, BLUE, GameManager.mana_potions)

func _flask(c: Vector2, col: Color, count: int) -> void:
	var fill := clampf(0.2 + count * 0.16, 0.2, 1.0)
	var top := c.y + 3.5 - 7.0 * fill
	for y in range(int(ceil(top)), int(c.y + 4)):
		var dy := y + 0.5 - c.y
		var half := sqrt(maxf(12.0 - dy * dy, 0.0))
		if half <= 0.0:
			continue
		var shade := col.darkened(0.25) if y > c.y + 1 else col
		draw_rect(Rect2(c.x - half, y, half * 2.0 + 1.0, 1), shade)
	# a glint that wobbles on the surface
	draw_rect(Rect2(c.x - 1 + roundf(sin(_t * 3.0)), floorf(top), 2, 1), col.lightened(0.5))

# Over the sprite: the basin's swirling liquid, bubbles and the glowing rune.
class _Overlay extends Node2D:
	var owner_t: Transmuter

	func _draw() -> void:
		var t := owner_t
		var col := t._liquid_color().lightened(t._flash * 0.4)
		var b := Transmuter.BASIN
		draw_rect(Rect2(b.x - 9, b.y - 0.5, 19, 2), col.darkened(0.2))
		draw_rect(Rect2(b.x - 8, b.y - 0.5, 17, 1), col)
		# a swirl of light running round the surface
		var sx := roundf(sin(t._t * 2.0) * 7.0)
		draw_rect(Rect2(b.x + sx, b.y - 0.5, 2, 1), col.lightened(0.6))
		for bub in t._bubbles:
			var k: float = bub["t"] / 0.9
			var p := Vector2(b.x + bub["x"], b.y - 1.0 - k * 5.0).round()
			draw_rect(Rect2(p, Vector2(1, 1)), Color(bub["c"].lightened(0.4), 1.0 - k))
		var rune := Color(Transmuter.GLOW, 0.5 + 0.5 * sin(t._t * 2.5) + t._flash * 0.5)
		draw_rect(Rect2(Transmuter.RUNE + Vector2(-1, -0.5), Vector2(2, 1)), rune)


# --- The trade menu ----------------------------------------------------------------------
# Same look as the rest of the UI: Pixelify text, gold and violet. Every row is one line:
# [potion] > [potion]   what it does / how many you carry   [ONE] [ALL]
class TransmuteMenu extends CanvasLayer:
	const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
	const GOLD := Color(0.95, 0.78, 0.35)
	const VIOLET := Color(0.62, 0.42, 0.9)
	const TEXT := Color(0.92, 0.88, 0.8)
	const DIM := Color(0.62, 0.58, 0.54)
	const W := 640.0
	const ROW_H := 60.0

	static var _open: CanvasLayer

	static func is_open() -> bool:
		return is_instance_valid(_open)

	static func open(t: Transmuter) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if is_open() or not tree or not tree.current_scene:
			return
		var m := TransmuteMenu.new()
		m._crucible = t
		tree.current_scene.add_child(m)
		_open = m

	var _crucible: Transmuter
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
		var h := 300.0
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.04, 0.08, 0.97)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.shadow_color = Color(VIOLET, 0.35)
		sb.shadow_size = 14
		panel.add_theme_stylebox_override("panel", sb)
		panel.size = Vector2(W, h)
		panel.position = ((vp - panel.size) / 2.0).round()
		add_child(panel)
		_text(panel, "ALCHEMIST'S CRUCIBLE", 33, GOLD, Vector2(0, 18), W, HORIZONTAL_ALIGNMENT_CENTER)
		_text(panel, "%d coins and the crucible remakes a potion." % Transmuter.COST, 22, DIM, Vector2(0, 58), W, HORIZONTAL_ALIGNMENT_CENTER)
		var rule := ColorRect.new()
		rule.color = Color(GOLD, 0.35)
		rule.position = Vector2(32, 92)
		rule.size = Vector2(W - 64, 2)
		panel.add_child(rule)
		_rows.append(_row(panel, 104.0, true))
		_rows.append(_row(panel, 104.0 + ROW_H, false))
		_coins = _text(panel, "", 22, GOLD, Vector2(0, 230), W, HORIZONTAL_ALIGNMENT_CENTER)
		_text(panel, "[1] [2] one    Shift: all    Esc: leave", 22, DIM, Vector2(0, 262), W, HORIZONTAL_ALIGNMENT_CENTER)
		# A visible way out for players who don't think of Esc.
		var leave := _button(panel, "LEAVE", Vector2(W - 112, 14), Vector2(92, 36))
		leave.pressed.connect(_close)
		_refresh()

	# One row, everything centred on the same horizontal line (cy).
	func _row(panel: Control, y: float, to_health: bool) -> Dictionary:
		var cy := y + ROW_H / 2.0
		var x := 32.0
		for path in ([Transmuter.MANA, Transmuter.HEALTH] if to_health else [Transmuter.HEALTH, Transmuter.MANA]):
			var ic := _potion_icon(path)
			if ic:
				var tr := TextureRect.new()
				tr.texture = ic
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.size = Vector2(36, 36)
				tr.position = Vector2(x, cy - 18)
				panel.add_child(tr)
			x += 64.0
		var arrow := _Arrow.new()
		arrow.position = Vector2(32 + 36 + 8, cy - 5)
		panel.add_child(arrow)
		var label := "Mana into Health" if to_health else "Health into Mana"
		_text(panel, "[%d]  %s" % [1 if to_health else 2, label], 22, TEXT, Vector2(166, cy - 26), 250, HORIZONTAL_ALIGNMENT_LEFT)
		var have := _text(panel, "", 22, DIM, Vector2(166, cy), 250, HORIZONTAL_ALIGNMENT_LEFT)
		var one := _button(panel, "ONE", Vector2(430, cy - 20), Vector2(84, 40))
		var all := _button(panel, "ALL", Vector2(524, cy - 20), Vector2(84, 40))
		one.pressed.connect(_do.bind(to_health, false))
		all.pressed.connect(_do.bind(to_health, true))
		return {"to_health": to_health, "have": have, "one": one, "all": all}

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
			st.bg_color = Color(0.2, 0.1, 0.24) if state in ["hover", "pressed"] else Color(0.12, 0.07, 0.14)
			st.border_color = GOLD if state == "hover" else (Color(VIOLET, 0.3) if state == "disabled" else VIOLET)
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

	func _potion_icon(path: String) -> Texture2D:
		var n: Node = load(path).instantiate()
		var spr := n.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, 0) if spr and spr.sprite_frames else null
		n.free()
		return tex

	func _refresh() -> void:
		var coins := GameManager.total_coins
		for r in _rows:
			var n: int = GameManager.mana_potions if r["to_health"] else GameManager.health_potions
			var can := mini(n, coins / Transmuter.COST)
			r["have"].text = "you carry %d" % n
			r["one"].disabled = can <= 0
			r["all"].disabled = can <= 0
			r["all"].text = "ALL" if can <= 1 else "ALL %d" % can
		_coins.text = "Coins: %d" % coins

	func _do(to_health: bool, all: bool) -> void:
		if is_instance_valid(_crucible):
			if all:
				_crucible.transmute_all(to_health)
			else:
				_crucible.transmute(to_health)
		_refresh()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_1, KEY_KP_1: _do(true, event.shift_pressed)
				KEY_2, KEY_KP_2: _do(false, event.shift_pressed)
				KEY_ESCAPE, KEY_F: _close()
			get_viewport().set_input_as_handled()

	func _close() -> void:
		get_tree().paused = false
		_open = null
		AudioManager.play_bank("ui_select", -10.0)
		queue_free()

# A small gold pixel arrow between the two potions.
class _Arrow extends Control:
	func _draw() -> void:
		var c := TransmuteMenu.GOLD
		draw_rect(Rect2(0, 4, 12, 2), c)
		for i in 5:
			draw_rect(Rect2(10 + i, i, 2, 10 - i * 2), c)
