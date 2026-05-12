extends Enemy
class_name BossBase

enum BossState { IDLE, CHASE, ATTACK, SPECIAL, HURT, DEATH }

@export var boss_state: BossState = BossState.IDLE
@export var attack_chance: float = 0.5
@export var special_attack_cooldown: float = 5.0

var special_timer: float = 0.0
var current_attack_name: String = ""
@export var attack_recovery_delay: float = 0.5

func _ready() -> void:
	super._ready()
	boss_state = BossState.IDLE

func _physics_process(delta: float) -> void:
	if not is_alive: return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	special_timer -= delta
	
	match boss_state:
		BossState.IDLE:
			_state_idle(delta)
		BossState.CHASE:
			_state_chase(delta)
		BossState.ATTACK:
			_state_attack(delta)
		BossState.SPECIAL:
			_state_special(delta)
		BossState.HURT:
			pass
		BossState.DEATH:
			velocity = Vector2.ZERO

	move_and_slide()

func _state_idle(_delta: float) -> void:
	_play_animation("idle")
	velocity = Vector2.ZERO
	if global_position.distance_to(player.global_position) < detection_range:
		boss_state = BossState.CHASE

func _state_chase(_delta: float) -> void:
	var distance = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			_choose_attack()
		else:
			_play_animation("idle")
	else:
		velocity = direction * speed
		_update_animations(direction)
		
	if distance > detection_range * 1.5:
		boss_state = BossState.IDLE

func _choose_attack() -> void:
	if special_timer <= 0:
		boss_state = BossState.SPECIAL
	else:
		boss_state = BossState.ATTACK

func _state_attack(_delta: float) -> void:
	if is_attacking: return
	_perform_basic_attack()

func _state_special(_delta: float) -> void:
	if is_attacking: return
	_perform_special_attack()

func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false
	_play_animation("attack1")
	
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_delay).timeout
	if is_alive: _check_hit()
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_recovery_delay).timeout
	is_attacking = false
	boss_state = BossState.CHASE
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_cooldown).timeout
	can_attack = true

func _perform_special_attack() -> void:
	
	special_timer = special_attack_cooldown
	boss_state = BossState.CHASE

func take_damage(amount: int) -> void:
	receive_damage(amount)
	if current_health > 0:
		_on_hit()

func _on_hit() -> void:
	
	pass

func die() -> void:
	if not is_alive: return
	is_alive = false
	boss_state = BossState.DEATH
	velocity = Vector2.ZERO
	
	GameManager.notify_boss_defeat(name)
	
	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	
	queue_free()
