extends BossBase

@export var fireball_scene: PackedScene = load("res://scenes/entities/projectiles/fireball.tscn")

func _init_stats() -> void:
	max_health = 400
	resistance = 0
	character_name = "Demon"

func _ready() -> void:
	base_element = ElementalSystem.Element.PYRO
	speed = 48.0
	attack_range = 45.0
	attack_damage = 15
	attack_cooldown = 0.7
	attack_delay = 0.2
	attack_recovery_delay = 0.2
	special_attack_cooldown = 2.5
	super._ready()

func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	var dist = global_position.distance_to(player.global_position)
	if dist > 120:
		_pattern_predictive_fireball()
	elif dist < 60 and randf() > 0.7:
		_pattern_blink_strike()
	else:
		_pattern_jump_slam()

func _pattern_predictive_fireball() -> void:
	_play_animation("idle")
	var t = get_tree()
	if not t: return
	await t.create_timer(0.4).timeout
	if is_instance_valid(player):
		var prediction_factor = 0.35
		var predicted_pos = player.global_position + (player.velocity * prediction_factor)
		var dir = (predicted_pos - global_position).normalized()
		var fb = fireball_scene.instantiate()
		fb.global_position = global_position
		fb.direction = dir
		fb.element = ElementalSystem.Element.PYRO
		fb.damage = attack_damage
		get_parent().add_child(fb)
	_finish_special()

func _pattern_blink_strike() -> void:
	mostrar_texto_flotante("BLINK", Color.PURPLE)
	var t = get_tree()
	if not t: return
	await t.create_timer(0.2).timeout
	if not is_instance_valid(player):
		_finish_special()
		return
	var player_back_dir = -player.last_direction.normalized()
	if player_back_dir == Vector2.ZERO:
		player_back_dir = Vector2.LEFT
	var behind_pos = player.global_position + (player_back_dir * 45)
	global_position = behind_pos
	if animated_sprite:
		animated_sprite.flip_h = (player.global_position.x < global_position.x)
	_play_animation("attack1")
	t = get_tree()
	if not t: return
	await t.create_timer(0.2).timeout
	if is_alive: _check_hit()
	_finish_special()

func _pattern_jump_slam() -> void:
	var original_speed = speed
	speed *= 3.0
	_play_animation("walk")
	var t = get_tree()
	if not t: return
	await t.create_timer(0.6).timeout
	speed = original_speed
	if global_position.distance_to(player.global_position) < 80:
		_play_animation("attack2")
		t = get_tree()
		if not t: return
		await t.create_timer(0.2).timeout
		if is_alive: _check_hit()
	_finish_special()

func _finish_special() -> void:
	special_timer = special_attack_cooldown
	is_attacking = false
	boss_state = BossState.CHASE
	var t = get_tree()
	if not t: return
	await t.create_timer(attack_cooldown).timeout
	can_attack = true

func _physics_process(delta: float) -> void:
	if is_alive and is_instance_valid(player) and not is_attacking:
		animated_sprite.flip_h = player.global_position.x < global_position.x
		
	if current_health < max_health * 0.4:
		speed = 72.0
		attack_cooldown = 0.4
		attack_recovery_delay = 0.15
	super._physics_process(delta)

func receive_damage(amount: int) -> void:
	if is_alive and randf() < 0.1:
		mostrar_texto_flotante("DODGE", Color.CYAN)
		var dodge_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		global_position += dodge_dir * 50
		return
	super.receive_damage(amount)

func die() -> void:
	if not is_alive: return
	is_alive = false
	boss_state = BossState.DEATH
	velocity = Vector2.ZERO
	
	GameManager.notify_boss_defeat(character_name)
	
	var death_anim = ""
	if animated_sprite.sprite_frames.has_animation("death"):
		death_anim = "death"
	elif animated_sprite.sprite_frames.has_animation("Death"):
		death_anim = "Death"
		
	if death_anim != "":
		animated_sprite.play(death_anim)
		await animated_sprite.animation_finished
		
	SceneManager.load_scene("res://scenes/ui/VictoryScreen.tscn")
	queue_free()
