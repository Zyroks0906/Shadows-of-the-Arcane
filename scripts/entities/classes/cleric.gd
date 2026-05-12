extends Player
class_name Cleric

func _init() -> void:
	character_name = "Cleric"
	base_element = ElementalSystem.Element.ELECTRO
	max_health = 110
	max_mana = 70
	strength = 9
	intelligence = 11
	resistance = 9
	wisdom = 16
	speed = 140.0
	base_scale = Vector2(0.09, 0.09)
