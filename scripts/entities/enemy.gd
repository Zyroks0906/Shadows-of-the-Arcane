extends BaseCharacter
class_name Enemy

@export var speed: float = 24.0
@export var detection_range: float = 150.0
@export var attack_range: float = 25.0
@export var attack_damage: int = 24
@export var attack_cooldown: float = 1.5
@export var attack_delay: float = 0.5
## Picks a random element when spawned by an EnemySpawner (slimes always do).
@export var random_element: bool = false
## Fraction of crowd control (freeze) ignored. Bosses use high values.
@export_range(0.0, 1.0) var cc_resistance: float = 0.0
## Size of the whole creature (sprite and collision) relative to its art, so every species
## reads at a sensible size next to the ~14 px tall heroes.
@export var body_scale: float = 1.0
## Melee: the enemy starts an attack within attack_range, telegraphs for attack_delay with
## its swing direction locked, then strikes an arc of attack_reach in front of it. Stepping
## out of that arc during the wind-up dodges the hit.
@export var attack_reach: float = 0.0 # 0 = attack_range + 4
@export var attack_arc_deg: float = 110.0
@export var attack_knockback: float = 140.0
@export var attack_recovery: float = 0.35

func _init_stats() -> void:
	max_health = 75
	resistance = 3
	character_name = name
	# Species that use this base script directly.
	var scene := scene_file_path.get_file().to_lower()
	if "slime" in scene:
		max_health = 60
		resistance = 2
		speed = 22.0 # a jelly blob: it hops forward a little at a time
	elif "skeleton" in scene:
		max_health = 75
		resistance = 4
		speed = 34.0

@export_group("VFX")
@export var override_aura_scene: PackedScene = null
@export var override_blood_scene: PackedScene = null
## Tint the sprite with the base element colour (disable for sprites drawn already coloured).
@export var use_element_tint: bool = true
## Show the elemental spike aura under the enemy while it carries an element.
@export var show_element_aura: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Sounds per species: SoundBank categories for attacking, getting hit, dying and spotting
# the player, plus a pitch (smaller creatures squeak higher). Resolved from the scene
# name unless a subclass sets sound_set itself.
const SOUND_SETS := {
	"slime": {"attack": "slime", "hurt": "slime", "die": "slime", "alert": "slime", "pitch": 1.0, "vol": -4.0},
	"skeleton": {"attack": "bones", "hurt": "bones", "die": "bones", "alert": "", "pitch": 1.0, "vol": -2.0},
	"bat": {"attack": "bug", "hurt": "bug", "die": "bug", "alert": "bug", "pitch": 1.6, "vol": -8.0},
	"rat": {"attack": "bug", "hurt": "bug", "die": "bug", "alert": "", "pitch": 1.9, "vol": -8.0},
	"orc": {"attack": "monster_attack", "hurt": "monster_hurt", "die": "monster_die", "alert": "monster_growl", "pitch": 0.8, "vol": -2.0},
	"demon": {"attack": "roar", "hurt": "monster_hurt", "die": "monster_die", "alert": "roar", "pitch": 0.7, "vol": 0.0},
	"golem": {"attack": "stomp", "hurt": "stomp", "die": "roar", "alert": "roar", "pitch": 0.55, "vol": 0.0},
	"wisp": {"attack": "electric_launch", "hurt": "electric_hit", "die": "teleport", "alert": "", "pitch": 1.2, "vol": -8.0},
	"monster": {"attack": "monster_attack", "hurt": "monster_hurt", "die": "monster_die", "alert": "monster_growl", "pitch": 1.0, "vol": -3.0},
}
var sound_set: String = ""

# Experience a kill is worth: grows with toughness and damage.
func xp_value() -> int:
	var xp := maxi(2, int(max_health / 10.0 + attack_damage / 4.0))
	return int(xp * elite.xp_mult()) if elite else xp
var _stunned_until_ms: int = 0

# Parried: reeling and defenceless for a moment (no moving, no attacking).
func apply_stun(duration: float) -> void:
	if not is_alive:
		return
	duration *= 1.0 - cc_resistance * 0.7
	_stunned_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	can_attack = false
	CombatFX.floating_label(global_position + Vector2(0, -6), "STUNNED", Color(1.0, 0.9, 0.4), 0.8)
	if animated_sprite:
		var tw := animated_sprite.create_tween().set_loops(int(duration / 0.2))
		tw.tween_property(animated_sprite, "modulate", Color(1.4, 1.3, 0.8), 0.1)
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(self) and is_alive and not is_attacking:
			can_attack = true)
