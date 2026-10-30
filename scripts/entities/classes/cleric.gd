extends Player
class_name Cleric

# Support bruiser: gauntlet punches; E heals and shields, Q is an earthquake.
func _init() -> void:
	character_name = "Cleric"
	base_element = ElementalSystem.Element.GEO
	max_health = 110
	max_mana = 100
	strength = 10
	intelligence = 10
	resistance = 8
	wisdom = 12
	speed = 72.0 # walks (its pack has no run): a steadier pace
	base_scale = Vector2(0.09, 0.09)
	skill_name = "Sanctuary"
	skill_cooldown = 8.0
	burst_name = "Earthsplitter"
	burst_cost = 60.0
	# Dark zealot with gauntlets: punches with a dull body thud, a grave, dark voice.
	snd_swing = [["fist_swing", -4.0, 0.85]]
	snd_hit = [["punch", 0.0, 0.85], ["heavy_flesh", -8.0, 0.8]]
	voice = "m4"
	voice_pitch = 0.8
	effort_chance = 0.3
	block_stamina_max = 60.0
	snd_block = [["heavy_clash", -2.0, 1.0]]
	dodge_distance = 40.0
	# Gauntlet punch: the fist slams down on frame 2 of 5. Short reach, quick.
	attack_reach = 18.0
	attack_arc_deg = 90.0
	attack_startup = 0.12
	attack_cycle = 0.42
	attack_impact_frame = 2
	attack_knockback = 170.0


func _heal() -> void:
	var heal := 10 + wisdom
	recover_health(heal)
	add_shield(15, 6.0, ElementalSystem.get_element_color(base_element))
	CombatFX.floating_label(global_position, "+%d HP" % heal, Color.GREEN, 1.0)
	CombatFX.burst(global_position, Color(0.6, 1.0, 0.6), 20, 60.0, 0.6, -60.0, 2.5)
	CombatFX.pvfx("radiant-heal", global_position, 0.55, 0.0, Color.WHITE, 1.0, 31, self)
	AudioManager.play_bank("heal", -2.0, 0.8)
	AudioManager.play_bank("magic_shield", -6.0, 0.8)
	_aoe(global_position, 26.0, roundi(_melee_damage() * 0.5), ElementalSystem.Element.GEO, 180.0)
	CombatFX.spike_ring("Crystal", global_position, 16.0, 6, 12.0)

# E: heals, raises a Geo shield and pushes nearby enemies away.
func _do_skill() -> void:
	_start_action("attack2", 0.2, 0.5, -1, _heal)

# Q: drives both gauntlets into the ground: an earthquake that stuns everything around.
func _do_burst() -> void:
	_start_action("Attack", 0.35, 0.8, attack_impact_frame, _quake)

func _quake() -> void:
	_aoe(global_position, 56.0, roundi(_melee_damage() * 2.4), ElementalSystem.Element.GEO, 240.0, 1.0, "burst")
	# The fist strikes the floor just in front of the cleric: everything starts there, at
	# foot level, not from the body.
	var strike := global_position + aim_direction.normalized() * 9.0
	CombatFX.spike_ring("Earth", strike, 34.0, 10, 18.0)
	CombatFX.ground_slam(strike, 56.0, Color(0.72, 0.6, 0.4))
	CombatFX.hit_stop(0.08)
