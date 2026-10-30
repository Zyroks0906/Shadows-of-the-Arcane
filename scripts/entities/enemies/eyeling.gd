extends SheetEnemy
class_name Eyeling

# A flying eye let loose by an Evil Wizard: small, quick and frail, it comes in pairs and
# bites (LuizMelo's Flying Eye).

func _init_stats() -> void:
	folder = "FlyingEye"
	body_px = 11.0
	art_px = 31.0
	sheets = {
		"idle": ["Flight", 12.0, true], "walk": ["Flight", 14.0, true], "attack": ["Attack", 14.0, false],
		"hurt": ["TakeHit", 12.0, false], "death": ["Death", 9.0, false],
	}
	shadow_hover = 6.0
	max_health = 14
	resistance = 0
	character_name = "Flying Eye"
	speed = 46.0
	attack_range = 12.0
	attack_reach = 16.0
	attack_damage = 6
	attack_delay = 0.4
	attack_cooldown = 1.0
	detection_range = 220.0
	knockback_scale = 1.3

func xp_value() -> int:
	return 1
