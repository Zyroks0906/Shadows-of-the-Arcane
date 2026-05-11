extends Player
class_name Gladiator

func _init() -> void:
	character_name = "Barbarian"
	base_element = ElementalSystem.Element.NONE
	max_health = 150
	max_mana = 30
	strength = 18
	intelligence = 4
	resistance = 12
	wisdom = 5
	speed = 170.0
	base_scale = Vector2(0.15, 0.15)
	sprite_offset = Vector2(0, -25)
