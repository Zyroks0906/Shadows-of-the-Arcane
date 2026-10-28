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
# The three maps in order; current_map is set when a level spawns the player.
const MAPS := ["res://scenes/levels/level_1.tscn", "res://scenes/levels/level_2.tscn", "res://scenes/levels/level_3.tscn"]
var current_map: String = ""

func next_map() -> String:
	var i := MAPS.find(current_map)
	return MAPS[i + 1] if i >= 0 and i + 1 < MAPS.size() else ""
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
			current_map = MAPS[clampi(int(arg.substr(4)) - 1, 0, MAPS.size() - 1)]

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
