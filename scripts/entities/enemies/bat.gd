extends Enemy

func _init_stats() -> void:
	shadow_hover = 9.0
	max_health = 24
	resistance = 0
	character_name = "Bat"

	body_scale = 0.42
	speed = 66.0
	attack_range = 10.0
	attack_reach = 13.0
	attack_damage = 6
	attack_cooldown = 1.0
	attack_delay = 0.28
	detection_range = 180.0

func _ready() -> void:
	super._ready()
	if animated_sprite:
		animated_sprite.play("idle")
