extends Player
class_name Mage

func _init() -> void:
	character_name = "Mage"
	base_element = ElementalSystem.Element.CRYO
	max_health = 80
	max_mana = 100
	strength = 6
	intelligence = 18
	resistance = 5
	wisdom = 14
	speed = 135.0
	base_scale = Vector2(0.17, 0.17)
	sprite_offset = Vector2(8, -5)
