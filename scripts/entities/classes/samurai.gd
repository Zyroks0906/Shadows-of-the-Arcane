extends Player
class_name Samurai

func _init() -> void:
	character_name = "Assassin (Samurai)"
	base_element = ElementalSystem.Element.HYDRO
	max_health = 95
	max_mana = 55
	strength = 15
	intelligence = 9
	resistance = 8
	wisdom = 10
	speed = 160.0
	base_scale = Vector2(0.4, 0.4)
	sprite_offset = Vector2(0, -15)
