extends Node2D

# Upgrades for the hand-made level_1, added at load time so the original scene and its
# decoration stay untouched:
#  - the three decorative chests next to the Demon become real reward chests that only
#    appear once the Demon falls,
#  - the two treasure chests that were rotated on their side stand upright,
#  - a transmuting altar between the sarcophagi and a sealed (coin) chest,
#  - the hatch in the Golem's chamber becomes a trap with a perk reward.

const CHEST_SCENE := "res://assets/sprites/sprite_frames/Chest.tscn"
const CHEST_SCRIPT := "res://scripts/world/chest.gd"
const HEALTH := "res://scenes/world/HealthPotion.tscn"

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	var level := get_parent()
	_shrink_decor(level)
	DecorPhysics.apply(level, true) # pots and pillars block, bones crunch
	_focus_mode(level)
	var chests := level.get_node_or_null("Chests")
	if chests:
		for c in chests.get_children():
			c.rotation = 0.0
		# Same generosity as levels 2 and 3: a pile of coins besides the item inside.
		var loot := {"Chest": {"coins_amount": 15},
			"Chest2": {"coins_amount": 20, "free_perk": true, "perk_min_rarity": 2},
			"Chest3": {"coins_amount": 18, "bonus_items": [HEALTH]}}
		for n in loot:
			var c := chests.get_node_or_null(n)
			if not c:
				continue
			for k in loot[n]:
				if k == "bonus_items":
					var items: Array[String] = []
					items.assign(loot[n][k])
					c.bonus_items = items
				else:
					c.set(k, loot[n][k])
		# The two chests in the small east room sit in an iron cage: light the brazier in the
		# room and the one in the west room, across the spike pit, before either goes out.
		var guarded := []
		for n in ["Chest2", "Chest3"]:
			var c := chests.get_node_or_null(n)
			if c:
				guarded.append(c)
		if not guarded.is_empty():
			_rune_vault(level, guarded)
	_boss_rewards(level)
	_demon_stairs(level)
	_golem_gates(level)
	_trapped_floor(level)
	# A gentler start: only the slow slime waits in the first room (the skeleton and the
	# spawner right on top of the spawn point are removed before they wake up, 1 s in).
	for n in ["EnemySpawners/RandomSpawner", "EnemySpawners/Skeleton"]:
		var sp := level.get_node_or_null(n)
		if sp:
			sp.queue_free()
	# Positions below are world coordinates measured on the rendered map; the scene root is
	# offset, so convert them to the root's local space.
	# (The transmuter is no longer by the spawn: it rises in the Undercroft once it is
	# cleared, see crypt.txt.)
	# First run: the starting room teaches the controls with a row of carved stones.
	if not TutorialStone.finished():
		TutorialStone.TutorialPath.build(level, TUTORIAL_SPOTS)
	_chest(level, Vector2(566, 100), {"coin_cost": 20})
	# The peddler waits in the quiet west room, off the way to the Golem.
	var peddler := Merchant.new()
	peddler.name = "Merchant"
	level.add_child(peddler)
	peddler.global_position = MERCHANT_AT
	var hatch := Node2D.new()
	hatch.set_script(load("res://scripts/world/trapdoor.gd"))
	level.add_child(hatch)
	# Drawn with the floor, before the characters: they stand in front of the open pit.
	var bg := level.get_node_or_null("Background")
	if bg:
		level.move_child(hatch, bg.get_index() + 1)
	hatch.global_position = Vector2(846, 574)
	# The Undercroft below the hatch lives far outside the map so it keeps level_1's state.
	var crypt: Node2D = load("res://scenes/levels/crypt.tscn").instantiate()
	level.add_child(crypt)
	crypt.global_position = Vector2(1700, 0)
	hatch.crypt = crypt
	# Last, once the vault and the crypt are in: their pots break and their bones crunch too.
	DecorPhysics.apply(level, true)

# Config is applied before the chest enters the tree: a sealed chest builds its price tag
# in _ready.
func _chest(parent: Node, world_pos: Vector2, cfg: Dictionary = {}) -> Node2D:
	var c: Node2D = load(CHEST_SCENE).instantiate()
	c.set_script(load(CHEST_SCRIPT))
	for k in cfg:
		if k == "bonus_items":
			var items: Array[String] = []
			items.assign(cfg[k])
			c.bonus_items = items
		else:
			c.set(k, cfg[k])
	parent.add_child(c)
	c.global_position = world_pos
	return c

