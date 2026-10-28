extends Node2D
class_name AegisOrbit

# Aegis (the Knight's ultimate): golden shields circle the knight for a while, striking and
# shoving back whatever they pass through. Each enemy can be struck by a given shield once
# every HIT_EVERY seconds.

const RADIUS := 24.0
const SPEED := 3.4 # radians per second
const HIT_EVERY := 0.45

var knight: Player
var count := 4
var duration := 8.0
var damage := 10
var _t := 0.0
var _last_hit: Dictionary = {} # "enemy_id:shield" -> time

static func summon(p: Player, shields: int, seconds: float, dmg: int) -> AegisOrbit:
	var old := p.get_node_or_null("AegisOrbit")
	if old:
		old.queue_free()
	var a := AegisOrbit.new()
	a.name = "AegisOrbit"
	a.knight = p
	a.count = shields
	a.duration = seconds
	a.damage = dmg
	a.z_index = 3
	p.add_child(a)
	return a

func _shield_pos(i: int) -> Vector2:
	var a := _t * SPEED + TAU * i / count
	# Flattened ring around the middle of the knight's body.
	return knight.body_center() + Vector2(cos(a) * RADIUS, sin(a) * RADIUS * 0.6)

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration or not knight.is_alive:
		for i in count:
			CombatFX.burst(global_position + _shield_pos(i), Color(1.0, 0.85, 0.4), 6, 30.0, 0.3)
		queue_free()
		return
	for i in count:
		var sp := global_position + _shield_pos(i)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.is_alive or e.global_position.distance_to(sp) > 10.0:
				continue
			var key := "%d:%d" % [e.get_instance_id(), i]
			if _t - float(_last_hit.get(key, -9.0)) < HIT_EVERY:
				continue
			_last_hit[key] = _t
			e.take_elemental_hit(damage, ElementalSystem.Element.NONE, knight)
			e.apply_knockback((e.global_position - global_position).normalized() * 150.0)
			knight.on_hit_landed("burst")
			CombatFX.burst(sp, Color(1.0, 0.9, 0.5), 8, 50.0, 0.25)
			AudioManager.play_bank_at("shield_block", sp, -6.0, 1.3)
	queue_redraw()

var _emblem: Texture2D

func _draw() -> void:
	var fade := clampf((duration - _t) / 0.6, 0.0, 1.0)
	if not _emblem:
		var data: Dictionary = CombatFX._pvfx_frames("arcane-parry")
		if not data.is_empty():
			var sf: SpriteFrames = data["frames"]
			_emblem = sf.get_frame_texture("default", int(sf.get_frame_count("default") * 0.7)) # emblem fully formed
	for i in count:
		var c := _shield_pos(i)
		# A short golden trail behind each shield.
		for k in range(1, 4):
			var a := _t * SPEED + TAU * i / count - k * 0.12
			var tp := knight.body_center() + Vector2(cos(a) * RADIUS, sin(a) * RADIUS * 0.6)
			draw_circle(tp, 2.5 - k * 0.5, Color(1.0, 0.85, 0.4, 0.25 * fade / k))
		# The shield: PVFX's arcane-parry emblem (gold rim, teal face), bobbing a little.
		if _emblem:
			var sz := 18.0 + sin(_t * 6.0 + i) * 0.8
			draw_texture_rect(_emblem, Rect2(c - Vector2(sz, sz) * 0.5 - Vector2(0, 1), Vector2(sz, sz)), false, Color(1, 1, 1, fade))
