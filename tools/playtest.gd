extends Node2D

# Scripted play session with a real window: drives the player with simulated input,
# measures movement and attack timings, and saves screenshots for review.
# Usage: Godot.exe --path . res://tools/playtest.tscn -- <out_dir> [class ...]
# Classes: knight, samurai, barbarian, assassin, cleric, archer, mage, necromancer.

const CLASSES := {
	"knight": GameManager.CharacterClass.KNIGHT, "samurai": GameManager.CharacterClass.SAMURAI,
	"barbarian": GameManager.CharacterClass.BARBARIAN, "assassin": GameManager.CharacterClass.ASSASSIN,
	"cleric": GameManager.CharacterClass.CLERIC, "archer": GameManager.CharacterClass.ARCHER,
	"mage": GameManager.CharacterClass.MAGE, "necromancer": GameManager.CharacterClass.NECROMANCER,
}

var out_dir := "user://playtest"
var player: Player
var level: Node

func _ready() -> void:
	Progression.auto_pick = true
	EliteAffix.enabled = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var classes: Array = args.slice(1) if args.size() > 1 else ["knight", "archer", "mage"]
	# Special tokens: "lineup" (all classes side by side), "torches", "wind".
	for c in classes:
		match c:
			"lineup": await _lineup()
			"enemies": await _enemy_lineup()
			"guard": await _guard_session()
			"chest": await _chest_session()
			_ when c.begins_with("abil:"): await _ability_session(c.substr(5))
			_ when c.begins_with("look:"): await _look_session(c.substr(5))
			"level1": await _level1_session()
			"victory": await _victory_session()
			"boss": await _boss_session()
			"perks": await _perks_session()
			"elites": await _elites_session()
			"death": await _death_session()
			"crucible": await _crucible_session()
			"controls": await _controls_session()
			"settings": await _settings_session()
			"zones": await _zones_session()
			"difficulty": await _difficulty_session()
			"champion": await _champion_session()
			"plates": await _plates_session()
			"tour": await _tour_session()
			"vault": await _vault_session()
			"puzzles": await _puzzles_session()
			"shield": await _shield_session()
			"newpuzzles": await _new_puzzles_session()
			"pots": await _pots_session()
			"pause": await _pause_session()
			"exits": await _exits_session()
			"bot_ambush": await _bot_ambush("barbarian")
			"bot_ambush_archer": await _bot_ambush("archer")
			"bot_ambush_mage": await _bot_ambush("mage")
			"bot_puzzles": await _bot_puzzles()
			"fortune": await _fortune_session()
			"bolts": await _bolts_session()
			"ult_aim": await _ult_aim_session()
			"leaks": await _leaks_session()
			"vault_exit": await _vault_exit_session()
			"golem_gate": await _golem_gate_session()
			"merchant": await _merchant_session()
			"stride": await _stride_session()
			"pickups": await _pickups_session()
			"relics": await _relics_session()
			"props_reach": await _props_reach_session()
			"phase3": await _phase3_session()
			"elites2": await _elites2_session()
			"anims": await _anims_session()
			"variants": await _variants_session()
			"wallprops": await _wallprops_session()
			"chamber": await _chamber_session()
			"secrets": await _secrets_session()
			"decor_check": await _decor_check_session()
			"bounds": await _bounds_session()
			"tutorial": await _tutorial_session()
			"leaks_orig":
				get_script() # the original map, before the east rooms were opened
				load("res://scripts/levels/level1_extras.gd").skip_east_open = true
				await _leaks_session()
			"torches": await _torches()
			"wind":
				await _wind_session("knight")
				await _wind_session("assassin")
			_: await _session(c)
	print("PLAYTEST DONE")
	get_tree().quit()

func _load_level(path: String, cls: String) -> void:
	GameManager.set_selected_class(CLASSES[cls])
	level = load(path).instantiate()
	add_child(level)
	await _wait(2.6)
	player = get_tree().get_first_node_in_group("player") as Player
	_real_max_hp = player.max_health
	player.max_health = 9999
	player.current_health = 9999
	player.current_mana = player.max_mana

func _unload() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack_1", "skill", "burst", "block"]:
		Input.action_release(a)
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _shot(name: String, around: Variant = null) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if around is Vector2:
		# Crop a 64x64 screen-pixel box around a world point and magnify it x4.
		var c: Vector2 = get_viewport().get_canvas_transform() * around
		var ratio := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var box := Vector2i(int(150 * ratio), int(100 * ratio))
		img = img.get_region(Rect2i(Vector2i(c * ratio) - box / 2, box))
		img.resize(450, 300, Image.INTERPOLATE_NEAREST)
	img.save_png(out_dir.path_join(name + ".png"))

func _aim_at(world: Vector2) -> void:
	var screen := get_viewport().get_canvas_transform() * world
	Input.warp_mouse(screen)
	var ev := InputEventMouseMotion.new()
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)

func _dummy(pos: Vector2) -> Enemy:
	var s: Enemy = load("res://scenes/entities/Enemies/slime_base.tscn").instantiate()
	s.detection_range = 0
	s.attack_range = 0
	level.add_child(s)
	s.global_position = pos
	s.max_health = 500
	s.current_health = 500
	return s

func _session(cls: String) -> void:
	print("=== ", cls)
	await _load_level("res://scenes/levels/level_1.tscn", cls)
	GameManager.debug_mode = true
	# Clear the real enemies near spawn so the dummies are the only targets.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player.global_position) < 250:
			e.queue_free()
	await _wait(0.2)

	# 1) Acceleration and top speed.
	var p0 := player.global_position
	Input.action_press("move_down")
	await _wait(0.1)
	var v_early := player.velocity.length()
	await _wait(0.6)
	var v_top := player.velocity.length()
	Input.action_release("move_down")
	await _wait(0.15)
	print("  speed: after 0.1 s %.0f px/s, top %.0f px/s (stat %.0f), stops at %.0f px/s" % [v_early, v_top, player.speed, player.velocity.length()])
	player.global_position = p0
	await _wait(0.2)

	# 2) Aim behind while running away: run left, aim and attack to the right.
	var ranged := player is Archer or player.attack_kind == Player.AttackKind.CAST
	var gap := 90.0 if ranged else 20.0
	var target := _dummy(player.global_position + Vector2(gap, 0))
	var decoy := _dummy(player.global_position + Vector2(-60, 40))
	await _wait(0.3)
	_aim_at(target.global_position)
	await _wait(0.1)
	await _shot("%s_1_aim" % cls)
	var hp := target.current_health
	Input.action_press("move_left")
	await _wait(0.05)
	var t0 := Time.get_ticks_msec()
	if player is Archer:
		Input.action_press("attack_1")
		await _wait(0.5)
		await _shot("%s_2_drawing" % cls)
		await _wait(0.5)
		await _shot("%s_3_full_charge" % cls)
		Input.action_release("attack_1")
		await _wait(0.08)
		await _shot("%s_4_arrow" % cls)
	else:
		await _tap("attack_1")
		await _wait(player.attack_startup * 0.5)
		await _shot("%s_2_windup" % cls)
		await _wait(player.attack_startup * 0.5 + 0.03)
		await _shot("%s_3_impact" % cls)
		await _wait(0.12)
		await _shot("%s_4_follow" % cls)
	while target.current_health == hp and Time.get_ticks_msec() - t0 < 2500:
		await get_tree().physics_frame
	Input.action_release("move_left")
	print("  hit behind while fleeing: %s, %d dmg after %d ms" % [target.current_health < hp, hp - target.current_health, Time.get_ticks_msec() - t0])
	await _wait(0.6)

	# 3) Cadence: mash attack for 2 s and count hits.
	if not (player is Archer):
		player.global_position = target.global_position - Vector2(gap, 0)
		target.knockback = Vector2.ZERO
		await _wait(0.3)
		_aim_at(target.global_position)
		var hits := 0
		var last := target.current_health
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2000:
			await _tap("attack_1")
			await _wait(0.03)
			if target.current_health < last:
				hits += 1
				last = target.current_health
			player.global_position = target.global_position - Vector2(gap, 0)
		print("  mashing 2 s -> %d hits (cycle %.2f s)" % [hits, player.attack_cycle])

	# 4) Reach: step back until the attack no longer connects.
	if not ranged:
		var reach_hit := 0.0
		for d in [14.0, 20.0, 26.0, 32.0, 40.0]:
			target.knockback = Vector2.ZERO
			player.global_position = target.global_position - Vector2(d, 0)
			await _wait(0.6)
			_aim_at(target.global_position)
			var before := target.current_health
			player.attack()
			await _wait(player.attack_cycle + 0.05)
			if target.current_health < before:
				reach_hit = d
		print("  furthest centre distance that still hit: %.0f px (reach %.0f)" % [reach_hit, player.attack_reach])
	target.queue_free()
	decoy.queue_free()
	GameManager.debug_mode = false
	await _unload()

func _wind_session(cls: String) -> void:
	await _load_level("res://scenes/levels/level_3.tscn", cls)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var zone: ElementZone = level.get_node("Zones/Wind2")
	var start := zone.global_position + Vector2(zone.size.x - 40, zone.size.y / 2.0)
	player.global_position = start
	await _wait(0.4)
	Input.action_press("move_left")
	await _wait(0.3)
	var a := player.global_position.x
	await _wait(1.0)
	var against := a - player.global_position.x
	Input.action_release("move_left")
	await _shot("wind_%s" % cls)
	player.global_position = zone.global_position + Vector2(40, zone.size.y / 2.0)
	await _wait(0.4)
	Input.action_press("move_right")
	await _wait(0.3)
	a = player.global_position.x
	await _wait(1.0)
	var with_wind := player.global_position.x - a
	Input.action_release("move_right")
	print("  wind (%s, speed %.0f): against %.0f px/s, with %.0f px/s" % [cls, player.speed, against, with_wind])
	await _unload()

# Every class side by side at in-game scale: idle row, then the attack frame row.
func _lineup() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	player.visible = false
	var names := ["knight", "samurai", "gladiator", "assassin", "cleric", "archer", "mage", "necromancer"]
	var dummies := []
	var origin := player.global_position + Vector2(-98, 0)
	for i in names.size():
		var d: Player = load("res://scenes/entities/player.tscn").instantiate()
		d.set_script(load("res://scripts/entities/classes/%s.gd" % names[i]))
		d._init()
		d.find_child("AnimatedSprite2D").sprite_frames = load("res://assets/sprites/sprite_frames/%s.tres" % names[i])
		level.add_child(d)
		d.remove_from_group("player")
		d._camera_node.enabled = false
		d._crosshair.queue_free()
		d.set_physics_process(false)
		d.collision_layer = 0
		d.collision_mask = 0
		d._apply_anim_scale()
		d.global_position = origin + Vector2(i * 28, 0)
		dummies.append(d)
	await _wait(0.4)
	await _shot("lineup_idle")
	for d in dummies:
		d._play_animation("Attack", BaseCharacter.AnimPriority.ACTION)
		var n: int = d.animated_sprite.sprite_frames.get_frame_count(d.animated_sprite.animation)
		d.animated_sprite.frame = n / 3
		d.animated_sprite.pause()
	await _wait(0.1)
	await _shot("lineup_attack")
	for d in dummies:
		d.animated_sprite.frame = (n_frames(d) * 2) / 3
	await _wait(0.1)
	await _shot("lineup_attack_late")
	await _unload()

