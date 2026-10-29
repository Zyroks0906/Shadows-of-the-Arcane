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
	skill_name = "Frost Gale"
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

# E: Frost Gale. A fan of freezing air bursts forward from a hand's breadth in front of the
# mage (never from her body): a crystal front sweeps out, shards fly, mist hangs for a
# moment. Everything in the cone takes Cryo damage; whoever is caught close is frozen.
const GALE_RANGE := 60.0
const GALE_HALF_ARC := 30.0 # degrees either side of the aim
const GALE_GAP := 10.0      # how far in front of the mage it starts

func _do_skill() -> void:
	# Aim assist: the gale turns onto an enemy near the crosshair.
	aim_direction = _assisted_dir(GALE_RANGE + 20.0)
	_start_action("attack2", attack_startup, attack_cycle, -1, _frost_gale)

func _frost_gale() -> void:
	var dir := aim_direction
	var origin := global_position + Vector2(0, -3) + dir * GALE_GAP

	_Gale.spawn(get_parent(), origin, dir, GALE_RANGE, deg_to_rad(GALE_HALF_ARC))
	AudioManager.play_bank("ice_launch", -2.0, 0.9)
	AudioManager.play_bank_at("ice_crack", origin + dir * 30.0, -6.0, 1.2)
	CombatFX.shake(1.5, 0.12)
	var dmg := roundi(_spell_damage() * 1.3)
	for e in _enemies():
		if not (e is Node2D) or not e.is_alive:
			continue
		var to: Vector2 = e.global_position - origin
		if to.length() > GALE_RANGE + 6.0 or absf(dir.angle_to(to)) > deg_to_rad(GALE_HALF_ARC + 6.0):
			continue
		e.take_elemental_hit(dmg, ElementalSystem.Element.CRYO, self)
		if e.has_method("apply_knockback"):
			e.apply_knockback(to.normalized() * 90.0)
		if to.length() < GALE_RANGE * 0.55 and e.has_method("apply_freeze"):
			e.apply_freeze(1.2)
		on_hit_landed("skill")

# Q: a blizzard on the nearest enemy in sight (the crosshair if none): frost every half
# second for 4.5 s.
func _do_burst() -> void:
	var at := _burst_target(cast_range)
	_start_action("attack2", 0.3, 0.6, -1, func():
		AbilityZone.spawn(self, at, {"radius": 48.0, "duration": 4.5, "tick": 0.5, "damage": roundi(_spell_damage() * 0.5),
			"element": ElementalSystem.Element.CRYO, "style": "ice"}))



# The gale itself, after Kaeya's Frostgnaw: a flash at the hand, thin streaks of ice
# shooting forward in a narrow fan, a cloud of frost billowing where they end, and loose
# crystal shards. No filled wedge: light, streaks and mist.
class _Gale extends Node2D:
	var reach := 60.0
	var half := 0.5
	var t := 0.0
	var streaks: Array = [] # [angle, start delay, length, speed]
	var shards: Array = []  # [angle, speed, size, colour]
	var puffs: Array = []   # [angle, distance, radius, drift]
	const LIFE := 0.75

	static func spawn(parent: Node, at: Vector2, dir: Vector2, r: float, half_arc: float) -> void:
		var g := _Gale.new()
		g.reach = r
		g.half = half_arc
		g.rotation = dir.angle()
		g.z_index = 4
		parent.add_child(g)
		g.global_position = at

	func _ready() -> void:
		for i in 16:
			# Most streaks run near the aim line, a few spread wider.
			var spread := (randf() + randf() - 1.0) * half
			streaks.append([spread, randf() * 0.1, randf_range(10.0, 20.0), randf_range(220.0, 300.0)])
		var cols := [Color(1, 1, 1), Color(0.78, 0.94, 1.0), Color(0.5, 0.8, 1.0)]
		for i in 22:
			shards.append([randf_range(-half, half) * 1.1, randf_range(60.0, 130.0), 1.0 if randf() < 0.75 else 2.0, cols[randi() % 3]])
		for i in 7:
			puffs.append([randf_range(-half, half) * 0.7, reach * randf_range(0.65, 0.95), randf_range(4.0, 7.0), randf_range(6.0, 14.0)])

	func _process(delta: float) -> void:
		t += delta
		if t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((LIFE - t) / 0.35, 0.0, 1.0)
		# Flash at the hand.
		if t < 0.14:
			var k := 1.0 - t / 0.14
			draw_circle(Vector2.ZERO, 5.0 * k + 1.0, Color(0.85, 0.96, 1.0, 0.7 * k))
			draw_line(Vector2(-4, 0) * k, Vector2(7, 0) * k, Color(1, 1, 1, k), 1.0)
			draw_line(Vector2(0, -4) * k, Vector2(0, 4) * k, Color(1, 1, 1, k), 1.0)
		# The frost cloud billows up where the streaks end.
		var cloud := clampf((t - 0.08) / 0.25, 0.0, 1.0)
		for p in puffs:
			var at: Vector2 = Vector2.from_angle(p[0]) * p[1] + Vector2(p[3] * t, 0)
			var rr: float = p[2] * (0.4 + 0.8 * cloud)
			draw_circle(at, rr, Color(0.72, 0.88, 1.0, 0.16 * cloud * fade))
			draw_circle(at - Vector2(1, 1), rr * 0.55, Color(0.92, 0.97, 1.0, 0.18 * cloud * fade))
		# Ice streaks: a faint cyan glow under a bright thin core, flying out and fading.
		for s in streaks:
			var tt: float = t - s[1]
			if tt <= 0.0:
				continue
			var head: float = minf(s[3] * tt, reach)
			var tail := maxf(head - s[2] * (1.0 + tt * 2.0), 0.0)
			var a := clampf(1.0 - tt / 0.45, 0.0, 1.0)
			if a <= 0.0 or head <= tail:
				continue
			var dirv := Vector2.from_angle(s[0])
			draw_line(dirv * tail, dirv * head, Color(0.45, 0.78, 1.0, 0.35 * a), 3.0)
			draw_line(dirv * tail, dirv * head, Color(0.92, 0.98, 1.0, 0.95 * a), 1.0)
		# Crystal shards, slowing as they go.
		for sh in shards:
			var d: float = sh[1] * t * (1.0 - t * 0.6)
			if d > reach * 1.05:
				continue
			var at := (Vector2.from_angle(sh[0]) * d).round()
			draw_rect(Rect2(at, Vector2(sh[2], sh[2])), Color(sh[3], fade))
		# Snowflake glints that blink in the cloud.
		for k in 3:
			var at := (Vector2.from_angle(-half * 0.6 + half * 0.6 * k) * reach * 0.8).round()
			var c := Color(1, 1, 1, 0.85 * fade * cloud * float(int(t * 12.0 + k) % 2))
			draw_rect(Rect2(at - Vector2(1, 0), Vector2(3, 1)), c)
			draw_rect(Rect2(at - Vector2(0, 1), Vector2(1, 3)), c)
