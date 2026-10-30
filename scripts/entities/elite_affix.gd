extends Node2D
class_name EliteAffix

# Elite enemies ("champions"): now and then a creature spawns with a trait that changes how
# it fights. Elites are tougher, wear a coloured aura on the floor and a nameplate with
# their own health bar, and pay out: triple experience, a handful of coins and sometimes a
# health potion. The deeper the level, the more of them.
#
#   SWIFT     faster, attacks sooner
#   HULKING   bigger, much tougher, hits harder, barely flinches
#   VAMPIRIC  heals when it hurts you
#   VOLATILE  bursts into flame a moment after dying (hurts you and other monsters)
#   WARDED    a ward soaks up the first three hits
#   GILDED    no special power, but carries a pile of gold

enum Kind { SWIFT, HULKING, VAMPIRIC, VOLATILE, WARDED, GILDED, PHANTOM, ELEMENTAL }

const INFO := {
	Kind.SWIFT: {"name": "Swift", "color": Color(0.4, 0.95, 1.0), "desc": "Faster, and quicker to strike."},
	Kind.HULKING: {"name": "Hulking", "color": Color(1.0, 0.35, 0.25), "desc": "Huge and very tough. Hits hard and barely flinches."},
	Kind.VAMPIRIC: {"name": "Vampiric", "color": Color(0.85, 0.1, 0.3), "desc": "Heals itself whenever it hurts you."},
	Kind.VOLATILE: {"name": "Volatile", "color": Color(1.0, 0.6, 0.15), "desc": "Explodes a moment after dying: step away, or lure others in."},
	Kind.WARDED: {"name": "Warded", "color": Color(0.6, 0.75, 1.0), "desc": "A magic ward blocks its first three hits."},
	Kind.GILDED: {"name": "Gilded", "color": Color(1.0, 0.85, 0.3), "desc": "No special power, but it carries a pile of gold."},
	Kind.PHANTOM: {"name": "Phantom", "color": Color(0.75, 0.8, 1.0), "desc": "Fades out now and then: while faded, blows pass right through it."},
	Kind.ELEMENTAL: {"name": "Elemental", "color": Color(0.55, 1.0, 0.75), "desc": "Wreathed in an element that keeps coming back. Plain blows barely hurt it: make it react."},
}
const CHANCE_BY_LEVEL := [0.08, 0.12, 0.16]
const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const COIN_SCENE := "res://assets/sprites/sprite_frames/Coin.tscn"
const HEALTH := "res://scenes/world/HealthPotion.tscn"

static var _announced: Dictionary = {} # kinds already explained to the player this session
static var enabled := true # tests turn elites off to keep fights deterministic
static var forced := -1 # dev/playtest: every eligible enemy gets this kind

var kind: Kind
var enemy: Enemy
var color: Color
var ward := 0
var _t := 0.0
var _top := -16.0 # nameplate height above the enemy's origin (unscaled px)
var _foot := 0.0
var _width := 14.0
var _phased := false         # Phantom: faded out, blows pass through
var _reimbue := 0.0          # Elemental: time until its element returns

const PHANTOM_CYCLE := 5.0   # seconds per cycle, the last PHANTOM_FADED of them faded
const PHANTOM_FADED := 2.0
const ELEMENTAL_TAKES := 0.4 # share of a plain (non-reaction) blow it feels

# Rolls for an elite; called from Enemy._ready after its stats are set and before health is
# filled, so the bonuses below are the real numbers.
static func roll(e: Enemy) -> EliteAffix:
	if not enabled or e is BossBase or e.max_health >= 300: # no elite bosses or minibosses
		return null
	if forced < 0 and not e.force_elite:
		var lvl := maxi(GameManager.MAPS.find(GameManager.current_map), 0)
		if randf() >= CHANCE_BY_LEVEL[mini(lvl, CHANCE_BY_LEVEL.size() - 1)]:
			return null
	var a := EliteAffix.new()
	a.kind = (forced if forced >= 0 else randi() % Kind.size()) as Kind
	a.enemy = e
	a.color = INFO[a.kind]["color"]
	a._apply_stats()
	return a

func _apply_stats() -> void:
	enemy.max_health = int(enemy.max_health * 1.6)
	match kind:
		Kind.SWIFT:
			enemy.speed *= 1.45
			enemy.attack_cooldown *= 0.75
		Kind.HULKING:
			enemy.max_health = int(enemy.max_health * 1.6)
			enemy.attack_damage = int(enemy.attack_damage * 1.3)
			enemy.body_scale *= 1.25
			enemy.knockback_scale *= 0.4
			enemy.cc_resistance = maxf(enemy.cc_resistance, 0.4)
		Kind.WARDED:
			ward = 3
	enemy.character_name = "%s %s" % [INFO[kind]["name"], enemy.character_name]

func display_name() -> String:
	return INFO[kind]["name"]

