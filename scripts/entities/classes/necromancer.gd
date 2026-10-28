extends Player
class_name Necromancer

# Caster: Pyro orbs, a bit sturdier than the Mage.
func _init() -> void:
	character_name = "Necromancer"
	base_element = ElementalSystem.Element.PYRO
	max_health = 85
	max_mana = 80
	strength = 8
	intelligence = 16
	resistance = 5
	wisdom = 12
	speed = 80.0
	base_scale = Vector2(0.25, 0.25)
	aim_tilt = true
	skill_name = "Hellfire"
	skill_cooldown = 6.0
	# Mana: basic 5, skill 16, ultimate 26 (regen ~0.15 x wisdom per second).
	cast_mana_cost = 5
	skill_mana_cost = 16
	burst_mana_cost = 26
	burst_name = "Meteor"
	burst_cost = 60.0
	uses_mana = true
	# Pyro necromancer: darker, slower fireballs; a deep, sinister voice.
	snd_cast = [["fire_launch", -2.0, 0.82]]
	snd_impact = [["fire_impact", -2.0, 0.85]]
	voice = "m3"
	voice_pitch = 0.72
	effort_chance = 0.1
	sprite_offset = Vector2(0, -15)
	block_stamina_max = 20.0
	snd_block = [["magic_shield", -2.0, 0.85]]
	dodge_distance = 46.0
	attack_kind = AttackKind.CAST
	# Attack1.png: the spirit is thrown on frame 3.
	attack_startup = 0.35
	attack_cycle = 0.6
	attack_impact_frame = 3
	attack_move_mult = 0.6

# E: Hellfire. A ring of fire bursts out around him and sets everything it touches ablaze.
func _do_skill() -> void:
	_start_action("attack2", 0.25, 0.55, -1, func():
		# Hellfire: a ring of black flame that sets everything around ablaze (burns for 3 s).
		for e in _aoe(global_position, 46.0, roundi(_spell_damage() * 0.8), ElementalSystem.Element.PYRO, 90.0):
			Burn.apply(e, self, 6)
		CombatFX.burst(global_position, Color(1.0, 0.45, 0.1), 30, 90.0, 0.6, -60.0, 2.5)
		CombatFX.pvfx("cinder-orchid", global_position, 0.9)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive and e.global_position.distance_to(global_position) < 46.0:
				CombatFX.pvfx("ember-jet", e.global_position, 0.35)
		CombatFX.spike_ring("Fire", global_position, 24.0, 10, 22.0)
		CombatFX.shockwave(global_position, Color(1.0, 0.45, 0.2), 40.0, 0.35, 3.0)
		CombatFX.shake(2.5, 0.2)
		AudioManager.play_bank("fire_launch", 0.0, 0.7))

# Q: marks the ground at the crosshair; a moment later a meteor crashes down there.
func _do_burst() -> void:
	var at := _target_point(cast_range)
	_start_action("attack2", 0.3, 0.6, -1, func():
		AbilityZone.spawn(self, at, {"radius": 52.0, "delay": 0.9, "duration": 0.4, "damage": roundi(_spell_damage() * 3.0),
			"element": ElementalSystem.Element.PYRO, "style": "fire", "explode_once": true, "stun": 0.6}))
