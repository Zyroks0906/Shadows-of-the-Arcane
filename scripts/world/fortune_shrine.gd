extends StaticBody2D
class_name FortuneShrine

# The Fortune Shrine: a stone one-armed bandit, somewhere to spend the coins a run piles up.
# F opens it; each pull costs coins (more in later chambers) and spins three reels:
#   3 stars   -> jackpot: pick one of three rare+ perks     2 stars   -> a random perk
#   3 moons   -> pick one of three uncommon+ perks          2 moons   -> the stake back
#   3 coins   -> five times the stake                       2 coins   -> twice the stake
#   3 potions -> two health potions and a mana potion       2 potions -> a health potion
#   3 skulls  -> a curse: an ambush, one elite              2 skulls  -> you lose 10% health
#   anything else -> the shrine keeps your coins.
# Odds (200k simulated pulls): a triple about one pull in five, the jackpot 3%; something
# won on ~56%, the stake back on 10%, nothing on 23%, a curse on 11%. It used to be 59%
# nothing at all and a 1% jackpot, and players stopped pulling.
# Art: assets/sprites/props/fortune_shrine.png (tools/gen_props_art.py); reels drawn here.

enum Sym { COIN, POTION, STAR, SKULL, MOON }
const WEIGHTS := {Sym.COIN: 26, Sym.POTION: 22, Sym.STAR: 18, Sym.SKULL: 16, Sym.MOON: 18}
const COST_BY_LEVEL := [10, 15, 20]
const ART := "res://assets/sprites/props/fortune_shrine.png"
const SIZE := Vector2(32, 40)
const WINDOWS := [Vector2(7.5, 21), Vector2(14.5, 21), Vector2(21.5, 21)] # reel centres in the art

# 7x7 pixel icons; letters pick the colour from each symbol's palette.
const ICONS := {
	Sym.STAR: ["...h...", "..hgh..", "hgggggh", ".ggggg.", "..ggg..", ".gg.gg.", "gd...dg"],
	Sym.COIN: ["..ddd..", ".dgggd.", "dgghggd", "dghhhgd", "dgghggd", ".dgggd.", "..ddd.."],
	Sym.POTION: ["..ddd..", "...d...", "..d.d..", ".drrrd.", "drrrrrd", "drrhrrd", ".ddddd."],
	Sym.SKULL: [".wwwww.", "wwwwwww", "wbbwbbw", "wwwwwww", ".ww.ww.", "..www..", ".w.w.w."],
	Sym.MOON: ["..ppp..", ".pp....", "pp.....", "pp.....", "pp.....", ".pp....", "..ppp.."],
}
const PALETTE := {
	"g": Color(0.95, 0.75, 0.3), "h": Color(1.0, 0.95, 0.7), "d": Color(0.55, 0.36, 0.14),
	"r": Color(0.86, 0.16, 0.24), "w": Color(0.9, 0.86, 0.76), "b": Color(0.12, 0.06, 0.1),
	"p": Color(0.55, 0.45, 0.8),
}

var _t := 0.0
var _flash := 0.0
var _idle: Array[int] = [Sym.STAR, Sym.COIN, Sym.SKULL]
var _sprite: Sprite2D
var _light: PointLight2D
var _glass: Node2D

# The chamber it stands in sets the price (the level scene above it, else the current map).
func cost() -> int:
	var lvl := GameManager.level_index(GameManager.current_map)
	var n: Node = self
	while n:
		if GameManager.level_index(n.scene_file_path) >= 0:
			lvl = GameManager.level_index(n.scene_file_path)
			break
		n = n.get_parent()
	lvl = maxi(lvl, 0)
	return COST_BY_LEVEL[mini(lvl, COST_BY_LEVEL.size() - 1)]

const STICKY := 0.3 # chance a reel lands on the same symbol as the one before it

static func roll_symbol() -> int:
	var total := 0
	for k in WEIGHTS:
		total += WEIGHTS[k]
	var r := randi() % total
	for k in WEIGHTS:
		r -= WEIGHTS[k]
		if r < 0:
			return k
	return Sym.MOON

# Three reels; each may "stick" to the previous symbol, so lines come up a bit more often
# (about one pull in five is a three-of-a-kind).
static func pull() -> Array[int]:
	var out: Array[int] = []
	for i in 3:
		out.append(out[i - 1] if i > 0 and randf() < STICKY else roll_symbol())
	return out

