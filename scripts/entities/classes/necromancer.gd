extends Player
class_name Necromancer

func _init() -> void:
	character_name = "Necromancer"
	base_element = ElementalSystem.Element.PYRO
	max_health = 85
	max_mana = 80
	strength = 8
	intelligence = 16
	resistance = 6
	wisdom = 12
	speed = 190.0
	base_scale = Vector2(0.25, 0.25)
	sprite_offset = Vector2(0, -15)
