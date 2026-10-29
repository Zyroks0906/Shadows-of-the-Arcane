extends Node

const SAVE_PATH = "user://savegame.cfg"

# Levels are unlocked per character: beating level 1 with the Mage opens level 2 for the
# Mage only. Nobody can skip ahead with a fresh, unlevelled character.
var _unlocked_by_class: Dictionary = {} # class id (as text) -> highest unlocked level
var unlocked_levels: int:
	get:
		return int(_unlocked_by_class.get(_cls(), 1))
var current_level_path = "res://scenes/levels/level_1.tscn"

func _cls() -> String:
	return str(GameManager.selected_class)

func _ready():
	load_game()

func save_game():
	var config = ConfigFile.new()
	config.set_value("progression", "unlocked_by_class", _unlocked_by_class)
	config.save(SAVE_PATH)

func load_game():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		var d = config.get_value("progression", "unlocked_by_class", {})
		_unlocked_by_class = d if d is Dictionary else {}

func unlock_level(level_index: int):
	if level_index > unlocked_levels:
		_unlocked_by_class[_cls()] = level_index
		save_game()

func reset_progress():
	_unlocked_by_class.clear()
	save_game()