func _boss_rewards(level: Node) -> void:
	var deco := level.get_node_or_null("Background/Tileset/Decorations/Chests")
	if not deco:
		return
	var spots := []
	for d in deco.get_children():
		spots.append(d.global_position)
	deco.queue_free()
	var reward := Node2D.new()
	reward.set_script(load("res://scripts/world/boss_reward.gd"))
	reward.boss_name = "Demon"
	level.add_child(reward)
	var contents := [
		{"coins_amount": 25, "bonus_items": [HEALTH]},
		{"coins_amount": 0, "free_perk": true, "perk_min_rarity": 3},
		{"coins_amount": 10, "bonus_items": [HEALTH, HEALTH]},
	]
	for i in spots.size():
		_chest(reward, spots[i], contents[i % contents.size()])

# --- Decoration scale ------------------------------------------------------------------
# level_1's props were drawn for bigger characters: 16 px candles next to a 14 px knight and
# 48 px sarcophagi. Shrink the decoration (not the characters), keeping every prop where
# it was placed: floor props shrink towards their base, wall-hung ones towards the wall.

const SPRITE_SCALE := {"Candles": 0.55, "Wax_Candle": 0.55, "Torchs": 0.75, "Side_Torchs": 0.75, "Wall_Torch": 0.75, "Flag": 0.7}
const PROP_SCALE := 0.62

func _shrink_decor(level: Node) -> void:
	var deco_root := level.get_node_or_null("Background/Tileset/Decorations")
	if deco_root:
		for n in deco_root.find_children("*", "AnimatedSprite2D", true, false):
			var sc: float = SPRITE_SCALE.get(String(n.get_parent().name), SPRITE_SCALE.get(String(n.name), 0.0))
			if sc <= 0.0:
				continue
			var tex: Texture2D = n.sprite_frames.get_frame_texture(n.animation, 0) if n.sprite_frames else null
			var h: float = tex.get_height() if tex else 16.0
			n.scale *= sc
			if String(n.get_parent().name) in ["Candles", "Wax_Candle"]:
				n.position.y += h * 0.5 * (1.0 - sc) # keep standing on the floor
	var layer := level.find_child("Decorations", true, false) as TileMapLayer
	var walls := level.find_child("Tileset", true, false) as TileMapLayer
	if layer:
		_shrink_tile_props(layer, walls)

func _shrink_tile_props(layer: TileMapLayer, walls: TileMapLayer) -> void:
	var cells := {}
	for c in layer.get_used_cells():
		cells[c] = true
	var seen := {}
	for start in cells:
		if seen.has(start):
			continue
		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			group.append(c)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					queue.append(n)
		# Pots stay tiles: DecorPhysics turns them (and a tall pot's neck) into breakables.
		var has_pot := false
		for c in group:
			has_pot = has_pot or BreakablePot.is_pot(layer, c) or BreakablePot.is_pot_neck(layer, c)
		if group.size() >= 2 and not has_pot:
			_group_to_sprites(layer, walls, group)

func _group_to_sprites(layer: TileMapLayer, walls: TileMapLayer, group: Array[Vector2i]) -> void:
	var minc := group[0]
	var maxc := group[0]
	for c in group:
		minc = Vector2i(mini(minc.x, c.x), mini(minc.y, c.y))
		maxc = Vector2i(maxi(maxc.x, c.x), maxi(maxc.y, c.y))
	var ts := layer.tile_set.tile_size
	var top_left := layer.map_to_local(minc) - Vector2(ts) / 2.0
	var bottom_right := layer.map_to_local(maxc) + Vector2(ts) / 2.0
	# Hung on the wall if a wall tile sits right above it; otherwise it stands on the floor.
	var hung := false
	if walls:
		for x in range(minc.x, maxc.x + 1):
			if walls.get_cell_source_id(Vector2i(x, minc.y - 1)) != -1:
				hung = true
	var anchor := Vector2((top_left.x + bottom_right.x) / 2.0, top_left.y if hung else bottom_right.y)
	var bone_group := true
	var prop := Node2D.new()
	prop.position = anchor
	prop.scale = Vector2(PROP_SCALE, PROP_SCALE)
	prop.z_index = layer.z_index
	layer.add_child(prop)
	for c in group:
		var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
		if not src:
			continue
		var atlas := layer.get_cell_atlas_coords(c)
		if not DecorPhysics.is_bone(layer, c):
			bone_group = false
		var at := AtlasTexture.new()
		at.atlas = src.texture
		at.region = src.get_tile_texture_region(atlas)
		var spr := Sprite2D.new()
		spr.texture = at
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = layer.map_to_local(c) - anchor
		prop.add_child(spr)
		layer.erase_cell(c)
	# Anything standing on the floor blocks (pots, pillars, sarcophagi), whatever the tile
	# data said; bones and things hung on a wall never do.
	if bone_group:
		DecorPhysics._add_crunch(layer, layer.to_global(anchor + Vector2(0, -4))) # walked over, crunches
	elif not hung:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var size := (bottom_right - top_left) * PROP_SCALE
		rect.size = Vector2(size.x, maxf(size.y * 0.55, 6.0))
		shape.shape = rect
		shape.position = Vector2(0, -rect.size.y / 2.0)
		body.add_child(shape)
		body.position = anchor
		layer.add_child(body)

