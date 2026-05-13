extends Enemy

func _init_stats() -> void:
	max_health = 45
	resistance = 2
	character_name = "Rat"

	speed = 65.0
	attack_range = 22.0
	attack_damage = 8
	attack_cooldown = 0.8
	attack_delay = 0.3
	detection_range = 160.0