func n_frames(d: Player) -> int:
	return d.animated_sprite.sprite_frames.get_frame_count(d.animated_sprite.animation)

# Close-ups of wall torches on maps 2 and 3, two animation frames apart.
func _torches() -> void:
	for path in ["res://scenes/levels/level_2.tscn", "res://scenes/levels/level_3.tscn"]:
		await _load_level(path, "knight")
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		var torch: AnimatedSprite2D = null
		for n in level.get_node("Lighting").get_children():
			if n is AnimatedSprite2D and n.global_position.distance_to(player.global_position) < 400:
				torch = n
				break
		if torch:
			player.global_position = torch.global_position + Vector2(0, 30)
			player.visible = false
			await _wait(1.5)
			for k in 2:
				torch.frame = k * 2
				torch.pause()
				await _wait(0.05)
				await _shot("torch_%s_f%d" % [path.get_file().get_basename(), k * 2], torch.global_position)
		await _unload()

# The knight next to every enemy at in-game scale.
func _enemy_lineup() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.2)
	var scenes := ["Skeleton", "Rat", "slime_base", "slime_base", "Bat", "Orc", "Wisp", "Golem", "GuardianBoss", "Demon"]
	var x := -150.0
	var k := 0
	for n in scenes:
		var e: Node2D = load("res://scenes/entities/Enemies/%s.tscn" % n).instantiate()
		k += 1
		if n == "slime_base":
			e.base_element = ElementalSystem.Element.HYDRO if k == 3 else ElementalSystem.Element.PYRO
		e.detection_range = 0
		e.attack_range = 0
		level.add_child(e)
		e.set_physics_process(false)
		e.global_position = player.global_position + Vector2(x, 0)
		x += 40.0 if not (n in ["Golem", "GuardianBoss"]) else 60.0
	player.global_position += Vector2(-60, 0)
	player.set_physics_process(false)
	await _wait(1.0)
	await _shot("enemy_lineup")
	await _unload()

# A real skeleton attacks the knight: first a held block, then a timed parry.
func _guard_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.2)
	var sk: Enemy = load("res://scenes/entities/Enemies/Skeleton.tscn").instantiate()
	level.add_child(sk)
	sk.global_position = player.global_position + Vector2(16, 0)
	await _wait(0.1)
	_aim_at(sk.global_position)
	Input.action_press("block")
	# Wait for the wind-up to start, then grab the telegraph and the blocked hit.
	while not sk.is_attacking:
		await get_tree().physics_frame
	await _wait(sk.attack_delay * 0.7)
	await _shot("guard_1_telegraph", player.global_position + Vector2(8, 0))
	await _wait(sk.attack_delay * 0.3 + 0.03)
	await _shot("guard_2_blocked", player.global_position + Vector2(8, 0))
	print("  block: hp %d/%d stamina %.0f" % [player.current_health, player.max_health, player._guard.stamina])
	Input.action_release("block")
	# Parry: raise the guard right before the next blow.
	while sk.is_attacking or not sk.can_attack:
		await get_tree().physics_frame
	player.global_position = sk.global_position - Vector2(16, 0)
	while not sk.is_attacking:
		await get_tree().physics_frame
	await _wait(sk.attack_delay - 0.08)
	Input.action_press("block")
	await _wait(0.12)
	await _shot("guard_3_parry", player.global_position + Vector2(8, 0))
	print("  parry: hp %d stamina %.0f skeleton stunned %s" % [player.current_health, player._guard.stamina, Time.get_ticks_msec() < sk._stunned_until_ms])
	Input.action_release("block")
	await _wait(0.3)
	await _shot("guard_4_stunned", player.global_position + Vector2(8, 0))
	await _unload()

# Opens a chest in level_1 and records the drop arc, the landed items and the pickup banner.
func _chest_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var chest: Chest = null
	for c in get_tree().get_nodes_in_group("interactable"):
		pass
	for n in level.find_children("*", "Node2D", true, false):
		if n is Chest:
			chest = n
			break
	if not chest:
		print("  no chest found")
		return
	chest.coins_amount = 7
	player.global_position = chest.global_position + Vector2(0, 26)
	await _wait(0.8)
	chest.open_chest(player)
	await _wait(0.35)
	await _shot("chest_1_opening", chest.global_position)
	await _wait(0.55)
	await _shot("chest_2_flying", chest.global_position)
	await _wait(0.8)
	await _shot("chest_3_landed", chest.global_position)
	var item: Node2D = chest.hidden_item
	if item and is_instance_valid(item):
		player.global_position = item.global_position
		await _wait(0.4)
		await _shot("chest_4_banner")
	print("  chest opened, hidden item: ", item)
	await _unload()

# Casts a class's E and Q into a small group of dummies and records the effects.
func _ability_session(cls: String) -> void:
	await _load_level("res://scenes/levels/level_1.tscn", cls)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	player.god_mode = true
	await _wait(0.3)
	var dummies := []
	for off in [Vector2(30, -8), Vector2(42, 10), Vector2(56, -2)]:
		dummies.append(_dummy(player.global_position + off))
	await _wait(0.4)
	_aim_at(player.global_position + Vector2(48, 0))
	await _wait(0.1)
	player.use_skill()
	await _wait(0.25)
	await _shot("abil_%s_E1" % cls)
	await _wait(0.35)
	await _shot("abil_%s_E2" % cls)
	await _wait(1.0)
	for d in dummies:
		if is_instance_valid(d):
			d.knockback = Vector2.ZERO
	player.energy = player.burst_cost
	_aim_at(player.global_position + Vector2(48, 0))
	await _wait(0.1)
	player.use_burst()
	for k in 5:
		await _wait(0.3)
		await _shot("abil_%s_Q%d" % [cls, k + 1])
	await _wait(1.6)
	await _shot("abil_%s_Q_late" % cls) # what an ultimate leaves behind
	await _unload()

# level_1 additions: altar + sealed chest, the perk picker, the hatch trap.
func _level1_session() -> void:
	Progression.reset_run()
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	await _wait(0.5)
	player.global_position = Vector2(612, 130)
	await _wait(1.0)
	await _shot("l1_altar_and_sealed")
	var orig := Progression.auto_pick
	Progression.auto_pick = false
	Progression.add_xp(Progression.xp_needed())
	await _wait(0.8)
	await _shot("l1_perk_picker")
	var ev := InputEventKey.new()
	ev.keycode = KEY_2
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.6)
	Progression.auto_pick = orig
	await _shot("l1_after_pick")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	GameManager.notify_boss_defeat("Golem")
	var hatch: Node2D = null
	for n in level.get_children():
		if n is Trapdoor: hatch = n
	player.global_position = hatch.global_position + Vector2(0, 26)
	await _wait(1.0)
	hatch.interact(player)
	await _wait(0.35)
	await _shot("l1_hatch_opening", hatch.global_position)
	await _wait(1.6)
	await _shot("l1_hatch_trap", hatch.global_position)
	await _wait(2.5)
	await _shot("l1_crypt_inside")
	await _unload()

# Boss bar and parry cue: stand next to level_1's Golem, hit it, and catch a skeleton's "!".
func _boss_session() -> void:
	Progression.reset_run()
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	await _wait(0.5)
	var boss: Node2D = get_tree().get_first_node_in_group("bosses")
	player.global_position = boss.global_position + Vector2(-40, 0)
	await _wait(0.4)
	boss.take_damage(120)
	await _wait(1.2)
	await _shot("boss_bar")
	await _shot("boss_gates", Vector2(846, 466))
	for i in 8:
		await _wait(0.6)
		await _shot("boss_fight_%d" % i)
	await _unload()

# The perk screen with every rarity: rare/epic/legendary, then common/uncommon/rare.
func _perks_session() -> void:
	Progression.reset_run()
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	await _wait(3.0)
	for set in [[["zeal", 2], ["vampirism", 3], ["mastery", 4]], [["might", 0], ["swiftness", 1], ["bulwark", 2]]]:
		var cards := []
		for c in set:
			cards.append({"id": c[0], "rarity": c[1]})
		PerkPicker.offer("LEVEL 2", cards)
		await _wait(0.9)
		await _shot("perks_%d_a" % cards[2]["rarity"])
		await _wait(0.7)
		await _shot("perks_%d_b" % cards[2]["rarity"])
		var ev := InputEventKey.new()
		ev.keycode = KEY_1
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.8)
	await _unload()

# One elite of each kind in a row, then the volatile one blows up.
func _elites_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(3.0)
	var base := player.global_position + Vector2(-75, -30)
	var made := []
	EliteAffix.enabled = true
	for k in EliteAffix.Kind.size():
		EliteAffix.forced = k
		var path: String = ["res://scenes/entities/Enemies/Skeleton.tscn", "res://scenes/entities/Enemies/slime_base.tscn"][k % 2]
		var e: Enemy = load(path).instantiate()
		e.detection_range = 0
		level.add_child(e)
		e.global_position = base + Vector2(30 * k, 0)
		made.append(e)
	EliteAffix.forced = -1
	EliteAffix.enabled = false
	await _wait(0.8)
	await _shot("elites_row")
	var vol: Enemy = made[EliteAffix.Kind.VOLATILE]
	vol.receive_damage(9999)
	await _wait(0.5)
	await _shot("elites_volatile_warn")
	await _wait(0.45)
	await _shot("elites_volatile_blast")
	await _wait(1.0)
	await _shot("elites_loot")
	await _unload()

# The death screen after a short run: a few perks, some kills, slain by an elite.
func _death_session() -> void:
	Progression.reset_run()
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	await _wait(1.0)
	for id in ["might", "vitality", "zeal", "greed"]:
		Progression.take({"id": id, "rarity": 1})
	Progression.stat("kills", 23)
	Progression.stat("elites", 2)
	Progression.stat("damage", 1840)
	Progression.stat("coins", 37)
	EliteAffix.enabled = true
	EliteAffix.forced = EliteAffix.Kind.SWIFT
	var e: Enemy = load("res://scenes/entities/Enemies/Skeleton.tscn").instantiate()
	level.add_child(e)
	e.global_position = player.global_position + Vector2(40, 0)
	EliteAffix.forced = -1
	EliteAffix.enabled = false
	await _wait(0.3)
	player.god_mode = false
	player.max_health = 150
	player.current_health = 5
	player.take_elemental_hit(50, ElementalSystem.Element.NONE, e)
	await _wait(4.0)
	await _shot("death_screen")
	DeathScreen._open.queue_free()
	DeathScreen._open = null
	get_tree().paused = false
	await _unload()

