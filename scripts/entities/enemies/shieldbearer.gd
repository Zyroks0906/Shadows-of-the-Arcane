extends SheetEnemy
class_name Shieldbearer

# The shield-bearer: a skeleton behind a round shield (LuizMelo's Skeleton, with its own
# guard animation). Blows from the front glance off (15% gets through, with a clank and
# sparks); it turns slowly, so dodge past it and strike its back or flanks. Reactions and
# burns still hurt it in full.

const TURN := 2.4            # radians per second it can turn its guard
const FRONT := 0.25          # dot product above which a hit counts as frontal
const LEAK := 0.15           # share of a frontal blow that gets through

var facing := Vector2.RIGHT

func _init_stats() -> void:
	folder = "Skeleton"
	body_px = 18.0
	art_px = 51.0
	sheets["shield"] = ["Shield", 10.0, false]
	max_health = 70
	resistance = 3
	character_name = "Skeleton Guard"
	speed = 28.0
	attack_range = 16.0
	attack_reach = 20.0
	attack_damage = 12
	attack_delay = 0.55
	attack_cooldown = 1.3
	detection_range = 160.0
	knockback_scale = 0.35

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_alive and is_instance_valid(player) and not is_frozen:
		var want := (player.global_position - global_position).normalized()
		facing = facing.rotated(clampf(facing.angle_to(want), -TURN * delta, TURN * delta))
	# The shield arm is drawn on the side it faces.
	if is_alive and not is_attacking and absf(facing.x) > 0.1:
		animated_sprite.flip_h = facing.x < 0.0

func take_elemental_hit(damage: int, element: ElementalSystem.Element, source: Node = null) -> void:
	if is_alive and damage > 0 and source is Node2D and not is_frozen:
		var from := ((source as Node2D).global_position - global_position).normalized()
		if facing.dot(from) > FRONT:
			damage = int(damage * LEAK)
			CombatFX.burst(global_position + facing * 7.0 + Vector2(0, -7), Color(1.0, 0.85, 0.5), 8, 60.0, 0.25, 0.0, 1.2)
			CombatFX.floating_label(global_position + Vector2(0, -20), "BLOCKED", Color(0.85, 0.8, 0.7), 0.8)
			AudioManager.play_bank_at("shield_block", global_position, -6.0, 1.1)
			if not is_attacking:
				_anim_play(animated_sprite, "shield", AnimPriority.ACTION)
				get_tree().create_timer(0.35).timeout.connect(_lower_guard)
	super.take_elemental_hit(damage, element, source)

func _lower_guard() -> void:
	if is_instance_valid(self) and not is_attacking:
		_anim_release(AnimPriority.ACTION)
