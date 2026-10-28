extends RefCounted
class_name Reactions

# Gameplay side of the elemental reactions. ElementalSystem decides *which* reaction
# happens and its damage multiplier; this file decides what the reaction *does*.


const OVERLOAD_RADIUS := 56.0
const OVERLOAD_KNOCKBACK := 280.0
const SUPERCONDUCT_RADIUS := 48.0
const SUPERCONDUCT_SHRED := 0.5
const SUPERCONDUCT_DURATION := 6.0
const SWIRL_RADIUS := 64.0
const SWIRL_DAMAGE_RATIO := 0.6
const ELECTRO_TICKS := 4
const ELECTRO_TICK_RATIO := 0.3
const ELECTRO_CHAIN_RADIUS := 56.0
const FREEZE_DURATION := 2.5
const SHATTER_MULTIPLIER := 1.5

static func trigger(target: BaseCharacter, reaction: String, aura: ElementalSystem.Element, trigger_element: ElementalSystem.Element, base_damage: int, source: Node) -> void:
	var pos := target.global_position
	var color: Color = ElementalSystem.REACTION_DATA.get(reaction, ElementalSystem.REACTION_DATA["None"])["color"]
	CombatFX.floating_label(pos + Vector2(0, -16), reaction.to_upper(), color, 1.15)

	match reaction:
		"Vaporize":
			CombatFX.burst(pos, Color(0.85, 0.92, 1.0), 26, 60.0, 0.8, -80.0, 3.0)
			CombatFX.burst(pos, Color.ORANGE_RED, 10, 90.0, 0.3)
			_bank("fire_impact", 0.0, 1.3)
			_bank("slime", -6.0, 1.6)
			CombatFX.hit_stop(0.07)
			CombatFX.shake(2.5, 0.2)
		"Melt":
			CombatFX.burst(pos, Color.CORAL, 22, 80.0, 0.5, 60.0, 2.5)
			CombatFX.burst(pos, Color(0.7, 0.95, 1.0), 12, 50.0, 0.6, 120.0, 2.0)
			_bank("fire_impact", 2.0, 0.85)
			_bank("ice_crack", -4.0, 1.2)
			CombatFX.hit_stop(0.07)
			CombatFX.shake(2.5, 0.2)
		"Overloaded":
			_overloaded(target, base_damage, source)
		"Superconduct":
			_superconduct(target, base_damage, source)
		"Electro-Charged":
			_electro_charged(target, base_damage)
		"Frozen":
			CombatFX.burst(pos, Color(0.75, 0.95, 1.0), 18, 55.0, 0.5, 0.0, 2.0)
			_bank("ice_crack", 0.0, 0.9)
			if target.has_method("apply_freeze"):
				target.apply_freeze(FREEZE_DURATION)
		"Swirl":
			var absorbed := aura if aura != ElementalSystem.Element.ANEMO else trigger_element
			_swirl(target, absorbed, base_damage, source)
		"Crystallize":
			var other := aura if aura != ElementalSystem.Element.GEO else trigger_element
			_crystallize(target, other)

static func shatter(target: BaseCharacter) -> void:
	var pos := target.global_position
	CombatFX.floating_label(pos + Vector2(0, -16), "SHATTER", Color(0.8, 0.95, 1.0), 1.15)
	CombatFX.burst(pos, Color(0.85, 0.97, 1.0), 30, 140.0, 0.45, 220.0, 3.0)
	_bank("ice_impact", 4.0, 0.8)
	_bank("bottle", -2.0, 0.7)
	CombatFX.hit_stop(0.08)
	CombatFX.shake(3.0, 0.2)

static func _overloaded(target: BaseCharacter, base_damage: int, source: Node) -> void:
	var pos := target.global_position
	CombatFX.shockwave(pos, Color.CRIMSON, OVERLOAD_RADIUS, 0.3, 4.0)
	CombatFX.burst(pos, Color.ORANGE_RED, 34, 160.0, 0.5, 0.0, 3.5)
	CombatFX.burst(pos, Color.MEDIUM_PURPLE, 12, 110.0, 0.35, 0.0, 2.0)
	_bank("fire_impact", 4.0, 0.7)
	_bank("electric_hit", 0.0, 0.8)
	CombatFX.hit_stop(0.09)
	CombatFX.shake(5.0, 0.3)
	target.apply_knockback(_away(source, target) * OVERLOAD_KNOCKBACK)
	for other in _neighbours(target, OVERLOAD_RADIUS):
		_hit(other, base_damage, Color.CRIMSON)
		other.apply_knockback((other.global_position - pos).normalized() * OVERLOAD_KNOCKBACK)

