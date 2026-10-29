extends BossBase

# Whispering Caverns boss: a crystal golem.
#  - Slam: melee Cryo hit with knockback.
#  - Glacial Spikes: telegraphed ice eruptions chasing the player's position.
#  - Below half health it shatters off two Cryo wisps once.
# Being Cryo, it can be Melted (Pyro) or Frozen (Hydro) - Hydro classes freeze it briefly.

const WISP_SCENE := "res://scenes/entities/Enemies/Wisp.tscn"

var _summoned: bool = false

func _init_stats() -> void:
	max_health = 950
	resistance = 4
	character_name = "Guardian"
	speed = 26.0
	attack_range = 34.0
	attack_damage = 24
	attack_cooldown = 1.6
	attack_delay = 0.6
	detection_range = 170.0
	special_attack_cooldown = 6.0
	base_element = ElementalSystem.Element.CRYO
	use_element_tint = false
	show_element_aura = false

func _ready() -> void:
	super._ready()
	for anim in ["attack1", "death", "hurt"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			animated_sprite.sprite_frames.set_animation_loop(anim, false)
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = Color(0.5, 0.85, 1.0)
	light.texture_scale = 1.6
	light.energy = 0.8
	add_child(light)

func _physics_process(delta: float) -> void:
	if is_alive and is_instance_valid(player) and not is_attacking:
		animated_sprite.flip_h = player.global_position.x < global_position.x
	super._physics_process(delta)

func receive_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_alive and not _summoned and current_health < max_health * 0.5:
		_summoned = true
		_summon_shards()

func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false
	_play_animation("attack1")
	if is_instance_valid(player):
		BossMoves.warn_cone(self, player.global_position - global_position, attack_range + 10.0, 120.0, attack_delay)
	await get_tree().create_timer(attack_delay).timeout
	if not is_alive: return
	if is_instance_valid(player) and not is_frozen and global_position.distance_to(player.global_position) <= attack_range + 10:
		player.take_elemental_hit(attack_damage, base_element, self)
		player.apply_knockback((player.global_position - global_position).normalized() * 280.0)
		CombatFX.shake(4.0, 0.25)
	AudioManager.play_bank_at("stomp", global_position, 2.0, 0.6)
	await get_tree().create_timer(attack_recovery_delay).timeout
	if not is_alive: return
	is_attacking = false
	boss_state = BossState.CHASE
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true

func _perform_special_attack() -> void:
	is_attacking = true
	special_timer = special_attack_cooldown
	velocity = Vector2.ZERO
	mostrar_texto_flotante("GLACIAL SPIKES", Color(0.6, 0.9, 1.0))
	_play_animation("idle")
	for i in 3:
		if not is_alive or not is_instance_valid(player): break
		_ice_spike(player.global_position)
		await get_tree().create_timer(0.45).timeout
	await get_tree().create_timer(0.8).timeout
	if not is_alive: return
	is_attacking = false
	boss_state = BossState.CHASE

func _ice_spike(target: Vector2) -> void:
	var mark := _Telegraph.new()
	mark.radius = 18.0
	mark.color = Color(0.55, 0.9, 1.0)
	get_parent().add_child(mark)
	mark.global_position = target
	await get_tree().create_timer(0.75).timeout
	if is_instance_valid(mark):
		mark.queue_free()
	if not is_alive: return
	CombatFX.burst(target, Color(0.8, 0.97, 1.0), 22, 110.0, 0.45, -60.0, 2.5)
	CombatFX.shockwave(target, Color(0.6, 0.9, 1.0), 20.0, 0.25, 2.0)
	AudioManager.play_bank_at("ice_impact", target, -2.0, 0.85)
	if is_instance_valid(player) and player.global_position.distance_to(target) <= 18.0:
		player.take_elemental_hit(14, ElementalSystem.Element.CRYO, self)

func _summon_shards() -> void:
	mostrar_texto_flotante("SHATTERED CORE", Color(0.6, 0.9, 1.0))
	CombatFX.shockwave(global_position, Color(0.6, 0.9, 1.0), 70.0, 0.5, 4.0)
	CombatFX.shake(5.0, 0.4)
	var scene: PackedScene = load(WISP_SCENE)
	for offset in [Vector2(-30, 10), Vector2(30, 10)]:
		var wisp: Enemy = scene.instantiate()
		wisp.base_element = ElementalSystem.Element.CRYO
		get_parent().add_child.call_deferred(wisp)
		wisp.set_deferred("global_position", global_position + offset)

func die() -> void:
	if not is_alive: return
	CombatFX.burst(global_position, Color(0.75, 0.95, 1.0), 50, 160.0, 0.9, 120.0, 3.5)
	CombatFX.shake(7.0, 0.6)
	super.die()

class _Telegraph extends Node2D:
	var radius: float = 16.0
	var color: Color = Color.WHITE
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / 0.75, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * k, Color(color, 0.25))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color, 0.8), 1.0)
