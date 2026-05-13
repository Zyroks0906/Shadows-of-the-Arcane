extends Enemy

func _init_stats() -> void:
	max_health = 35
	resistance = 1
	character_name = "Bat"

	speed = 85.0
	attack_range = 25.0
	attack_damage = 6
	attack_cooldown = 1.0
	attack_delay = 0.2
	detection_range = 180.0

func _ready() -> void:
	super._ready()
	if animated_sprite:
		animated_sprite.play("idle")
