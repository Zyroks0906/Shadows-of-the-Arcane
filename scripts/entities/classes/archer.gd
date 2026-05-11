extends Player
class_name Archer

func _init() -> void:
	character_name = "Archer"
	base_element = ElementalSystem.Element.ANEMO
	max_health = 90
	max_mana = 60
	strength = 12
	intelligence = 10
	resistance = 7
	wisdom = 9
	speed = 220.0
	base_scale = Vector2(0.8, 0.8)