# --- Focus mode --------------------------------------------------------------------------
# The same atmosphere as maps 2 and 3: darkness, a light around the hero, drifting dust and
# a title card; every torch and candle of the original map now actually casts light.

func _focus_mode(level: Node) -> void:
	var amb := Node2D.new()
	amb.set_script(load("res://scripts/levels/level_ambience.gd"))
	amb.level_title = "THE FORGOTTEN CRYPT"
	amb.level_subtitle = "Where the old dead still keep watch"
	amb.darkness = Color(0.42, 0.36, 0.5)
	amb.player_light_color = Color(1.0, 0.86, 0.7)
	amb.mote_color = Color(0.9, 0.75, 0.55, 0.45)
	amb.mote_gravity = Vector2(0, -4)
	level.add_child(amb)
	var deco := level.get_node_or_null("Background/Tileset/Decorations")
	if not deco:
		return
	for n in deco.find_children("*", "AnimatedSprite2D", true, false):
		var group := String(n.get_parent().name)
		var candle := group in ["Candles", "Wax_Candle"]
		var torch := group in ["Torchs", "Side_Torchs", "Wall_Torch"] or String(n.name).begins_with("Torch")
		if not (candle or torch):
			continue
		var light := PointLight2D.new()
		light.texture = LevelAmbience.light_texture()
		light.color = Color(1.0, 0.68, 0.38) if torch else Color(1.0, 0.78, 0.5)
		light.energy = 1.0 if torch else 0.75
		light.texture_scale = (1.5 if torch else 0.9) / maxf(absf(n.global_scale.x), 0.1)
		n.add_child(light)

# --- The Golem's chamber locks you in ------------------------------------------------------
# Its only way in is the 3-tile corridor at the top. Portcullises drop there the moment the
# Golem joins the fight and rise again only when it falls: no running away from this one.
const GOLEM_GATE_CELLS := [Vector2(830, 462), Vector2(846, 462), Vector2(862, 462)]
const GOLEM_ROOM := Rect2(726, 470, 240, 128) # the chamber's floor, below the gate line
const GATE_CLEAR := 32.0

func _golem_gates(level: Node) -> void:
	var golem := level.get_node_or_null("Golem") as BossBase
	if not golem:
		return
	var gates: Array[Node2D] = []
	for at in GOLEM_GATE_CELLS:
		var g: Node2D = load("res://scenes/world/door.tscn").instantiate()
		g.required_key = Door.KeyType.NONE
		g.is_open = true
		g.gate_style = true
		level.add_child(g)
		g.global_position = at
		gates.append(g)
	var watcher := _GateWatcher.new()
	watcher.golem = golem
	watcher.gates = gates
	level.add_child(watcher)

