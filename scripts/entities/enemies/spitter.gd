extends SheetEnemy
class_name Spitter

# The mushroom spits toxic spores (LuizMelo's Mushroom). It hangs back and lobs a glob in an arc at where the player stands;
# where it lands an acid pool hisses for a few seconds and burns whoever stands in it.
# Keep moving, or close in: up close it can only bite.

const KEEP := 80.0
const POOL_SECONDS := 4.0

var _strafe := 1.0
var _strafe_t := 0.0

func _init_stats() -> void:
	folder = "Mushroom"
	body_px = 14.0
	art_px = 37.0
	sheets["walk"] = ["Run", 10.0, true]
	max_health = 42
	resistance = 1
	character_name = "Sporecap"
	speed = 36.0
	attack_range = 150.0
	attack_damage = 5
	attack_delay = 0.45
	attack_cooldown = 2.4
	detection_range = 190.0
	knockback_scale = 1.2

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _process_knockback(delta) or is_frozen or is_attacking or is_hurt or Time.get_ticks_msec() < _stunned_until_ms:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	var to := player.global_position - global_position
	var d := to.length()
	if d > detection_range:
		velocity = Vector2.ZERO
		_play_animation("idle")
		move_and_slide()
		return
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 2.0)
		_strafe = [-1.0, 1.0].pick_random()
	var dir := to.normalized()
	var radial := 1.0 if d > KEEP + 15.0 else (-1.2 if d < KEEP - 15.0 else 0.0)
	var move := (dir * radial + dir.orthogonal() * _strafe * 0.6).normalized()
	velocity = move * speed * terrain_speed_mult + external_push
	_update_animations(move)
	move_and_slide()
	if can_attack and d <= attack_range:
		_spit()

func _spit() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	_telegraph(attack_delay, false)
	_play_attack_anim("attack", attack_delay)
	await get_tree().create_timer(attack_delay).timeout
	if is_alive and not is_frozen and is_instance_valid(player):
		var target := BossMoves.safe_spot(get_world_2d(), global_position, player.global_position, [get_rid(), player.get_rid()])
		AcidPool.lob(get_parent(), global_position + Vector2(0, -8), target, attack_damage, POOL_SECONDS, self)
		AudioManager.play_bank_at("slime", global_position, -8.0, 1.4)
	await get_tree().create_timer(0.3).timeout
	_anim_release(AnimPriority.ACTION)
	animated_sprite.speed_scale = 1.0
	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive:
		can_attack = true
