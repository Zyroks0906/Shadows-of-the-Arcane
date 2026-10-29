extends Node

# Run progression shared by the three maps: experience from defeated enemies, character
# level, and the perks picked on every level-up (three random cards, Megabonk style, with
# rarities). It survives moving to the next map; dying restores what you had when the map
# started, so a failed attempt costs only what was earned during it.

signal xp_changed(xp: int, needed: int, level: int)
signal leveled_up(level: int)
signal perks_changed

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.75, 0.75, 0.78), Color(0.45, 0.9, 0.45), Color(0.4, 0.65, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.75, 0.25)]
const RARITY_WEIGHTS := [55.0, 26.0, 12.0, 5.5, 1.5]

# Each perk: value per rarity (common .. legendary). "fmt" builds the card text.
const PERKS := {
	"might": {"name": "Might", "fmt": "+%d%% physical damage", "values": [8, 12, 18, 26, 40]},
	"arcana": {"name": "Arcana", "fmt": "+%d%% spell & skill damage", "values": [8, 12, 18, 26, 40]},
	"vitality": {"name": "Vitality", "fmt": "+%d max health (and heals it)", "values": [10, 16, 24, 35, 55]},
	"iron_skin": {"name": "Iron Skin", "fmt": "+%d armour", "values": [1, 2, 3, 5, 8]},
	"swiftness": {"name": "Swiftness", "fmt": "+%d%% movement speed", "values": [6, 9, 13, 18, 28]},
	"fury": {"name": "Fury", "fmt": "+%d%% attack speed", "values": [10, 14, 20, 28, 40]},
	"bulwark": {"name": "Bulwark", "fmt": "+%d%% guard stamina", "values": [10, 16, 24, 35, 55]},
	"focus": {"name": "Focus", "fmt": "-%d%% skill (E) cooldown", "values": [8, 12, 16, 22, 30]},
	"zeal": {"name": "Zeal", "fmt": "+%d%% ultimate (Q) charge", "values": [8, 12, 18, 26, 40]},
	"vampirism": {"name": "Vampirism", "fmt": "Heal %d HP on hit (0.4 s cooldown)", "values": [1, 1, 2, 3, 5], "min": Rarity.UNCOMMON},
	"mastery": {"name": "Elemental Mastery", "fmt": "+%d%% reaction damage", "values": [8, 12, 18, 26, 40]},
	"greed": {"name": "Greed", "fmt": "+%d%% coins picked up", "values": [15, 25, 40, 60, 100]},
	"wisdom": {"name": "Wisdom", "fmt": "+%d max mana, faster regen", "values": [10, 16, 24, 35, 55], "mana_only": true},
	"luck": {"name": "Fortune", "fmt": "Better perk rarities (+%d%%)", "values": [10, 16, 25, 40, 60]},
}

var level: int = 1
var xp: int = 0
# perk id -> summed value
var perks: Dictionary = {}
var _snapshot: Dictionary = {}
var _pending_levels: int = 0
# Tests and scripted play sessions: take the first card instead of opening the picker.
var auto_pick: bool = false

func xp_needed() -> int:
	return 20 + (level - 1) * 14

func value(id: String) -> float:
	return float(perks.get(id, 0))

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		_pending_levels += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_needed(), level)
	if _pending_levels > 0:
		_offer_next()

func _offer_next() -> void:
	if PerkPicker.is_open():
		return
	if _pending_levels <= 0:
		return
	_pending_levels -= 1
	if auto_pick:
		take(roll(3)[0])
		_offer_next()
		return
	PerkPicker.offer("LEVEL %d" % level, roll(3), func(): _offer_next())

# Three distinct perks with rolled rarities; `min_rarity` for special rewards.
func roll(count: int, min_rarity: int = Rarity.COMMON) -> Array:
	var player := get_tree().get_first_node_in_group("player") as Player
	var pool := []
	for id in PERKS:
		if PERKS[id].get("mana_only", false) and not (player and player.uses_mana):
			continue
		pool.append(id)
	pool.shuffle()
	var out := []
	for id in pool.slice(0, count):
		var r := maxi(_roll_rarity(), min_rarity)
		r = maxi(r, PERKS[id].get("min", Rarity.COMMON))
		out.append({"id": id, "rarity": r})
	return out

func _roll_rarity() -> int:
	var w := RARITY_WEIGHTS.duplicate()
	var luck := value("luck") / 100.0
	for i in range(1, w.size()):
		w[i] *= 1.0 + luck * i
	var total := 0.0
	for x in w:
		total += x
	var r := randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 0

func describe(card: Dictionary) -> String:
	var p: Dictionary = PERKS[card["id"]]
	return p["fmt"] % p["values"][card["rarity"]]

func take(card: Dictionary) -> void:
	var id: String = card["id"]
	var v: int = PERKS[id]["values"][card["rarity"]]
	perks[id] = int(perks.get(id, 0)) + v
	for player in get_tree().get_nodes_in_group("player"):
		if player is Player:
			player.apply_perks(id == "vitality", v if id == "vitality" else 0)
	perks_changed.emit()
	# Say what changed, on the hero, so a perk is felt the moment it's taken.
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero:
		var total := int(perks[id])
		var text: String = (PERKS[id]["fmt"] % v).to_upper()
		if total != v:
			text += "  (NOW %d)" % total
		CombatFX.floating_label(hero.global_position + Vector2(0, -22), text, Color(1.0, 0.88, 0.5), 1.6)

# Called when a map starts / when the player dies.
func snapshot() -> void:
	_snapshot = {"level": level, "xp": xp, "perks": perks.duplicate()}
	_pending_levels = 0

func restore() -> void:
	if _snapshot.is_empty():
		return
	level = _snapshot["level"]
	xp = _snapshot["xp"]
	perks = _snapshot["perks"].duplicate()
	_pending_levels = 0

# Run statistics for the end-of-run screens. Kept across deaths and levels; a new run (class
# selection) clears them.
var stats: Dictionary = {}
# > 0 while a hit by the player (and the reactions it sets off) is being resolved.
var player_hit_depth: int = 0

func reset_stats() -> void:
	stats = {"kills": 0, "elites": 0, "damage": 0, "taken": 0, "coins": 0, "deaths": 0,
		"start_ms": Time.get_ticks_msec(), "killer": ""}

func stat(key: String, amount: int = 1) -> void:
	if stats.is_empty():
		reset_stats()
	stats[key] = int(stats.get(key, 0)) + amount

func run_time_text() -> String:
	if stats.is_empty():
		reset_stats()
	var sec := (Time.get_ticks_msec() - int(stats["start_ms"])) / 1000
	return "%d:%02d" % [sec / 60, sec % 60]

func reset_run() -> void:
	reset_stats()
	level = 1
	xp = 0
	perks.clear()
	_snapshot.clear()
	_pending_levels = 0
