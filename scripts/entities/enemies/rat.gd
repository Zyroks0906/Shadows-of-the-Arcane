extends Enemy

func _init_stats() -> void:
	max_health = 30
	resistance = 1
	character_name = "Rat"

	body_scale = 0.36
	speed = 52.0
	attack_range = 10.0
	attack_reach = 13.0
	attack_damage = 8
	attack_cooldown = 0.8
	attack_delay = 0.3
	detection_range = 160.0
