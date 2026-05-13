extends BossBase

@onready var laser_sprite: AnimatedSprite2D = $laser
@onready var weapon_sprite: AnimatedSprite2D = $weapon
@onready var laser_area: Area2D = $laser/Area2D

var _is_hardened: bool = false
var _hits_taken_recently: int = 0
var _hit_timer: float = 0.0

func _init_stats() -> void:
	max_health = 600
	resistance = 0
	character_name = "Golem"

func _ready() -> void:
	base_element = ElementalSystem.Element.NONE
	speed = 20.0
	attack_range = 70.0
	attack_damage = 40
	attack_cooldown = 1.5
	special_attack_cooldown = 5.0
	super._ready()
	if laser_sprite: laser_sprite.visible = false
	if weapon_sprite: weapon_sprite.visible = false
	if laser_area:
		laser_area.monitoring = false
		laser_area.body_entered.connect(_on_laser_hit)

func _physics_process(delta: float) -> void:
	if not is_alive: return

	if is_instance_valid(player) and not is_attacking:
		animated_sprite.flip_h = player.global_position.x < global_position.x

	_hit_timer -= delta
	if _hit_timer <= 0:
		_hits_taken_recently = 0
		if _is_hardened:
			_is_hardened = false
			mostrar_texto_flotante("NORMAL", Color.WHITE)

	if boss_state == BossState.SPECIAL and laser_sprite and laser_sprite.visible:
		var dir = (player.global_position - global_position).normalized()
		var target_angle = dir.angle()
		laser_sprite.rotation = lerp_angle(laser_sprite.rotation, target_angle, delta * 2.5)

	super._physics_process(delta)

func receive_damage(amount: int) -> void:
	if not is_alive: return
	_hits_taken_recently += 1
	_hit_timer = 2.0
	if _hits_taken_recently > 10 and not _is_hardened:
		_is_hardened = true
		mostrar_texto_flotante("FOCUSED", Color.ORANGE)
	super.receive_damage(amount)

func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	var dist = global_position.distance_to(player.global_position)
	if dist < 90:
		_pattern_shockwave()
	else:
		_pattern_tracking_laser()

func _pattern_shockwave() -> void:
	_play_animation("charge_energy")
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	if not is_alive: return

	mostrar_texto_flotante("SHOCKWAVE", Color.ORANGE)
	_play_animation("attack1")
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < 130:
		player.take_elemental_hit(int(attack_damage * 0.7), ElementalSystem.Element.ANEMO)
		var push_dir = (player.global_position - global_position).normalized()
		player.velocity = push_dir * 600
	_finish_special_golem()

func _pattern_tracking_laser() -> void:
	_play_animation("charge_energy")
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.5).timeout
	if not is_alive: return

	if laser_sprite:
		laser_sprite.visible = true
		laser_sprite.play("default")
		if laser_area: laser_area.monitoring = true
		var duration = 3.5
		while duration > 0:
			duration -= 0.1
			await get_tree().create_timer(0.1).timeout
			if not is_alive: break
			if laser_area:
				for body in laser_area.get_overlapping_bodies():
					_on_laser_hit(body)

		if not is_alive: return
		laser_sprite.visible = false
		if laser_area: laser_area.monitoring = false
		mostrar_texto_flotante("VULNERABLE", Color.YELLOW)
		await get_tree().create_timer(4.0).timeout

	if is_alive: _finish_special_golem()

func _finish_special_golem() -> void:
	if not is_alive: return
	special_timer = special_attack_cooldown
	is_attacking = false
	boss_state = BossState.CHASE
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true

func _on_laser_hit(body: Node2D) -> void:
	if body == player and is_instance_valid(player):
		player.take_elemental_hit(int(attack_damage * 0.3), ElementalSystem.Element.ELECTRO)

func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false

	if is_instance_valid(player):
		animated_sprite.flip_h = player.global_position.x < global_position.x

	var anim = "attack1" if randf() > 0.5 else "attack2"
	_play_animation(anim)
	await get_tree().create_timer(1.5).timeout
	if not is_alive: return

	_check_hit()
	await get_tree().create_timer(1.0).timeout
	if not is_alive: return

	is_attacking = false
	boss_state = BossState.CHASE
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true

func _check_hit() -> void:
	if not is_instance_valid(player): return
	var distance := global_position.distance_to(player.global_position)
	if distance <= attack_range + 5:
		player.take_elemental_hit(attack_damage, base_element)

func die() -> void:
	if not is_alive: return
	is_alive = false
	boss_state = BossState.DEATH
	velocity = Vector2.ZERO

	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Combat and Gore/squelching_2.wav", 5.0, 0.8)

	GameManager.notify_boss_defeat(character_name)

	var death_anim = ""
	if animated_sprite.sprite_frames.has_animation("death"): death_anim = "death"
	elif animated_sprite.sprite_frames.has_animation("Death"): death_anim = "Death"

	if death_anim != "":
		animated_sprite.play(death_anim)
		await animated_sprite.animation_finished

	await get_tree().create_timer(1.0).timeout
	queue_free()