# What a line pays: [kind, text]. kind: jackpot | moonlit | coins5 | potions | perk | double |
# flask | refund | hurt | ambush | none
static func judge(line: Array[int]) -> Array:
	var n := {}
	for s in line:
		n[s] = n.get(s, 0) + 1
	if n.get(Sym.STAR, 0) == 3:
		return ["jackpot", "JACKPOT! The stars align: a rare blessing."]
	if n.get(Sym.SKULL, 0) == 3:
		return ["ambush", "CURSED! The dead answer the shrine's call."]
	if n.get(Sym.MOON, 0) == 3:
		return ["moonlit", "Three moons: a blessing of your choice."]
	if n.get(Sym.COIN, 0) == 3:
		return ["coins5", "Three coins: the shrine pays five times over!"]
	if n.get(Sym.POTION, 0) == 3:
		return ["potions", "Three flasks: two health potions and a mana potion."]
	if n.get(Sym.STAR, 0) == 2:
		return ["perk", "Two stars: a blessing, sight unseen."]
	if n.get(Sym.SKULL, 0) == 2:
		return ["hurt", "Two skulls: the shrine drinks some of your life."]
	if n.get(Sym.COIN, 0) == 2:
		return ["double", "Two coins: your stake comes back doubled."]
	if n.get(Sym.POTION, 0) == 2:
		return ["flask", "Two flasks: a health potion."]
	if n.get(Sym.MOON, 0) == 2:
		return ["refund", "Two moons: your stake comes back."]
	return ["none", "Nothing. The shrine keeps your coins."]

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 6)
	shape.shape = rect
	shape.position = Vector2(-2, -4)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load(ART)
	_sprite.centered = false
	_sprite.offset = Vector2(-SIZE.x / 2.0, -SIZE.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	# Reels and bulbs glow on their own, unaffected by the chamber's darkness.
	_glass = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glass.material = mat
	_glass.draw.connect(_draw_glass)
	add_child(_glass)
	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = Color(1.0, 0.78, 0.4)
	_light.energy = 0.7
	_light.texture_scale = 0.8
	_light.position = Vector2(-2, -20)
	add_child(_light)
	GroundShadow.attach(self, 0.0, 0.95) # about the plinth, not a pool around it

func interact(_body: Node2D = null) -> void:
	FortuneMenu.open(self)

func flash() -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 1.5, 0.0)
	_light.energy = 0.7 + 0.1 * sin(_t * 3.0) + 0.9 * _flash
	# Now and then a reel ticks over, as if the shrine were idly dreaming of luck.
	if fmod(_t, 1.4) < delta:
		_idle[randi() % 3] = randi() % Sym.size()
	_glass.queue_redraw()

func _draw_glass() -> void:
	var origin := -Vector2(SIZE.x / 2.0, SIZE.y)
	for i in 3:
		var c: Vector2 = origin + WINDOWS[i]
		FortuneShrine.draw_icon(_glass, _idle[i], c - Vector2(3.5, 3.5), 1.0, 0.95)
	# Bulbs along the base trim chase each other.
	for k in 6:
		var on := int(_t * 6.0) % 6 == k or _flash > 0.0
		_glass.draw_rect(Rect2(origin + Vector2(3 + k * 4, 32), Vector2(1, 1)), Color(1.0, 0.95, 0.7, 0.95 if on else 0.25))
	# The star medallion catches the light.
	_glass.draw_rect(Rect2(origin + Vector2(14, 3), Vector2(1, 1)), Color(1.0, 0.95, 0.7, 0.5 + 0.5 * sin(_t * 2.0)))

static func draw_icon(ci: CanvasItem, sym: int, at: Vector2, px: float, alpha: float = 1.0) -> void:
	var rows: Array = ICONS[sym]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(at + Vector2(x, y) * px, Vector2(px, px)), Color(PALETTE[ch], alpha))