var _alerted: bool = false

func _snd(kind: String, vol_add: float = 0.0) -> void:
	var ss: Dictionary = SOUND_SETS.get(sound_set, SOUND_SETS["monster"])
	var cat: String = ss.get(kind, "")
	if cat != "":
		AudioManager.play_bank_at(cat, global_position, ss["vol"] + vol_add, ss["pitch"])

func _resolve_sound_set() -> void:
	if sound_set != "":
		return
	var key := (scene_file_path.get_file() + " " + character_name).to_lower()
	for k in SOUND_SETS:
		if k in key:
			sound_set = k
			return
	if "esqueleto" in key:
		sound_set = "skeleton"
	elif "guardian" in key or "warden" in key:
		sound_set = "golem"
	else:
		sound_set = "monster"

var player: BaseCharacter = null # usually the Player; a shadow clone can draw aggro
var can_attack: bool = true
var is_attacking: bool = false
var is_hurt: bool = false
var shader_material: ShaderMaterial = null
var is_frozen: bool = false
var _freeze_token: int = 0
var _aura_token: int = 0

# An element applied by an attack fades after a while; elemental creatures
# get their own element back shortly after a reaction consumes it.
const IMBUED_AURA_DURATION := 7.0
const BASE_AURA_REGEN := 3.0

# Set when this creature rolled as an elite (see EliteAffix).
var elite: EliteAffix = null

func _ready() -> void:
	_init_stats()
	_resolve_sound_set()
	elite = EliteAffix.roll(self)
	if body_scale != 1.0:
		scale *= body_scale
	super._ready()
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	player = get_tree().get_first_node_in_group("player")
	_setup_elemental_shader()
	_setup_elemental_vfx_aura()
	var blood_hit := get_node_or_null("BloodHit") as AnimatedSprite2D
	if blood_hit:
		blood_hit.visible = false
		blood_hit.animation_finished.connect(_on_blood_hit_done)
	if elite:
		elite.setup.call_deferred()

func _setup_elemental_shader() -> void:
	if not animated_sprite:
		return
	var shader = load("res://assets/shaders/elemental_tint.gdshader")
	if not shader:
		return
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	animated_sprite.material = shader_material
	var color = ElementalSystem.get_element_color(base_element)
	var secondary_color = ElementalSystem.get_element_secondary_color(base_element)
	shader_material.set_shader_parameter("tint_color", color)
	shader_material.set_shader_parameter("secondary_tint_color", secondary_color)
	var tinted := use_element_tint and base_element != ElementalSystem.Element.NONE
	shader_material.set_shader_parameter("tint_intensity", 0.65 if tinted else 0.0)

var _badge: ElementBadge

# The element a creature carries is shown as an icon over its head; the old looping spike
# auras are hidden.
func _setup_elemental_vfx_aura() -> void:
	for child in get_children():
		if child.has_meta("vfx_aura"):
			if child.has_meta("vfx_runtime"):
				child.queue_free()
			else:
				child.visible = false
				if child.has_method("stop"):
					child.stop()
	if not _badge and is_inside_tree():
		_badge = ElementBadge.attach(self, ElementBadge.head_height_of(self, animated_sprite))
	if _badge:
		_badge.set_element(current_imbued_element)

func _child_matches_element(child: Node, element: ElementalSystem.Element) -> bool:
	var en = child.get("element_name")
	if en == null:
		return false
	match element:
		ElementalSystem.Element.PYRO:    return en == "PYRO"
		ElementalSystem.Element.HYDRO:   return en == "HYDRO"
		ElementalSystem.Element.ANEMO:   return en == "ANEMO"
		ElementalSystem.Element.CRYO:    return en == "CRYO"
		ElementalSystem.Element.ELECTRO: return en == "ELECTRO"
	return false

func _create_runtime_aura(element: ElementalSystem.Element) -> void:
	var scene: PackedScene = override_aura_scene
	if not scene:
		scene = _get_default_aura_scene(element)
	if not scene:
		return
	var aura := scene.instantiate()
	aura.set_meta("vfx_aura", true)
	aura.set_meta("vfx_runtime", true)
	add_child(aura)

func _get_default_aura_scene(element: ElementalSystem.Element) -> PackedScene:
	var path: String
	match element:
		ElementalSystem.Element.PYRO:    path = "res://scenes/vfx/aura_pyro.tscn"
		ElementalSystem.Element.HYDRO:   path = "res://scenes/vfx/aura_hydro.tscn"
		ElementalSystem.Element.ANEMO:   path = "res://scenes/vfx/aura_anemo.tscn"
		ElementalSystem.Element.CRYO:    path = "res://scenes/vfx/aura_cryo.tscn"
		ElementalSystem.Element.ELECTRO: path = "res://scenes/vfx/aura_electro.tscn"
		_: return null
	if ResourceLoader.exists(path):
		return load(path)
	return null

