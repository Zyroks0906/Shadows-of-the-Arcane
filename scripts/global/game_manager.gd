extends Node

enum CharacterClass { ARCHER, KNIGHT, WARRIOR, NECROMANCER, ASSASSIN, SAMURAI, MAGE, CLERIC, BARBARIAN }

signal coins_changed(new_amount)
signal keys_changed(new_amount)
signal silver_keys_changed(new_amount)
signal golden_keys_changed(new_amount)
signal health_potions_changed(new_amount)
signal mana_potions_changed(new_amount)

var selected_class: CharacterClass = CharacterClass.ARCHER
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