# Pays out a line in the world (the menu has closed or is about to).
func reward(kind: String, stake: int) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Player
	match kind:
		"jackpot":
			flash()
			CombatFX.shockwave(global_position + Vector2(0, -16), Color(1.0, 0.85, 0.4), 70.0, 0.7, 3.0)
			AudioManager.play_bank("gem", 0.0, 1.2)
			if Progression.auto_pick:
				Progression.take(Progression.roll(3, Progression.Rarity.RARE)[0])
			else:
				PerkPicker.offer("FORTUNE'S FAVOUR", Progression.roll(3, Progression.Rarity.RARE))
		"moonlit":
			flash()
			AudioManager.play_bank("gem", -2.0, 1.0)
			if Progression.auto_pick:
				Progression.take(Progression.roll(3, Progression.Rarity.UNCOMMON)[0])
			else:
				PerkPicker.offer("MOONLIT BLESSING", Progression.roll(3, Progression.Rarity.UNCOMMON))
		"perk":
			if Progression.auto_pick:
				Progression.take(Progression.roll(1)[0])
			else:
				PerkPicker.offer("TWO STARS", Progression.roll(1))
		"potions", "flask":
			GameManager.add_health_potion(2 if kind == "potions" else 1)
			if kind == "potions":
				GameManager.add_mana_potion(1)
			AudioManager.play_bank("bottle", -4.0, 1.0)
		"coins5", "double", "refund":
			GameManager.total_coins += stake * {"coins5": 5, "double": 2, "refund": 1}[kind]
			AudioManager.play_bank("coin", -2.0, 1.1)
		"hurt":
			if pl:
				pl.receive_damage(maxi(4, roundi(pl.max_health * 0.10)))
		"ambush":
			_ambush(pl)

func _ambush(pl: Player) -> void:
	if not pl:
		return
	# Whatever haunts this chamber: borrow the level's own spawners for the enemy kinds.
	var kinds: Array[PackedScene] = []
	for sp in get_tree().current_scene.find_children("*", "Marker2D", true, false):
		if sp.has_method("spawn_enemy"):
			if sp.enemy_scene:
				kinds.append(sp.enemy_scene)
			for k in sp.random_pool:
				kinds.append(k)
	if kinds.is_empty():
		return
	CombatFX.shake(4.0, 0.4)
	AudioManager.play_bank("roar", -4.0, 0.9)
	for i in 3:
		# Around the player, but short of any wall: next to a shrine against the back wall a
		# plain circle put one of them behind it, out of the map.
		var at := BossMoves.safe_spot(pl.get_world_2d(), pl.global_position, pl.global_position + Vector2.from_angle(TAU * i / 3.0 + 0.4) * 46.0, [pl.get_rid()])
		var ground := MapBounds.ground_layers(self)
		if not ground.is_empty() and not MapBounds.on_map(ground, at):
			at = MapBounds.nearest_on_map(ground, at)
		CombatFX.pvfx("rift-portal", at, 0.35)
		var e: Node2D = kinds.pick_random().instantiate()
		if e is Enemy:
			e.force_elite = i == 0
		get_parent().add_child(e)
		e.global_position = at


