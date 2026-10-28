extends Player
class_name Mage

# Frail caster that keeps its distance: Cryo orbs, the least health and armour.
func _init() -> void:
	character_name = "Mage"
	base_element = ElementalSystem.Element.CRYO
	max_health = 75
	max_mana = 100
	strength = 6
	intelligence = 18
	resistance = 3
	wisdom = 14
	speed = 80.0
	base_scale = Vector2(0.17, 0.17)
	aim_tilt = true
	skill_name = "Glacial Path"
	skill_cooldown = 5.0
	# Mana: basic 6, skill 18, ultimate 30 (regen ~0.15 x wisdom per second).
	cast_mana_cost = 6
	skill_mana_cost = 18
	burst_mana_cost = 30
	burst_name = "Blizzard"
	burst_cost = 60.0
	uses_mana = true
	# Cryo: ice shards that crack where they land.
	snd_cast = [["ice_launch", -3.0, 1.0]]
	snd_impact = [["ice_impact", -3.0, 1.0], ["ice_crack", -10.0, 1.1]]
	voice = "m1"
	voice_pitch = 0.98
	effort_chance = 0.1
	sprite_offset = Vector2(8, -5)
	block_stamina_max = 15.0
	# A thin arcane barrier instead of a weapon guard.
	snd_block = [["magic_shield", -2.0, 1.2]]
	dodge_distance = 46.0
	attack_kind = AttackKind.CAST
	# Attack1.png: staff raised for three frames, the spell leaves on frame 4.
	attack_startup = 0.35
	attack_cycle = 0.6
	attack_impact_frame = 4
	attack_move_mult = 0.6

# E: Glacial Path. Ice spikes burst out of the floor one after another along the aim line,
# up to the first wall; each one hurts what stands on it (Cryo), and the last, biggest one
# freezes it solid.
func _do_skill() -> void:
	aim_direction = _raw_aim_dir()
	_start_action("attack2", attack_startup, attack_cycle, -1, _glacial_path)

func _glacial_path() -> void:
	var dir := aim_direction
	var start := global_position + dir * 12.0
	var q := PhysicsRayQueryParameters2D.create(start, start + dir * 96.0, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var length := start.distance_to(hit["position"]) - 4.0 if hit else 96.0
	var steps := 6
	for i in steps:
		if not is_alive:
			return
		var at := start + dir * (length * i / float(steps - 1))
		var last := i == steps - 1
		CombatFX.spike("Ice", at, 16.0 if not last else 24.0, 2 if not last else 3)
		var hits := _aoe(at, 12.0 if not last else 18.0, roundi(_spell_damage() * (0.6 if not last else 1.2)), ElementalSystem.Element.CRYO, 30.0)
		if last:
			CombatFX.pvfx("frost-nova", at, 0.55)
			for e in hits:
				if e.has_method("apply_freeze"):
					e.apply_freeze(1.6)
			CombatFX.shake(2.0, 0.15)
		AudioManager.play_bank_at("ice_crack", at, -6.0, 1.3 + i * 0.05)
		await get_tree().create_timer(0.06).timeout

# Q: a blizzard at the crosshair: frost every half second for 3 s.
func _do_burst() -> void:
	var at := _target_point(cast_range)
	_start_action("attack2", 0.3, 0.6, -1, func():
		AbilityZone.spawn(self, at, {"radius": 48.0, "duration": 3.0, "tick": 0.5, "damage": roundi(_spell_damage() * 0.5),
			"element": ElementalSystem.Element.CRYO, "style": "ice"}))
