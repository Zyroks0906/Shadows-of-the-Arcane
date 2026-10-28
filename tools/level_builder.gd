extends Node

# Builds the chamber scenes (and the enemy scenes they use) from the ASCII layouts in
# tools/levels/. Re-run after editing a layout:
#
#   Godot_v4.6.2-stable_win64_console.exe --headless --path . res://tools/level_builder.tscn
#
# It runs as a scene (not --script) so the autoloads the game scripts rely on exist.
#
# Layout legend
#   terrain   ' ' rock/void   '.' floor   ',' shallow water (Hydro zone, slows)   '~' deep water
#             '*' rune floor  '>' '<' 'A' 'V' wind current east/west/north/south (Anemo zone, pushes)
#   entities  'P' player start   'X' exit portal   'B' boss   'e' random enemy   's' slime   'w' wisp   'O' orc
#             'c' Cryo crystal   'z' Electro crystal   'p' pillar / dormant crystal   'o' pot
#             '1' silver key   '2' golden key   'D' silver door   'G' golden door   'd' boss door
#             'h' health potion   'm' mana potion   '$' coin   'C' chest   'x' spike trap
#   arenas    'R' combat room (the floor region around it, bounded by gates/doors)
#             '=' arena gate (open until the player walks in, closes during the fight)
#             'E' second-wave enemy (random)   rewards revealed on clear: 'k' chest with the
#             silver key, 'g' chest with the golden key, 'r' chest with supplies
#   extras    'T' transmuting altar (mana potions -> health potions)
#             'Y' sealed chest (costs coins, offers a rare perk)

const T := 16
const GENERATED_SEED := 1337

const SCN := {
	"player_spawner": "res://scripts/levels/player_spawner.gd",
	"hud": "res://scenes/ui/hud.tscn",
	"spawner": "res://scripts/world/enemy_spawner.gd",
	"slime": "res://scenes/entities/Enemies/slime_base.tscn",
	"skeleton": "res://scenes/entities/Enemies/Skeleton.tscn",
	"rat": "res://scenes/entities/Enemies/Rat.tscn",
	"bat": "res://scenes/entities/Enemies/Bat.tscn",
	"wisp": "res://scenes/entities/Enemies/Wisp.tscn",
	"orc": "res://scenes/entities/Enemies/Orc.tscn",
	"guardian": "res://scenes/entities/Enemies/GuardianBoss.tscn",
	"golem": "res://scenes/entities/Enemies/Golem.tscn",
	"door": "res://scenes/world/door.tscn",
	"silver_key": "res://scenes/world/SilverKey.tscn",
	"golden_key": "res://assets/sprites/sprite_frames/GoldenKey.tscn",
	"health": "res://scenes/world/HealthPotion.tscn",
	"mana": "res://scenes/world/ManaPotion.tscn",
	"coin": "res://assets/sprites/sprite_frames/Coin.tscn",
	"chest": "res://assets/sprites/sprite_frames/Chest.tscn",
	"chest_script": "res://scripts/world/chest.gd",
	"spikes": "res://scenes/world/SpikeTrap.tscn",
}

const FG := "res://assets/tilesets/Farm Game Dungeon Cellar Tileset/Tilesets/FG_Cellar.png"
const MUSIC := "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/"

# Atlas source ids inside each generated TileSet.
const SRC_THEME := 0
const SRC_FG := 1

