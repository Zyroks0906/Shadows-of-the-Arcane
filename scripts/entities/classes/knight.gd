extends Player
class_name Knight

func _init() -> void:
	character_name = "Knight"
	base_element = ElementalSystem.Element.NONE
	max_health = 130
	max_mana = 40
	strength = 14
	intelligence = 6
	resistance = 15
	wisdom = 7
	speed = 180.0
	base_scale = Vector2(0.4, 0.4)