func receive_damage(amount: int) -> void:
	if not is_alive:
		return
	if elite and elite.absorb(amount):
		return
	if amount > 0:
		_spawn_blood_hit_vfx()
		CombatFX.flash(animated_sprite)
		if not is_frozen:
			_play_hurt_anim()
	# "Damage dealt" counts the health actually removed, and only while a hit of the
	# player's (or a reaction it set off) is being resolved: traps and blasts don't count.
	var before := current_health
	super.receive_damage(amount)
	if Progression.player_hit_depth > 0:
		Progression.stat("damage", maxi(before - current_health, 0))

func take_elemental_hit(damage: int, element: ElementalSystem.Element, source: Node = null) -> void:
	var by_player := source is Player
	if by_player:
		Progression.player_hit_depth += 1
	_take_hit(damage, element, source)
	if by_player:
		Progression.player_hit_depth -= 1

func _take_hit(damage: int, element: ElementalSystem.Element, source: Node) -> void:
	if elite and elite.ward > 0 and damage > 0 and is_alive:
		elite.absorb(damage) # the ward takes the whole hit, element included
		return
	if is_frozen and damage > 0 and is_alive:
		_unfreeze()
		Reactions.shatter(self)
		damage = int(damage * Reactions.SHATTER_MULTIPLIER)
	super.take_elemental_hit(damage, element, source)

func apply_freeze(duration: float) -> void:
	if not is_alive:
		return
	duration *= 1.0 - cc_resistance
	if duration < 0.2:
		return
	is_frozen = true
	_freeze_token += 1
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.pause()
	if shader_material:
		shader_material.set_shader_parameter("freeze_amount", 1.0)
	get_tree().create_timer(duration).timeout.connect(_unfreeze.bind(_freeze_token))

func _unfreeze(token: int = -1) -> void:
	if token != -1 and token != _freeze_token:
		return
	if not is_frozen:
		return
	is_frozen = false
	if animated_sprite and is_alive:
		animated_sprite.play()
	if shader_material:
		shader_material.set_shader_parameter("freeze_amount", 0.0)

func _play_hurt_anim() -> void:
	if not animated_sprite or is_attacking:
		return
	for anim in ["hurt", "hit", "Hurt", "Hit"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			is_hurt = true
			_anim_play(animated_sprite, anim, AnimPriority.ACTION)
			if not animated_sprite.sprite_frames.get_animation_loop(anim):
				await animated_sprite.animation_finished
			else:
				await get_tree().create_timer(0.4).timeout
			_anim_release(AnimPriority.ACTION)
			if is_instance_valid(self):
				is_hurt = false
			return

func _spawn_blood_hit_vfx() -> void:
	_snd("hurt")
	AudioManager.play_bank_at("blade_flesh", global_position, -10.0, 0.9)
	var from := player.global_position if is_instance_valid(player) else global_position + Vector2.LEFT
	CombatFX.blood(global_position, global_position - from, _blood_color())

# What comes out when this creature is hit: blood, bone chips, goo or sparks.
func _blood_color() -> Color:
	match sound_set:
		"skeleton": return Color(0.92, 0.9, 0.82)
		"golem": return Color(0.55, 0.55, 0.6)
		"slime", "wisp":
			if base_element != ElementalSystem.Element.NONE:
				return ElementalSystem.get_element_color(base_element)
			return Color(0.35, 0.75, 0.55)
	return Color(0.6, 0.05, 0.08)

func _on_blood_hit_done() -> void:
	var blood_hit := get_node_or_null("BloodHit") as AnimatedSprite2D
	if blood_hit:
		blood_hit.visible = false

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _process_knockback(delta) or is_frozen or is_attacking or is_hurt:
		return
	if Time.get_ticks_msec() < _stunned_until_ms:
		velocity = Vector2.ZERO
		return
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= attack_range:
		# Hold position, but don't stand inside another creature.
		velocity = _separation() * speed * 0.6
		if can_attack:
			_perform_attack()
		else:
			_play_animation("idle")
	elif distance <= detection_range:
		if not _alerted:
			_alerted = true
			_snd("alert")
		var direction := (player.global_position - global_position).normalized()
		direction = (direction + _separation() * 1.2).normalized()
		velocity = _move_rhythm(direction) * speed * terrain_speed_mult + external_push
		_update_animations(direction)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")

	move_and_slide()

var _move_t: float = randf() * TAU

# How each species moves: slimes hop (surges between pauses), bats flutter side to side,
# everything else walks steadily.
func _move_rhythm(direction: Vector2) -> Vector2:
	_move_t += get_physics_process_delta_time()
	match sound_set:
		"slime":
			var hop := maxf(sin(_move_t * 6.0), 0.0)
			return direction * (0.25 + 1.6 * hop * hop)
		"bat":
			return (direction + direction.orthogonal() * sin(_move_t * 9.0) * 0.7).normalized()
	return direction

# Soft push away from nearby enemies so a group spreads around the player instead of
# stacking on one spot.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var my_r := 8.0 * absf(scale.x)
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node2D):
			continue
		var d: Vector2 = global_position - other.global_position
		var min_d: float = my_r + 8.0 * absf(other.scale.x) + 2.0
		var l := d.length()
		if l < min_d:
			push += (d / maxf(l, 0.1)) * (1.0 - l / min_d) if l > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)
	return push