const LEVELS := [
	{
		# A room inserted into the hand-made level_1 (not a level of its own): same tileset,
		# no HUD/spawner/ambience. See scripts/levels/level1_extras.gd.
		"theme": "crypt",
		"fragment": true,
		"layout": "res://tools/levels/crypt.txt",
		"out": "res://scenes/levels/crypt.tscn",
		"root_name": "Crypt",
		"wall_tex": "res://assets/tilesets/character and tileset/Dungeon_Tileset.png",
		"torch_light": Color(1.0, 0.62, 0.3),
		"pool": ["skeleton", "rat", "bat"],
		"elements": [ElementalSystem.Element.PYRO, ElementalSystem.Element.HYDRO],
		"room_names": ["THE UNDERCROFT"],
		"boss_name": "",
	},
	{
		"theme": "caverns",
		"room_names": ["WISP SHRINE", "SLIME POOLS"],
		"sealed_cost": 25,
		"layout": "res://tools/levels/whispering_caverns.txt",
		"out": "res://scenes/levels/level_2.tscn",
		"root_name": "Level2",
		"wall_tex": "res://assets/tilesets/generated/dungeon_caverns.png",
		"title": "WHISPERING CAVERNS",
		"subtitle": "The river remembers every footstep",
		"music": MUSIC + "12 - Frozen Abyss.mp3",
		"darkness": Color(0.32, 0.4, 0.55),
		"player_light": Color(0.75, 0.9, 1.0),
		"motes": Color(0.55, 0.85, 1.0, 0.55),
		"mote_gravity": Vector2(0, 5),
		"torch_light": Color(0.35, 0.75, 1.0),
		"pool": ["slime", "bat", "rat", "wisp"],
		"elements": [ElementalSystem.Element.HYDRO, ElementalSystem.Element.CRYO, ElementalSystem.Element.ELECTRO],
		"boss": "guardian",
		"boss_name": "Guardian",
		"unlocks": 3,
		"exit_glow": Color(0.45, 0.9, 1.0),
		"water_tint": Color(0.32, 0.5, 0.62),
	},
	{
		"theme": "skyhold",
		"room_names": ["SANCTUM GUARD", "BARRACKS"],
		"sealed_cost": 35,
		"layout": "res://tools/levels/skyhold_ruins.txt",
		"out": "res://scenes/levels/level_3.tscn",
		"root_name": "Level3",
		"wall_tex": "res://assets/tilesets/generated/dungeon_skyhold.png",
		"title": "SKYHOLD RUINS & TOWER",
		"subtitle": "Where the winds still guard the sigil",
		"music": MUSIC + "11 - The Mighty Kingdom.mp3",
		"darkness": Color(0.55, 0.5, 0.7),
		"player_light": Color(1.0, 0.9, 0.8),
		"motes": Color(0.8, 0.6, 1.0, 0.6),
		"mote_gravity": Vector2(4, -7),
		"torch_light": Color(0.8, 0.55, 1.0),
		"pool": ["skeleton", "orc", "bat", "wisp"],
		"elements": [ElementalSystem.Element.ANEMO, ElementalSystem.Element.ELECTRO, ElementalSystem.Element.PYRO, ElementalSystem.Element.GEO],
		"boss": "golem",
		"boss_script": "res://scripts/entities/enemies/warden.gd",
		"boss_name": "Warden",
		"unlocks": 0,
		"exit_glow": Color(0.8, 0.6, 1.0),
	},
]

const FLOORISH_EXCLUDE := " #"
const SOLID_CHARS := "~po"
const WIND := {">": Vector2.RIGHT, "<": Vector2.LEFT, "A": Vector2.UP, "V": Vector2.DOWN}

var rng := RandomNumberGenerator.new()
var grid: Array[String] = []
# Terrain under entity cells (a slime standing in water still stands in water).
var underlay := {}
var width := 0
var height := 0

func _ready() -> void:
	rng.seed = GENERATED_SEED
	_build_enemy_scenes()
	for def in LEVELS:
		_build_level(def)
	get_tree().quit()

# --------------------------------------------------------------------------- grid helpers

func ch(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= width:
		return " "
	return grid[y][x]

func floorish(x: int, y: int) -> bool:
	return not FLOORISH_EXCLUDE.contains(ch(x, y))

func solid(x: int, y: int) -> bool:
	return not floorish(x, y) or SOLID_CHARS.contains(ch(x, y))

func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T / 2.0)

func _load_layout(path: String) -> void:
	var text := FileAccess.get_file_as_string(path).replace("\r", "")
	var lines := text.split("\n")
	# Pad with a margin so walls always have room around the outermost floors.
	const MARGIN := 3
	width = 0
	for l in lines:
		width = maxi(width, l.length())
	width += MARGIN * 2
	grid.clear()
	for i in MARGIN:
		grid.append(" ".repeat(width))
	for l in lines:
		grid.append((" ".repeat(MARGIN) + l).rpad(width))
	for i in MARGIN:
		grid.append(" ".repeat(width))
	height = grid.size()
	underlay.clear()
	for y in height:
		for x in width:
			if ".,~*><AV #".contains(ch(x, y)):
				continue
			var counts := {}
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := ch(x + d.x, y + d.y)
				if ",><AV".contains(n):
					counts[n] = counts.get(n, 0) + 1
			for k in counts:
				if counts[k] >= 2:
					underlay[Vector2i(x, y)] = k

func terrain(x: int, y: int) -> String:
	return underlay.get(Vector2i(x, y), ch(x, y))