# The Alchemist's Crucible in the Undercroft: buried, rises when the room is cleared, the
# trade menu, and the potions it throws out.
func _crucible_session() -> void:
	Progression.reset_run()
	await _load_level("res://scenes/levels/level_1.tscn", "mage")
	player.god_mode = true
	await _wait(1.0)
	var t: Transmuter = null
	for n in level.find_children("*", "StaticBody2D", true, false):
		if n is Transmuter:
			t = n
	var room: ArenaRoom = null
	for r in get_tree().get_nodes_in_group("arena_rooms"):
		if r.contains(t.global_position):
			room = r
	player.global_position = t.global_position + Vector2(0, 30)
	await _wait(0.8)
	await _shot("crucible_0_buried")
	room._clear()
	await _wait(1.9)
	await _shot("crucible_1_rising")
	await _wait(1.6)
	await _shot("crucible_2_risen")
	GameManager.mana_potions = 3
	GameManager.health_potions = 2
	GameManager.total_coins = 9
	await _wait(0.3)
	player.global_position = t.global_position + Vector2(0, 30)
	await _wait(0.6)
	await _shot("crucible_3_flasks", t.global_position + Vector2(0, -16))
	t.interact(player)
	await _wait(0.5)
	await _shot("crucible_4_menu")
	for k in [KEY_1, KEY_1]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.3)
	await _shot("crucible_5_after_trade")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(1.0)
	await _shot("crucible_6_drops")
	await _unload()

# Options > Controls with a clash, then the unsaved-changes prompt.
func _controls_session() -> void:
	ControlsMenu.open_menu()
	await _wait(0.5)
	var m := ControlsMenu._open
	m._table["interact"][1] = "key:%d" % KEY_Q
	m._refresh()
	await _wait(0.2)
	await _shot("controls_menu")
	m._try_close()
	await _wait(0.3)
	await _shot("controls_unsaved")
	m._close()
	await _wait(0.2)

# Settings: the AUDIO page (no scrollbar), then the CONTROLS tab replacing it.
func _settings_session() -> void:
	var o: Node = load("res://scenes/ui/OptionsOverlay.tscn").instantiate()
	add_child(o)
	await _wait(0.3)
	o.show_options()
	await _wait(0.4)
	await _shot("settings_audio")
	o._open_controls()
	await _wait(0.5)
	await _shot("settings_controls")
	ControlsMenu._open._close()
	await _wait(0.3)
	await _shot("settings_back_to_audio")
	o.queue_free()

# Blizzard and the tornado side by side in front of the player.
func _zones_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "mage")
	player.god_mode = true
	await _wait(3.5)
	AbilityZone.spawn(player, player.global_position + Vector2(-50, 10), {"radius": 48.0, "duration": 4.0, "tick": 0.5, "damage": 1, "element": ElementalSystem.Element.CRYO, "style": "ice"})
	AbilityZone.spawn(player, player.global_position + Vector2(55, 10), {"radius": 40.0, "duration": 4.0, "tick": 0.45, "damage": 1, "element": ElementalSystem.Element.ANEMO, "style": "wind", "pull": 30.0})
	await _wait(0.8)
	await _shot("zones_a")
	await _wait(0.6)
	await _shot("zones_b")
	await _unload()

func _difficulty_session() -> void:
	DifficultyPopup.ask(func(): pass)
	await _wait(0.6)
	await _shot("difficulty_popup")
	DifficultyPopup._open._close()
	await _wait(0.2)

func _champion_session() -> void:
	await _load_level("res://scenes/levels/level_3.tscn", "knight")
	player.god_mode = true
	await _wait(1.0)
	var boss: Node2D = get_tree().get_first_node_in_group("bosses")
	player.global_position = boss.global_position + Vector2(-60, 0)
	await _wait(0.3)
	boss.receive_damage(10)
	for i in 6:
		await _wait(0.5)
		await _shot("champion_%d" % i)
	await _unload()

func _plates_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "necromancer")
	player.god_mode = true
	await _wait(3.0)
	player.global_position = Vector2(936, 336)
	await _wait(0.8)
	await _shot("plates_on", Vector2(936, 336))
	await _unload()

func _victory_session() -> void:
	GameManager.current_map = GameManager.MAPS[0]
	# In game it is a whole scene; under this Node2D a CanvasLayer gives it the screen size.
	var holder := CanvasLayer.new()
	add_child(holder)
	var v: Node = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
	holder.add_child(v)
	await _wait(3.5)
	await _shot("victory")
	holder.queue_free()

# A walk through every level: spawn, then each interactable spot (chests, passages, puzzles,
# exits) and each boss, one frame per place, for a visual check of the whole game.
func _tour_session() -> void:
	var levels := {"level_1": "necromancer", "level_2": "knight", "level_3": "archer"}
	for lv in levels:
		await _load_level("res://scenes/levels/%s.tscn" % lv, levels[lv])
		player.god_mode = true
		await _wait(1.0)
		await _shot("tour_%s_00_spawn" % lv)
		var spots: Array[Vector2] = []
		for n in get_tree().get_nodes_in_group("interactable") + get_tree().get_nodes_in_group("bosses"):
			var at: Vector2 = (n as Node2D).global_position
			var near := false
			for s in spots:
				near = near or s.distance_to(at) < 110.0
			if not near:
				spots.append(at)
		var vault := level.find_child("Vault", true, false)
		if vault and vault.has_node("Entry"):
			spots.append((vault.get_node("Entry") as Node2D).global_position + Vector2(0, -60))
		var i := 1
		for at in spots.slice(0, 12):
			player.global_position = at + Vector2(0, 26)
			await _wait(0.7)
			await _shot("tour_%s_%02d" % [lv, i])
			i += 1
		await _unload()

func _vault_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "necromancer")
	player.god_mode = true
	await _wait(1.0)
	var rp := level.find_child("RunePuzzle", true, false) as RunePuzzle
	print("RUNES parent=", rp.get_parent().name, " z=", rp.get_parent().z_index, " tablet=", rp.tablet_pos)
	player.global_position = rp.tablet_pos + Vector2(0, 40)
	await _wait(1.0)
	await _shot("vault_runes")
	await _unload()

# Plays the three level_1 puzzles for real (as the player would) and reports each step.
func _puzzles_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "necromancer")
	player.god_mode = true
	await _wait(1.0)
	# 1. Block puzzle: stand behind each block and press F (interact) like the player.
	var pz := level.find_child("PushPuzzle", true, false) as PushPuzzle
	var down: Node = null
	for n in level.find_children("*", "Node2D", true, false):
		if n is Passage and n.going_down:
			down = n
	print("PUZZLE push: down passage locked=", down.locked if down else "none")
	player.global_position = pz.blocks[0].global_position + Vector2(0, 30)
	await _wait(0.8)
	await _shot("pz_push_before")
	for push in [[0, Vector2(0, 16)], [0, Vector2(0, 16)], [0, Vector2(0, 16)], [1, Vector2(16, 0)], [1, Vector2(16, 0)], [1, Vector2(0, -16)]]:
		var b: Node2D = pz.blocks[push[0]]
		player.global_position = b.global_position + push[1]
		await _wait(0.1)
		b.interact(player)
		await _wait(0.35)
	await _wait(0.5)
	await _shot("pz_push_after")
	print("PUZZLE push: solved=", pz.done, " down locked=", down.locked if down else "none")
	# 2. Down the stairs into the vault.
	if down:
		player.global_position = down.global_position + Vector2(0, 8)
		await _wait(0.2)
		down.interact(player)
		await _wait(1.6)
	var rp := level.find_child("RunePuzzle", true, false) as RunePuzzle
	print("PUZZLE vault: player near tablet=", player.global_position.distance_to(rp.tablet_pos) < 200.0)
	# 3. Runes: one wrong step, then the right order, walking on each stone.
	var wrong := rp.order[1]
	player.global_position = rp.stones[wrong] + Vector2(0, 20)
	await _wait(0.3)
	player.global_position = rp.stones[wrong]
	await _wait(0.4)
	print("PUZZLE vault: after wrong rune progress=", rp._progress)
	for k in rp.order:
		player.global_position = rp.stones[k] + Vector2(0, 20)
		await _wait(0.25)
		player.global_position = rp.stones[k]
		await _wait(0.35)
	await _wait(1.2)
	var open := true
	for c in rp.chests:
		open = open and c.locked_reason == ""
	print("PUZZLE vault: solved=", rp.done, " chests unlocked=", open)
	player.global_position = rp.tablet_pos + Vector2(0, 30)
	await _wait(0.6)
	await _shot("pz_vault_after")
	# 4. Arrow plates: step on every cell of the first row; at least one must fire.
	var plates := level.find_child("PressurePlates", true, false) as PressurePlates
	var fired := 0
	for c in plates._cells.slice(0, 3):
		player.global_position = (c["rect"] as Rect2).get_center()
		await _wait(0.6)
		fired += 1 if c["revealed"] else 0
	print("PUZZLE plates: cells=", plates._cells.size(), " fired in row 1=", fired)
	await _shot("pz_plates")
	await _unload()

func _shield_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "samurai")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	player.add_shield(100, 30.0, ElementalSystem.get_element_color(ElementalSystem.Element.CRYO))
	await _wait(0.6)
	await _shot("shield_full", player.global_position + Vector2(0, -8))
	player.receive_damage(10)
	await _wait(0.05)
	await _shot("shield_hit", player.global_position + Vector2(0, -8))
	player.receive_damage(60)
	await _wait(0.6)
	await _shot("shield_low", player.global_position + Vector2(0, -8))
	await _unload()

# The level 2 and 3 puzzle rooms, played through: sluices, echo crystals, sun mirrors.
func _new_puzzles_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	player.god_mode = true
	await _wait(1.0)
	var sl := level.find_child("SluicePuzzle", true, false) as SluicePuzzle
	print("NEWPZ sluice: channels=", sl.channels.size(), " levers=", sl.levers.size())
	player.global_position = sl.levers[1].global_position + Vector2(0, 14)
	await _wait(1.0)
	await _shot("np_sluice_before")
	sl.levers[0].interact(player)
	await _wait(1.6)
	await _shot("np_sluice_wrong")
	sl.levers[0].interact(player)
	await _wait(1.2)
	for i in [1, 2]:
		player.global_position = sl.levers[i].global_position + Vector2(0, 14)
		await _wait(0.2)
		sl.levers[i].interact(player)
		await _wait(1.4)
	print("NEWPZ sluice: solved=", sl.done, " full=", sl.channels.map(func(c): return c["full"]))
	player.global_position = (sl.channels[2]["rect"] as Rect2).get_center() + Vector2(-24, 0)
	await _wait(0.6)
	await _shot("np_sluice_after")
	var echo := level.find_child("EchoPuzzle", true, false) as EchoPuzzle
	player.global_position = echo.stone_pos + Vector2(0, 20)
	await _wait(0.9)
	await _shot("np_echo_playing")
	while echo._playing:
		await _wait(0.1)
	echo.strike(echo.crystals[(echo.melody[0] + 1) % 4]) # a wrong note first
	await _wait(0.2)
	await _shot("np_echo_wrong")
	await _wait(0.4)
	for r in 2:
		while echo._playing or echo.melody.is_empty():
			await _wait(0.1)
		await _wait(0.6)
		while echo._playing:
			await _wait(0.1)
		for n in echo.melody.duplicate():
			echo.strike(echo.crystals[n])
			await _wait(0.35)
		await _wait(0.4)
	await _wait(1.5)
	var gate := level.get_tree().get_nodes_in_group("puzzle_gates")
	print("NEWPZ echo: solved=", echo.done, " gate open=", gate.map(func(g): return g.is_open))
	player.global_position = echo.stone_pos + Vector2(0, -30)
	await _wait(0.6)
	await _shot("np_echo_after")
	await _unload()
	await _load_level("res://scenes/levels/level_3.tscn", "archer")
	player.god_mode = true
	await _wait(1.0)
	var mp := level.find_child("MirrorPuzzle", true, false) as MirrorPuzzle
	player.global_position = mp.source + Vector2(40, 60)
	await _wait(1.0)
	await _shot("np_mirror_before")
	var ms: Array = mp.mirrors.values()
	for mask in 32:
		for i in ms.size():
			var want := (mask >> i) & 1 == 1
			if ms[i].slash != want and not mp.done:
				ms[i].interact(player)
		if mp.done:
			break
	await _wait(1.5)
	print("NEWPZ mirror: solved=", mp.done, " gate open=", level.get_tree().get_nodes_in_group("puzzle_gates").map(func(g): return g.is_open))
	await _shot("np_mirror_after")
	await _unload()