func _update_animations(direction: Vector2) -> void:
	if direction.x != 0:
		animated_sprite.flip_h = direction.x < 0
	if animated_sprite.sprite_frames.has_animation("walk"):
		_play_animation("walk")
	elif animated_sprite.sprite_frames.has_animation("run"):
		_play_animation("run")
	else:
		_play_animation("idle")

func _play_animation(anim_name: String) -> void:
	_anim_play(animated_sprite, anim_name, AnimPriority.FREE)

func _perform_attack() -> void:
	await _melee_attack(attack_delay, attack_damage, attack_knockback, "attack")
	if not is_alive: return
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true

var _attack_dir: Vector2 = Vector2.RIGHT
var _base_sprite_scale: Vector2 = Vector2.ZERO

# Wind-up (red glow, direction locked) -> strike in an arc -> recovery.
func _melee_attack(windup: float, damage: int, knock: float, anim: String, heavy: bool = false) -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	if is_instance_valid(player):
		_attack_dir = (player.global_position - global_position).normalized()
	if animated_sprite and absf(_attack_dir.x) > 0.05:
		animated_sprite.flip_h = _attack_dir.x < 0
	_play_attack_anim(anim, windup)
	_telegraph(windup, heavy)
	await get_tree().create_timer(windup).timeout
	if not is_alive: return
	if not is_frozen and Time.get_ticks_msec() >= _stunned_until_ms:
		_snd("attack")
		var landed := _strike_arc(_attack_dir, _reach(), attack_arc_deg, damage, knock)
		if landed and heavy:
			CombatFX.shake(3.5, 0.2)
	await get_tree().create_timer(attack_recovery).timeout
	if not is_alive: return
	_anim_release(AnimPriority.ACTION)
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
	is_attacking = false
	_anim_play(animated_sprite, "idle", AnimPriority.FREE)

func _reach() -> float:
	return attack_reach if attack_reach > 0.0 else attack_range + 4.0

# Times the attack animation so its middle frame (the blow) lands when the wind-up ends.
func _play_attack_anim(anim: String, windup: float) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var sf := animated_sprite.sprite_frames
	var a := anim if sf.has_animation(anim) else "attack"
	if not sf.has_animation(a):
		return
	if _anim_play(animated_sprite, a, AnimPriority.ACTION):
		var n := sf.get_frame_count(a)
		var fps := maxf(sf.get_animation_speed(a), 0.01)
		animated_sprite.speed_scale = clampf((maxi(n / 2, 1) / fps) / maxf(windup, 0.05), 0.4, 3.0)

# The tell: the creature glows red and tenses (squash) while winding up.
const PARRY_CUE := 0.15 # seconds before the blow: the flash that says "parry now"

# The tell: the creature glows red and tenses while winding up; PARRY_CUE seconds before
# the blow lands it flashes white-gold with a "!" and a click, the moment to raise the
# guard for a parry.
func _telegraph(windup: float, heavy: bool) -> void:
	if not animated_sprite:
		return
	if _base_sprite_scale == Vector2.ZERO:
		_base_sprite_scale = animated_sprite.scale
	var glow := Color(1.9, 0.55, 0.5) if heavy else Color(1.5, 0.75, 0.7)
	var build := maxf(windup - PARRY_CUE, 0.05)
	var tw := animated_sprite.create_tween()
	tw.set_parallel(true)
	tw.tween_property(animated_sprite, "modulate", glow, build)
	tw.tween_property(animated_sprite, "scale", _base_sprite_scale * Vector2(1.08, 0.92), build)
	tw.chain().tween_callback(_parry_cue)
	tw.tween_property(animated_sprite, "modulate", Color(2.2, 2.0, 1.4), 0.04)
	tw.chain().tween_property(animated_sprite, "modulate", Color.WHITE, PARRY_CUE)
	tw.parallel().tween_property(animated_sprite, "scale", _base_sprite_scale, PARRY_CUE)

