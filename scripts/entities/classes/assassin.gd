extends Player
class_name Assassin

# Glass cannon: fastest, frail, short and very quick dagger cuts.
func _init() -> void:
	character_name = "Assassin"
	base_element = ElementalSystem.Element.NONE
	max_health = 85
	max_mana = 60
	strength = 14
	intelligence = 10
	resistance = 4
	wisdom = 12
	speed = 90.0 # the fastest, though its short steps can only keep up so far
	base_scale = Vector2(0.42, 0.42)
	skill_name = "Shuriken Volley"
	skill_cooldown = 5.0
	burst_name = "Shadow Clones"
	burst_cost = 50.0
	# Silent killer: light dagger whips, quick cuts, almost never makes a sound.
	snd_swing = [["dagger_swing", -4.0, 1.1]]
	snd_hit = [["blade_flesh", -5.0, 1.25]]
	voice = "m1"
	voice_pitch = 1.12
	voice_volume = -8.0
	effort_chance = 0.05
	block_stamina_max = 25.0
	# Can barely block; lives by rolling.
	snd_block = [["metal_clash", -4.0, 1.25]]
	dodge_distance = 60.0
	dodge_duration = 0.24
	dodge_cooldown = 0.45
	# Daggers: attack1_right.png cuts on frame 2.
	attack_reach = 17.0
	attack_arc_deg = 90.0
	attack_startup = 0.08
	attack_cycle = 0.30
	attack_impact_frame = 2
	attack_damage_mult = 0.6
	attack_knockback = 80.0
	attack_move_mult = 0.7

# E: Shuriken volley. Three stars thrown in quick succession at the crosshair (each one
# pierces one enemy). Quick and from range: the ninja never has to stand in the fight.
func _do_skill() -> void:
	_face_aim_until_ms = Time.get_ticks_msec() + 400
	for i in 3:
		if not is_alive:
			return
		var dir := _assisted_dir(160.0).rotated(deg_to_rad([0.0, -7.0, 7.0][i]))
		aim_direction = dir
		_update_facing(Vector2.ZERO)
		Shuriken.throw(self, global_position + Vector2(0, -4) + dir * 6.0, dir, roundi(_melee_damage() * 1.1))
		AudioManager.play_bank("dagger_swing", -4.0, 1.5 + i * 0.1)
		await get_tree().create_timer(0.08).timeout

# Q: Shadow clones. Three to five dark copies appear around the ninja in a puff of smoke;
# nearby monsters turn on them (they poke back a little) while he gets to work. They have
# almost no health and vanish in smoke.
func _do_burst() -> void:
	var n := randi_range(3, 5)
	AudioManager.play_bank("teleport", -2.0, 1.3)
	CombatFX.burst(global_position, Color(0.45, 0.3, 0.6), 24, 60.0, 0.5, -20.0, 3.0)
	for i in n:
		var at := global_position + Vector2.RIGHT.rotated(TAU * i / n + randf() * 0.4) * randf_range(16.0, 26.0)
		var q := PhysicsRayQueryParameters2D.create(global_position, at, 1, [get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit:
			at = global_position.lerp(hit["position"], 0.6)
		ShadowClone.spawn(self, at)
