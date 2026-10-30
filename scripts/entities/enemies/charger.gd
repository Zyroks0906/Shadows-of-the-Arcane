extends SheetEnemy
class_name Charger

# The goblin raider charges (LuizMelo's Goblin). Seeing the player at middle range it plants its feet and a red lane
# marks the floor ahead (the tell), then it barrels down that lane. Caught, the player is
# hit hard and thrown aside; dodged, the goblin runs on until the lane ends, and if it rams a
# wall it is left stunned, open to punishment. Up close it slams like any brute.

const WINDUP := 0.8
const DASH_SPEED := 220.0
const MIN_RANGE := 36.0
const MAX_RANGE := 130.0
const CHARGE_EVERY := 3.5

var _dir := Vector2.RIGHT
var _left := 0.0             # lane length still to run
var _charging := false
var _next_charge_ms := 0
var _lane: Node2D
var _lane_t := 0.0
var _hit_player := false

func _init_stats() -> void:
	folder = "Goblin"
	body_px = 15.0
	art_px = 36.0
	sheets["walk"] = ["Run", 12.0, true]
	max_health = 90
	resistance = 3
	character_name = "Goblin Raider"
	speed = 24.0
	attack_range = 20.0
	attack_reach = 26.0
	attack_damage = 16
	attack_delay = 0.7
	attack_cooldown = 1.6
	detection_range = 190.0
	knockback_scale = 0.2
	cc_resistance = 0.3

func _ready() -> void:
	super._ready()
	_lane = Node2D.new()
	_lane.show_behind_parent = true
	_lane.draw.connect(_draw_lane)
	add_child(_lane)

func _physics_process(delta: float) -> void:
	if _charging:
		_run_charge(delta)
		return
	if is_alive and can_attack and not is_attacking and not is_frozen and is_instance_valid(player) \
			and Time.get_ticks_msec() >= _next_charge_ms and Time.get_ticks_msec() >= _stunned_until_ms:
		var to := player.global_position - global_position
		if to.length() > MIN_RANGE and to.length() < MAX_RANGE and _clear_line(player.global_position):
			_start_charge(to)
			return
	super._physics_process(delta)

func _clear_line(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 1, [get_rid(), player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _start_charge(to: Vector2) -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	_dir = to.normalized()
	_left = minf(to.length() + 40.0, MAX_RANGE + 30.0)
	animated_sprite.flip_h = _dir.x < 0
	_telegraph(WINDUP, true)
	_snd("alert")
	var tw := create_tween()
	tw.tween_method(func(t: float): _lane_t = t; _lane.queue_redraw(), 0.0, 1.0, WINDUP)
	await get_tree().create_timer(WINDUP).timeout
	if not is_alive or is_frozen:
		_end_charge()
		return
	_charging = true
	_hit_player = false
	AudioManager.play_bank_at("roar", global_position, -8.0, 1.2)

func _run_charge(delta: float) -> void:
	if not is_alive or is_frozen:
		_end_charge()
		return
	velocity = _dir * DASH_SPEED
	_play_animation("walk")
	animated_sprite.speed_scale = 2.2
	move_and_slide()
	_left -= DASH_SPEED * delta
	if not _hit_player and is_instance_valid(player) and player.is_alive and global_position.distance_to(player.global_position) < 13.0:
		_hit_player = true
		player.take_elemental_hit(int(attack_damage * 1.5), base_element, self)
		player.apply_knockback((_dir + (player.global_position - global_position).normalized()).normalized() * 320.0)
		CombatFX.shake(4.0, 0.25)
		if elite:
			elite.on_hit_player(attack_damage)
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is TileMapLayer or other is StaticBody2D:
			# Rammed a wall: dazed, wide open.
			CombatFX.shake(3.0, 0.2)
			CombatFX.burst(global_position + _dir * 8.0, Color(0.75, 0.7, 0.6), 14, 60.0, 0.4, 40.0, 2.0)
			AudioManager.play_bank_at("stomp", global_position, -2.0, 0.8)
			_end_charge()
			apply_stun(1.6)
			return
	if _left <= 0.0:
		_end_charge()

func _end_charge() -> void:
	_charging = false
	_lane_t = 0.0
	_lane.queue_redraw()
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
	is_attacking = false
	_next_charge_ms = Time.get_ticks_msec() + int(CHARGE_EVERY * 1000.0)
	await get_tree().create_timer(0.6).timeout
	if is_alive:
		can_attack = true

# The tell: a lane of red pixel chevrons (">" shapes pointing the way it will run) that
# fills from the goblin's feet outwards, brightest near it.
func _draw_lane() -> void:
	if _lane_t <= 0.0:
		return
	var n := int(_left / 10.0)
	var lit := int(n * _lane_t)
	var side := _dir.orthogonal()
	for i in lit:
		var tip := _dir * (12.0 + i * 10.0)
		var a := 0.85 - 0.45 * float(i) / maxf(n, 1)
		for j in 4:
			for k in [-1.0, 1.0]:
				var q: Vector2 = tip - _dir * j + side * j * k
				_lane.draw_rect(Rect2(q.round(), Vector2(1, 1)), Color(1.0, 0.25 + 0.1 * j, 0.2, a))
