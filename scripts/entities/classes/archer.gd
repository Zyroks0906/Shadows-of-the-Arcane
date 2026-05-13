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
	speed = 130.0
	base_scale = Vector2(0.4, 0.4)

func attack() -> void:
	if not _can_attack: return
	_can_attack = false

	if _play_animation("Attack", AnimPriority.ACTION):
		is_attacking = true

	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Weapons/sword_slice.wav", 1.0, 1.2)

	var arrow_scene = load("res://scenes/Proyectiles/arrow.tscn")
	if not arrow_scene:
		print("Error: No se encuentra la escena de la flecha")
	else:
		var arrow = arrow_scene.instantiate()
		if arrow.get_script() == null:
			arrow.set_script(load("res://scripts/entities/projectile.gd"))

		var shoot_dir = last_direction.normalized()
		if shoot_dir == Vector2.ZERO:
			shoot_dir = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT

		arrow.damage = strength
		arrow.element = base_element
		arrow.direction = shoot_dir

		get_parent().add_child(arrow)

		var offset = shoot_dir * 15
		arrow.global_position = global_position + offset
		arrow.rotation = shoot_dir.angle()

		print("Arquero dispara flecha hacia: ", shoot_dir, " Elemento: ", ElementalSystem.get_element_name(base_element))

	var t = get_tree()
	if t:
		await t.create_timer(attack_lock_time).timeout
		_can_attack = true