func _parry_cue() -> void:
	if not is_alive or is_frozen:
		return
	var top := global_position + Vector2(0, -14.0 * absf(scale.y))
	CombatFX.floating_label(top, "!", Color(1.0, 0.92, 0.5), 0.9)
	AudioManager.play_bank_at("ui_click", global_position, -6.0, 1.6)

# Hits the player if their body overlaps the arc in front of the enemy.
func _strike_arc(dir: Vector2, reach: float, arc_deg: float, damage: int, knock: float) -> bool:
	if not is_instance_valid(player) or not player.is_alive:
		return false
	var to := player.global_position - global_position
	var dist := to.length()
	const PLAYER_RADIUS := 5.0
	if dist - PLAYER_RADIUS > reach:
		return false
	if dist > PLAYER_RADIUS + 3.0 and absf(dir.angle_to(to)) > deg_to_rad(arc_deg * 0.5) + atan2(PLAYER_RADIUS, dist):
		return false
	player.take_elemental_hit(damage, base_element, self)
	player.apply_knockback(to.normalized() * knock)
	if elite:
		elite.on_hit_player(damage)
	return true

func _on_element_applied() -> void:
	_setup_elemental_vfx_aura()
	_aura_token += 1
	if current_imbued_element != base_element:
		get_tree().create_timer(IMBUED_AURA_DURATION).timeout.connect(_expire_imbued_aura.bind(_aura_token))

func _on_reaction_triggered(_reaction_name: String, _data: Dictionary) -> void:
	_setup_elemental_vfx_aura()

func limpiar_elemento() -> void:
	super.limpiar_elemento()
	_setup_elemental_vfx_aura()
	_aura_token += 1
	if base_element != ElementalSystem.Element.NONE and is_inside_tree():
		get_tree().create_timer(BASE_AURA_REGEN).timeout.connect(_restore_base_aura.bind(_aura_token))

func _expire_imbued_aura(token: int) -> void:
	if token == _aura_token and is_alive:
		limpiar_elemento()

func _restore_base_aura(token: int) -> void:
	if token == _aura_token and is_alive and current_imbued_element == ElementalSystem.Element.NONE:
		current_imbued_element = base_element
		_on_element_applied()

# Kept for subclasses that time their own blows: strikes in the locked attack direction.
func _check_hit() -> void:
	if is_frozen or not is_instance_valid(player):
		return
	_strike_arc(_attack_dir, _reach(), attack_arc_deg, attack_damage, attack_knockback)

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	_unfreeze()
	if elite:
		elite.on_death()
	Progression.stat("kills")
	_drop_coins()
	if elite:
		Progression.stat("elites")
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("gain_energy"):
		p.gain_energy(Player.ENERGY_PER_KILL)
	# Experience: tougher creatures are worth more.
	XpOrb.drop(global_position, xp_value(), get_parent())
	remove_from_group("enemies")
	collision_layer = 0
	CombatFX.burst(global_position, ElementalSystem.get_element_color(base_element) if base_element != ElementalSystem.Element.NONE else Color(0.55, 0.05, 0.08), 18, 70.0, 0.6, 80.0, 2.5)

	_snd("die", 2.0)

	if _anim_play(animated_sprite, "death", AnimPriority.LOCKED):
		await animated_sprite.animation_finished

	await get_tree().create_timer(1.0).timeout
	queue_free()

# Ordinary monsters sometimes leave a coin or two (elites and bosses have their own loot).
const COIN_SCENE := "res://assets/sprites/sprite_frames/Coin.tscn"

func _drop_coins() -> void:
	if elite or self is BossBase:
		return
	var big := max_health > 100
	if randf() > (0.7 if big else 0.35):
		return
	for i in (randi_range(1, 2) if big else 1):
		var coin: Node2D = load(COIN_SCENE).instantiate()
		get_parent().add_child.call_deferred(coin)
		var to := global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(8.0, 14.0)
		(func():
			var c: Node = coin if coin.has_method("pop_out") else coin.get_node_or_null("Area2D")
			if c:
				c.pop_out(global_position, to, 0.05 * i)).call_deferred()
