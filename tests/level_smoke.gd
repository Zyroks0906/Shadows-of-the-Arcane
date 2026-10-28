extends Node2D
var fails := 0
func check(c: bool, m: String) -> void:
	print(("PASS  " if c else "FAIL  ") + m)
	if not c: fails += 1

func _ready() -> void:
	EliteAffix.enabled = false
	Progression.auto_pick = true
	for cls in [GameManager.CharacterClass.SAMURAI, GameManager.CharacterClass.CLERIC]:
		GameManager.set_selected_class(cls)
		for path in ["res://scenes/levels/level_1.tscn", "res://scenes/levels/level_2.tscn", "res://scenes/levels/level_3.tscn"]:
			await _run(path)
	print("RESULT failures=", fails)
	get_tree().quit(fails)

func _run(path: String) -> void:
	var level: Node = load(path).instantiate()
	add_child(level)
	await get_tree().create_timer(2.5).timeout
	var player := get_tree().get_first_node_in_group("player") as Player
	check(player != null and player.is_alive, "%s: player spawned (%s)" % [path.get_file(), GameManager.get_selected_class_name()])
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() >= 5, "%s: enemies alive = %d" % [path.get_file(), enemies.size()])
	var kinds := {}
	for e in enemies: kinds[e.character_name] = kinds.get(e.character_name, 0) + 1
	print("      kinds: ", kinds)
	if path.get_file() == "level_1.tscn":
		await _check_level1(level, player)
	var exit := level.get_node_or_null("ExitPortal")
	if path.get_file() != "level_1.tscn":
		check(exit != null and not exit.active, "%s: exit portal dormant until boss dies" % path.get_file())
		var boss_name: String = exit.boss_to_track
		GameManager.notify_boss_defeat(boss_name)
		await get_tree().process_frame
		check(exit.active, "%s: exit activates when %s falls" % [path.get_file(), boss_name])
		# Walk the player through a zone if any, to exercise environment imbue.
		var zone: ElementZone = level.get_node("Zones").get_child(0)
		if zone and player:
			player.global_position = zone.global_position + zone.size / 2.0
			await get_tree().create_timer(1.0).timeout
			check(player.current_imbued_element != ElementalSystem.Element.NONE, "%s: zone imbues player (%s)" % [path.get_file(), ElementalSystem.get_element_name(player.current_imbued_element)])
		await _check_arenas(level, player, path.get_file())
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

# Walk into each arena: gates seal, both waves come, clearing opens the gates and shows the
# reward chest.
func _check_arenas(level: Node, player: Player, file: String) -> void:
	var arenas := level.get_node_or_null("Arenas")
	check(arenas != null and arenas.get_child_count() == 2, "%s: two arenas" % file)
	if not arenas:
		return
	player.god_mode = true
	for room: ArenaRoom in arenas.get_children():
		check(room.reward != null and not room.reward.visible, "%s/%s: reward hidden before the fight" % [file, room.room_name])
		# Stand in the middle of the room (its cell farthest from any gate).
		var best: Vector2i = room.cells[0]
		var best_d := -1.0
		for c in room.cells:
			var d := INF
			for g in room.gates:
				d = minf(d, Vector2(c * 16).distance_to(g.global_position))
			if d > best_d:
				best_d = d
				best = c
		player.global_position = Vector2(best * 16) + Vector2(8, 8)
		await get_tree().create_timer(0.3).timeout
		check(room.state == ArenaRoom.State.FIGHT, "%s/%s: walking in starts the fight" % [file, room.room_name])
		check(room.gates.all(func(g): return not g.is_open), "%s/%s: gates close" % [file, room.room_name])
		for g in room.gates:
			g.interact(player)
		await get_tree().physics_frame
		check(room.gates.all(func(g): return not g.is_open), "%s/%s: gates can't be opened mid-fight" % [file, room.room_name])
		await get_tree().create_timer(1.2).timeout
		check(room._alive.size() == room.wave1.size(), "%s/%s: wave 1 summoned (%d)" % [file, room.room_name, room._alive.size()])
		for e in room._alive:
			e.die()
		await get_tree().create_timer(1.6).timeout
		check(room._wave == 2, "%s/%s: second wave arrives" % [file, room.room_name])
		for e in room._alive:
			if is_instance_valid(e): e.die()
		await get_tree().create_timer(1.2).timeout
		check(room.state == ArenaRoom.State.CLEARED, "%s/%s: room cleared" % [file, room.room_name])
		check(room.gates.all(func(g): return g.is_open), "%s/%s: gates reopen" % [file, room.room_name])
		check(room.reward.visible, "%s/%s: reward chest appears" % [file, room.room_name])
		check(room.reward.bonus_items.size() == 1, "%s/%s: reward includes a health potion" % [file, room.room_name])
	player.god_mode = false

# level_1 extras: boss chests hidden until the Demon falls; the Golem's hatch trap.
func _check_level1(level: Node, player: Player) -> void:
	var reward: Node = null
	var hatch: Node = null
	for n in level.get_children():
		if n is BossReward: reward = n
		if n is Trapdoor: hatch = n
	check(reward != null and reward.get_child_count() == 3, "level_1: three Demon reward chests")
	check(reward and reward.get_children().all(func(c): return not c.visible), "level_1: reward chests hidden before the Demon falls")
	check(hatch != null and hatch.state == Trapdoor.State.SEALED, "level_1: hatch sealed while the Golem lives")
	GameManager.notify_boss_defeat("Golem")
	await get_tree().process_frame
	check(hatch.state == Trapdoor.State.READY, "level_1: hatch can be opened after the Golem")
	player.god_mode = true
	player.global_position = hatch.global_position + Vector2(0, 20)
	hatch.interact(player)
	await get_tree().create_timer(2.0).timeout
	var crypt_room: ArenaRoom = hatch.crypt.get_node("Arenas").get_child(0)
	check(hatch.state == Trapdoor.State.BELOW and player.global_position.distance_to(hatch.crypt.get_node("Entry").global_position) < 40, "level_1: the hatch leads down into the Undercroft")
	check(crypt_room.state == ArenaRoom.State.FIGHT, "level_1: the dead rise in the Undercroft")
	for w in 2:
		await get_tree().create_timer(1.4).timeout
		for e in crypt_room._alive:
			if is_instance_valid(e): e.die()
	await get_tree().create_timer(2.0).timeout
	check(crypt_room.state == ArenaRoom.State.CLEARED and hatch._ladder.active, "level_1: clearing the crypt lights the ladder")
	hatch._ladder.interact(player)
	await get_tree().create_timer(1.2).timeout
	check(hatch.state == Trapdoor.State.DONE and player.global_position.distance_to(hatch.global_position) < 30, "level_1: the ladder brings you back up")
	GameManager.notify_boss_defeat("Demon")
	await get_tree().create_timer(2.6).timeout
	check(reward.get_children().all(func(c): return c.visible), "level_1: reward chests appear after the Demon")
	player.god_mode = false