func _pots_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "samurai")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	var pots := get_tree().get_nodes_in_group("breakables")
	print("POTS level_1 (+crypt): ", pots.size())
	var pot: Node2D = pots[0]
	for q in pots:
		if q.global_position.distance_to(player.global_position) < pot.global_position.distance_to(player.global_position):
			pot = q
	player.global_position = pot.global_position + Vector2(-16, 2)
	await _wait(0.6)
	await _shot("pot_before", pot.global_position)
	var at := pot.global_position
	player._strike_arc(Vector2.RIGHT, 22.0, 120.0, 5, 0.0)
	await _wait(0.08)
	await _shot("pot_burst", at)
	await _wait(1.0)
	await _shot("pot_after", at)
	print("POTS left after one hit: ", get_tree().get_nodes_in_group("breakables").size())
	await _unload()

func _pause_session() -> void:
	var pm: CanvasLayer = load("res://scenes/ui/PauseMenu.tscn").instantiate()
	add_child(pm)
	await _wait(0.2)
	pm.visible = true
	pm.restart_btn.pressed.emit()
	await _wait(0.3)
	await _shot("pause_restart_armed")
	pm.queue_free()

# look:x,y[,level] — one frame of level_1 (or the given level) centred on a world point.
func _look_session(arg: String) -> void:
	var parts := arg.split(",")
	var lv := "level_1" if parts.size() < 3 else parts[2]
	await _load_level("res://scenes/levels/%s.tscn" % lv, "barbarian")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.global_position = Vector2(float(parts[0]), float(parts[1]))
	await _wait(0.8)
	await _shot("look_%s_%s_%s" % [lv, parts[0], parts[1]])
	await _unload()

func _exits_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "barbarian")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var st := level.find_child("DemonStairs", true, false)
	player.global_position = st.global_position + Vector2(20, 24)
	await _wait(0.8)
	await _shot("exit_stairs_sealed")
	GameManager.notify_boss_defeat("Demon")
	await _wait(3.5)
	await _shot("exit_stairs_open")
	print("EXITS l1 stairs active=", st.active)
	# The hatch: open it, come back up, and check the pit now blocks.
	var hatch := level.find_child("*", true, false)
	for n in level.get_children():
		if n is Trapdoor:
			hatch = n
	GameManager.notify_boss_defeat("Golem")
	await _wait(0.2)
	hatch.interact(player)
	await _wait(2.5)
	hatch.climb_back()
	await _wait(1.5)
	player.global_position = hatch.global_position + Vector2(0, 20)
	await _wait(0.3)
	for i in 30:
		player.velocity = Vector2(0, -60)
		player.move_and_slide()
		await get_tree().physics_frame
	print("ORDER hatch idx=", hatch.get_index(), " z=", hatch.z_index, " player path=", player.get_path(), " z=", player.z_index, " parent idx=", player.get_parent().get_index(), " bg idx=", level.get_node("Background").get_index(), " bg z=", level.get_node("Background").z_index)
	print("EXITS hatch: player y=", player.global_position.y, " hatch y=", hatch.global_position.y, " (blocked if player stays below)")
	await _shot("exit_hatch_open")
	await _unload()
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	var ex := level.find_child("ExitPortal", true, false)
	print("EXITS l2 portal visible before boss=", ex.visible)
	GameManager.notify_boss_defeat("Guardian")
	await _wait(2.5)
	print("EXITS l2 portal visible after boss=", ex.visible, " active=", ex.active)
	await _unload()
	await _load_level("res://scenes/levels/level_3.tscn", "archer")
	var ex3 := level.find_child("ExitPortal", true, false)
	print("EXITS l3 style=", ex3.style, " children=", ex3.get_child_count())
	await _unload()

# ------------------------------------------------------------------ bot player
# Plays with the real input actions (moves, attacks, F, potions) and the mouse aim, so the
# game reacts exactly as to a person; prints BOT lines and saves numbered frames.

var _bot_shots := 0
var _real_max_hp := 100

# The bot plays with the class's real health (the other sessions use 9999).
func _bot_real_hp() -> void:
	player.max_health = _real_max_hp
	player.current_health = _real_max_hp

func _bot_say(t: String) -> void:
	print("BOT ", t)

func _bot_shot(tag: String) -> void:
	_bot_shots += 1
	await _shot("%02d_%s" % [_bot_shots, tag])

func _cell(plan: Vector2i) -> Vector2:
	return Vector2((plan.x + 3) * 16 + 8, (plan.y + 3) * 16 + 8) # builder levels pad 3 cells

func _moves(d: Vector2) -> void:
	var want := {"move_left": d.x < -2.0, "move_right": d.x > 2.0, "move_up": d.y < -2.0, "move_down": d.y > 2.0}
	for a in want:
		if want[a]:
			Input.action_press(a)
		else:
			Input.action_release(a)

func _stop() -> void:
	_moves(Vector2.ZERO)

# Walk to a point; if blocked, slide sideways for a moment like a person would.
func _walk_to(target: Vector2, timeout: float = 8.0) -> bool:
	var t := 0.0
	var check_t := 0.0
	var last := player.global_position
	var side := 0.0
	while t < timeout and is_instance_valid(player) and player.is_alive:
		var d := target - player.global_position
		if d.length() < 5.0:
			break
		if side > 0.0:
			side -= get_physics_process_delta_time()
			_moves(Vector2(-d.y, d.x).normalized() * 10.0 + d.normalized() * 3.0)
		else:
			_moves(d)
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		check_t += dt
		if check_t > 0.4:
			if player.global_position.distance_to(last) < 2.0:
				side = 0.35
			last = player.global_position
			check_t = 0.0
	_stop()
	return is_instance_valid(player) and player.global_position.distance_to(target) < 10.0

func _press_f() -> void:
	player.interact() # the F action's handler

