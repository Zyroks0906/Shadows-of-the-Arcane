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
		await _wait(0.2)
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
