extends Enemy

# Sturdy melee bruiser. Every third swing is a telegraphed heavy cleave that hits
# harder and shoves the player back, so it rewards dodging instead of face-tanking.

var _swings: int = 0

func _init_stats() -> void:
	max_health = 110
	resistance = 5
	character_name = "Orc"
	speed = 32.0
	body_scale = 1.1
	attack_range = 18.0
	attack_reach = 22.0
	attack_arc_deg = 120.0
	attack_damage = 14
	attack_cooldown = 1.1
	attack_delay = 0.5
	detection_range = 170.0
	knockback_scale = 0.6

func _perform_attack() -> void:
	_swings += 1
	var heavy := _swings % 3 == 0
	if heavy:
		await _melee_attack(0.75, int(attack_damage * 1.8), 300.0, "attack2", true)
	else:
		await _melee_attack(attack_delay, attack_damage, attack_knockback, "attack")
	if not is_alive: return
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true
