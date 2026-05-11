extends Player
class_name Warrior

func _init() -> void:
	character_name = "Warrior"
	base_element = ElementalSystem.Element.NONE
	max_health = 115
	max_mana = 45
	strength = 16
	intelligence = 7
	resistance = 10
	wisdom = 8
	speed = 200.0
	base_scale = Vector2(0.7, 0.7)