func _enemies_near(at: Vector2, r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.is_alive and e.global_position.distance_to(at) < r:
			out.append(e)
	return out

# Fight whatever is near until nothing is left for a while. Returns stats.
func _fight(center: Vector2, radius: float, timeout: float, shot_every: float, tag: String) -> Dictionary:
	var hp0: int = player.current_health
	var pots0: int = GameManager.health_potions
	var t := 0.0
	var quiet := 0.0
	var next_shot := 0.5
	var next_skill := 2.0
	var lowest: int = player.current_health
	while t < timeout and player.is_alive:
		var foes := _enemies_near(center, radius)
		if foes.is_empty():
			quiet += 0.1
			_stop()
			if quiet > 2.5:
				break
		else:
			quiet = 0.0
			foes.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
			var f: Node2D = foes[0]
			_aim_at(f.global_position)
			var dist := f.global_position.distance_to(player.global_position)
			if dist > 20.0:
				_moves(f.global_position - player.global_position)
			else:
				_stop()
				_tap("attack_1")
			if t > next_skill and dist < 40.0:
				_tap("skill")
				next_skill = t + 4.0
			if player.current_health < player.max_health * 0.35 and GameManager.health_potions > 0:
				_tap("use_health_potion")
				_bot_say("%s: drank a potion at %d HP" % [tag, player.current_health])
		lowest = mini(lowest, player.current_health)
		if t >= next_shot:
			next_shot = t + shot_every
			await _bot_shot(tag)
		await _wait(0.1)
		t += 0.1
	_stop()
	return {"time": snappedf(t, 0.1), "hp_lost": hp0 - player.current_health, "lowest": lowest, "potions_used": pots0 - GameManager.health_potions, "alive": player.is_alive}

func _bot_ambush(cls: String) -> void:
	_bot_say("=== ambush as " + cls)
	await _load_level("res://scenes/levels/level_2.tscn", cls)
	EliteAffix.enabled = true
	GameManager.health_potions = 3
	_bot_real_hp()
	await _wait(3.5) # the level title fades, like a player taking it in
	_bot_say("start hp=%d/%d potions=%d" % [player.current_health, player.max_health, GameManager.health_potions])
	await _bot_shot("spawn")
	# Down the side passage from the entrance grotto into the Forgotten Cellar.
	for wp in [_cell(Vector2i(7, 28)), _cell(Vector2i(7, 33)), _cell(Vector2i(7, 36)), _cell(Vector2i(8, 39))]:
		var ok := await _walk_to(wp, 6.0)
		if not ok:
			_bot_say("could not reach %s (at %s)" % [wp, player.global_position])
	await _wait(0.3)
	await _bot_shot("cellar_enter")
	var room: ArenaRoom = null
	for r in level.find_child("Arenas", true, false).get_children():
		if r.room_name == "FORGOTTEN CELLAR":
			room = r
	var res := await _fight(_cell(Vector2i(8, 40)), 140.0, 60.0, 2.5, "cellar_fight")
	_bot_say("cellar fight: %s" % res)
	await _wait(1.0)
	await _bot_shot("cellar_cleared")
	if room and room.reward:
		await _walk_to(room.reward.global_position + Vector2(0, 14), 5.0)
		var coins0 := GameManager.total_coins
		var pots0 := GameManager.health_potions
		_press_f()
		await _wait(2.5)
		for off in [Vector2(-18, 10), Vector2(18, 10), Vector2(18, -16), Vector2(-18, -16), Vector2(0, 14)]:
			await _walk_to(room.reward.global_position + off, 1.5) # sweep over the drops
		await _wait(1.0)
		await _bot_shot("cellar_reward")
		_bot_say("reward: +%d coins, +%d potions" % [GameManager.total_coins - coins0, GameManager.health_potions - pots0])
	_bot_say("end hp=%d/%d potions=%d coins=%d" % [player.current_health, player.max_health, GameManager.health_potions, GameManager.total_coins])
	await _unload()

func _bot_open_chest_near(at: Vector2) -> void:
	await _walk_to(at + Vector2(0, 14), 4.0)
	var c0 := GameManager.total_coins
	var p0 := GameManager.health_potions
	_press_f()
	await _wait(2.4)
	for off in [Vector2(-16, 8), Vector2(16, 8), Vector2(0, 16)]:
		await _walk_to(at + off, 1.2)
	_bot_say("chest at %s: +%d coins, +%d potions" % [at, GameManager.total_coins - c0, GameManager.health_potions - p0])

func _bot_puzzles() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "samurai")
	_bot_real_hp()
	player.god_mode = true # the puzzles are what's being played here
	await _wait(3.0)
	# --- Sluice Hall: in from the flooded gallery.
	var sl := level.find_child("SluicePuzzle", true, false) as SluicePuzzle
	player.global_position = _cell(Vector2i(21, 10))
	await _wait(0.5)
	await _walk_to(_cell(Vector2i(17, 10)), 4.0)
	await _wait(1.5)
	await _bot_shot("sluice_arrive")
	# A first try: the top lever (it drains the near canal... and the middle one).
	var t0 := Time.get_ticks_msec()
	for i in [0, 0, 1, 2]:
		var lv: Node2D = sl.levers[i]
		await _walk_to(lv.global_position + Vector2(0, 12), 4.0)
		_press_f()
		await _wait(1.3)
		_bot_say("lever %d (drives %s, on=%s): canals full=%s" % [i + 1, lv.drives, lv.on, sl.channels.map(func(c): return c["full"])])
		await _bot_shot("sluice_lever%d" % (i + 1))
	_bot_say("sluice solved=%s after %.1fs" % [sl.done, (Time.get_ticks_msec() - t0) / 1000.0])
	var crossed := await _walk_to(_cell(Vector2i(3, 6)), 8.0)
	_bot_say("sluice: walked across the dry canals=%s" % crossed)
	await _bot_shot("sluice_grotto")
	for c in level.find_child("Items", true, false).get_children():
		if c.has_method("open_chest") and c.global_position.distance_to(_cell(Vector2i(2, 8))) < 70.0:
			await _bot_open_chest_near(c.global_position)
	# --- Echo Grotto: in from the vestibule.
	var echo := level.find_child("EchoPuzzle", true, false) as EchoPuzzle
	player.global_position = _cell(Vector2i(54, 25))
	await _wait(0.4)
	await _walk_to(echo.stone_pos + Vector2(0, 18), 6.0)
	await _wait(0.6)
	await _bot_shot("echo_listening")
	t0 = Time.get_ticks_msec()
	var mistakes := 0
	for r in 2:
		while echo._playing:
			await _wait(0.1)
		await _wait(0.4)
		var tune := echo.melody.duplicate()
		if r == 0:
			# A slip on the second note, like someone misremembering.
			var wrong: int = (tune[1] + 1) % 4
			await _walk_to(echo.crystals[tune[0]].global_position + Vector2(0, 12), 4.0)
			_press_f()
			await _wait(0.3)
			await _walk_to(echo.crystals[wrong].global_position + Vector2(0, 12), 4.0)
			_press_f()
			mistakes += 1
			await _wait(0.25)
			await _bot_shot("echo_wrong_note")
			await _wait(0.6)
			while echo._playing or not echo._playing and echo._input != 0:
				await _wait(0.1)
			while echo._playing:
				await _wait(0.1)
			await _wait(0.3)
			tune = echo.melody.duplicate()
		_bot_say("echo round %d tune=%s playing=%s" % [echo._round, tune, echo._playing])
		for n in tune:
			await _walk_to(echo.crystals[n].global_position + Vector2(0, 12), 4.0)
			_press_f()
			await _wait(0.3)
			_bot_say("  struck %d -> input=%d round=%d playing=%s" % [n, echo._input, echo._round, echo._playing])
		await _wait(1.2)
	await _wait(1.5)
	_bot_say("echo solved=%s after %.1fs, %d mistake(s)" % [echo.done, (Time.get_ticks_msec() - t0) / 1000.0, mistakes])
	await _bot_shot("echo_solved")
	var through := await _walk_to(echo.stone_pos + Vector2(0, -62), 6.0)
	_bot_say("echo: walked through the raised grate=%s" % through)
	await _bot_shot("echo_alcove")
	for c in level.find_child("Items", true, false).get_children():
		if c.has_method("open_chest") and c.global_position.distance_to(echo.stone_pos + Vector2(0, -110)) < 70.0:
			await _bot_open_chest_near(c.global_position)
	await _unload()
	# --- Sun Sanctum (level 3).
	await _load_level("res://scenes/levels/level_3.tscn", "archer")
	_bot_real_hp()
	player.god_mode = true
	await _wait(3.0)
	var mp := level.find_child("MirrorPuzzle", true, false) as MirrorPuzzle
	player.global_position = _cell(Vector2i(53, 26))
	await _wait(0.4)
	await _walk_to(_cell(Vector2i(60, 27)), 5.0)
	await _wait(0.8)
	await _bot_shot("sanctum_arrive")
	# Work out which mirrors to turn (a person follows the light; the bot just knows).
	var ms: Array = mp.mirrors.values()
	var start := ms.map(func(m): return m.slash)
	var plan := []
	for mask in 32:
		for i in ms.size():
			ms[i].slash = (mask >> i) & 1 == 1
		mp.trace()
		if mp.hit:
			for i in ms.size():
				if ms[i].slash != start[i]:
					plan.append(ms[i])
			break
	for i in ms.size():
		ms[i].slash = start[i]
	mp.trace()
	t0 = Time.get_ticks_msec()
	for m in plan:
		await _walk_to(m.global_position + Vector2(0, 12), 6.0)
		_press_f()
		await _wait(0.5)
		await _bot_shot("sanctum_turn")
	await _wait(1.5)
	_bot_say("sanctum solved=%s after %.1fs, turned %d mirror(s)" % [mp.done, (Time.get_ticks_msec() - t0) / 1000.0, plan.size()])
	await _bot_shot("sanctum_solved")
	var gate_in := await _walk_to(_cell(Vector2i(76, 27)), 8.0)
	_bot_say("sanctum: walked into the reliquary=%s" % gate_in)
	await _bot_shot("sanctum_reliquary")
	for c in level.find_child("Items", true, false).get_children():
		if c.has_method("open_chest") and c.global_position.distance_to(_cell(Vector2i(76, 27))) < 50.0:
			await _bot_open_chest_near(c.global_position)
	await _unload()

func _fortune_session() -> void:
	for lv in ["level_1", "level_2"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "samurai")
		player.god_mode = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		var sh := level.find_child("FortuneShrine", true, false) as FortuneShrine
		player.global_position = sh.global_position + Vector2(-22, 18)
		await _wait(1.0)
		await _shot("fortune_%s_world" % lv)
		await _shot("fortune_%s_zoom" % lv, sh.global_position + Vector2(0, -16))
		_bot_say("%s shrine at %s" % [lv, sh.global_position])
		await _unload()
	await _load_level("res://scenes/levels/level_2.tscn", "samurai")
	player.god_mode = true
	GameManager.total_coins = 200
	var sh2 := level.find_child("FortuneShrine", true, false) as FortuneShrine
	player.global_position = sh2.global_position + Vector2(0, 18)
	await _wait(0.5)
	sh2.interact(player)
	await _wait(0.5)
	await _shot("fortune_menu")
	var menu = FortuneShrine.FortuneMenu._open
	var tally := {}
	for i in 12:
		if not FortuneShrine.FortuneMenu.is_open():
			sh2.interact(player)
			await _wait(0.3)
			menu = FortuneShrine.FortuneMenu._open
		menu._pull()
		await _wait(0.4)
		if i == 0:
			await _shot("fortune_spinning")
		await _wait(1.6)
		if FortuneShrine.FortuneMenu.is_open():
			var r: String = menu._result.text
			tally[r] = tally.get(r, 0) + 1
			if i < 3:
				await _shot("fortune_result_%d" % i)
		else:
			tally["(closed: world effect)"] = tally.get("(closed: world effect)", 0) + 1
			await _wait(0.5)
			await _shot("fortune_effect_%d" % i)
			if PerkPicker.is_open():
				PerkPicker._open._choose(0)
				await _wait(0.6)
	_bot_say("12 pulls, coins 200 -> %d; %s" % [GameManager.total_coins, tally])
	if FortuneShrine.FortuneMenu.is_open():
		menu._close()
	await _unload()

# Enemy bolts of every element, frozen mid-flight in a column, for a look at the art.
func _bolts_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	var E := ElementalSystem.Element
	var els := [E.HYDRO, E.ANEMO, E.GEO, E.PYRO, E.CRYO, E.ELECTRO]
	for i in els.size():
		var b := ElementBolt.create(els[i], 1, Vector2.RIGHT, 0.0, null)
		level.add_child(b)
		b.global_position = player.global_position + Vector2(-30, -40 + i * 14)
	await _wait(0.4)
	await _shot("bolts_full")
	await _unload()

# Area ultimates must find the enemy by themselves: the crosshair is pointed the other way.
func _ult_aim_session() -> void:
	for cls in ["mage", "necromancer", "archer"]:
		await _load_level("res://scenes/levels/level_1.tscn", cls)
		player.god_mode = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await _wait(0.3)
		var d := _dummy(player.global_position + Vector2(64, 22))
		await _wait(0.3)
		_aim_at(player.global_position + Vector2(-90, -20)) # wrong way on purpose
		await _wait(0.1)
		player.energy = player.burst_cost
		player.use_burst()
		await _wait(1.0)
		await _shot("ult_%s" % cls)
		await _wait(2.0)
		_bot_say("%s ultimate with the crosshair away: enemy hp 500 -> %d (%s)" % [cls, d.current_health, "HIT" if d.current_health < 500 else "MISSED"])
		if cls == "mage":
			# Glacial Path aimed a little off the enemy: the assist should still land it.
			d.current_health = 500
			await _wait(1.5)
			_aim_at(d.global_position + Vector2(0, 20))
			await _wait(0.1)
			player.current_mana = player.max_mana
			player.use_skill()
			await _wait(1.0)
			await _shot("mage_glacial_off_aim")
			_bot_say("mage Glacial Path aimed 20 px off: enemy hp 500 -> %d (%s)" % [d.current_health, "HIT" if d.current_health < 500 else "MISSED"])
		await _unload()