class _GateWatcher extends Node:
	var golem: BossBase
	var gates: Array[Node2D] = []
	var _closed := false

	func _process(_delta: float) -> void:
		if not is_instance_valid(golem) or not golem.is_alive:
			if _closed:
				for g in gates:
					g.is_locked = false
					g.open()
				AudioManager.play_bank("door_open", 0.0, 0.8)
			queue_free()
			return
		if not is_instance_valid(golem.player):
			return
		var at: Vector2 = golem.player.global_position
		# Safety net: the gates never keep the player out. If they somehow end up outside the
		# chamber with the gates down (a shove, a dodge back through), they rise again.
		if _closed and not GOLEM_ROOM.has_point(at):
			_closed = false
			for g in gates:
				g.is_locked = false
				g.open()
			return
		# Close only once the player is well inside the chamber (two tiles past the gate line,
		# so the bars never drop on them or behind a step they are still taking) and the
		# Golem is fighting.
		if not _closed and golem.is_engaged() and GOLEM_ROOM.grow_individual(0, -GATE_CLEAR, 0, 0).has_point(at):
			_closed = true
			for g in gates:
				g.close()
				g.is_locked = true
			AudioManager.play_bank("door_close", 2.0, 0.7)
			AudioManager.play_bank("chain", -2.0, 0.8)
			CombatFX.shake(3.0, 0.3)

# --- The arrow corridor ---------------------------------------------------------------------
# The four wall traps no longer fire on a timer (you could just walk between volleys): the
# corridor floor is now pressure tiles, two per row, one safe per row (see PressurePlates).
func _trapped_floor(level: Node) -> void:
	var traps := level.get_node_or_null("ArrowTraps")
	if not traps:
		return
	# Hidden plates over the full corridor width (3 cells per row). Few per row, never two
	# side by side, alternating, so a single winding safe path runs through.
	var pattern := [[false, true, false], [true, false, true], [false, true, false], [true, false, false]]
	var rows := []
	var k := 0
	for name in ["ArrowTrap", "ArrowTrap4", "ArrowTrap2", "ArrowTrap3"]:
		var t := traps.get_node_or_null(name)
		if not t:
			continue
		if t.timer and t.timer.timeout.is_connected(t._on_timer_timeout):
			t.timer.timeout.disconnect(t._on_timer_timeout)
			t.timer.stop()
		rows.append({"y": t.global_position.y, "xs": [608.0, 622.0, 636.0], "trapped": pattern[k % pattern.size()], "trap": t})
		k += 1
	PressurePlates.build(level, rows)

# --- The Rune Vault ------------------------------------------------------------------------
# Two puzzles in a row. Up here: light the brazier in the east room and the one in the west
# room (across the spike pit) before either dies out, and the grate over the stairway in the
# east room lifts. Down there (scenes/levels/vault.tscn, built from tools/levels/vault.txt):
# a tablet shows four runes in order; step on the floor runes in that order and the cages
# around the two chests in the alcove sink away.
const VAULT_AT := Vector2(1700, 420)

func _rune_vault(level: Node, chests: Array) -> void:
	var vault: Node2D = load("res://scenes/levels/vault.tscn").instantiate()
	level.add_child(vault)
	vault.global_position = VAULT_AT
	var cell := func(x: int, y: int) -> Vector2: return vault.to_global(Vector2(x * 16 + 8, y * 16 + 8))
	# The way down, sealed until both braziers burn.
	var down := Passage.new()
	down.locked = true
	down.locked_text = "A heavy grate seals the stairway. The rune plates on the floor are empty..."
	level.add_child(down)
	down.global_position = Vector2(1015, 362)
	var up_target := Marker2D.new()
	level.add_child(up_target)
	up_target.global_position = Vector2(1015, 384)
	down.target = vault.get_node("Entry") if vault.has_node("Entry") else up_target
	var up := Passage.new()
	up.going_down = false
	up.target = up_target
	# The way out is the very ladder you came down: the vault's own ladder sprite, with
	# the passage sitting invisibly on it (it used to draw a second ladder next to it).
	up.draw_art = false
	vault.add_child(up)
	var ladder := vault.get_node_or_null("Ladder") as Node2D
	up.global_position = ladder.global_position if ladder else cell.call(14, 18)
	if not skip_east_open:
		_open_east_rooms(level)
	# Push the two rune blocks onto the two plates to lift the grate.
	var pushes := PushPuzzle.build(level, [Vector2(936, 378), Vector2(1000, 378)], [Vector2(936, 330), Vector2(968, 394)]) # block 1: up x3; block 2: left x2, down x1
	pushes.solved.connect(down.unlock)
	# The treasure moves down into the alcove.
	# The alcove is the highest floor of the vault: measure it on the generated floor layer
	# (the builder pads the plan, so plan coordinates don't map 1:1).
	var floor := vault.find_child("Floor", true, false) as TileMapLayer
	var spot: Vector2 = cell.call(14, 3)
	if floor:
		var cells := floor.get_used_cells()
		var top := 9999
		for c in cells:
			top = mini(top, c.y)
		var xs := []
		for c in cells:
			if c.y == top + 2:
				xs.append(c.x)
		if not xs.is_empty():
			xs.sort()
			spot = floor.to_global(floor.map_to_local(Vector2i(xs[xs.size() / 2], top + 2)))
	for i in chests.size():
		var c: Node2D = chests[i]
		c.reparent(vault)
		c.global_position = spot + Vector2(-14 + i * 28, 0)
	RunePuzzle.build(vault, [cell.call(8, 8), cell.call(20, 8), cell.call(8, 13), cell.call(20, 13)], cell.call(14, 11), chests)

