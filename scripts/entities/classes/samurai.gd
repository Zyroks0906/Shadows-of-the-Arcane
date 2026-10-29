extends Player
class_name Samurai

# Fast duelist: medium health, longer blade, a larger parry window (blocking block).
func _init() -> void:
	character_name = "Samurai"
	base_element = ElementalSystem.Element.HYDRO
	max_health = 115
	max_mana = 55
	strength = 15
	intelligence = 9
	resistance = 8
	wisdom = 10
	speed = 92.0
	base_scale = Vector2(0.43, 0.43)
	skill_name = "Iaido Flurry"
	skill_cooldown = 5.0
	burst_name = "Thousand Cuts"
	burst_cost = 60.0
	# Duelist: quick, sharp katana and a short kiai on many cuts.
	snd_swing = [["sword_swing", -3.0, 1.18]]
	snd_hit = [["blade_flesh", -3.0, 1.12]]
	voice = "m1"
	voice_pitch = 1.04
	effort_chance = 0.45
	sprite_offset = Vector2(0, -15)
	block_stamina_max = 55.0
	# Masters of timing: a much wider parry window.
	parry_window = 0.35
	snd_block = [["metal_clash", -2.0, 1.1]]
	dodge_distance = 48.0
	# Katana: ATTACK 1.png crouches for four frames and cuts on frame 4.
	attack_reach = 24.0
	attack_arc_deg = 100.0
	attack_startup = 0.12
	attack_cycle = 0.45
	attack_impact_frame = 4

# E: Iaido flurry. Four lightning-fast cuts in a cone in front of him, each one a visible
# crescent. All edge, no guard: he stands his ground while he cuts.
func _do_skill() -> void:
	var dir := _assisted_dir(attack_reach * 1.4)
	aim_direction = dir
	_update_facing(Vector2.ZERO)
	_voice("effort")
	var reach := attack_reach * 1.35
	for k in 4:
		if not is_alive:
			return
		var d := dir.rotated(deg_to_rad([-22.0, 22.0, -8.0, 8.0][k]))
		var hits := _strike_arc(d, reach, 80.0, roundi(_melee_damage() * 0.75), 60.0)
		CombatFX.slash(global_position + Vector2(0, -2), d, reach, 80.0, Color(0.6, 0.85, 1.0), 6.0)
		_play_layers(snd_swing, randf_range(1.05, 1.25), -1.0)
		if hits > 0:
			on_hit_landed("skill")
			_play_layers(snd_hit, 1.1, -2.0)
			CombatFX.hit_stop(0.03)
		await get_tree().create_timer(0.09).timeout

# Q: Thousand Cuts. Eight great crescents slash all around him, then a final ring cut.
func _do_burst() -> void:
	for i in 8:
		if not is_alive:
			return
		var d := Vector2.RIGHT.rotated(TAU * i / 8.0 + randf_range(-0.3, 0.3))
		CombatFX.slash(global_position + Vector2(0, -2), d, 38.0, 120.0, Color(0.7, 0.9, 1.0), 7.0)
		_aoe(global_position, 44.0, roundi(_melee_damage() * 0.6), ElementalSystem.Element.HYDRO, 40.0, 0.0, "burst")
		_play_layers(snd_swing, randf_range(1.0, 1.3), -2.0)
		await get_tree().create_timer(0.11).timeout
	CombatFX.shockwave(global_position, Color(0.7, 0.9, 1.0), 48.0, 0.35, 4.0)
	CombatFX.pvfx("resonant-break", global_position, 0.55)
	CombatFX.pvfx("splash-crown", global_position, 0.55)
	CombatFX.hit_stop(0.08)
	CombatFX.shake(3.0, 0.25)
	_aoe(global_position, 48.0, roundi(_melee_damage() * 1.2), ElementalSystem.Element.HYDRO, 160.0, 0.4, "burst")
