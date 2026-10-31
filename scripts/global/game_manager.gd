extends Node

enum CharacterClass { ARCHER, KNIGHT, WARRIOR, NECROMANCER, ASSASSIN, SAMURAI, MAGE, CLERIC, BARBARIAN }

signal coins_changed(new_amount)
signal keys_changed(new_amount)
signal silver_keys_changed(new_amount)
signal golden_keys_changed(new_amount)
signal health_potions_changed(new_amount)
signal mana_potions_changed(new_amount)
signal boss_defeated(boss_name)

var selected_class: CharacterClass = CharacterClass.ARCHER
# The three levels in order. Each has up to MAX_VARIANTS layouts: the base scene
# (level_N.tscn) and the generated ones beside it (level_N_s2.tscn ... level_N_s5.tscn, built
# from tools/levels by the level builder). A run draws one variant per level from its seed;
# current_map is set when a level spawns the player.
const MAPS := ["res://scenes/levels/level_1.tscn", "res://scenes/levels/level_2.tscn", "res://scenes/levels/level_3.tscn"]
const MAX_VARIANTS := 5
var current_map: String = ""
var run_seed: int = 0
var run_maps: Array = []      # the variant chosen for each level this run

# Every layout that exists for a level (0-based), the base scene first.
func variants(level: int) -> Array:
	var out := [MAPS[level]]
	for k in range(2, MAX_VARIANTS + 1):
		var p: String = MAPS[level].replace(".tscn", "_s%d.tscn" % k)
		if ResourceLoader.exists(p):
			out.append(p)
	return out

# Which level (0-based) a scene is a layout of, or -1.
func level_index(path: String) -> int:
	for i in MAPS.size():
		if path == MAPS[i] or path.begins_with(MAPS[i].replace(".tscn", "_s")):
			return i
	return -1

# A new run: a seed (given, to replay or share one, or rolled) and a layout per level drawn
# from it. Any layout of map 1 can open a run: the tutorial stones stand in every one.
func start_run(seed: int = 0) -> void:
	run_seed = seed if seed > 0 else randi_range(100000, 999999)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	run_maps = []
	for i in MAPS.size():
		var v := variants(i)
		run_maps.append(v[rng.randi_range(0, v.size() - 1)])

func map_for(level: int) -> String:
	if run_maps.size() != MAPS.size():
		start_run()
	return run_maps[clampi(level, 0, MAPS.size() - 1)]

# "Variant 3 of 5" for the current level, for the pause and victory screens.
func variant_text() -> String:
	var i := level_index(current_map)
	if i < 0:
		return ""
	var v := variants(i)
	return "Seed %d  -  layout %d/%d" % [run_seed, v.find(current_map) + 1, v.size()]

func next_map() -> String:
	var i := level_index(current_map)
	return map_for(i + 1) if i >= 0 and i + 1 < MAPS.size() else ""
var debug_mode: bool = false:
	set(value):
		debug_mode = value
		for node in get_tree().get_nodes_in_group("base_character"):
			if node.has_method("queue_redraw"):
				node.queue_redraw()
var total_coins: int = 0:
	set(value):
		total_coins = value
		coins_changed.emit(total_coins)

var total_keys: int = 0:
	set(value):
		total_keys = value
		keys_changed.emit(total_keys)

var silver_keys: int = 0:
	set(value):
		silver_keys = value
		silver_keys_changed.emit(silver_keys)

var golden_keys: int = 0:
	set(value):
		golden_keys = value
		golden_keys_changed.emit(golden_keys)

var health_potions: int = 0:
	set(value):
		health_potions = value
		health_potions_changed.emit(health_potions)

var mana_potions: int = 0:
	set(value):
		mana_potions = value
		mana_potions_changed.emit(mana_potions)

func add_coins(amount: int) -> void:
	total_coins += amount

func add_keys(amount: int) -> void:
	total_keys += amount

func add_silver_key(amount: int) -> void:
	silver_keys += amount

func add_golden_key(amount: int) -> void:
	golden_keys += amount

func add_health_potion(amount: int) -> void:
	health_potions += amount

func add_mana_potion(amount: int) -> void:
	mana_potions += amount

func use_health_potion() -> bool:
	if health_potions > 0:
		health_potions -= 1
		return true
	return false

func use_mana_potion() -> bool:
	if mana_potions > 0:
		mana_potions -= 1
		return true
	return false

func reset_progress() -> void:
	total_keys = 0
	silver_keys = 0
	golden_keys = 0
	health_potions = 0
	mana_potions = 0

# The bag (coins, keys, potions) is kept from one level to the next with NEXT LEVEL only.
# A new run (picking a character) starts empty; dying rolls back to how it was when the
# level began.
var _bag_snapshot: Dictionary = {}

func reset_run() -> void:
	reset_progress()
	run_maps = [] # the next run draws its own layouts
	total_coins = 0
	_bag_snapshot.clear()

func snapshot_bag() -> void:
	_bag_snapshot = {"coins": total_coins, "health": health_potions, "mana": mana_potions}

func restore_bag() -> void:
	reset_progress() # keys belong to the level: they never carry over
	if _bag_snapshot.is_empty():
		return
	total_coins = _bag_snapshot["coins"]
	health_potions = _bag_snapshot["health"]
	mana_potions = _bag_snapshot["mana"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_mode = !debug_mode
		print("Debug Mode: ", debug_mode)

# Development shortcut: `Godot --path . res://scenes/levels/level_3.tscn -- class=barbarian`
# starts a level directly with that class.
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("class="):
			var want := arg.substr(6).to_upper()
			if want == "GLADIATOR":
				want = "BARBARIAN"
			if CharacterClass.has(want):
				selected_class = CharacterClass[want]
		elif arg.begins_with("map="):
			current_map = map_for(int(arg.substr(4)) - 1)

func set_selected_class(c_class: CharacterClass) -> void:
	selected_class = c_class

func get_selected_class_name() -> String:
	match selected_class:
		CharacterClass.ARCHER: return "archer"
		CharacterClass.KNIGHT: return "knight"
		CharacterClass.WARRIOR: return "warrior"
		CharacterClass.NECROMANCER: return "necromancer"
		CharacterClass.ASSASSIN: return "assassin"
		CharacterClass.SAMURAI: return "samurai"
		CharacterClass.MAGE: return "mage"
		CharacterClass.CLERIC: return "cleric"
		CharacterClass.BARBARIAN: return "gladiator"
	return "unknown"

func notify_boss_defeat(boss_name: String) -> void:
	boss_defeated.emit(boss_name)
