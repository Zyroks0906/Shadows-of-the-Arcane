extends BossBase

@onready var laser_sprite: AnimatedSprite2D = $laser
@onready var weapon_sprite: AnimatedSprite2D = $weapon

func _ready() -> void:
	base_element = ElementalSystem.Element.NONE
	speed = 30.0
	max_health = 8000
	attack_range = 50.0
	attack_damage = 25
	super._ready()
	if laser_sprite: laser_sprite.visible = false
	if weapon_sprite: weapon_sprite.visible = false

func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	
	_pattern_laser()

func _pattern_laser() -> void:
	_play_animation("charge_energy")
	velocity = Vector2.ZERO
	
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(1.0).timeout
	
	if laser_sprite:
		laser_sprite.visible = true
		laser_sprite.play("default")
		
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < 150:
				player.take_elemental_hit(attack_damage, ElementalSystem.Element.ELECTRO)
				
		tree = get_tree()
		if not tree: return
		await tree.create_timer(1.5).timeout
		laser_sprite.visible = false
	
	special_timer = special_attack_cooldown
	is_attacking = false
	boss_state = BossState.CHASE
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false
	
	var anim = "attack1" if randf() > 0.5 else "attack2"
	_play_animation(anim)
	
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(0.6).timeout
	if is_alive: _check_hit()
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(0.6).timeout
	is_attacking = false
	boss_state = BossState.CHASE
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_cooldown).timeout
	can_attack = true