# Caves should not look like rooms: carve and grow the edges of open areas along
# smooth noise blobs, then clean up one-tile spikes so walls read as rock, not battlements.
func _erode() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = GENERATED_SEED
	noise.frequency = 0.11
	for pass_i in 2:
		var changes := []
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				if _near_special(x, y) or _near_corridor(x, y):
					continue
				var c := ch(x, y)
				var n := noise.get_noise_2d(x, y + pass_i * 31)
				var floor_n := _floor_neighbours8(x, y)
				if c == "." and floor_n <= 6 and floor_n >= 3 and n > 0.12:
					changes.append([x, y, " "])
				elif c == " " and floor_n >= 2 and n < -0.2:
					changes.append([x, y, "."])
		_apply(changes)
	# Smooth: remove floor spurs and fill rock notches.
	for pass_i in 2:
		var changes := []
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				if _near_special(x, y) or _near_corridor(x, y):
					continue
				var f4 := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if floorish(x + d.x, y + d.y):
						f4 += 1
				if ch(x, y) == "." and f4 <= 1:
					changes.append([x, y, " "])
				elif ch(x, y) == " " and f4 >= 3:
					changes.append([x, y, "."])
		_apply(changes)

# Corridors are designed passages (2-3 tiles wide): erosion must not pinch them shut or
# widen them into rooms. Protects any cell within 1 tile of a narrow floor run.
func _near_corridor(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _is_corridor(x + dx, y + dy):
				return true
	return false

func _is_corridor(x: int, y: int) -> bool:
	if not floorish(x, y):
		return false
	return _run(x, y, Vector2i(1, 0)) <= 3 or _run(x, y, Vector2i(0, 1)) <= 3

func _run(x: int, y: int, d: Vector2i) -> int:
	var n := 1
	var i := 1
	while floorish(x + d.x * i, y + d.y * i) and n < 5:
		n += 1
		i += 1
	i = 1
	while floorish(x - d.x * i, y - d.y * i) and n < 5:
		n += 1
		i += 1
	return n

func _near_special(x: int, y: int) -> bool:
	for dy in [-2, -1, 0, 1, 2]:
		for dx in [-2, -1, 0, 1, 2]:
			if "DGdXPB=R".contains(ch(x + dx, y + dy)):
				return true
	return false

func _floor_neighbours8(x: int, y: int) -> int:
	var count := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and floorish(x + dx, y + dy):
				count += 1
	return count

func _apply(changes: Array) -> void:
	for change in changes:
		var row: String = grid[change[1]]
		grid[change[1]] = row.substr(0, change[0]) + change[2] + row.substr(change[0] + 1)

# --------------------------------------------------------------------------- tiles

func _make_tileset(wall_tex: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	for entry in [[SRC_THEME, wall_tex], [SRC_FG, FG]]:
		var src := TileSetAtlasSource.new()
		src.texture = load(entry[1])
		src.texture_region_size = Vector2i(T, T)
		ts.add_source(src, entry[0])
	return ts

func _put_tile(layer: TileMapLayer, x: int, y: int, source: int, atlas: Vector2i) -> void:
	var src := layer.tile_set.get_source(source) as TileSetAtlasSource
	if not src.has_tile(atlas):
		src.create_tile(atlas)
	layer.set_cell(Vector2i(x, y), source, atlas)

func _pick(options: Array) -> Vector2i:
	return options[rng.randi_range(0, options.size() - 1)]

# Wall autotile rules, learned from how level_1 uses Dungeon_Tileset.
func _wall_tile(x: int, y: int) -> Variant:
	var n := floorish(x, y - 1)
	var s := floorish(x, y + 1)
	var e := floorish(x + 1, y)
	var w := floorish(x - 1, y)
	if s:
		return _pick([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	if n and e and not w:
		return Vector2i(5, 5)
	if n and w and not e:
		return Vector2i(0, 5)
	if n:
		return _pick([Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)])
	if e and not w:
		return _pick([Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	if w and not e:
		return _pick([Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)])
	if e and w:
		return Vector2i(0, 1)
	if floorish(x + 1, y + 1):
		return Vector2i(0, 0)
	if floorish(x - 1, y + 1):
		return Vector2i(5, 0)
	if floorish(x + 1, y - 1):
		return Vector2i(0, 4)
	if floorish(x - 1, y - 1):
		return Vector2i(5, 4)
	return null

func _floor_tile(theme: String, x: int, y: int) -> Array:
	var c := ch(x, y)
	if theme == "skyhold":
		if c == "*":
			return [SRC_FG, Vector2i(27 + posmod(x + y, 3), 4)]
		# Dark castle flagstones, with the occasional cut or patched slab.
		if rng.randf() < 0.85:
			return [SRC_FG, Vector2i(10, 14)]
		return [SRC_FG, _pick([Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14), Vector2i(14, 14), Vector2i(15, 14)])]
	# Caverns: worn stone with a few cracked variants.
	if rng.randf() < 0.75:
		return [SRC_THEME, _pick([Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)])]
	return [SRC_THEME, _pick([Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(0, 6), Vector2i(1, 7), Vector2i(2, 6)])]

func _water_tile(x: int, y: int) -> Vector2i:
	var wn := ch(x, y - 1) == "~"
	var ws := ch(x, y + 1) == "~"
	var we := ch(x + 1, y) == "~"
	var ww := ch(x - 1, y) == "~"
	var tx := 21
	if not ww and we: tx = 20
	elif not we and ww: tx = 22
	var ty := 20
	if not wn and ws: ty = 19
	elif not ws and wn: ty = 21
	return Vector2i(tx, ty)

# --------------------------------------------------------------------------- level

func _build_level(def: Dictionary) -> void:
	_load_layout(def["layout"])
	var theme: String = def["theme"]
	# No erosion: one-tile notches made the wall autotile draw floating ledges. Rooms keep
	# clean edges; the caves get their character from tiles, water and light instead.
	var root := Node2D.new()
	root.name = def["root_name"]

	var ts := _make_tileset(def["wall_tex"])
	var background := _layer("Background", ts, -10)
	var floor_layer := _layer("Floor", ts, -9)
	var water := _layer("Water", ts, -9)
	# FG's water is bright daylight blue; pull it into the level's palette.
	water.modulate = def.get("water_tint", Color.WHITE)
	var walls := _layer("Walls", ts, -8)
	var decor := _layer("Decor", ts, -7)
	var overhead := _layer("Overhead", ts, 6)
	for l in [background, floor_layer, water, walls, decor, overhead]:
		root.add_child(l)

	var groups := {}
	for g in ["Lighting", "Zones", "Props", "Items", "Doors", "Traps", "EnemySpawners", "Bosses"]:
		var n := Node2D.new()
		n.name = g
		root.add_child(n)
		groups[g] = n

	var spawn_pos := Vector2.ZERO
	var exit_pos := Vector2.ZERO
	var face_count := 0
	# Arena bookkeeping: what sits on each cell, resolved into rooms after the pass.
	var room_markers: Array[Vector2i] = []
	var gate_at := {}
	var spawner_at := {}
	var reward_at := {}

	for y in height:
		for x in width:
			var c := ch(x, y)
			if not floorish(x, y):
				_put_tile(background, x, y, SRC_THEME, Vector2i(8, 7))
				var wt = _wall_tile(x, y)
				if wt != null:
					_put_tile(walls, x, y, SRC_THEME, wt)
					# Wall faces get torches and theme ornaments at a steady rhythm.
					if floorish(x, y + 1) and not (ch(x, y + 1) in ["D", "G", "d"]):
						face_count += 1
						_decorate_wall_face(theme, def, x, y, face_count, decor, groups["Lighting"])
				continue
			if c == "~":
				_put_tile(water, x, y, SRC_FG, _water_tile(x, y))
				continue
			var ft := _floor_tile(theme, x, y)
			_put_tile(floor_layer, x, y, ft[0], ft[1])
			_decorate_floor(theme, x, y, decor)

			var pos := cell_center(x, y)
			match c:
				"P": spawn_pos = pos
				"L": _add_ladder(root, pos)
				"i": _add_candle(groups["Lighting"], pos)
				"X": exit_pos = pos
				"B": _add_boss(def, groups["Bosses"], pos)
				"e": spawner_at[Vector2i(x, y)] = _add_spawner(def, groups["EnemySpawners"], pos, "")
				"E": spawner_at[Vector2i(x, y)] = _add_spawner(def, groups["EnemySpawners"], pos, "")
				"R": room_markers.append(Vector2i(x, y))
				"=": gate_at[Vector2i(x, y)] = _add_gate(groups["Doors"], x, y)
				"k": reward_at[Vector2i(x, y)] = _add_reward_chest(groups["Items"], pos, SCN["silver_key"])
				"g": reward_at[Vector2i(x, y)] = _add_reward_chest(groups["Items"], pos, SCN["golden_key"])
				"r": reward_at[Vector2i(x, y)] = _add_reward_chest(groups["Items"], pos, SCN["health"])
				"s": spawner_at[Vector2i(x, y)] = _add_spawner(def, groups["EnemySpawners"], pos, "slime")
				"w": spawner_at[Vector2i(x, y)] = _add_spawner(def, groups["EnemySpawners"], pos, "wisp")
				"O": spawner_at[Vector2i(x, y)] = _add_spawner(def, groups["EnemySpawners"], pos, "orc")
				"c": _add_crystal(groups["Props"], pos, ElementalSystem.Element.CRYO, true)
				"z": _add_crystal(groups["Props"], pos, ElementalSystem.Element.ELECTRO, true)
				"p": _add_pillar(theme, x, y, decor, overhead, groups["Props"])
				"o": _put_tile(decor, x, y, SRC_FG, _pick([Vector2i(24, 8), Vector2i(25, 8), Vector2i(26, 8)]))
				"1": _add_instance(groups["Items"], SCN["silver_key"], pos)
				"2": _add_instance(groups["Items"], SCN["golden_key"], pos)
				"h": _add_instance(groups["Items"], SCN["health"], pos)
				"m": _add_instance(groups["Items"], SCN["mana"], pos)
				"$": _add_instance(groups["Items"], SCN["coin"], pos)
				"C": _add_chest(groups["Items"], pos)
				"T": _add_transmuter(groups["Props"], pos)
				"Y": _add_sealed_chest(def, groups["Items"], pos)
				"x": _add_instance(groups["Traps"], SCN["spikes"], pos)
				"D": _add_door(groups["Doors"], x, y, Door.KeyType.SILVER, "")
				"G": _add_door(groups["Doors"], x, y, Door.KeyType.GOLDEN, "")
				"d": _add_door(groups["Doors"], x, y, Door.KeyType.NONE, def["boss_name"])

	root.add_child(_build_collision())
	_add_zones(groups["Zones"])
	var arenas := Node2D.new()
	arenas.name = "Arenas"
	root.add_child(arenas)
	var room_names: Array = def.get("room_names", [])
	for i in room_markers.size():
		_add_arena(arenas, room_markers[i], gate_at, spawner_at, reward_at, room_names[i] if i < room_names.size() else "AMBUSH!")

	if def.get("fragment", false):
		var entry := Marker2D.new()
		entry.name = "Entry"
		entry.position = spawn_pos
		root.add_child(entry)
		_save(root, def["out"])
		return

	var spawner := Node2D.new()
	spawner.name = "Spawner"
	spawner.set_script(load(SCN["player_spawner"]))
	var marker := Marker2D.new()
	marker.name = "PlayerSpawn"
	marker.position = spawn_pos
	spawner.add_child(marker)
	root.add_child(spawner)

	if exit_pos != Vector2.ZERO:
		var exit := Node2D.new()
		exit.name = "ExitPortal"
		exit.set_script(load("res://scripts/world/level_exit.gd"))
		exit.position = exit_pos + Vector2(0, 8)
		exit.boss_to_track = def["boss_name"]
		exit.unlocks_level = def["unlocks"]
		exit.glow_color = def["exit_glow"]
		root.add_child(exit)

	var amb := Node2D.new()
	amb.name = "Ambience"
	amb.set_script(load("res://scripts/levels/level_ambience.gd"))
	amb.level_title = def["title"]
	amb.level_subtitle = def["subtitle"]
	amb.music_path = def["music"]
	amb.darkness = def["darkness"]
	amb.player_light_color = def["player_light"]
	amb.mote_color = def["motes"]
	amb.mote_gravity = def["mote_gravity"]
	root.add_child(amb)

	var hud: Node = load(SCN["hud"]).instantiate()
	hud.name = "HUD"
	root.add_child(hud)

	_save(root, def["out"])

func _layer(layer_name: String, ts: TileSet, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = ts
	l.z_index = z
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l

var _torch_sf: SpriteFrames

func _torch_frames() -> SpriteFrames:
	if _torch_sf:
		return _torch_sf
	_torch_sf = SpriteFrames.new()
	_torch_sf.set_animation_speed("default", 5.0)
	for i in range(1, 5):
		_torch_sf.add_frame("default", load("res://assets/tilesets/items and trap_animation/torch/torch_%d.png" % i))
	return _torch_sf

func _decorate_wall_face(theme: String, def: Dictionary, x: int, y: int, count: int, decor: TileMapLayer, lighting: Node2D) -> void:
	var slot := count % 7
	if slot == 0:
		var torch := AnimatedSprite2D.new()
		# The real 4-frame torch animation (same as level_1): only the flame moves.
		# Tiles (0,9)/(1,9) of the wall tileset are two different torches, not frames.
		torch.sprite_frames = _torch_frames()
		torch.autoplay = "default"
		torch.frame = rng.randi_range(0, 3)
		torch.frame_progress = rng.randf()
		torch.position = cell_center(x, y)
		torch.z_index = -6
		var light := PointLight2D.new()
		light.texture = _light_tex()
		light.color = def["torch_light"]
		light.energy = 1.1
		light.texture_scale = 1.6
		light.position = Vector2(0, 6)
		torch.add_child(light)
		lighting.add_child(torch)
	# (Banners and hanging shields were full 16 px tiles: far too big next to the heroes.)

func _decorate_floor(theme: String, x: int, y: int, decor: TileMapLayer) -> void:
	if ch(x, y) != ".":
		return
	var wall_n := not floorish(x, y - 1)
	if wall_n and not floorish(x - 1, y) and not floorish(x - 1, y - 1) and rng.randf() < 0.18:
		_put_tile(decor, x, y, SRC_THEME, Vector2i(4, 6))
		return
	if wall_n and not floorish(x + 1, y) and not floorish(x + 1, y - 1) and rng.randf() < 0.18:
		_put_tile(decor, x, y, SRC_THEME, Vector2i(5, 6))
		return
	var r := rng.randf()
	if theme in ["caverns", "crypt"]:
		var k := 2.5 if theme == "crypt" else 1.0 # the crypt is littered with bones
		if r < 0.025 * k: _put_tile(decor, x, y, SRC_THEME, Vector2i(8, 6))
		elif r < 0.035 * k: _put_tile(decor, x, y, SRC_THEME, Vector2i(7, 7))
	# (Skyhold used to scatter loose rocks here: decor without collision that read as
	# obstacles. Removed.)

func _add_pillar(theme: String, x: int, y: int, decor: TileMapLayer, overhead: TileMapLayer, props: Node2D) -> void:
	# Solid arcane crystal pillars: they block movement and shots, and match the theme's
	# elements (the old three-tile stone column looked thin and floaty).
	var els := [ElementalSystem.Element.HYDRO, ElementalSystem.Element.CRYO] if theme == "caverns" else [ElementalSystem.Element.ANEMO, ElementalSystem.Element.ELECTRO]
	var crystal := _add_crystal(props, cell_center(x, y), els[(x + y) % 2], false)
	crystal.crystal_scale = 1.3

func _add_crystal(parent: Node2D, pos: Vector2, element: ElementalSystem.Element, pulses: bool) -> Node2D:
	var crystal := StaticBody2D.new()
	crystal.name = "Crystal"
	crystal.set_script(load("res://scripts/world/arcane_crystal.gd"))
	crystal.position = pos
	crystal.element = element
	crystal.pulses = pulses
	parent.add_child(crystal, true)
	return crystal

func _add_spawner(def: Dictionary, parent: Node2D, pos: Vector2, kind: String) -> Node2D:
	var m := Marker2D.new()
	m.name = "Spawner"
	m.set_script(load(SCN["spawner"]))
	m.position = pos
	if kind == "":
		var pool: Array[PackedScene] = []
		for k in def["pool"]:
			pool.append(load(SCN[k]))
		m.random_pool = pool
	else:
		m.enemy_scene = load(SCN[kind])
	var elements: Array[ElementalSystem.Element] = []
	elements.assign(def["elements"])
	m.element_pool = elements
	parent.add_child(m, true)
	return m

func _add_gate(parent: Node2D, x: int, y: int) -> Node2D:
	var door: Node2D = load(SCN["door"]).instantiate()
	door.name = "Gate"
	door.position = cell_center(x, y)
	if floorish(x - 1, y) and floorish(x + 1, y) and ch(x - 1, y) != "=" and ch(x + 1, y) != "=":
		door.rotation = PI / 2.0
	door.required_key = Door.KeyType.NONE
	door.is_open = true
	door.gate_style = true
	parent.add_child(door, true)
	return door

# A chest that stays hidden until its arena is cleared, holding a specific item.
func _add_reward_chest(parent: Node2D, pos: Vector2, item_scene: String) -> Node2D:
	var chest := _add_instance(parent, SCN["chest"], pos)
	chest.name = "RewardChest"
	chest.set_script(load(SCN["chest_script"]))
	chest.coins_amount = rng.randi_range(4, 8)
	var item := _add_instance(parent, item_scene, pos)
	chest.hidden_item = item
	return chest

# The room is every floor cell reachable from the 'R' marker without crossing a gate or a
# door. Spawners inside become its waves ('E' = second wave); its gates are the '=' cells
# touching it.
func _add_arena(parent: Node2D, marker: Vector2i, gate_at: Dictionary, spawner_at: Dictionary, reward_at: Dictionary, title: String) -> void:
	var room := Node2D.new()
	room.name = "Arena"
	room.set_script(load("res://scripts/world/arena_room.gd"))
	room.room_name = title
	var seen := {marker: true}
	var queue: Array[Vector2i] = [marker]
	var gates: Array[Node2D] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not floorish(n.x, n.y):
				continue
			if gate_at.has(n):
				if not gates.has(gate_at[n]):
					gates.append(gate_at[n])
				continue
			if "DGd".contains(ch(n.x, n.y)):
				continue
			seen[n] = true
			queue.append(n)
	var cells: Array[Vector2i] = []
	var w1: Array[Node2D] = []
	var w2: Array[Node2D] = []
	for c in seen:
		cells.append(c)
		if spawner_at.has(c):
			var sp: Node2D = spawner_at[c]
			sp.spawn_on_ready = false
			if ch(c.x, c.y) == "E":
				w2.append(sp)
			else:
				w1.append(sp)
		if reward_at.has(c):
			room.reward = reward_at[c]
	# The reward appears where nobody can miss it: the middle of the room (the 'R' mark),
	# and every arena also pays out a health potion.
	if room.reward:
		room.reward.position = cell_center(marker.x, marker.y)
		if room.reward.hidden_item:
			room.reward.hidden_item.position = room.reward.position
		var bonus: Array[String] = [SCN["health"]]
		room.reward.bonus_items = bonus
	room.cells = cells
	room.gates = gates
	room.wave1 = w1
	room.wave2 = w2
	parent.add_child(room, true)
	print("  arena '%s': %d cells, %d gates, waves %d+%d, reward %s" % [title, cells.size(), gates.size(), w1.size(), w2.size(), room.reward != null])

func _add_boss(def: Dictionary, parent: Node2D, pos: Vector2) -> void:
	var boss: Node2D = load(SCN[def["boss"]]).instantiate()
	boss.name = def["boss_name"]
	if def.has("boss_script"):
		boss.set_script(load(def["boss_script"]))
	boss.position = pos
	parent.add_child(boss)

func _add_instance(parent: Node2D, path: String, pos: Vector2) -> Node:
	var n: Node2D = load(path).instantiate()
	n.position = pos
	parent.add_child(n, true)
	return n

func _add_ladder(parent: Node2D, pos: Vector2) -> void:
	var ladder := Sprite2D.new()
	ladder.name = "Ladder"
	ladder.texture = load("res://assets/tilesets/character and tileset/Dungeon_Tileset.png")
	ladder.region_enabled = true
	ladder.region_rect = Rect2(144.6, 47.5, 14.65, 17.73) # same stairs art as level_1
	ladder.position = pos
	ladder.z_index = -5
	parent.add_child(ladder)

var _candle_sf: SpriteFrames

func _add_candle(parent: Node2D, pos: Vector2) -> void:
	if not _candle_sf:
		_candle_sf = SpriteFrames.new()
		_candle_sf.set_animation_speed("default", 6.0)
		for i in range(1, 5):
			_candle_sf.add_frame("default", load("res://assets/tilesets/items and trap_animation/torch/candlestick_1_%d.png" % i))
	var c := AnimatedSprite2D.new()
	c.sprite_frames = _candle_sf
	c.autoplay = "default"
	c.frame = rng.randi_range(0, 3)
	c.scale = Vector2(0.55, 0.55)
	c.position = pos + Vector2(0, 3)
	var light := PointLight2D.new()
	light.texture = _light_tex()
	light.color = Color(1.0, 0.7, 0.4)
	light.energy = 0.9
	light.texture_scale = 0.9
	light.position = Vector2(0, -10)
	c.add_child(light)
	parent.add_child(c)

func _add_transmuter(parent: Node2D, pos: Vector2) -> void:
	var t := StaticBody2D.new()
	t.name = "Transmuter"
	t.set_script(load("res://scripts/world/transmuter.gd"))
	t.position = pos
	parent.add_child(t, true)

func _add_sealed_chest(def: Dictionary, parent: Node2D, pos: Vector2) -> void:
	var chest := _add_instance(parent, SCN["chest"], pos)
	chest.name = "SealedChest"
	chest.set_script(load(SCN["chest_script"]))
	chest.coin_cost = def.get("sealed_cost", 25)
	chest.coins_amount = 0

func _add_chest(parent: Node2D, pos: Vector2) -> void:
	var chest := _add_instance(parent, SCN["chest"], pos)
	chest.set_script(load(SCN["chest_script"]))
	chest.coins_amount = rng.randi_range(6, 12)

func _add_door(parent: Node2D, x: int, y: int, key: Door.KeyType, boss: String) -> void:
	var door: Node2D = load(SCN["door"]).instantiate()
	door.position = cell_center(x, y)
	# Doors are drawn for horizontal walls; turn them when the wall runs vertically.
	if floorish(x - 1, y) and floorish(x + 1, y):
		door.rotation = PI / 2.0
	door.required_key = key
	if boss != "":
		door.boss_to_track = boss
		door.lock_after_pass = true
	parent.add_child(door, true)

# Merge solid cells that touch walkable space into horizontal strips of collision.
func _build_collision() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "WallCollision"
	body.collision_layer = 1
	for y in height:
		var x := 0
		while x < width:
			if not _blocks(x, y):
				x += 1
				continue
			var start := x
			while x < width and _blocks(x, y):
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((x - start) * T, T)
			shape.shape = rect
			shape.position = Vector2(start * T + rect.size.x / 2.0, y * T + T / 2.0)
			body.add_child(shape)
	return body

func _blocks(x: int, y: int) -> bool:
	if not solid(x, y):
		return false
	if floorish(x, y):
		return true
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if floorish(x + dx, y + dy):
				return true
	return false

# Merge zone cells into as few rectangles as possible (rows first, then grow downwards).
func _add_zones(parent: Node2D) -> void:
	var used := {}
	for y in height:
		for x in width:
			var c := terrain(x, y)
			if used.has(Vector2i(x, y)) or (c != "," and not WIND.has(c)):
				continue
			var x1 := x
			while x1 + 1 < width and terrain(x1 + 1, y) == c and not used.has(Vector2i(x1 + 1, y)):
				x1 += 1
			var y1 := y
			while y1 + 1 < height:
				var full := true
				for xi in range(x, x1 + 1):
					if terrain(xi, y1 + 1) != c or used.has(Vector2i(xi, y1 + 1)):
						full = false
						break
				if not full:
					break
				y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					used[Vector2i(xx, yy)] = true
			var zone := Area2D.new()
			zone.name = "Water" if c == "," else "Wind"
			zone.set_script(load("res://scripts/world/element_zone.gd"))
			zone.position = Vector2(x * T, y * T)
			zone.size = Vector2((x1 - x + 1) * T, (y1 - y + 1) * T)
			if c == ",":
				zone.style = ElementZone.Style.WATER
				zone.element = ElementalSystem.Element.HYDRO
				zone.speed_mult = 0.7
			else:
				zone.style = ElementZone.Style.WIND
				zone.element = ElementalSystem.Element.ANEMO
				zone.push = WIND[c] * 45.0
			parent.add_child(zone, true)

func _light_tex() -> GradientTexture2D:
	return LevelAmbience.light_texture()

func _save(root: Node, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed for %s: %s" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	print("saved ", path, " (", width, "x", height, ") err=", err)
	root.free()

func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		# Children of instanced scenes belong to their own scene file.
		if child.scene_file_path == "":
			_own(child, owner_node)

# --------------------------------------------------------------------------- enemy scenes

func _build_enemy_scenes() -> void:
	_save_enemy("Orc", "res://scripts/entities/enemies/orc.gd", _orc_frames(), Vector2.ZERO, 1.0, 5.0, 12.0, Vector2(0, 3), SCN["orc"])
	_save_enemy("Wisp", "res://scripts/entities/enemies/wisp.gd", Wisp._build_frames(ElementalSystem.Element.PYRO), Vector2.ZERO, 1.0, 5.0, 10.0, Vector2(0, 5), SCN["wisp"])
	var guardian_src: Node = load("res://scenes/entities/Enemies/Guardian.tscn").instantiate()
	var frames: SpriteFrames = guardian_src.get_node("AnimatedSprite2D").sprite_frames.duplicate(true)
	guardian_src.free()
	_save_enemy("Guardian", "res://scripts/entities/enemies/guardian.gd", frames, Vector2.ZERO, 0.55, 9.0, 26.0, Vector2(0, 14), SCN["guardian"])

func _save_enemy(enemy_name: String, script_path: String, frames: SpriteFrames, offset: Vector2, sprite_scale: float, radius: float, height_px: float, shape_pos: Vector2, out: String) -> void:
	var body := CharacterBody2D.new()
	body.name = enemy_name
	body.collision_layer = 4
	body.collision_mask = 5
	body.set_script(load(script_path))
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.offset = offset
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var cap := CapsuleShape2D.new()
	cap.radius = radius
	cap.height = height_px
	col.shape = cap
	col.position = shape_pos
	body.add_child(col)
	_save(body, out)

func _orc_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var dir := "res://assets/sprites/enemies/Orc/"
	for entry in [["idle", "Orc-Idle.png", 6, 8.0, true], ["walk", "Orc-Walk.png", 8, 10.0, true],
			["attack", "Orc-Attack01.png", 6, 12.0, false], ["attack2", "Orc-Attack02.png", 6, 9.0, false],
			["hurt", "Orc-Hurt.png", 4, 12.0, false], ["death", "Orc-Death.png", 4, 8.0, false]]:
		var tex: Texture2D = load(dir + entry[1])
		sf.add_animation(entry[0])
		sf.set_animation_speed(entry[0], entry[3])
		sf.set_animation_loop(entry[0], entry[4])
		for i in entry[2]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 100, 0, 100, 100)
			sf.add_frame(entry[0], at)
	return sf
