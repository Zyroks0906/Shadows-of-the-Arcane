extends Player
class_name Gladiator

# Barbarian: the most health but little armour; slow, wide, heavy swings.
func _init() -> void:
	character_name = "Barbarian"
	base_element = ElementalSystem.Element.NONE
	max_health = 170
	max_mana = 30
	strength = 18
	intelligence = 4
	resistance = 6
	wisdom = 5
	speed = 76.0
	base_scale = Vector2(0.18, 0.18)
	skill_name = "Earthshaker"
	skill_cooldown = 7.0
	burst_name = "Spartan Rage"
	burst_cost = 60.0
	# Brute: heavy axe, wet meaty impacts, a deep bellow on almost every swing.
	snd_swing = [["heavy_swing", 0.0, 0.85]]
	snd_hit = [["heavy_flesh", 0.0, 0.85], ["blade_flesh", -8.0, 0.75]]
	voice = "m3"
	voice_pitch = 0.82
	effort_chance = 0.7
	# The "360" sheets (attack, hurt, jump attack) are drawn at 61 px tall vs 82 px idle.
	anim_scale = {"Attack1": 1.34, "Attack2": 1.34, "Hurt": 1.34}
	anim_feet_px = 64.0
	sprite_offset = Vector2(0, -25)
	block_stamina_max = 45.0
	snd_block = [["heavy_clash", 0.0, 0.85]]
	dodge_distance = 40.0
	dodge_duration = 0.3
	dodge_cooldown = 0.7
	# Two-handed axe: the 360 spin connects around 40% into the animation.
	attack_reach = 28.0
	attack_arc_deg = 140.0
	attack_startup = 0.30
	attack_cycle = 0.75
	attack_impact_frame = 38
	attack_damage_mult = 1.5
	attack_knockback = 230.0
	attack_move_mult = 0.4

# E: Earthshaker (Kratos-style). He leaps up and comes down axe-first: a heavy slam that
# stuns and throws back everything around the landing spot. Unlike his swings, it is a jump.
func _do_skill() -> void:
	_cancel_actions()
	_attack_token += 1
	var now := Time.get_ticks_msec()
	_busy_until_ms = now + 700
	_face_aim_until_ms = now
	var land := global_position + _assisted_dir(48.0) * 22.0
	var q := PhysicsRayQueryParameters2D.create(global_position, land, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		land = global_position.lerp(hit["position"], 0.7)
	_voice("effort", 3.0)
	CombatFX.pvfx("landing-dust", global_position, 0.4)
	is_attacking = true
	_play_animation("Attack", AnimPriority.ACTION)
	# The jump: the body arcs up and over while the shadow stays on the floor.
	if _sprite_rest == Vector2.INF:
		_sprite_rest = animated_sprite.position
	airborne = true
	var tw := create_tween()
	tw.tween_method(func(t: float):
		global_position = global_position.lerp(land, 0.25)
		animated_sprite.position.y = _sprite_rest.y - 14.0 * 4.0 * t * (1.0 - t), 0.0, 1.0, 0.38)
	await tw.finished
	airborne = false
	animated_sprite.position.y = _sprite_rest.y
	_aoe(global_position, 40.0, roundi(_melee_damage() * 1.8 * damage_mult_buff), ElementalSystem.Element.NONE, 200.0, 0.7)
	CombatFX.pvfx("earth-rupture", global_position, 0.75)
	CombatFX.pvfx("landing-dust", global_position, 0.6)
	CombatFX.shockwave(global_position, Color(0.85, 0.7, 0.5), 42.0, 0.35, 4.0)
	CombatFX.burst(global_position, Color(0.55, 0.45, 0.35), 24, 80.0, 0.5, 120.0, 2.5)
	CombatFX.shake(4.0, 0.3)
	CombatFX.hit_stop(0.06)
	AudioManager.play_bank("stomp", 2.0, 0.8)
	_finish_attack_anim()

# Q: Spartan Rage for 7 s: swings 30% faster and hits 20% harder, but he guards nothing and
# takes 5% more damage. A red aura burns around him while it lasts.
func _do_burst() -> void:
	_voice("effort", 4.0)
	AudioManager.play_bank("roar", -2.0, 1.1)
	CombatFX.shockwave(global_position, Color(1.0, 0.25, 0.2), 40.0, 0.4, 3.0)
	_buff("attack_speed_mult", 1.3, 7.0)
	_buff("damage_mult_buff", 1.2, 7.0)
	_buff("damage_taken_mult", 1.05, 7.0)
	var tw := animated_sprite.create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1.35, 0.75, 0.7), 0.2)
	tw.tween_interval(6.6)
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	for i in 46:
		if not is_alive:
			return
		CombatFX.burst(global_position + Vector2(randf_range(-6, 6), randf_range(-12, 0)), Color(1.0, randf_range(0.1, 0.35), 0.1), 2, 18.0, 0.5, -60.0, 1.5)
		await get_tree().create_timer(0.15).timeout
