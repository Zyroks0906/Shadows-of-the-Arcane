extends SheetEnemy
class_name Summoner

# The evil wizard (LuizMelo's Evil Wizard) never fights itself. It keeps its distance
# (backing off when the player closes in) and, while it can see the player, tears open a
# pair of rifts every few seconds and flying eyes pour out, up to four at once. Kill it
# first and its eyes fall with it.

const MINION := "res://scenes/entities/Enemies/Eyeling.tscn"
const KEEP := 90.0
const EVERY := 6.5
const MAX_RAISED := 4

var _raised: Array[Node] = []
var _next_ms := 0
var _strafe := 1.0
var _strafe_t := 0.0

func _init_stats() -> void:
	folder = "EvilWizard"
	body_px = 20.0
	art_px = 55.0
	sheets["walk"] = ["Move", 9.0, true]
	max_health = 50
	resistance = 1
	character_name = "Evil Wizard"
	speed = 34.0
	attack_range = 0.0
	detection_range = 200.0
	knockback_scale = 1.1

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
		_strafe_t = randf_range(1.2, 2.2)
		_strafe = [-1.0, 1.0].pick_random()
	var dir := to.normalized()
	var radial := 1.0 if d > KEEP + 20.0 else (-1.3 if d < KEEP - 20.0 else 0.0)
	var move := (dir * radial + dir.orthogonal() * _strafe * 0.5).normalized()
	velocity = move * speed * terrain_speed_mult + external_push
	_update_animations(move if radial != 0.0 else dir)
	move_and_slide()
	_raised = _raised.filter(func(n): return is_instance_valid(n) and n.is_alive)
	if Time.get_ticks_msec() >= _next_ms and _raised.size() <= MAX_RAISED - 2 and _sees_player():
		_raise()

func _sees_player() -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _raise() -> void:
	_next_ms = Time.get_ticks_msec() + int(EVERY * 1000.0)
	is_attacking = true
	velocity = Vector2.ZERO
	_telegraph(0.7, false)
	_play_attack_anim("attack", 0.7)
	AudioManager.play_bank_at("magic_shield", global_position, -6.0, 0.6)
	var spots: Array[Vector2] = []
	for k in 2:
		var want := global_position + Vector2.from_angle(randf() * TAU) * randf_range(18.0, 28.0)
		var at := BossMoves.safe_spot(get_world_2d(), global_position, want, [get_rid()])
		var ground := MapBounds.ground_layers(self)
		if not ground.is_empty() and not MapBounds.on_map(ground, at):
			at = global_position
		spots.append(at)
		CombatFX.pvfx("rift-portal", at, 0.35)
	await get_tree().create_timer(0.7).timeout
	_anim_release(AnimPriority.ACTION)
	animated_sprite.speed_scale = 1.0
	is_attacking = false
	if not is_alive:
		return
	for at in spots:
		var s: Node2D = load(MINION).instantiate()
		get_parent().add_child(s)
		s.global_position = at
		_raised.append(s)

func die() -> void:
	super.die()
	for s in _raised:
		if is_instance_valid(s) and s.is_alive:
			s.die()