# Added to the enemy once it is in the tree (its sprite and scale are final by then).
func setup() -> void:
	name = "Elite"
	z_index = 2
	enemy.add_child(self)
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite:
		var m := GroundShadow._measure(sprite)
		_foot = m["foot"].y
		_top = m["top"]
		_width = m["width"] * absf(enemy.scale.x)
	scale = Vector2.ONE / absf(enemy.scale.x) # draw in screen pixels whatever the body scale
	_foot *= absf(enemy.scale.x)
	_top *= absf(enemy.scale.x)
	# The aura goes under the creature, right above its shadow.
	var aura := _Aura.new()
	aura.color = color
	aura.radius = clampf(_width * 0.6, 6.0, 14.0)
	aura.position = Vector2(0, _foot / absf(enemy.scale.x))
	aura.scale = scale
	enemy.add_child(aura)
	enemy.move_child(aura, mini(1, enemy.get_child_count() - 1))

# --- Hooks called by Enemy -----------------------------------------------------------------

# Elemental: plain blows are blunted; a reaction (Reactions marks its hits) lands in full.
func scale_damage(amount: int) -> int:
	if kind != Kind.ELEMENTAL or amount <= 0 or enemy.get_meta("reaction_hit", false):
		return amount
	if randf() < 0.35:
		CombatFX.floating_label(enemy.global_position + Vector2(0, _top - 4), "REACT!", color, 0.7)
	return maxi(1, roundi(amount * ELEMENTAL_TAKES))

# True if the ward ate the hit (or a faded Phantom let it through).
func absorb(amount: int) -> bool:
	if kind == Kind.PHANTOM and _phased and amount > 0:
		CombatFX.floating_label(enemy.global_position + Vector2(0, _top - 4), "PHASED", color, 0.6)
		return true
	if ward <= 0 or amount <= 0:
		return false
	ward -= 1
	CombatFX.floating_label(enemy.global_position + Vector2(0, _top - 4), "WARDED" if ward > 0 else "WARD BROKEN", color, 0.8)
	CombatFX.burst(enemy.global_position, color, 10 if ward > 0 else 22, 70.0, 0.35)
	AudioManager.play_bank_at("magic_shield", enemy.global_position, -4.0, 1.4 if ward > 0 else 0.8)
	return true

func on_hit_player(damage: int) -> void:
	if kind == Kind.VAMPIRIC and enemy.is_alive:
		var heal := maxi(1, int(damage * 0.6))
		enemy.current_health = mini(enemy.current_health + heal, enemy.max_health)
		CombatFX.floating_label(enemy.global_position + Vector2(0, _top), "+%d" % heal, color, 0.8)
		CombatFX.burst(enemy.global_position, color, 8, 40.0, 0.4, -40.0)

func on_death() -> void:
	_drop_loot()
	if kind == Kind.VOLATILE:
		_explode.call_deferred(enemy.global_position, enemy.get_parent())
	visible = false

func xp_mult() -> float:
	return 3.0

# --- Loot --------------------------------------------------------------------------------

func _drop_loot() -> void:
	var parent := enemy.get_parent()
	var from := enemy.global_position
	var drops: Array[Node2D] = []
	var coins := randi_range(8, 14) if kind == Kind.GILDED else randi_range(2, 4)
	var count := mini(coins, 4)
	for i in count:
		var coin: Node2D = load(COIN_SCENE).instantiate()
		parent.add_child.call_deferred(coin)
		var c := _collectible(coin)
		if c:
			c.value = coins / count + (1 if i < coins % count else 0)
		drops.append(coin)
	if randf() < 0.3:
		var p: Node2D = load(HEALTH).instantiate()
		parent.add_child.call_deferred(p)
		drops.append(p)
	var i := 0
	for d in drops:
		var angle := TAU * (i + 0.5) / drops.size() + randf() * 0.4
		var to := from + Vector2(cos(angle), sin(angle) * 0.7) * randf_range(12.0, 20.0)
		_pop.call_deferred(d, from, to, i * 0.06)
		i += 1

func _pop(item: Node2D, from: Vector2, to: Vector2, delay: float) -> void:
	var c := _collectible(item)
	if c and c.has_method("pop_out"):
		c.pop_out(from, to, delay)
	else:
		item.global_position = to

static func _collectible(item: Node) -> Node:
	if item.has_method("pop_out"):
		return item
	return item.get_node_or_null("Area2D")

# --- Volatile ----------------------------------------------------------------------------

const BLAST_RADIUS := 34.0
const BLAST_DELAY := 0.8