class FortuneMenu extends CanvasLayer:
	const FONT: FontFile = preload("res://assets/fonts/PixelifySans.ttf")
	const GOLD := Color(0.95, 0.78, 0.35)
	const VIOLET := Color(0.62, 0.42, 0.9)
	const TEXT := Color(0.92, 0.88, 0.8)
	const DIM := Color(0.62, 0.58, 0.54)
	const W := 760.0
	const H := 516.0

	static var _open: CanvasLayer

	static func is_open() -> bool:
		return is_instance_valid(_open)

	static func open(s: FortuneShrine) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if is_open() or not tree or not tree.current_scene:
			return
		var m := FortuneMenu.new()
		m._shrine = s
		tree.current_scene.add_child(m)
		_open = m

	var _shrine: FortuneShrine
	var _reels: Array = []
	var _result: Label
	var _coins: Label
	var _spin: Button
	var _spinning := false
	var _pending := ""

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
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.04, 0.08, 0.97)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.shadow_color = Color(VIOLET, 0.35)
		sb.shadow_size = 14
		panel.add_theme_stylebox_override("panel", sb)
		panel.size = Vector2(W, H)
		panel.position = ((vp - panel.size) / 2.0).round()
		add_child(panel)
		_text(panel, "FORTUNE SHRINE", 33, GOLD, Vector2(0, 18), W, HORIZONTAL_ALIGNMENT_CENTER)
		_text(panel, "%d coins a pull. The stars favour the bold." % _shrine.cost(), 22, DIM, Vector2(0, 58), W, HORIZONTAL_ALIGNMENT_CENTER)
		var rule := ColorRect.new()
		rule.color = Color(GOLD, 0.35)
		rule.position = Vector2(32, 92)
		rule.size = Vector2(W - 64, 2)
		panel.add_child(rule)
		# Three reels on the left.
		for i in 3:
			var r := _Reel.new()
			r.position = Vector2(36 + i * 124, 104)
			r.size = Vector2(112, 156) # three full rows of 52 px: no icon is ever cut
			panel.add_child(r)
			_reels.append(r)
		for side in [Vector2(22, 177), Vector2(400, 177)]:
			var arrow := _PayArrow.new()
			arrow.position = side
			arrow.flip = side.x > 100.0
			panel.add_child(arrow)
		_result = _text(panel, "Pull the lever and trust the stars.", 22, TEXT, Vector2(36, 274), 360, HORIZONTAL_ALIGNMENT_CENTER)
		_result.autowrap_mode = TextServer.AUTOWRAP_WORD
		_result.size = Vector2(360, 56)
		# The paytable on the right.
		var col := ColorRect.new()
		col.color = Color(VIOLET, 0.25)
		col.position = Vector2(424, 108)
		col.size = Vector2(2, 286)
		panel.add_child(col)
		var bad := Color(1.0, 0.5, 0.5)
		var rows := [[[2, 2, 2], "Pick a rare perk", GOLD], [[4, 4, 4], "Pick a perk", GOLD],
			[[0, 0, 0], "Stake x5", TEXT], [[1, 1, 1], "2 health + 1 mana", TEXT], [[2, 2, -1], "Random perk", TEXT],
			[[0, 0, -1], "Stake x2", TEXT], [[1, 1, -1], "Health potion", TEXT], [[4, 4, -1], "Stake back", TEXT],
			[[3, 3, -1], "Lose 10% health", bad], [[3, 3, 3], "Ambush!", bad]]
		for k in rows.size():
			var y := 110.0 + k * 29.0
			var icons := _Line.new()
			icons.syms = rows[k][0]
			icons.position = Vector2(446, y)
			icons.size = Vector2(96, 26)
			panel.add_child(icons)
			_text(panel, rows[k][1], 22, rows[k][2], Vector2(556, y - 1), 180, HORIZONTAL_ALIGNMENT_LEFT)
		_coins = _text(panel, "", 22, GOLD, Vector2(0, 412), W, HORIZONTAL_ALIGNMENT_CENTER)
		_spin = _button(panel, "PULL", Vector2(W / 2.0 - 110, 450), Vector2(104, 44))
		_spin.pressed.connect(_pull)
		var leave := _button(panel, "LEAVE", Vector2(W / 2.0 + 6, 450), Vector2(104, 44))
		leave.pressed.connect(_close)
		_refresh()

	func _refresh() -> void:
		var c := _shrine.cost()
		_coins.text = "Coins: %d     [Space] pull    Esc: leave" % GameManager.total_coins
		_spin.disabled = _spinning or GameManager.total_coins < c

	func _pull() -> void:
		var c := _shrine.cost()
		if _spinning or GameManager.total_coins < c:
			if GameManager.total_coins < c:
				_result.text = "You need %d coins." % c
				AudioManager.play_bank("ui_error", -6.0)
			return
		_spinning = true
		GameManager.total_coins -= c
		AudioManager.play_bank("coin", -4.0, 0.8)
		AudioManager.play_bank("chain", -8.0, 1.3)
		_result.text = ""
		_refresh()
		var line := FortuneShrine.pull()
		for i in 3:
			_reels[i].spin()
		for i in 3:
			await get_tree().create_timer(0.7 if i == 0 else 0.45, true, false, true).timeout
			_reels[i].stop(line[i])
			AudioManager.play_bank("stomp", -10.0, 1.6 + i * 0.1)
		var verdict := FortuneShrine.judge(line)
		_result.text = verdict[1]
		var kind: String = verdict[0]
		var good := kind in ["jackpot", "moonlit", "coins5", "potions", "perk", "double", "flask", "refund"]
		AudioManager.play_bank("gem" if good else ("ui_error" if kind != "none" else "ui_back"), -4.0, 1.2 if kind in ["jackpot", "moonlit"] else 0.9)
		for r in _reels:
			r.glow = Color(1.0, 0.85, 0.4) if good else (Color(1.0, 0.35, 0.4) if kind in ["hurt", "ambush"] else Color(0, 0, 0, 0))
		if is_instance_valid(_shrine):
			_shrine.flash()
		_spinning = false
		# Effects that need the world (a perk card, an ambush, a hit) happen after leaving.
		if kind in ["jackpot", "moonlit", "perk", "ambush", "hurt"]:
			_pending = kind
			await get_tree().create_timer(1.1, true, false, true).timeout
			_close()
			return
		if is_instance_valid(_shrine):
			_shrine.reward(kind, c)
		_refresh()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_SPACE, KEY_1, KEY_KP_1: _pull()
				KEY_ESCAPE:
					if not _spinning:
						_close()
				# F does nothing while the window is open (it used to close and reopen it).
			get_viewport().set_input_as_handled()

	func _close() -> void:
		get_tree().paused = false
		_open = null
		AudioManager.play_bank("ui_select", -10.0)
		if _pending != "" and is_instance_valid(_shrine):
			_shrine.reward(_pending, _shrine.cost())
		queue_free()

	func _button(panel: Control, text: String, pos: Vector2, size: Vector2) -> Button:
		var b := Button.new()
		b.text = text
		b.position = pos
		b.size = size
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 22)
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
		l.horizontal_alignment = align
		l.position = pos
		l.size = Vector2(width, 26)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(l)
		return l


