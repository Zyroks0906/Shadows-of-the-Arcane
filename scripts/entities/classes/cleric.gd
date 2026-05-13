extends Player

func _init_stats() -> void:
	character_name = "Cleric"
	max_health = 110
	max_mana = 100
	strength = 8
	intelligence = 10
	resistance = 8
	wisdom = 12
	speed = 85.0
	base_scale = Vector2(0.35, 0.35)

func attack() -> void:
	if not can_attack or is_attacking: return
	is_attacking = true
	can_attack = false
	_play_animation("Attack")
	var t = get_tree()
	if t: await t.create_timer(0.3).timeout
	_check_hit(attack_damage, 35.0)
	t = get_tree()
	if t: await t.create_timer(0.2).timeout
	is_attacking = false
	can_attack = true

func special_attack() -> void:
	if not can_attack or is_attacking: return
	if use_mana(25):
		is_attacking = true
		can_attack = false
		_play_animation("Attack2")
		mostrar_texto_flotante("HEAL", Color.GREEN)
		recover_health(20)
		var t = get_tree()
		if t: await t.create_timer(0.5).timeout
		is_attacking = false
		can_attack = true