# The two small east rooms used to be split by a wall with a spike corridor through it: the
# wall and the trap go, leaving one hall for the block puzzle. Rebuilt with the map's own
# tiles (the Tileset layer holds both the walls and the floor): the dividing columns become
# floor in the rooms' pattern, and the top and bottom walls run on unbroken across them, so
# there is no seam, no stray wall end and no gap to the void.
const MERCHANT_AT := Vector2(570, 326) # against the back wall, between the stairs and the torch
const TUTORIAL_SPOTS := [Vector2(615, 124), Vector2(642, 124), Vector2(669, 124), Vector2(696, 124), Vector2(723, 124)] # the starting room, below the spawn
const EAST_OPEN := Rect2(926, 318, 66, 80) # what the hall clears (decor and traps)
const EAST_SEAM_X := [942.0, 958.0, 974.0] # world x of the three columns between the rooms
const EAST_TOP_WALL_Y := 294.0
const EAST_FLOOR_Y := [310.0, 326.0, 342.0, 358.0, 374.0, 390.0]
const EAST_BOTTOM_WALL_Y := 406.0
const EAST_PATTERN_X0 := 894.0 # the west room's first floor column: floor atlas x = 6 + col % 3
static var skip_east_open := false # playtest: compare the map before the east rooms were opened

func _open_east_rooms(level: Node) -> void:
	var walls := level.find_child("Tileset", true, false) as TileMapLayer
	if walls:
		var src := walls.get_cell_source_id(walls.local_to_map(walls.to_local(Vector2(EAST_PATTERN_X0, EAST_FLOOR_Y[0]))))
		for x in EAST_SEAM_X:
			var col := int(roundf((x - EAST_PATTERN_X0) / 16.0))
			walls.set_cell(_cell_at(walls, x, EAST_TOP_WALL_Y), src, Vector2i(4, 0))
			walls.set_cell(_cell_at(walls, x, EAST_BOTTOM_WALL_Y), src, Vector2i(4, 4))
			for k in EAST_FLOOR_Y.size():
				walls.set_cell(_cell_at(walls, x, EAST_FLOOR_Y[k]), src, Vector2i(6 + posmod(col, 3), k % 2))
		var deco := level.find_child("Decorations", true, false) as TileMapLayer
		if deco:
			for c in deco.get_used_cells():
				if EAST_OPEN.has_point(deco.to_global(deco.map_to_local(c))):
					deco.erase_cell(c)
	var traps := level.get_node_or_null("Traps")
	if traps:
		for t in traps.get_children():
			if t is Node2D and EAST_OPEN.grow(8.0).has_point(t.global_position):
				t.queue_free()

static func _cell_at(layer: TileMapLayer, x: float, y: float) -> Vector2i:
	return layer.local_to_map(layer.to_local(Vector2(x, y)))

# The stairway in the Demon's hall is the way on to level 2 (no portal on this level): it
# stays sealed while the Demon lives, then lights up with the exit glow; F goes down.
func _demon_stairs(level: Node) -> void:
	var exit := Node2D.new()
	exit.set_script(load("res://scripts/world/level_exit.gd"))
	exit.name = "DemonStairs"
	exit.style = "stairs"
	exit.boss_to_track = "Demon"
	exit.unlocks_level = 2
	exit.glow_color = Color(1.0, 0.62, 0.35)
	level.add_child(exit)
	exit.global_position = Vector2(117, 362) # the middle of the stairway going down