static func _explode(at: Vector2, parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	var warn := _BlastWarning.new()
	warn.z_index = 1 # above the floor layers (level 1 draws its floors at z 0)
	parent.add_child(warn)
	warn.global_position = at # after add_child: level 1's root is offset
	AudioManager.play_bank_at("fire_small", at, -2.0, 0.8)
	await parent.get_tree().create_timer(BLAST_DELAY, false).timeout
	if not is_instance_valid(parent):
		return
	warn.queue_free()
	CombatFX.shockwave(at, Color(1.0, 0.55, 0.15), BLAST_RADIUS, 0.3, 4.0)
	CombatFX.burst(at, Color(1.0, 0.5, 0.1), 30, 120.0, 0.5, -20.0, 3.0)
	CombatFX.shake(3.0, 0.25)
	AudioManager.play_bank_at("fire_impact", at, 2.0, 0.7)
	for p in parent.get_tree().get_nodes_in_group("player"):
		if p is Player and p.is_alive and p.global_position.distance_to(at) <= BLAST_RADIUS:
			p.take_elemental_hit(18, ElementalSystem.Element.PYRO, null)
			p.apply_knockback((p.global_position - at).normalized() * 160.0)
	# It hurts its own kind too: lure them in.
	for e in parent.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_alive and e.global_position.distance_to(at) <= BLAST_RADIUS:
			e.take_elemental_hit(40, ElementalSystem.Element.PYRO, null)

# --- Drawing -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if kind == Kind.PHANTOM and enemy.is_alive:
		var c := fmod(_t, PHANTOM_CYCLE)
		var fade := PHANTOM_CYCLE - PHANTOM_FADED
		# Fades out over 0.3 s, stays faded, fades back in over 0.3 s.
		var a := 1.0
		if c > fade:
			a = lerpf(1.0, 0.12, clampf((c - fade) / 0.3, 0.0, 1.0))
			a = lerpf(a, 1.0, clampf((c - PHANTOM_CYCLE + 0.3) / 0.3, 0.0, 1.0))
		var was := _phased
		_phased = c > fade + 0.15 and c < PHANTOM_CYCLE - 0.15
		enemy.modulate.a = a
		if _phased != was:
			AudioManager.play_bank_at("teleport", enemy.global_position, -14.0, 1.6 if _phased else 1.2)
	if kind == Kind.ELEMENTAL and enemy.is_alive:
		_reimbue -= delta
		if _reimbue <= 0.0 and enemy.current_imbued_element == ElementalSystem.Element.NONE:
			_reimbue = 3.0
			var el: int = [ElementalSystem.Element.PYRO, ElementalSystem.Element.HYDRO, ElementalSystem.Element.ELECTRO, ElementalSystem.Element.CRYO].pick_random()
			enemy.current_imbued_element = el
			enemy._on_element_applied()
	# The first time the player meets each kind, a banner says what it does.
	if not _announced.has(kind) and enemy.is_alive and is_instance_valid(enemy.player) 			and enemy.player.global_position.distance_to(enemy.global_position) < 120.0:
		_announced[kind] = true
		ItemBanner.show_item("Elite: %s" % INFO[kind]["name"], "%s Elites drop coins and triple experience." % INFO[kind]["desc"], color)

func _draw() -> void:
	if not enemy.is_alive:
		return
	# Nameplate: the trait in its colour over a little health bar. The text is drawn at the
	# camera's inverse zoom so it is 8 crisp screen pixels however close the camera is.
	var zoom := maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var label: String = INFO[kind]["name"].to_upper()
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var y := _top - 5.0
	draw_set_transform(Vector2(0, y), 0.0, Vector2.ONE / zoom)
	draw_string_outline(FONT, Vector2(-w / 2.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, Color(0, 0, 0))
	draw_string(FONT, Vector2(-w / 2.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bw := 14.0
	var f := clampf(float(enemy.current_health) / maxf(enemy.max_health, 1), 0.0, 1.0)
	draw_rect(Rect2(-bw / 2.0 - 0.5, y + 1.0, bw + 1.0, 2.0), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-bw / 2.0, y + 1.5, bw * f, 1.0), color)
	# Ward: a bubble with one pip per charge left.
	if ward > 0:
		var c := Vector2(0, (_top + _foot) / 2.0)
		var r := (_foot - _top) * 0.62
		draw_arc(c, r, 0, TAU, 28, Color(color, 0.35 + 0.15 * sin(_t * 4.0)), 1.0)
		for i in ward:
			var a := _t * 1.5 + TAU * i / 3.0
			draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * r - Vector2(1, 1), Vector2(2, 2)), color)

class _Aura extends Node2D:
	var color := Color.WHITE
	var radius := 10.0
	var _t := randf() * TAU

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var e := get_parent() as BaseCharacter
		if e and not e.is_alive:
			return
		var k := 0.5 + 0.5 * sin(_t * 3.0)
		var r := radius + k * 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, r, Color(color, 0.18 + 0.1 * k))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, 0.7), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Motes rising from the ring.
		for i in 3:
			var p := fmod(_t * 0.6 + i / 3.0, 1.0)
			var a := TAU * i / 3.0 + _t * 0.5
			var pos := Vector2(cos(a) * r * 0.8, sin(a) * r * 0.3 - p * 18.0)
			draw_rect(Rect2(pos.round(), Vector2(1, 1)), Color(color, 1.0 - p))

class _BlastWarning extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / EliteAffix.BLAST_DELAY, 0.0, 1.0)
		var r := EliteAffix.BLAST_RADIUS
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.4, 0.1, 0.12 + 0.18 * k))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.9), 1.5)
		draw_circle(Vector2.ZERO, r * k, Color(1.0, 0.6, 0.2, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
