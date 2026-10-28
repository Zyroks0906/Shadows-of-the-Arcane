extends Node2D
class_name Burn

# Burning: the target takes a chunk of damage every TICK seconds for a few seconds, flickers
# orange and sheds little flames. Re-applying refreshes the duration (it doesn't stack).
# Damage per tick is a share of the target's max health (bosses take a smaller share), and
# counts as the player's damage when the player set it.

const TICK := 0.5
const SHARE := 0.08 # of max health per tick for normal creatures
const BOSS_SHARE := 0.015
const BOSS_TICK_CAP := 8

var target: BaseCharacter
var source: Node
var ticks_left: int = 6
var _t: float = 0.0
var _flame_t: float = 0.0

static func apply(t: BaseCharacter, from: Node, ticks: int = 6) -> void:
	if not is_instance_valid(t) or not t.is_alive:
		return
	var b := t.get_node_or_null("Burn") as Burn
	if b:
		b.ticks_left = maxi(b.ticks_left, ticks)
		return
	b = Burn.new()
	b.name = "Burn"
	b.target = t
	b.source = from
	b.ticks_left = ticks
	t.add_child(b)
	CombatFX.floating_label(t.global_position + Vector2(0, -10), "BURNING", Color(1.0, 0.55, 0.2), 0.8)

func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive or ticks_left <= 0:
		_end()
		return
	_t += delta
	_flame_t -= delta
	if _flame_t <= 0.0:
		_flame_t = 0.12
		CombatFX.burst(target.global_position + Vector2(randf_range(-4, 4), randf_range(-8, 0)), Color(1.0, randf_range(0.35, 0.65), 0.1), 2, 14.0, 0.45, -50.0, 1.5)
	var spr := target.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if spr:
		spr.self_modulate = Color(1, 1, 1).lerp(Color(1.5, 0.8, 0.5), 0.5 + 0.5 * sin(_t * 18.0))
	if _t >= TICK:
		_t -= TICK
		ticks_left -= 1
		var boss := target is BossBase
		var dmg := maxi(2, roundi(target.max_health * (BOSS_SHARE if boss else SHARE)))
		if boss:
			dmg = mini(dmg, BOSS_TICK_CAP) # bosses' huge health pools must not make it absurd
		dmg += target.resistance # fire ignores armour: undo the flat reduction
		target.next_hit_color = Color(1.0, 0.55, 0.2)
		var by_player := source is Player
		if by_player:
			Progression.player_hit_depth += 1
		target.receive_damage(dmg)
		if by_player:
			Progression.player_hit_depth -= 1

func _end() -> void:
	if is_instance_valid(target):
		var spr := target.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if spr:
			spr.self_modulate = Color.WHITE
	queue_free()
