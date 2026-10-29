extends Enemy
class_name BossBase

enum BossState { IDLE, CHASE, ATTACK, SPECIAL, HURT, DEATH }

@export var boss_state: BossState = BossState.IDLE
@export var attack_chance: float = 0.5
@export var special_attack_cooldown: float = 5.0

var special_timer: float = 0.0
var current_attack_name: String = ""
@export var attack_recovery_delay: float = 0.5
# A boss belongs to its room: it only wakes when it can see you, never chases further than
# `leash` from where it stands, and if it loses you for LOSE_TIME it walks back home,
# recovers, and the fight (and its health bar) ends.
@export var leash: float = 150.0
const LOSE_TIME := 3.0
var home: Vector2
var _lost_t: float = 0.0
var _returning: bool = false

func _ready() -> void:
	add_to_group("bosses")
	knockback_scale = 0.15
	cc_resistance = 0.6
	super._ready()
	boss_state = BossState.IDLE
	(func(): home = global_position).call_deferred()

# A hit always starts (or keeps) the fight, even from out of sight.
func receive_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_alive and amount > 0 and boss_state == BossState.IDLE:
		_returning = false
		boss_state = BossState.CHASE
	_lost_t = 0.0

# In a fight: chasing, attacking or casting (not idle or walking home).
func is_engaged() -> bool:
	return is_alive and boss_state != BossState.IDLE and not _returning

# Nothing solid (walls, layer 1) between the boss and the player.
func _sees_player() -> bool:
	if not is_instance_valid(player):
		return false
	var q := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(delta: float) -> void:
	if not is_alive: return
	if _process_knockback(delta) or is_frozen: return

	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	special_timer -= delta
	_watch_player(delta)

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
	if _returning:
		var to_home := home - global_position
		if to_home.length() > 4.0:
			velocity = to_home.normalized() * speed
			_update_animations(to_home.normalized())
			return
		_returning = false
		# Back home it recovers a quarter of its health: chip-and-run isn't free, but a long
		# fight isn't wiped either.
		current_health = mini(max_health, current_health + max_health / 4)
	_play_animation("idle")
	velocity = Vector2.ZERO
	if global_position.distance_to(player.global_position) < detection_range and _sees_player():
		boss_state = BossState.CHASE
		_lost_t = 0.0

# Counts how long the player has been out of reach during a fight; gives up after LOSE_TIME.
func _watch_player(delta: float) -> void:
	if not is_engaged() or is_attacking:
		return
	# Only a real escape ends the fight: being far from its room. Losing sight of you behind
	# a pillar inside the arena does not (it used to, and the boss "vanished" mid-fight).
	var gone := player.global_position.distance_to(home) > leash + detection_range
	_lost_t = _lost_t + delta if gone else 0.0
	if _lost_t >= LOSE_TIME:
		_lost_t = 0.0
		_returning = true
		boss_state = BossState.IDLE

# Chase velocity, but never past the leash: at the edge of its room it waits.
func _leashed(v: Vector2) -> Vector2:
	if home == Vector2.ZERO:
		return v
	var next := global_position + v * get_physics_process_delta_time()
	if next.distance_to(home) > leash and next.distance_to(home) > global_position.distance_to(home):
		return Vector2.ZERO
	return v

func _state_chase(_delta: float) -> void:
	var distance = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()

	# A special can come from range: bosses don't just walk at you.
	if special_timer <= 0.0 and can_attack and distance < detection_range and _sees_player():
		velocity = Vector2.ZERO
		boss_state = BossState.SPECIAL
		return
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			_choose_attack()
		else:
			_play_animation("idle")
	else:
		velocity = _leashed(direction * speed)
		if velocity == Vector2.ZERO:
			_play_animation("idle")
		else:
			_update_animations(direction)

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
	if is_instance_valid(player):
		BossMoves.warn_cone(self, player.global_position - global_position, attack_range + 6.0, 110.0, maxf(attack_delay, 0.45))

	var tree = get_tree()
	if not tree: return
	await tree.create_timer(maxf(attack_delay, 0.45)).timeout
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
	XpOrb.drop(global_position, 60, get_parent())

	GameManager.notify_boss_defeat(name)

	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	queue_free()
