extends Player
class_name Assassin

func _init() -> void:
	character_name = "Assassin"
	base_element = ElementalSystem.Element.NONE
	max_health = 100
	max_mana = 60
	strength = 14
	intelligence = 10
	resistance = 7
	wisdom = 12
	speed = 80.0
	base_scale = Vector2(0.4, 0.4)