# Walk the whole of level_1 from the spawn (flood fill over free 6 px cells) and report every
# reachable spot with no floor tile under it: a hole in the walls lets the player off the map.
func _leaks_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	# Every door and gate open: the whole map must still be sealed by its walls.
	for n in level.find_children("*", "StaticBody2D", true, false):
		if n is Door or "Gate" in String(n.name) or "Portcullis" in String(n.name) or n.get_script() and String(n.get_script().resource_path).contains("gate"):
			n.queue_free()
	await _wait(1.0)
	var floor := level.get_node("Background") as TileMapLayer
	var space := player.get_world_2d().direct_space_state
	var probe := CircleShape2D.new()
	probe.radius = 3.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = probe
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	const STEP := 6.0
	var start := player.global_position
	var seen := {Vector2i.ZERO: true}
	var parent := {}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var leaks: Array[Vector2] = []
	while not queue.is_empty() and seen.size() < 60000:
		var c: Vector2i = queue.pop_front()
		var at := start + Vector2(c) * STEP
		if floor.get_cell_source_id(floor.local_to_map(floor.to_local(at))) == -1:
			leaks.append(at)
			if leaks.size() > 400:
				break
			continue # off the floor: don't walk further out into the void
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			parent[n] = c
			q.transform = Transform2D(0.0, start + Vector2(n) * STEP)
			if space.intersect_shape(q, 1).is_empty():
				queue.append(n)
	_bot_say("leak check: %d cells reached, %d off the floor" % [seen.size(), leaks.size()])
	# The bounds guard must agree: every reachable cell counts as "on the map" for it.
	var ground := MapBounds.ground_layers(player)
	var disagree := 0
	var first := Vector2.ZERO
	for c in seen:
		var at2 := start + Vector2(c) * STEP
		q.transform = Transform2D(0.0, at2)
		if space.intersect_shape(q, 1).is_empty() and not MapBounds.on_map(ground, at2):
			disagree += 1
			if first == Vector2.ZERO:
				first = at2
	_bot_say("walkable cells the bounds guard would call off-map: %d (first at %s)" % [disagree, first])
	var walls := level.find_child("Tileset", true, false) as TileMapLayer
	for yy in range(230, 440, 16):
		var line := ""
		for xx in range(862, 1046, 16):
			var c := walls.local_to_map(walls.to_local(Vector2(xx, yy)))
			var src := walls.get_cell_source_id(c)
			line += ("   .   " if src == -1 else "%d:%2d,%2d" % [src, walls.get_cell_atlas_coords(c).x, walls.get_cell_atlas_coords(c).y]) + " "
		_bot_say("y=%3d %s" % [yy, line])
	# Which stretches of the east edge of the map's rooms are open (free of walls)?
	for x in [990.0, 996.0, 1002.0]:
		var open := []
		var run_start := -1.0
		for yy in range(0, 700, 3):
			q.transform = Transform2D(0.0, Vector2(x, yy))
			var free := space.intersect_shape(q, 1).is_empty()
			if free and run_start < 0.0:
				run_start = yy
			elif not free and run_start >= 0.0:
				open.append("%d-%d" % [run_start, yy])
				run_start = -1.0
		_bot_say("free at x=%d: %s" % [x, open])
	if not leaks.is_empty():
		# The way out: walk back from the first leak to the spawn and print the route.
		var cell := Vector2i(((leaks[0] - start) / STEP).round())
		var route: Array[Vector2] = []
		while parent.has(cell):
			route.push_front(start + Vector2(cell) * STEP)
			cell = parent[cell]
		_bot_say("route to the first leak (%d steps), every 4th point:" % route.size())
		for k in range(0, route.size(), 4):
			_bot_say("   %s" % route[k])
	var shown := {}
	for l in leaks:
		var key := Vector2i(l / 48.0)
		if not shown.has(key):
			shown[key] = true
			_bot_say("  off-floor at %s" % l)
	await _unload()

# Down into the vault, then out again by the same ladder.
func _vault_exit_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	await _wait(0.5)
	var down: Passage = null
	var up: Passage = null
	for n in level.find_children("*", "Node2D", true, false):
		if n is Passage:
			if n.going_down:
				down = n
			else:
				up = n
	down.unlock()
	player.global_position = down.global_position + Vector2(0, 8)
	await _wait(0.3)
	down.interact(player)
	await _wait(1.4)
	var ladder := level.find_child("Vault", true, false).get_node("Ladder") as Node2D
	_bot_say("in the vault at %s; ladder %s; exit passage %s" % [player.global_position, ladder.global_position, up.global_position])
	await _shot("vault_arrive", player.global_position + Vector2(0, -10))
	player.global_position = up.global_position + Vector2(0, -6)
	await _wait(0.3)
	player.interact()
	await _wait(1.4)
	_bot_say("after climbing: %s (near the hall stairs %s: %s)" % [player.global_position, down.global_position, player.global_position.distance_to(down.global_position) < 60.0])
	await _unload()

# A secret room and the story: the cracked wall blocks until three blows bring it down, the
# tablet behind it gives a page to the Journal (a test journal, never the player's).
func _secrets_session() -> void:
	Lore.use_test_journal()
	await _load_level("res://scenes/levels/level_1_s2.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	var cw := level.find_child("CrackedWall", true, false) as CrackedWall
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var walls := level.get_node("Walls") as TileMapLayer
	var probe := PhysicsPointQueryParameters2D.new()
	probe.position = cw.global_position
	probe.collision_mask = 1
	var blocked_before := not space.intersect_point(probe, 1).is_empty()
	var zcell := cw.cell
	player.global_position = cw.global_position + Vector2(0, 0) + (Vector2(18, 0) if walls.get_cell_source_id(cw.cell + Vector2i(1, 0)) == -1 else Vector2(-18, 0))
	await _wait(3.0)
	await _shot("secret_wall_before")
	for i in 3:
		cw.break_open(Vector2.LEFT)
		await _wait(0.25)
	await _wait(0.3)
	await _shot("secret_wall_after")
	var blocked_after := not space.intersect_point(probe, 1).is_empty()
	_bot_say("cracked wall: blocked before=%s, wall tile left=%s, blocked after=%s" % [blocked_before, walls.get_cell_source_id(zcell) != -1, blocked_after])
	var stones := level.find_children("*", "StaticBody2D", true, false).filter(func(n): return n is LoreStone)
	var st: LoreStone = stones[0]
	player.global_position = st.global_position + Vector2(0, 16)
	await _wait(0.6)
	await _shot("lore_stone")
	st.interact(player)
	await _wait(0.5)
	await _shot("lore_page")
	_bot_say("tablets in this map: %d; read one: page open=%s, journal %d/%d" % [stones.size(), LoreStone.LorePage.is_open(), Lore.found_count(), Lore.total()])
	LoreStone.LorePage._open.queue_free()
	LoreStone.LorePage._open = null
	get_tree().paused = false
	JournalMenu.open_menu()
	await _wait(0.4)
	await _shot("journal")
	JournalMenu._open.queue_free()
	await _unload()

# The chamber screen (seed field) and a seed shown in a level.
func _chamber_session() -> void:
	var ch: Node = load("res://scenes/Screens/SelectChamber.tscn").instantiate()
	add_child(ch)
	await _wait(1.0)
	ch._seed_edit.text = "123456"
	await _wait(0.2)
	await _shot("chamber_seed")
	ch.queue_free()
	GameManager.start_run(123456)
	_bot_say("seed 123456 draws %s" % [GameManager.run_maps.map(func(p): return p.get_file())])

# Every fortune shrine, transmuter and peddler of every map, close up against its wall.
func _wallprops_session() -> void:
	var maps := GameManager.variants(0) + GameManager.variants(1) + GameManager.variants(2)
	var k := 0
	for path in maps:
		await _load_level(path, "knight")
		player.god_mode = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await _wait(0.4)
		for n in level.find_children("*", "StaticBody2D", true, false):
			if not (n is FortuneShrine or n is Transmuter or n is Merchant):
				continue
			if n is Transmuter and n.state != Transmuter.State.ACTIVE:
				n.state = Transmuter.State.ACTIVE
				n._set_active(true)
			player.global_position = n.global_position + Vector2(-26, 22)
			await _wait(1.2)
			await _shot("wall_%02d_%s_%s" % [k, path.get_file().get_basename(), n.get_script().get_global_name()])
			k += 1
		await _unload()

# Every seeded layout of maps 2 and 3: it loads, it has what a level needs, its puzzles are
# built and wired, and no pickup sits in a wall.
func _variants_session() -> void:
	for lv in [0, 1, 2]:
		for path in GameManager.variants(lv):
			if path == GameManager.MAPS[0]:
				continue # the hand-made map 1 has its own checks
			await _load_level(path, "knight")
			player.god_mode = true
			await _wait(0.5)
			var count := func(f: Callable) -> int: return level.find_children("*", "", true, false).filter(f).size()
			var puzzles: int = count.call(func(n): return n is SluicePuzzle or n is EchoPuzzle or n is MirrorPuzzle)
			var gates_wired := get_tree().get_nodes_in_group("puzzle_gates").size()
			var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
			var probe := PhysicsPointQueryParameters2D.new()
			probe.collision_mask = 1
			var stuck := 0
			for c in get_tree().get_nodes_in_group("interactable"):
				if c.has_method("pop_out"):
					probe.position = c._item_root().global_position
					if not space.intersect_point(probe, 1).is_empty():
						stuck += 1
			var arenas := level.get_node_or_null("Arenas")
			var names := []
			if arenas:
				for a in arenas.get_children():
					names.append(a.get("room_name") if a.get("room_name") else a.name)
			_bot_say("%s: player=%s boss=%s exit=%s merchant=%s arenas=%d %s puzzles=%d puzzle_gates=%d enemies=%d pickups_in_walls=%d" % [
				path.get_file(), player != null, count.call(func(n): return n is BossBase) > 0,
				count.call(func(n): return n is LevelExit) > 0, count.call(func(n): return n is Merchant) > 0,
				arenas.get_child_count() if arenas else 0, names, puzzles, gates_wired,
				get_tree().get_nodes_in_group("enemies").size(), stuck])
			await _unload()

# Every animation of every new creature, captured close up and named in the log.
func _anims_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(4.0)
	var base := player.global_position
	for kind in ["Shieldbearer", "Charger", "Summoner", "Spitter", "Eyeling"]:
		var e := _phase3_spawn(kind, base + Vector2(20, 0))
		e.set_physics_process(false)
		e.player = player
		await _wait(0.3)
		var at := e.global_position + Vector2(0, -7)
		var log := []
		var snap := func(tag: String) -> void:
			log.append("%s=%s:%d%s" % [tag, e.animated_sprite.animation, e.animated_sprite.frame, "L" if e.animated_sprite.flip_h else "R"])
			await _shot("anim_%s_%s" % [kind, tag], at)
		e.animated_sprite.flip_h = false
		await snap.call("idleR")
		e.animated_sprite.flip_h = true
		await _wait(0.05)
		await snap.call("idleL")
		e.animated_sprite.flip_h = false
		e._play_animation("walk")
		await _wait(0.25)
		await snap.call("walk")
		e._play_animation("idle")
		await _wait(0.1)
		match kind:
			"Spitter": e._spit()
			"Summoner": e._cast_fire()
			_: e._melee_attack(e.attack_delay, 1, 0.0, "attack")
		await _wait(0.2)
		await snap.call("windup")
		await _wait(maxf(e.attack_delay, 0.5) - 0.1)
		await snap.call("strike")
		await _wait(1.0)
		e.is_attacking = false
		e._play_hurt_anim()
		await _wait(0.12)
		await snap.call("hurt")
		await _wait(0.6)
		e.die()
		await _wait(0.2)
		await snap.call("death1")
		await _wait(0.35)
		await snap.call("death2")
		_bot_say("%s: %s" % [kind, " ".join(log)])
		for x in get_tree().get_nodes_in_group("enemies"):
			x.queue_free()
		await _wait(0.6)
	await _unload()

# The two new elite kinds, measured.
func _elites2_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	var base := player.global_position
	EliteAffix.enabled = true
	EliteAffix.forced = EliteAffix.Kind.PHANTOM
	var ph := _phase3_spawn("Spitter", base + Vector2(40, 0))
	ph.set_physics_process(false)
	var landed := 0
	var phased := 0
	for i in 25:
		var h := ph.current_health
		ph.receive_damage(1)
		if ph.current_health < h:
			landed += 1
		else:
			phased += 1
		await _wait(0.2)
	_bot_say("phantom over 5 s: %d blows landed, %d passed through; alpha now %.2f" % [landed, phased, ph.modulate.a])
	ph.queue_free()
	EliteAffix.forced = EliteAffix.Kind.ELEMENTAL
	var el := _phase3_spawn("Shieldbearer", base + Vector2(40, 0))
	el.set_physics_process(false)
	await _wait(0.3)
	var h0 := el.current_health
	el.receive_damage(20)
	var plain := h0 - el.current_health
	h0 = el.current_health
	Reactions._hit(el, 20, Color.WHITE)
	_bot_say("elemental: a plain 20 hit deals %d, a reaction's 20 deals %d; carries element %d" % [plain, h0 - el.current_health, el.current_imbued_element])
	await _shot("elites2_elemental")
	EliteAffix.forced = -1
	EliteAffix.enabled = false
	el.queue_free()
	await _unload()

# Phase 3 archetypes: a line-up next to the hero, then each behaviour measured.
func _phase3_spawn(scene: String, at: Vector2) -> Enemy:
	var e: Enemy = load("res://scenes/entities/Enemies/%s.tscn" % scene).instantiate()
	level.add_child(e)
	e.global_position = at
	return e

func _phase3_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	player.god_mode = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(4.0)
	var base := player.global_position
	var line := []
	for k in ["Shieldbearer", "Charger", "Summoner", "Spitter", "Eyeling"].size():
		var e := _phase3_spawn(["Shieldbearer", "Charger", "Summoner", "Spitter", "Eyeling"][k], base + Vector2(-48 + k * 22, -26))
		e.set_physics_process(false)
		line.append(e)
	await _wait(0.4)
	await _shot("phase3_lineup")
	for e in line:
		e.queue_free()
	await _wait(0.2)
	# Shield: same blow from the front and from behind.
	var sb := _phase3_spawn("Shieldbearer", base + Vector2(30, 0))
	sb.set_physics_process(false)
	sb.facing = Vector2.LEFT
	var h0 := sb.current_health
	sb.take_elemental_hit(20, ElementalSystem.Element.NONE, player)
	var front := h0 - sb.current_health
	sb.facing = Vector2.RIGHT
	h0 = sb.current_health
	sb.take_elemental_hit(20, ElementalSystem.Element.NONE, player)
	_bot_say("shieldbearer: a 20 blow from the front deals %d, from behind %d" % [front, h0 - sb.current_health])
	sb.queue_free()
	# Ogre: charges from middle range; then a charge into a wall stuns it.
	var og := _phase3_spawn("Charger", base + Vector2(90, 0))
	var hp0 := player.current_health
	player.god_mode = false
	player.max_health = 999
	player.current_health = 999
	hp0 = player.current_health
	await _wait(0.5)
	await _shot("phase3_charge_tell")
	await _wait(1.0)
	_bot_say("ogre charge: player hit for %d (charging=%s)" % [hp0 - player.current_health, og._charging])
	player.god_mode = true
	og.queue_free()
	# Shaman: raises skeletons while it sees the player.
	var sh := _phase3_spawn("Summoner", base + Vector2(70, 0))
	await _wait(2.0)
	var raised := get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Eyeling).size()
	await _shot("phase3_summon")
	sh.die()
	await _wait(0.5)
	var left := get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Eyeling and e.is_alive).size()
	_bot_say("shaman: raised %d flying eyes; after it dies %d still stand" % [raised, left])
	# Evil wizard: a fireball from its hand, aimed at the player.
	var wz := _phase3_spawn("Summoner", base + Vector2(70, 0))
	wz.set_physics_process(false)
	wz.player = player
	player.god_mode = false
	player.current_health = 999
	player._invulnerable_until_ms = 0
	await _wait(0.2)
	wz._cast_fire()
	await _wait(0.75)
	await _shot("phase3_fireball")
	await _wait(0.8)
	_bot_say("wizard fireball from 70 px: player lost %d" % (999 - player.current_health))
	player.god_mode = true
	wz.queue_free()
	# Chort: spits, the pool burns the player standing in it.
	var ch := _phase3_spawn("Spitter", base + Vector2(70, 0))
	player.god_mode = false
	player.current_health = 999
	for k in 4:
		await _wait(0.18)
		await _shot("phase3_spore_%d" % k)
	await _wait(0.48)
	await _shot("phase3_acid")
	await _wait(2.0)
	_bot_say("chort acid: player lost %d standing still for ~3 s; pools %d" % [999 - player.current_health, level.find_children("*", "Node2D", false, false).filter(func(n): return n is AcidPool).size()])
	player.god_mode = true
	ch.queue_free()
	await _unload()

