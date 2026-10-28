extends BaseCharacter
class_name ShadowClone

# Shadow clone (the Assassin's ultimate): a dark copy of the hero that draws the attention
# of nearby monsters (not bosses), pokes them for a little damage, and vanishes in a puff of
# smoke when hit hard enough or when its time runs out.

const LIFE := 7.0
const TAUNT_RANGE := 150.0
const HUNT_RANGE := 140.0
const SPEED := 70.0

var owner_player: Player
var _sprite: AnimatedSprite2D
var _life := LIFE
var _attack_cd := 0.6
var _bob := randf() * TAU

static func spawn(p: Player, at: Vector2) -> ShadowClone:
	var c := ShadowClone.new()
	c.owner_player = p
	c.character_name = "Shadow clone"
	c.max_health = 18
	c.resistance = 0
	p.get_parent().add_child(c)
	c.global_position = at
	return c

func _ready() -> void:
	super._ready()
	add_to_group("shadow_clones")
	collision_layer = 0
	collision_mask = 1
	var src := owner_player.animated_sprite
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "AnimatedSprite2D"
	_sprite.sprite_frames = src.sprite_frames
	_sprite.scale = src.scale
	_sprite.position = src.position
	_sprite.offset = src.offset
	_sprite.flip_h = src.flip_h
	_sprite.modulate = Color(0.35, 0.2, 0.55, 0.8)
	add_child(_sprite)
	_sprite.play(src.animation)
	_puff()
	# Monsters close by turn on the clone.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not (e is BossBase) and e.is_alive and e.global_position.distance_to(global_position) < TAUNT_RANGE:
			e.player = self

func receive_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_alive and current_health <= 0:
		die()

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	_vanish()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if not is_instance_valid(owner_player):
		queue_free()
		return
	_life -= delta
	_bob += delta * 3.0
	_sprite.position.y = owner_player.animated_sprite.position.y + sin(_bob) * 0.6
	if _life <= 0.0:
		die()
		return
	_attack_cd -= delta
	# Hunt: run at the closest monster in reach, cut it when close enough.
	var target: Enemy = null
	var best := HUNT_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if e is Enemy and e.is_alive and d < best:
			best = d
			target = e
	if target and best > 14.0:
		var dir := (target.global_position - global_position).normalized()
		velocity = dir * SPEED
		_sprite.flip_h = dir.x < 0
		_anim(["Run", "run", "Walk", "walk"])
	else:
		velocity = Vector2.ZERO
		_anim(["Idle", "idle"])
	move_and_slide()
	if target and best <= 16.0 and _attack_cd <= 0.0:
		_attack_cd = 0.7
		var dir := (target.global_position - global_position).normalized()
		_sprite.flip_h = dir.x < 0
		_anim(["Attack", "attack", "Attack1"])
		CombatFX.slash(global_position + Vector2(0, -2), dir, 16.0, 90.0, Color(0.6, 0.4, 0.9), 4.0)
		target.take_elemental_hit(maxi(1, roundi(owner_player._melee_damage() * 0.25)), ElementalSystem.Element.NONE, owner_player)
		AudioManager.play_bank_at("dagger_swing", global_position, -10.0, 1.4)

func _anim(names: Array) -> void:
	for n in names:
		if _sprite.sprite_frames.has_animation(n):
			if _sprite.animation != n:
				_sprite.play(n)
			return

# Gone in a puff of smoke; the monsters it fooled look for the real hero again.
func _vanish() -> void:
	_puff()
	AudioManager.play_bank_at("teleport", global_position, -8.0, 1.6)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.player == self:
			e.player = owner_player
	queue_free()

func _puff() -> void:
	CombatFX.pvfx("smoke-puff", global_position, 0.45)
	CombatFX.burst(global_position + Vector2(0, -6), Color(0.55, 0.5, 0.6), 16, 40.0, 0.5, -30.0, 3.0)
	CombatFX.burst(global_position + Vector2(0, -6), Color(0.3, 0.2, 0.4), 10, 25.0, 0.6, -20.0, 4.0)
