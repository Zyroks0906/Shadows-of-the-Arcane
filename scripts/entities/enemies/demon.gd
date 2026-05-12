extends BossBase

@export var fireball_scene: PackedScene = load("res://scenes/entities/projectiles/fireball.tscn")

func _ready() -> void:
	base_element = ElementalSystem.Element.PYRO
	speed = 80.0
	max_health = 600
	attack_range = 45.0
	attack_damage = 20
	attack_cooldown = 0.8
	attack_delay = 0.25
	attack_recovery_delay = 0.3
	special_attack_cooldown = 2.5
	super._ready()

func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	
	if randf() > 0.5:
		_pattern_fireball()
	else:
		_pattern_jump_slam()

func _pattern_fireball() -> void:
	_play_animation("idle")
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(0.5).timeout
	
	if is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		var fb = fireball_scene.instantiate()
		fb.global_position = global_position
		fb.direction = dir
		fb.element = ElementalSystem.Element.PYRO
		fb.damage = attack_damage
		get_parent().add_child(fb)
	
	_finish_special()

func _pattern_jump_slam() -> void:
	var original_speed = speed
	speed *= 2.5
	_play_animation("walk")
	
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(0.8).timeout
	
	speed = original_speed
	if global_position.distance_to(player.global_position) < 60:
		_play_animation("attack1")
		tree = get_tree()
		if not tree: return
		await tree.create_timer(0.3).timeout
		if is_alive: _check_hit()
	
	_finish_special()

func _finish_special() -> void:
	special_timer = special_attack_cooldown
	is_attacking = false
	boss_state = BossState.CHASE
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_cooldown).timeout
	can_attack = true

func _physics_process(delta: float) -> void:
	if current_health < max_health * 0.4:
		speed = 100.0
		attack_cooldown = 0.5
		attack_recovery_delay = 0.2
	
	super._physics_process(delta)