# Next to the back-wall props: the shrine's ambush spawns and the crucible's potions must
# land on ground the player can reach (not behind the wall or in the void).
func _props_reach_session() -> void:
	for lv in ["level_1", "level_2", "level_3"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "knight")
		player.god_mode = true
		await _wait(0.5)
		var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
		var reach := func(from: Vector2, p: Vector2, ground: Array[TileMapLayer]) -> bool:
			var q := PhysicsRayQueryParameters2D.create(from, p, 1, [player.get_rid()])
			return MapBounds.on_map(ground, p) and space.intersect_ray(q).is_empty()
		for n in level.find_children("*", "StaticBody2D", true, false):
			var ground := MapBounds.ground_layers(n)
			if n is FortuneShrine:
				player.global_position = n.global_position + Vector2(0, 16)
				var before: Array = get_tree().get_nodes_in_group("enemies")
				n._ambush(player)
				await _wait(0.1)
				# The ambush: the foes that weren't there a moment ago and stand around the player.
				var foes: Array = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e in before and e.global_position.distance_to(player.global_position) < 70.0)
				var bad := 0
				for e in foes:
					if not reach.call(player.global_position, e.global_position, ground):
						bad += 1
				_bot_say("%s shrine %s: ambush %d foes, %d off the map or behind a wall" % [lv, n.global_position, foes.size(), bad])
				for e in foes:
					e.queue_free()
			elif n is Transmuter:
				n.state = Transmuter.State.ACTIVE
				n._set_active(true)
				GameManager.total_coins = 100
				GameManager.mana_potions = 20
				var kids := n.get_parent().get_child_count()
				for i in 20:
					n.transmute(true)
				await _wait(1.0)
				var bad := 0
				var foot: Vector2 = n.global_position + Vector2(0, 6)
				for c in n.get_parent().get_children().slice(kids):
					if c is Node2D and not reach.call(foot, c.global_position, ground):
						bad += 1
				_bot_say("%s crucible %s: 20 potions, %d behind a wall or off the map" % [lv, n.global_position, bad])
		await _unload()

# Relics: each hook measured, the HUD row and a synergy banner.
func _relics_session() -> void:
	await _load_level("res://scenes/levels/level_2.tscn", "knight")
	await _wait(0.5)
	var foes: Array = get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Enemy and not (e is BossBase))
	for e in foes:
		e.set_physics_process(false)
	var e: Enemy = foes[0]
	e.max_health = 100000
	e.current_health = 100000
	e.resistance = 0
	# No relics: a 10 hit deals 10.
	var h0 := e.current_health
	e.take_elemental_hit(10, ElementalSystem.Element.NONE, player)
	_bot_say("no relics: hit 10 -> %d" % (h0 - e.current_health))
	Progression.relics = ["wolf_fang"]
	Relics.reset()
	var dealt := []
	for i in 8:
		h0 = e.current_health
		e.take_elemental_hit(10, ElementalSystem.Element.NONE, player)
		dealt.append(h0 - e.current_health)
	_bot_say("wolf fang, 8 hits of 10: %s" % [dealt])
	Progression.relics = ["glass_cannon"]
	h0 = e.current_health
	e.take_elemental_hit(10, ElementalSystem.Element.NONE, player)
	var hp0 := player.current_health
	player._invulnerable_until_ms = 0
	player.receive_damage(20)
	_bot_say("glass cannon: deals %d, takes %d of 20" % [h0 - e.current_health, hp0 - player.current_health])
	Progression.relics = ["stone_heart"]
	Relics.reset()
	hp0 = player.current_health
	player._invulnerable_until_ms = 0
	player.receive_damage(20)
	var first := hp0 - player.current_health
	player._invulnerable_until_ms = 0
	player.receive_damage(20)
	_bot_say("stone heart: first hit takes %d, second %d" % [first, hp0 - first - player.current_health])
	Progression.relics = ["phoenix_feather"]
	player._invulnerable_until_ms = 0
	player.receive_damage(99999)
	_bot_say("phoenix: alive=%s hp %d/%d, feather left=%s" % [player.is_alive, player.current_health, player.max_health, Relics.has("phoenix_feather")])
	Progression.relics = ["bloodstone", "loaded_die"]
	player.current_health = 50
	var coins := GameManager.total_coins
	var k: Enemy = foes[1]
	k.take_elemental_hit(99999, ElementalSystem.Element.NONE, player)
	await _wait(0.2)
	_bot_say("bloodstone + die on a kill: hp 50 -> %d, coins +%d" % [player.current_health, GameManager.total_coins - coins])
	Progression.relics = ["frost_heels"]
	var f: Enemy = foes[2]
	f.set_physics_process(true)
	f.global_position = player.global_position + Vector2(16, 0)
	player._dodge_ready_ms = 0
	player._try_dodge(Vector2.LEFT)
	await _wait(0.1)
	_bot_say("frost heels: foe beside the dodge frozen=%s" % f.is_frozen)
	# The HUD row and the banners: two relics, then the one that completes a synergy.
	Progression.relics = []
	Progression.relics_changed.emit()
	Relics.grant("ember_heart")
	Relics.grant("bloodstone")
	await _wait(0.4)
	Relics.grant("storm_ring")
	await _wait(0.6)
	await _shot("relics_banner")
	await _wait(3.0)
	await _shot("relics_synergy")
	_bot_say("owned %s, plasma=%s" % [Progression.relics, Relics.has_synergy("plasma")])
	await _unload()

