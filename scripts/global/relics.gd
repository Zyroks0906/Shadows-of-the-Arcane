extends RefCounted
class_name Relics

# Relics: rare objects found during a run (sealed chests, bosses, the peddler) that change
# HOW you fight, where perks only add percentages. One of each at most; they last the whole
# run (Progression.relics, kept and reset with the perks).
#
# Some pairs hide a synergy: owning both wakes a stronger effect, announced the first time.
# Hooks: Enemy.take_elemental_hit (outgoing hits), Enemy.die (kills), Player.receive_damage
# (hits taken), Player._try_dodge (dodges).

const DATA := {
	"ember_heart": {"name": "Ember Heart", "text": "Your hits may set foes ablaze (15%).", "color": Color(1.0, 0.5, 0.2),
		"icon": ["...r...", "..rgr..", ".rgygr.", ".rgyyr.", "rgyyygr", ".rgggr.", "..rrr.."]},
	"wolf_fang": {"name": "Wolf Fang", "text": "Every 8th hit strikes twice as hard.", "color": Color(0.9, 0.9, 0.85),
		"icon": ["w......", "ww.....", ".ww....", ".www...", "..www..", "...www.", "....wwd"]},
	"storm_ring": {"name": "Storm Ring", "text": "Every 5th hit arcs lightning to another foe.", "color": Color(0.7, 0.55, 1.0),
		"icon": ["..ggg..", ".g...g.", "g..p..g", "g.pp..g", "g..pp.g", ".g..p..", "..ggg.."]},
	"hunter_mark": {"name": "Hunter's Mark", "text": "+30% damage to foes at full health.", "color": Color(0.95, 0.35, 0.35),
		"icon": ["...r...", ".rrrrr.", ".r...r.", "rr.r.rr", ".r...r.", ".rrrrr.", "...r..."]},
	"last_stand": {"name": "Last Stand", "text": "Below 30% health you deal +35% damage.", "color": Color(0.95, 0.3, 0.3),
		"icon": [".r...r.", "rrr.rrr", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."]},
	"glass_cannon": {"name": "Glass Cannon", "text": "+40% damage, but you take 25% more.", "color": Color(0.6, 0.9, 1.0),
		"icon": ["..bbb..", "..b.b..", "..b.b..", ".bb.bb.", ".b...b.", ".b.h.b.", ".bbbbb."]},
	"bloodstone": {"name": "Bloodstone", "text": "Every kill heals 2 health.", "color": Color(0.85, 0.15, 0.25),
		"icon": ["..ddd..", ".drrrd.", "drrhrrd", "drrrrrd", "drrrrrd", ".drrrd.", "..ddd.."]},
	"red_chalice": {"name": "Red Chalice", "text": "Felling an elite heals 25% of your health.", "color": Color(0.9, 0.2, 0.3),
		"icon": ["g.....g", "grrrrrg", ".grrrg.", "..ggg..", "...g...", "...g...", ".ggggg."]},
	"loaded_die": {"name": "Loaded Die", "text": "Every kill drops a coin straight in your purse.", "color": Color(0.95, 0.8, 0.35),
		"icon": ["wwwwwww", "wb...bw", "w.....w", "w..b..w", "w.....w", "wb...bw", "wwwwwww"]},
	"stone_heart": {"name": "Stone Heart", "text": "Every 20 s, the next hit you take is shrugged off.", "color": Color(0.7, 0.68, 0.62),
		"icon": [".s...s.", "sss.sss", "sssssss", "sshssss", ".sssss.", "..sss..", "...s..."]},
	"frost_heels": {"name": "Frost Heels", "text": "Dodging chills foes close to you.", "color": Color(0.55, 0.85, 1.0),
		"icon": ["...b...", "b..b..b", ".b.b.b.", "..bbb..", ".b.b.b.", "b..b..b", "...b..."]},
	"phoenix_feather": {"name": "Phoenix Feather", "text": "Once, a killing blow leaves you at 30% instead.", "color": Color(1.0, 0.6, 0.25),
		"icon": ["....yy.", "...yrr.", "..yrr..", ".yrr...", ".rr....", "r......", "r......"]},
}

# Hidden pairs. Discovered (and announced) the first time both are owned.
const SYNERGIES := {
	"plasma": {"name": "Plasma", "needs": ["ember_heart", "storm_ring"], "text": "Your lightning sets its targets ablaze."},
	"apex": {"name": "Apex Predator", "needs": ["wolf_fang", "hunter_mark"], "text": "A fang strike on an unhurt foe hits three times as hard."},
	"feast": {"name": "Sanguine Feast", "needs": ["bloodstone", "red_chalice"], "text": "Kills heal 4, elites 40%."},
	"glacier": {"name": "Glacier", "needs": ["stone_heart", "frost_heels"], "text": "Shrugging off a hit freezes the foes around you."},
}

const PALETTE := {
	"r": Color(0.86, 0.2, 0.22), "g": Color(0.95, 0.75, 0.3), "y": Color(1.0, 0.92, 0.55), "w": Color(0.92, 0.9, 0.84),
	"d": Color(0.45, 0.08, 0.12), "p": Color(0.75, 0.6, 1.0), "b": Color(0.6, 0.88, 1.0), "h": Color(1.0, 1.0, 1.0),
	"s": Color(0.6, 0.58, 0.54),
}

const STONE_EVERY := 20.0

static var _hits := 0
static var _stone_ready_ms := 0

static func owned() -> Array:
	return Progression.relics

static func has(id: String) -> bool:
	return id in Progression.relics

static func has_synergy(id: String) -> bool:
	for r in SYNERGIES[id]["needs"]:
		if not has(r):
			return false
	return true

# A relic the run doesn't have yet, or "" when every one is owned.
static func roll() -> String:
	var pool := []
	for id in DATA:
		if not has(id):
			pool.append(id)
	return "" if pool.is_empty() else pool[randi() % pool.size()]

# Adds a relic, says so, and announces any synergy it completes.
static func grant(id: String) -> void:
	if id == "" or has(id):
		return
	Progression.relics.append(id)
	Progression.relics_changed.emit()
	var d: Dictionary = DATA[id]
	ItemBanner.show_item("Relic: " + d["name"], d["text"], d["color"], icon(id, 4))
	AudioManager.play_bank("gem", -2.0, 0.8)
	for s in SYNERGIES:
		if id in SYNERGIES[s]["needs"] and has_synergy(s):
			var sd: Dictionary = SYNERGIES[s]
			var tree := Engine.get_main_loop() as SceneTree
			if tree:
				await tree.create_timer(2.6).timeout
			ItemBanner.show_item("Synergy: " + sd["name"], sd["text"], Color(1.0, 0.85, 0.4))
			AudioManager.play_bank("magic_shield", -4.0, 1.3)

# A crisp pixel icon (7 x 7 cells, `px` screen pixels each).
static func icon(id: String, px: int = 2) -> Texture2D:
	var rows: Array = DATA[id]["icon"]
	var img := Image.create(9 * px, 9 * px, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == ".":
				continue
			img.fill_rect(Rect2i((x + 1) * px, (y + 1) * px, px, px), PALETTE[row[x]])
	return ImageTexture.create_from_image(img)

static func reset() -> void:
	_hits = 0
	_stone_ready_ms = 0

# --- Hooks -------------------------------------------------------------------------------

# A hit of the player's about to land on `target`: returns the damage to deal.
static func outgoing(target: BaseCharacter, damage: int) -> int:
	if Progression.relics.is_empty() or damage <= 0:
		return damage
	_hits += 1
	var pl := target.get_tree().get_first_node_in_group("player") as Player
	var mult := 1.0
	var full := target.current_health >= target.max_health
	if has("hunter_mark") and full:
		mult *= 1.3
	if has("last_stand") and pl and pl.current_health < pl.max_health * 0.3:
		mult *= 1.35
	if has("glass_cannon"):
		mult *= 1.4
	if has("wolf_fang") and _hits % 8 == 0:
		var fang := 3.0 if has_synergy("apex") and full else 2.0
		mult *= fang
		CombatFX.floating_label(target.global_position + Vector2(0, -18), "FANG x%d" % int(fang), Color(1.0, 0.95, 0.8), 1.1)
	return maxi(1, roundi(damage * mult))

# After a hit of the player's landed on `target`.
static func after_hit(target: BaseCharacter, damage: int) -> void:
	if Progression.relics.is_empty() or not is_instance_valid(target):
		return
	if has("ember_heart") and target.is_alive and randf() < 0.15:
		Burn.apply(target, target.get_tree().get_first_node_in_group("player"))
	if has("storm_ring") and _hits % 5 == 0:
		_arc(target, damage)

# Lightning jumps from `from` to the nearest other living foe.
static func _arc(from: BaseCharacter, damage: int) -> void:
	var best: BaseCharacter = null
	var best_d := 80.0
	for e in from.get_tree().get_nodes_in_group("enemies"):
		if e == from or not (e is BaseCharacter) or not e.is_alive:
			continue
		var d: float = e.global_position.distance_to(from.global_position)
		if d < best_d:
			best_d = d
			best = e
	if not best:
		return
	var pl := from.get_tree().get_first_node_in_group("player")
	CombatFX.lightning(from.global_position + Vector2(0, -6), best.global_position + Vector2(0, -6), Color(0.75, 0.6, 1.0))
	AudioManager.play_bank_at("electric_hit", best.global_position, -6.0, 1.2)
	var dmg := maxi(1, damage / 2)
	Progression.player_hit_depth += 1
	best.receive_damage(dmg)
	Progression.player_hit_depth -= 1
	if has_synergy("plasma") and best.is_alive:
		Burn.apply(best, pl)

# A foe fell.
static func on_kill(enemy: BaseCharacter, was_elite: bool) -> void:
	if Progression.relics.is_empty():
		return
	var pl := enemy.get_tree().get_first_node_in_group("player") as Player
	if not pl:
		return
	var feast := has_synergy("feast")
	if has("bloodstone"):
		pl.recover_health(4 if feast else 2)
	if has("red_chalice") and was_elite:
		pl.recover_health(roundi(pl.max_health * (0.4 if feast else 0.25)))
	if has("loaded_die"):
		GameManager.add_coins(1)
		CombatFX.floating_label(enemy.global_position + Vector2(0, -14), "+1", Color(1.0, 0.85, 0.35), 0.8)

# A hit is about to land on the player: returns what is left of it.
static func incoming(pl: Player, amount: int) -> int:
	if Progression.relics.is_empty() or amount <= 0:
		return amount
	if has("stone_heart") and Time.get_ticks_msec() >= _stone_ready_ms:
		_stone_ready_ms = Time.get_ticks_msec() + int(STONE_EVERY * 1000.0)
		CombatFX.floating_label(pl.global_position + Vector2(0, -20), "STONE HEART", Color(0.85, 0.82, 0.75), 1.0)
		AudioManager.play_bank("magic_shield", -4.0, 0.8)
		if has_synergy("glacier"):
			_chill_around(pl, 40.0, 1.2)
		return 0
	if has("glass_cannon"):
		amount = roundi(amount * 1.25)
	# The feather: a blow that would kill leaves you standing, once per run.
	if has("phoenix_feather") and amount >= pl.current_health:
		Progression.relics.erase("phoenix_feather")
		Progression.relics_changed.emit()
		pl.current_health = maxi(1, roundi(pl.max_health * 0.3))
		pl.health_changed.emit(pl.current_health, pl.max_health)
		CombatFX.burst(pl.global_position + Vector2(0, -8), Color(1.0, 0.6, 0.25), 24, 70.0, 0.7, -40.0, 2.0)
		ItemBanner.show_item("Phoenix Feather", "It burns away. You rise again.", Color(1.0, 0.6, 0.25))
		return 0
	return amount

# The player dodged.
static func on_dodge(pl: Player) -> void:
	if has("frost_heels"):
		_chill_around(pl, 34.0, 0.7)

static func _chill_around(pl: Player, radius: float, seconds: float) -> void:
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_alive and e.global_position.distance_to(pl.global_position) < radius and not (e is BossBase):
			e.apply_freeze(seconds)
	CombatFX.burst(pl.global_position, Color(0.6, 0.88, 1.0), 12, 50.0, 0.4, 0.0, 1.5)
