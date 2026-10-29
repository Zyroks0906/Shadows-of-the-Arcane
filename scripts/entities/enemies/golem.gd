extends BossBase

@onready var laser_sprite: AnimatedSprite2D = $laser
@onready var weapon_sprite: AnimatedSprite2D = $weapon
@onready var laser_area: Area2D = $laser/Area2D

var _is_hardened: bool = false
var _hits_taken_recently: int = 0
var _hit_timer: float = 0.0

func _init_stats() -> void:
	max_health = 650
	resistance = 0
	character_name = "Golem"

func _ready() -> void:
	base_element = ElementalSystem.Element.NONE
	speed = 30.0
	attack_range = 70.0
	attack_damage = 32
	attack_cooldown = 1.2
	special_attack_cooldown = 4.0
	super._ready()
	if laser_sprite: laser_sprite.visible = false
	if weapon_sprite: weapon_sprite.visible = false
	if laser_area:
		laser_area.monitoring = false # the old sprite laser is replaced by BossMoves.laser

func _physics_process(delta: float) -> void:
	if not is_alive: return

	if is_instance_valid(player) and not is_attacking:
		animated_sprite.flip_h = player.global_position.x < global_position.x

	_hit_timer -= delta
	if _hit_timer <= 0:
		_hits_taken_recently = 0
		if _is_hardened:
			_is_hardened = false
			mostrar_texto_flotante("NORMAL", Color.WHITE)

	if boss_state == BossState.SPECIAL and laser_sprite and laser_sprite.visible:
		var dir = (player.global_position - global_position).normalized()
		var target_angle = dir.angle()
		laser_sprite.rotation = lerp_angle(laser_sprite.rotation, target_angle, delta * 2.5)

	super._physics_process(delta)

func receive_damage(amount: int) -> void:
	if not is_alive: return
	_hits_taken_recently += 1
	_hit_timer = 2.0
	if _hits_taken_recently > 10 and not _is_hardened:
		_is_hardened = true
		mostrar_texto_flotante("FOCUSED", Color.ORANGE)
	super.receive_damage(amount)

# --- Moves (BossMoves: each one telegraphed) ------------------------------------------
# Close: arm slams in a cone. In reach of its eye: a sweeping laser. Too close for comfort:
# a shockwave. Below half health it is enraged: faster wind-ups, more specials, and it
# starts calling down rock rain.
var _move_i := 0

func _enraged() -> bool:
	return current_health < max_health * 0.5

# The eye, near the top of the body (sprite measured once).
var _eye_cache := Vector2.INF
func _eye() -> Vector2:
	if _eye_cache == Vector2.INF:
		var m := GroundShadow._measure(animated_sprite)
		_eye_cache = Vector2(0.0, lerpf(m["top"], m["foot"].y, 0.2)) * absf(scale.y)
	return _eye_cache

func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	if is_instance_valid(player):
		animated_sprite.flip_h = player.global_position.x < global_position.x
	_play_animation("attack1")
	await BossMoves.slam(self, 58.0, 110.0, attack_damage, 0.55 if _enraged() else 0.75)
	await _end_move(attack_cooldown)

func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	_move_i += 1
	_play_animation("charge_energy")
	var d := global_position.distance_to(player.global_position) if is_instance_valid(player) else 999.0
	if d < 60.0:
		mostrar_texto_flotante("SHOCKWAVE", Color.ORANGE)
		await BossMoves.shockwave(self, 110.0, int(attack_damage * 0.8))
	elif _enraged() and _move_i % 2 == 0:
		mostrar_texto_flotante("ROCK RAIN", Color.ORANGE)
		await BossMoves.rock_rain(self, 6, int(attack_damage * 0.7))
	else:
		await BossMoves.laser(self, _eye(), 0.9, 3.0 if _enraged() else 2.2, maxi(4, attack_damage / 6), 1.2 if _enraged() else 0.9)
	special_timer = special_attack_cooldown * (0.6 if _enraged() else 1.0)
	await _end_move(attack_cooldown * 0.6)

func _end_move(cooldown: float) -> void:
	if not is_alive:
		return
	is_attacking = false
	boss_state = BossState.CHASE
	await get_tree().create_timer(cooldown, false).timeout
	if is_alive:
		can_attack = true

func die() -> void:
	if not is_alive: return
	is_alive = false
	boss_state = BossState.DEATH
	velocity = Vector2.ZERO
	XpOrb.drop(global_position, 60, get_parent())

	AudioManager.play_bank_at("roar", global_position, 4.0, 0.5)

	GameManager.notify_boss_defeat(character_name)

	var death_anim = ""
	if animated_sprite.sprite_frames.has_animation("death"): death_anim = "death"
	elif animated_sprite.sprite_frames.has_animation("Death"): death_anim = "Death"

	if death_anim != "":
		animated_sprite.play(death_anim)
		await animated_sprite.animation_finished

	await get_tree().create_timer(1.0).timeout
	queue_free()