# No pickup (coin, potion, key) may sit in a wall or past the edge of the floor.
func _pickups_session() -> void:
	for lv in ["level_1", "level_2", "level_3"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "knight")
		player.god_mode = true
		await _wait(1.0)
		var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
		var probe := PhysicsPointQueryParameters2D.new()
		probe.collision_mask = 1
		var bad := []
		var n := 0
		for c in get_tree().get_nodes_in_group("interactable"):
			if not c.has_method("pop_out"):
				continue
			n += 1
			var root: Node2D = c._item_root()
			probe.position = root.global_position
			var ground := MapBounds.ground_layers(root)
			if not space.intersect_point(probe, 1).is_empty() or (not ground.is_empty() and not MapBounds.on_map(ground, root.global_position)):
				bad.append(root.global_position)
		_bot_say("%s: %d pickups, %d in a wall or off the floor %s" % [lv, n, bad.size(), bad.slice(0, 5)])
		# Throw coins from floor cells hugging a wall, straight at the wall, like a kill there.
		var floor_l := level.get_node_or_null("Floor") as TileMapLayer
		if floor_l:
			var edge := []
			for cell in floor_l.get_used_cells():
				if floor_l.get_cell_source_id(cell + Vector2i.LEFT) == -1 or floor_l.get_cell_source_id(cell + Vector2i.UP) == -1:
					edge.append(cell)
			edge.shuffle()
			var coins := []
			for k in mini(60, edge.size()):
				var cell: Vector2i = edge[k]
				var from := floor_l.to_global(floor_l.map_to_local(cell))
				var away := Vector2.LEFT if floor_l.get_cell_source_id(cell + Vector2i.LEFT) == -1 else Vector2.UP
				var coin: Node2D = load("res://assets/sprites/sprite_frames/Coin.tscn").instantiate()
				level.add_child(coin)
				var c: Node = coin if coin.has_method("pop_out") else coin.get_node("Area2D")
				c.pop_out(from, from + away * 18.0)
				coins.append(coin)
			await _wait(1.2)
			var off := []
			for coin in coins:
				probe.position = coin.global_position
				if not space.intersect_point(probe, 1).is_empty() or not MapBounds.on_map(MapBounds.ground_layers(coin), coin.global_position):
					off.append(coin.global_position)
			_bot_say("  %d coins thrown at walls: %d landed in a wall or off the floor %s" % [coins.size(), off.size(), off.slice(0, 4)])
		if lv == "level_2":
			await _wait(3.5)
			await _shot("pickups_level_2_start")
		await _unload()

# Every class walks: body height, real speed and the walk cycle's playback rate (the feet
# should cover about StrideSync.STRIDE body heights per cycle, not glide).
func _stride_session() -> void:
	for cls in ["knight", "archer", "assassin", "cleric", "mage", "necromancer", "samurai"]:
		await _load_level("res://scenes/levels/level_2.tscn", cls)
		player.god_mode = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		await _wait(0.5)
		var x0 := player.global_position.x
		Input.action_press("move_right")
		await _wait(1.0)
		var spr := player.animated_sprite
		var ss := player.get_node("StrideSync") as StrideSync
		var anim := String(spr.animation)
		var h := ss._height(anim) * absf(spr.global_scale.y)
		var fr := spr.sprite_frames.get_frame_count(anim)
		var fps := spr.sprite_frames.get_animation_speed(anim)
		var cycle := float(fr) / (fps * spr.speed_scale)
		_bot_say("%-11s anim %s h=%.1fpx speed=%.0f scale=%.2f -> %.2f cycles/s, %.1f px per cycle (was %.1f)" % [cls, anim, h, player.velocity.length(), spr.speed_scale, 1.0 / cycle, player.velocity.length() * cycle, player.velocity.length() * fr / fps])
		if cls == "knight":
			for i in 4:
				await _wait(0.12)
				await _shot("stride_knight_%d" % i, player.global_position + Vector2(0, -8))
		Input.action_release("move_right")
		await _unload()

# The peddler on every level: how he sits in his room, the shop, prices per level, buying
# until the purse or the stock runs out, and the scroll's perk reveal.
func _merchant_session() -> void:
	for lv in ["level_1", "level_2", "level_3"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "knight")
		player.god_mode = true
		for e in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		var m := level.find_child("Merchant", true, false) as Merchant
		if not m:
			_bot_say("%s: NO MERCHANT" % lv)
			await _unload()
			continue
		player.global_position = m.global_position + Vector2(-14, 16)
		await _wait(4.5) # past the level's title card
		await _shot("merchant_%s_world" % lv)
		GameManager.total_coins = 30
		var hp := GameManager.health_potions
		m.interact(player)
		await _wait(0.4)
		if lv == "level_1":
			await _shot("merchant_menu")
		var bought := 0
		for i in 6:
			if m.buy("health"):
				bought += 1
		_bot_say("%s at %s: prices %s; 30 coins bought %d health (bag %d -> %d), coins left %d, stock %s" % [lv, m.global_position,
			Merchant.WARES.map(func(w): return m.price(w)), bought, hp, GameManager.health_potions, GameManager.total_coins, m.stock])
		GameManager.total_coins = 100
		m.buy("perk")
		await _wait(0.6)
		_bot_say("  scroll: menu open=%s picker open=%s; second scroll allowed=%s" % [Merchant.MerchantMenu.is_open(), PerkPicker.is_open(), m.buy("perk")])
		if lv == "level_1":
			await _shot("merchant_scroll")
		if Merchant.MerchantMenu.is_open():
			Merchant.MerchantMenu.close_open()
		if PerkPicker.is_open():
			PerkPicker._open._choose(0)
			await _wait(0.6)
		get_tree().paused = false
		await _unload()

# The Golem's gates: open while the player is still in the corridor (even with the Golem
# fighting), shut once they are inside, and rise again if the player ends up outside.
func _golem_gate_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	var golem := level.get_node("Golem") as BossBase
	var gates: Array = []
	for n in level.get_children():
		if n is Door and n.gate_style and n.global_position.y == 462.0:
			gates.append(n)
	var shut := func() -> String: return str(gates.map(func(g): return not g.is_open))
	for step in [["corridor", Vector2(846, 446)], ["doorway", Vector2(846, 478)], ["inside", Vector2(846, 520)], ["pushed out", Vector2(846, 440)], ["back in", Vector2(846, 530)]]:
		player.global_position = step[1]
		golem.receive_damage(1)
		await _wait(0.4)
		_bot_say("%s %s: engaged=%s gates shut=%s" % [step[0], player.global_position, golem.is_engaged(), shut.call()])
	await _shot("golem_gate_inside", Vector2(846, 500))
	await _unload()

# Every level: each pot breaks and leaves no tile behind (neck included); no bone is solid.
func _decor_check_session() -> void:
	for lv in ["level_1", "level_2", "level_3"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "knight")
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await _wait(0.6)
		var pots := get_tree().get_nodes_in_group("breakables")
		for p in pots:
			if p.region.position.y < 140.0 and p.region.position.y >= 112.0 or p.region.size.y > 16.0:
				_bot_say("  pot region %s at %s" % [p.region, p.global_position])
		for spr in level.find_children("*", "Sprite2D", true, false):
			if spr.texture is AtlasTexture and spr.texture.atlas and spr.texture.atlas.resource_path.get_file() == "decorative.png" and int(spr.texture.region.position.y / 16) == 7:
				_bot_say("  prop sprite with a row-7 decorative tile %s at %s" % [spr.texture.region, spr.global_position])
		var tall: Node2D = null
		for p in pots:
			if p.region.size.y > 16.0:
				tall = p
		if tall:
			player.global_position = tall.global_position + Vector2(-18, 4)
			await _wait(0.4)
			await _shot("decor_%s_tall_before" % lv, tall.global_position + Vector2(0, -8))
		var had_tall := tall != null
		var at := tall.global_position if tall else Vector2.ZERO
		for p in pots:
			if is_instance_valid(p):
				p.break_open(Vector2.ZERO)
		await _wait(0.6)
		if had_tall:
			await _shot("decor_%s_tall_after" % lv, at + Vector2(0, -8))
		var left_pots := 0
		var solid_bones := 0
		var bones := 0
		var space := player.get_world_2d().direct_space_state
		for layer in level.find_children("*", "TileMapLayer", true, false):
			if String(layer.name) not in ["Decorations", "Decor"]:
				continue
			for c in layer.get_used_cells():
				if BreakablePot.is_pot(layer, c) or BreakablePot.is_pot_neck(layer, c):
					left_pots += 1
					_bot_say("  left: %s %s atlas %s above %s below %s at %s" % [layer.name, c, layer.get_cell_atlas_coords(c), layer.get_cell_atlas_coords(c + Vector2i.UP), layer.get_cell_atlas_coords(c + Vector2i.DOWN), layer.to_global(layer.map_to_local(c))])
				var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
				if src and src.texture and src.texture.resource_path.get_file() == "decorative.png" and layer.get_cell_atlas_coords(c).y == 7 and layer.get_cell_atlas_coords(c).x >= 9:
					_bot_say("  neck tile still there: %s %s" % [layer.get_cell_atlas_coords(c), layer.to_global(layer.map_to_local(c))])
				if DecorPhysics.is_bone(layer, c):
					bones += 1
					var q := PhysicsPointQueryParameters2D.new()
					q.position = layer.to_global(layer.map_to_local(c))
					q.collision_mask = 1
					for r in space.intersect_point(q, 4):
						if r["collider"] is StaticBody2D and r["collider"].get_parent() == layer:
							solid_bones += 1
		_bot_say("%s: %d pots broken (tall one: %s), pot tiles left %d, bones %d, solid bones %d" % [lv, pots.size(), had_tall, left_pots, bones, solid_bones])
		await _unload()

# The bounds safety net: an enemy pushed off the map comes back; enemies on the map (also in
# the crypt, and wisps over the river) are left alone.
func _bounds_session() -> void:
	for lv in ["level_1", "level_2"]:
		await _load_level("res://scenes/levels/%s.tscn" % lv, "knight")
		player.god_mode = true
		await _wait(1.5)
		var moved := 0
		var before := {}
		for e in get_tree().get_nodes_in_group("enemies"):
			before[e] = e.global_position
		await _wait(1.0)
		var e0: Node2D = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive and not (e is BossBase):
				e0 = e
				break
		var home: Vector2 = e0.global_position
		e0.global_position = Vector2(-4000, -4000) # thrown off the map
		await _wait(0.6)
		_bot_say("%s: enemy thrown off the map came back=%s (%s -> %s)" % [lv, e0.global_position.distance_to(home) < 40.0, home, e0.global_position])
		await _unload()

# Walk the first-room lessons: each stone's plaque, then do what it asks.
func _tutorial_session() -> void:
	await _load_level("res://scenes/levels/level_1.tscn", "knight")
	player.god_mode = true
	await _wait(3.5)
	var tp: Node = level.find_child("TutorialPath", true, false)
	if not tp:
		_bot_say("tutorial: none (already finished on this machine)")
		await _unload()
		return
	var acts := ["", "attack_1", "dodge", "block", "skill"]
	for i in tp.stones.size():
		var st: Node2D = tp.stones[i]
		await _walk_to(st.global_position + Vector2(0, 14), 5.0)
		await _wait(0.5)
		await _shot("tutorial_%d" % i)
		if i == 0:
			await _walk_to(st.global_position + Vector2(16, 24), 1.5)
		else:
			_aim_at(st.global_position + Vector2(40, 0))
			_tap(acts[i])
		await _wait(0.6)
		_bot_say("tutorial lesson %d done=%s" % [i, st.done])
	await _shot("tutorial_end")
	await _unload()
