extends Player
class_name Knight

# Tank: slowest, most health, best armour and the biggest block meter (shield).
func _init() -> void:
	character_name = "Knight"
	base_element = ElementalSystem.Element.NONE
	max_health = 150
	max_mana = 40
	strength = 14
	intelligence = 6
	resistance = 12
	wisdom = 7
	speed = 72.0
	base_scale = Vector2(0.4, 0.4)
	skill_name = "Shield Bash"
	skill_cooldown = 6.0
	burst_name = "Aegis"
	burst_cost = 50.0
	# Veteran soldier: clean sword, steady low voice, rarely shouts.
	snd_swing = [["sword_swing", -2.0, 1.0]]
	snd_hit = [["blade_flesh", -3.0, 0.95]]
	voice = "m2"
	voice_pitch = 0.94
	effort_chance = 0.15
	block_stamina_max = 100.0
	# Shield: the best guard in the game, but plate armour makes the roll short.
	snd_block = [["shield_block", 0.0, 1.0]]
	dodge_distance = 36.0
	dodge_duration = 0.28
	dodge_cooldown = 0.75
	# Sword: ATTACK 1.png slashes on frame 3.
	attack_reach = 22.0
	attack_arc_deg = 100.0
	attack_startup = 0.14
	attack_cycle = 0.45
	attack_impact_frame = 3

# E: Shield Bash. No dash (that's what the dodge is for): he plants his feet and slams the
# shield forward. Everything in the cone in front of him is stunned and thrown back. Pure
# control: it buys the knight time, it doesn't chase.
func _do_skill() -> void:
	var dir := _assisted_dir(40.0)
	aim_direction = dir
	_face_aim_until_ms = Time.get_ticks_msec() + 400
	_update_facing(Vector2.ZERO)
	AudioManager.play_bank("fist_swing", -2.0, 0.8)
	await get_tree().create_timer(0.1).timeout
	if not is_alive:
		return
	var hits := _strike_arc(dir, 34.0, 100.0, roundi(_melee_damage() * 1.0), 260.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive and e.global_position.distance_to(global_position) < 40.0 and absf(dir.angle_to(e.global_position - global_position)) < deg_to_rad(55):
			e.apply_stun(1.2)
	# Gold, one colour: the crescent's own rainbow tones read as an element he doesn't have.
	CombatFX.slash(global_position + Vector2(0, -2), dir, 30.0, 100.0, Color(1.0, 0.85, 0.4), 8.0, true)
	CombatFX.slash(global_position + Vector2(0, -2), dir, 20.0, 80.0, Color(1.0, 0.95, 0.7), 5.0, true)
	CombatFX.burst(global_position + dir * 14.0, Color(1.0, 0.85, 0.4), 14, 70.0, 0.3)
	CombatFX.pvfx("arcane-parry", global_position + dir * 12.0 + Vector2(0, 4), 0.35, 0.0, Color.WHITE, 1.6)
	AudioManager.play_bank("shield_block", 2.0, 0.85)
	if hits > 0:
		on_hit_landed("skill")
		CombatFX.hit_stop(0.06)
		CombatFX.shake(2.5, 0.15)
		AudioManager.play_bank("heavy_flesh", -2.0, 0.9)

# Q: Aegis. Four golden shields circle the knight for 11 s, striking and shoving back
# whatever they pass through; behind them he takes a quarter less damage.
func _do_burst() -> void:
	CombatFX.shockwave(global_position, Color(1.0, 0.85, 0.35), 30.0, 0.3, 2.5)
	AudioManager.play_bank("heal", 0.0, 0.7)
	AudioManager.play_bank("shield_block", -2.0, 0.8)
	AegisOrbit.summon(self, 4, 11.0, roundi(_melee_damage() * 0.8)) # was 8 s
	_buff("damage_taken_mult", 0.75, 11.0)
