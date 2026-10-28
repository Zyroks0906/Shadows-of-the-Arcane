extends Node2D
class_name ArenaRoom

# A combat room (Isaac style). Walking in seals the gates and summons the room's enemies,
# optionally in two waves; clearing it opens the gates and reveals the reward chest.
# Built by tools/level_builder.gd from 'R' (room), '=' (gates), spawners inside the room
# ('E' = second wave) and a reward chest ('k' silver key, 'g' golden key, 'r' supplies).

enum State { IDLE, FIGHT, CLEARED }
signal cleared

const T := 16

@export var room_name: String = "AMBUSH"
@export var cells: Array[Vector2i] = []
@export var gates: Array[Node2D] = []
@export var wave1: Array[Node2D] = []
@export var wave2: Array[Node2D] = []
@export var reward: Node2D

var state: State = State.IDLE
var _cellset: Dictionary = {}
var _gate_cells: Dictionary = {}
var _alive: Array = []
var _wave: int = 0
var _spawning: bool = false

# Spawns of the coming waves that are forced to be elites (a Transmuter buried in the room
# asks for some: its room is the trial that earns it).
var elite_spawns: int = 0

func _ready() -> void:
	add_to_group("arena_rooms")
	for c in cells:
		_cellset[c] = true
	for g in gates:
		if is_instance_valid(g):
			_gate_cells[Vector2i((to_local(g.global_position) / T).floor())] = true
	if is_instance_valid(reward):
		_set_reward_active(false)

func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p and _contains_safely(p.global_position):
				_start()
		State.FIGHT:
			if _spawning:
				return
			_alive = _alive.filter(func(e): return is_instance_valid(e) and e.is_alive)
			if _alive.is_empty():
				if _wave == 1 and not wave2.is_empty():
					_wave = 2
					_spawn_wave(wave2, 0.7)
				else:
					_clear()

# Whether a world point lies on the room's floor.
func contains(world: Vector2) -> bool:
	return _cellset.has(Vector2i((to_local(world) / T).floor()))

# Inside the room and not standing in a doorway, so the gates never close on the player.
func _contains_safely(world: Vector2) -> bool:
	# Cells are in the level's own grid; the level may be placed anywhere (the crypt).
	var c := Vector2i((to_local(world) / T).floor())
	if not _cellset.has(c):
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if _gate_cells.has(c + Vector2i(dx, dy)):
				return false
	return true

func _start() -> void:
	state = State.FIGHT
	for g in gates:
		if is_instance_valid(g):
			g.close()
			g.is_locked = true
			CombatFX.burst(g.global_position, Color(0.6, 0.55, 0.5), 10, 40.0, 0.4, 60.0, 1.5)
	AudioManager.play_bank("door_close", 2.0, 0.8)
	AudioManager.play_bank("chain", -2.0, 0.8)
	CombatFX.shake(2.5, 0.3)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		CombatFX.floating_label(p.global_position + Vector2(0, -10), room_name, Color(1.0, 0.45, 0.35), 1.2)
	_wave = 1
	_spawn_wave(wave1, 0.35)

func _spawn_wave(spawners: Array, delay: float) -> void:
	_spawning = true
	await get_tree().create_timer(delay).timeout
	var i := 0
	for s in spawners:
		if not is_instance_valid(s):
			continue
		if elite_spawns > 0 and EliteAffix.enabled:
			EliteAffix.forced = randi() % EliteAffix.Kind.size()
			elite_spawns -= 1
		var e = s.spawn_enemy(true)
		EliteAffix.forced = -1
		if e:
			_alive.append(e)
		i += 1
		await get_tree().create_timer(0.12).timeout
	_spawning = false

func _clear() -> void:
	state = State.CLEARED
	cleared.emit()
	for g in gates:
		if is_instance_valid(g):
			g.is_locked = false
			g.open()
	AudioManager.play_bank("door_open", 0.0, 0.9)
	AudioManager.play_bank("heal", -4.0, 1.0)
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		CombatFX.floating_label(p.global_position + Vector2(0, -10), "ROOM CLEARED", Color(0.6, 1.0, 0.7), 1.2)
	if is_instance_valid(reward):
		await get_tree().create_timer(0.6).timeout
		_set_reward_active(true)
		CombatFX.shockwave(reward.global_position, Color(1.0, 0.85, 0.4), 22.0, 0.4, 2.0)
		CombatFX.burst(reward.global_position, Color(1.0, 0.85, 0.4), 20, 60.0, 0.6, -40.0, 1.5)
		AudioManager.play_bank_at("teleport", reward.global_position, -2.0, 1.1)

func _set_reward_active(on: bool) -> void:
	reward.visible = on
	var a := reward.get_node_or_null("Area2D") as Area2D
	if a:
		a.set_deferred("monitoring", on)
		a.set_deferred("monitorable", on)
	if on:
		reward.scale = Vector2(0.2, 0.2)
		reward.create_tween().tween_property(reward, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
