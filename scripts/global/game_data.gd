extends Node

const SAVE_PATH = "user://savegame.cfg"

var unlocked_levels = 1
var current_level_path = "res://scenes/levels/Map_1.tscn"

func _ready():
	load_game()

func save_game():
	var config = ConfigFile.new()
	config.set_value("progression", "unlocked_levels", unlocked_levels)
	config.save(SAVE_PATH)

func load_game():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		unlocked_levels = config.get_value("progression", "unlocked_levels", 1)

func unlock_level(level_index: int):
	if level_index > unlocked_levels:
		unlocked_levels = level_index
		save_game()

func reset_progress():
	unlocked_levels = 1
	save_game()