# One reel window: symbols roll past while spinning, then it settles on its result.
class _Reel extends Control:
	const ROW := 52.0
	const PX := 6.0
	var strip: Array[int] = [] # top, middle (the payline), bottom
	var glow := Color(0, 0, 0, 0)
	var _rolling := false
	var _off := 0.0
	var _settle := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		clip_contents = true
		for i in 4:
			strip.append(FortuneShrine.roll_symbol())

	func spin() -> void:
		_rolling = true
		glow = Color(0, 0, 0, 0)

	# Settles with `s` on the payline; the symbols above and below are whatever came round.
	func stop(s: int) -> void:
		_rolling = false
		strip = [FortuneShrine.roll_symbol(), s, FortuneShrine.roll_symbol(), FortuneShrine.roll_symbol()]
		_off = 0.0
		_settle = 1.0

	func _process(delta: float) -> void:
		if _rolling:
			_off += delta * 1100.0
			while _off >= ROW:
				_off -= ROW
				strip.pop_back()
				strip.push_front(FortuneShrine.roll_symbol())
				AudioManager.play_bank("ui_click", -22.0, 1.9)
		_settle = maxf(_settle - delta * 4.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.06, 0.12))
		# The payline row is lit; the rows above and below sit in shadow.
		var mid_y := (size.y - ROW) / 2.0
		draw_rect(Rect2(Vector2(0, mid_y), Vector2(size.x, ROW)), Color(0.2, 0.13, 0.22))
		var icon := 7.0 * PX
		var bounce := -sin(_settle * PI) * 6.0
		for k in strip.size():
			var y := mid_y + (k - 1) * ROW + (_off if _rolling else bounce) + (ROW - icon) / 2.0
			var faded := 1.0 if k == 1 and not _rolling else 0.45
			FortuneShrine.draw_icon(self, strip[k], Vector2((size.x - icon) / 2.0, y), PX, faded)
		# A soft shade at the very top and bottom, as on a curved drum (it never covers icons).
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 4)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2(0, size.y - 4), Vector2(size.x, 4)), Color(0, 0, 0, 0.45))
		var line := Color(0.95, 0.78, 0.35, 0.8)
		draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(line, 0.35), 1.0)
		draw_line(Vector2(0, mid_y + ROW), Vector2(size.x, mid_y + ROW), Color(line, 0.35), 1.0)
		if glow.a > 0.0:
			draw_rect(Rect2(Vector2(0, mid_y), Vector2(size.x, ROW)), Color(glow, 0.18))
		draw_rect(Rect2(Vector2.ZERO, size), glow if glow.a > 0.0 else Color(0.62, 0.42, 0.9), false, 2.0)


# A small row of paytable icons (-1 = any).
class _Line extends Control:
	var syms: Array = []

	func _draw() -> void:
		for i in syms.size():
			var at := Vector2(i * 32, 0)
			if syms[i] < 0:
				draw_rect(Rect2(at + Vector2(8, 10), Vector2(8, 3)), Color(0.62, 0.58, 0.54, 0.6))
			else:
				FortuneShrine.draw_icon(self, syms[i], at, 3.0)


# A small gold arrow marking the payline beside the reels.
class _PayArrow extends Control:
	var flip := false

	func _draw() -> void:
		var c := Color(0.95, 0.78, 0.35)
		for i in 5:
			var x := (4 - i) if flip else i
			draw_rect(Rect2(x * 2.0, i, 2, 10 - i * 2), c)
