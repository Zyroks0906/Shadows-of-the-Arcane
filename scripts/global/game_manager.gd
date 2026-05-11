extends Node

enum CharacterClass { ARCHER, KNIGHT, WARRIOR, NECROMANCER, ASSASSIN, MAGE, CLERIC, BARBARIAN }

signal coins_changed(new_amount)
signal keys_changed(new_amount)

var selected_class: CharacterClass = CharacterClass.ARCHER
var total_coins: int = 0:
	set(value):
		total_coins = value
		coins_changed.emit(total_coins)

var total_keys: int = 0:
	set(value):
		total_keys = value
		keys_changed.emit(total_keys)

func add_coins(amount: int) -> void:
	total_coins += amount

func add_keys(amount: int) -> void:
	total_keys += amount

func set_selected_class(c_class: CharacterClass) -> void:
	selected_class = c_class

func get_selected_class_name() -> String:
	match selected_class:
		CharacterClass.ARCHER: return "archer"
		CharacterClass.KNIGHT: return "knight"
		CharacterClass.WARRIOR: return "warrior"
		CharacterClass.NECROMANCER: return "necromancer"
		CharacterClass.ASSASSIN: return "samurai"
		CharacterClass.MAGE: return "mage"
		CharacterClass.CLERIC: return "cleric"
		CharacterClass.BARBARIAN: return "gladiator"
	return "unknown"