static func _superconduct(target: BaseCharacter, base_damage: int, _source: Node) -> void:
	var pos := target.global_position
	CombatFX.shockwave(pos, Color.CYAN, SUPERCONDUCT_RADIUS, 0.35, 3.0)
	CombatFX.burst(pos, Color(0.7, 1.0, 1.0), 24, 100.0, 0.6, -20.0, 2.0)
	_bank("electric_hit", -2.0, 0.7)
	_bank("ice_crack", -6.0, 1.3)
	CombatFX.hit_stop(0.05)
	CombatFX.shake(2.0, 0.15)
	target.apply_resistance_shred(SUPERCONDUCT_SHRED, SUPERCONDUCT_DURATION)
	for other in _neighbours(target, SUPERCONDUCT_RADIUS):
		_hit(other, int(base_damage * 0.5), Color.CYAN)
		other.apply_resistance_shred(SUPERCONDUCT_SHRED, SUPERCONDUCT_DURATION)

static func _electro_charged(target: BaseCharacter, base_damage: int) -> void:
	_bank("electric_hit", -4.0, 1.0)
	CombatFX.burst(target.global_position, Color.MEDIUM_PURPLE, 14, 70.0, 0.4)
	var existing := target.get_node_or_null("ElectroCharge")
	if existing:
		existing.ticks_left = ELECTRO_TICKS
		return
	var dot := _ElectroCharge.new()
	dot.name = "ElectroCharge"
	dot.tick_damage = maxi(1, int(base_damage * ELECTRO_TICK_RATIO))
	dot.ticks_left = ELECTRO_TICKS
	target.add_child(dot)

static func _swirl(target: BaseCharacter, absorbed: ElementalSystem.Element, base_damage: int, source: Node) -> void:
	var pos := target.global_position
	var color := ElementalSystem.get_element_color(absorbed)
	CombatFX.shockwave(pos, Color.AQUAMARINE, SWIRL_RADIUS, 0.4, 2.0)
	CombatFX.shockwave(pos, color, SWIRL_RADIUS * 0.7, 0.5, 3.0)
	CombatFX.burst(pos, color, 28, 130.0, 0.6, 0.0, 2.5)
	_bank("teleport", -2.0, 1.3)
	CombatFX.hit_stop(0.05)
	CombatFX.shake(2.0, 0.2)
	# Deferred so a chain of swirls never recurses inside the current damage call.
	for other in _neighbours(target, SWIRL_RADIUS):
		other.take_elemental_hit.call_deferred(int(base_damage * SWIRL_DAMAGE_RATIO), absorbed, source)

static func _crystallize(target: BaseCharacter, element: ElementalSystem.Element) -> void:
	var pos := target.global_position
	CombatFX.burst(pos, Color.GOLDENROD, 18, 80.0, 0.4)
	_bank("gem", 0.0, 0.9)
	# Enemies drop a shard the player can pick up; a player hit by Geo just gets the visuals.
	if not target.is_in_group("enemies"):
		return
	var shard := CrystalShard.new()
	shard.element = element
	target.get_parent().add_child.call_deferred(shard)
	shard.set_deferred("global_position", pos + Vector2(randf_range(-10, 10), randf_range(-6, 6)))

static func _hit(target: BaseCharacter, amount: int, color: Color) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	target.next_hit_color = color
	target.receive_damage(amount)

# Living characters on the same side as the target, excluding the target itself.
static func _neighbours(target: BaseCharacter, radius: float) -> Array[BaseCharacter]:
	var out: Array[BaseCharacter] = []
	if not target.is_in_group("enemies"):
		return out
	for node in target.get_tree().get_nodes_in_group("enemies"):
		var other := node as BaseCharacter
		if other and other != target and other.is_alive and other.global_position.distance_to(target.global_position) <= radius:
			out.append(other)
	return out

static func _away(source: Node, target: Node2D) -> Vector2:
	if source is Node2D and is_instance_valid(source):
		var dir := (target.global_position - (source as Node2D).global_position).normalized()
		if dir != Vector2.ZERO:
			return dir
	return Vector2.from_angle(randf() * TAU)

static func _bank(category: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	AudioManager.play_bank(category, volume_db, pitch)

# Damage over time that also arcs to nearby enemies, like Electro-Charged in Genshin.
class _ElectroCharge extends Node:
	var tick_damage: int = 1
	var ticks_left: int = 4

	func _ready() -> void:
		var timer := Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(_tick)
		add_child(timer)

	func _tick() -> void:
		var host := get_parent() as BaseCharacter
		if not host or not host.is_alive or ticks_left <= 0:
			queue_free()
			return
		ticks_left -= 1
		Reactions._hit(host, tick_damage, Color.MEDIUM_PURPLE)
		CombatFX.burst(host.global_position, Color.MEDIUM_PURPLE, 6, 50.0, 0.25)
		var chained := 0
		for other in Reactions._neighbours(host, Reactions.ELECTRO_CHAIN_RADIUS):
			if chained >= 2:
				break
			CombatFX.lightning(host.global_position, other.global_position, Color.MEDIUM_PURPLE)
			Reactions._hit(other, tick_damage, Color.MEDIUM_PURPLE)
			chained += 1
