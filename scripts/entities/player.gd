extends BaseCharacter
class_name Player

enum AttackKind { MELEE, CAST }

@export var speed: float = 80.0
@export var sprite_offset: Vector2 = Vector2.ZERO
# Some sprite packs draw animations at different resolutions (the Barbarian's "360"
# sheets are ~25% smaller than its idle/walk). Multiplies base_scale per animation so the
# character never changes size on screen; feet stay put using anim_feet_px (distance
# from the frame centre down to the feet, in texture pixels).
var anim_scale: Dictionary = {}
var anim_feet_px: float = 0.0

@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _camera_node: Camera2D
var _is_interacting: bool = false
var _is_hurt: bool = false

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

var is_attacking: bool = false
var last_direction: Vector2 = Vector2.RIGHT
var interactables_in_range: Array[Node2D] = []

const INVULNERABILITY_TIME := 0.6
const MANA_REGEN_PER_WISDOM := 0.15

# --- Movement feel -------------------------------------------------------------
# A short ramp up and down so characters have weight without feeling floaty
# (~0.08 s to full speed at these values).
var move_accel: float = 900.0
var move_friction: float = 1100.0
# Walking straight into a wind current costs an extra 10% on top of its push.
const HEADWIND_PENALTY := 0.10

# --- Attack profile (each class overrides these in _init) -------------------------
# An attack has three phases: startup (wind-up until the impact frame), active (the
# frame where the hit lands) and recovery (until attack_cycle ends). The attack
# animation is time-stretched so its impact frame lands exactly at attack_startup.
var attack_kind: AttackKind = AttackKind.MELEE
var attack_startup: float = 0.14
var attack_cycle: float = 0.45
var attack_impact_frame: int = -1 # -1: middle of the animation
var attack_reach: float = 22.0 # px from the character's centre to the tip of the swing
var attack_arc_deg: float = 100.0
var attack_damage_mult: float = 1.0
var attack_knockback: float = 140.0
var attack_move_mult: float = 0.5 # movement speed while committed to an attack
var cast_speed: float = 200.0 # CAST: speed of the spell projectile
var cast_range: float = 220.0 # CAST: range used for aim assist
var block_stamina_max: float = 50.0 # guard stamina (see PlayerGuard)
var parry_window: float = 0.25 # seconds after raising the guard that count as a parry
var snd_block: Array = [["metal_clash", -2.0, 0.95]] # only plays on a real blocked hit

# --- Elemental skill (E) and ultimate (Q) ------------------------------------------
# Like Genshin: E is on a cooldown; Q is charged with energy earned by landing hits.
# Mana is only for spellcasters (their basic orbs); others turn mana potions into energy.
var skill_name: String = "Skill"
var skill_cooldown: float = 8.0
var burst_name: String = "Ultimate"
var burst_cost: float = 60.0
var energy: float = 0.0
var uses_mana: bool = false
var cast_mana_cost: int = 2
# Casters pay for their special moves too (basic < skill < ultimate), so mana and mana
# potions matter. 0 for fighters.
var skill_mana_cost: int = 0
var burst_mana_cost: int = 0
var _skill_ready_ms: int = 0
const ENERGY_PER_HIT := 5.0
const ENERGY_PER_SKILL_HIT := 10.0
const ENERGY_PER_KILL := 5.0
# Temporary buffs set by abilities.
var damage_taken_mult: float = 1.0
var attack_speed_mult: float = 1.0
var damage_mult_buff: float = 1.0
var _dash_damage: int = 0
var _dash_element: ElementalSystem.Element = ElementalSystem.Element.NONE
var _dash_radius: float = 12.0
var _dash_hit: Dictionary = {}

# --- Dodge roll ------------------------------------------------------------------
# A short committed roll with invulnerability; heavier classes roll shorter.
var dodge_distance: float = 44.0
var dodge_duration: float = 0.26
var dodge_cooldown: float = 0.6
var _dodge_until_ms: int = 0
var _dodge_ready_ms: int = 0
var _dodge_dir: Vector2 = Vector2.RIGHT
var _ghost_t: float = 0.0
var _stunned_until_ms: int = 0
var _guard: PlayerGuard
# Lean towards the crosshair while aiming (archer draw, casting): side-view sprites read as
# aiming up or down instead of only left/right.
var aim_tilt: bool = false

# --- Sound profile (each class sets its own) --------------------------------------
# Every list holds layers [SoundBank category, volume_db, pitch]; all layers play together
# (e.g. a punch plus a dull body thud). The bank picks a different variant each time.
var snd_swing: Array = [["sword_swing", -2.0, 1.0]]
var snd_hit: Array = [["blade_flesh", -3.0, 1.0]]
var snd_cast: Array = [] # CAST: the spell leaving the hand
var snd_impact: Array = [] # CAST: the spell landing
# Voice: which actor (SoundBank "<voice>_effort/_hurt/_death") and how it is pitched, so
# the same recordings give each character its own timbre.
var voice: String = "m2"
var voice_pitch: float = 1.0
var voice_volume: float = -4.0
var effort_chance: float = 0.25 # how often a normal attack gets a battle grunt
var _last_hurt_voice_ms: int = 0

# --- Aim -------------------------------------------------------------------------
# Attacks go towards the cursor (or right stick), independent of movement.
var using_gamepad: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var aim_locked: bool = false # an enemy is inside the current weapon's reach
var aim_charge: float = -1.0 # charge ring on the crosshair; < 0 hides it
var aim_override: Vector2 = Vector2.ZERO # forces the aim (tests, cutscenes); ZERO = use input
var _crosshair: Crosshair

var _move_vel: Vector2 = Vector2.ZERO
var _attack_token: int = 0
var _busy_until_ms: int = 0
var _face_aim_until_ms: int = 0
var _attack_buffered_until_ms: int = 0
var _impact_pending: bool = false
var _impact_frame: int = -1
var _impact_callback: Callable
var _recovery_speed: float = 1.0
var _debug_swing: Dictionary = {}

const ATTACK_BUFFER_MS := 150

var shield_hp: int = 0
var _shield_max: int = 0
var _shield_ring: _ShieldRing = null
var _shield_token: int = 0
var _invulnerable_until_ms: int = 0
var _slow_time_left: float = 0.0
var _mana_regen_acc: float = 0.0

func _ready() -> void:
	_apply_class_stats()
	add_to_group("player")
	_capture_base_stats()
	apply_perks()
	super._ready()

	_camera_node = Camera2D.new()
	_camera_node.zoom = Vector2(2.0, 2.0)
	_camera_node.position_smoothing_enabled = true
	_camera_node.position_smoothing_speed = 12.0
	_camera_node.drag_horizontal_enabled = true
	_camera_node.drag_vertical_enabled = true
	add_child(_camera_node)

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 5

	if animated_sprite:
		animated_sprite.scale = Vector2(1, 1)
		animated_sprite.offset = sprite_offset
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_frame_changed)
		animated_sprite.animation_changed.connect(_apply_anim_scale)
		_apply_anim_scale.call_deferred()

	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)

	_crosshair = Crosshair.new()
	_crosshair.player = self
	add_child(_crosshair)

	_guard = PlayerGuard.new()
	_guard.z_index = 5
	add_child(_guard)
	_guard.setup(block_stamina_max, parry_window)

	var combat_hud := CombatHud.new()
	combat_hud.player = self
	add_child(combat_hud)

# Debug builds only: F4 toggles god mode, F6 refills health and mana. For play-testing.
var god_mode: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F4:
			god_mode = not god_mode
			CombatFX.floating_label(global_position, "GOD MODE " + ("ON" if god_mode else "OFF"), Color.GOLD, 1.0)
		KEY_F6:
			current_health = max_health
			current_mana = max_mana
			CombatFX.floating_label(global_position, "REFILL", Color.GREEN, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		using_gamepad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		using_gamepad = true

func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_regen_mana(delta)
	_slow_time_left = maxf(_slow_time_left - delta, 0.0)
	_update_aim()
	var now := Time.get_ticks_msec()
	if now < _dodge_until_ms:
		_process_dodge(delta)
		return
	if _process_knockback(delta):
		_move_vel = Vector2.ZERO
		_guard.update(delta, false, aim_direction)
		# Being shoved must not eat the attack button (nor freeze an Archer's draw).
		_handle_attack_input(delta)
		return
	if now < _stunned_until_ms:
		# Guard broken: staggered, no control for a moment.
		_move_vel = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		_guard.update(delta, false, aim_direction)
		move_and_slide()
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var blocking := _guard.update(delta, Input.is_action_pressed("block") and not _is_committed(), aim_direction)
	if Input.is_action_just_pressed("dodge") and _try_dodge(direction):
		return
	var move_speed := speed * terrain_speed_mult * (0.45 if _slow_time_left > 0.0 else 1.0)
	if _is_committed():
		move_speed *= attack_move_mult
	elif blocking:
		move_speed *= 0.5
	if external_push != Vector2.ZERO and direction != Vector2.ZERO:
		var against := -direction.normalized().dot(external_push.normalized())
		if against > 0.0:
			move_speed *= 1.0 - HEADWIND_PENALTY * against

	var rate := move_accel if direction != Vector2.ZERO else move_friction
	_move_vel = _move_vel.move_toward(direction * move_speed, rate * delta)
	velocity = _move_vel + external_push
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
	_update_facing(direction)

	if not is_attacking and not _is_hurt:
		_play_animation("Run" if direction != Vector2.ZERO else "Idle")
	_update_tilt(delta)

	move_and_slide()

	if not blocking:
		_handle_attack_input(delta)
	if not blocking and Input.is_action_just_pressed("skill"):
		use_skill()
	elif not blocking and Input.is_action_just_pressed("burst"):
		use_burst()
	elif Input.is_action_just_pressed("interact"):
		interact()
	elif Input.is_action_just_pressed("use_health_potion"):
		use_health_potion()
	elif Input.is_action_just_pressed("use_mana_potion"):
		use_mana_potion()

# Pressing attack near the end of a swing queues the next one, so mashing never eats inputs.
func _handle_attack_input(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if Input.is_action_just_pressed("attack_1"):
		_attack_buffered_until_ms = now + ATTACK_BUFFER_MS
	if _attack_buffered_until_ms > now and not _is_attack_busy():
		_attack_buffered_until_ms = 0
		attack()

var _sprite_rest: Vector2 = Vector2.INF
var _body_center: Vector2 = Vector2.INF

# Middle of the character's visible body (feet to head of the idle frame), in local space.
# Things that orbit or wrap the hero (shields, Aegis) centre on this, whatever the class.
func body_center() -> Vector2:
	if _body_center == Vector2.INF and animated_sprite:
		var m := GroundShadow._measure(animated_sprite)
		_body_center = Vector2(0.0, (m["foot"].y + m["top"]) * 0.5)
	return _body_center if _body_center != Vector2.INF else Vector2(0, -6)
var airborne: bool = false # a jump moves the sprite itself: the lunge keeps out of it

func _update_tilt(delta: float) -> void:
	if not animated_sprite:
		return
	var target := 0.0
	var lunge := Vector2.ZERO
	# The sheets only swing sideways, so an attack up or down leans the whole body that way
	# (and melee lunges a little towards the blow): the swing reads in every direction.
	var melee := attack_kind == AttackKind.MELEE and not aim_tilt # archer (aim_tilt) keeps its bow tilt
	if (aim_tilt or melee) and _is_committed():
		var horiz := Vector2(-1, 0) if animated_sprite.flip_h else Vector2(1, 0)
		var limit := 1.2 if melee else 0.55
		target = clampf(horiz.angle_to(aim_direction), -limit, limit) * 0.45
		if melee:
			lunge = aim_direction * 2.5
	animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target, clampf(delta * 14.0, 0.0, 1.0))
	if _sprite_rest == Vector2.INF:
		_sprite_rest = animated_sprite.position
	if airborne:
		return
	animated_sprite.position = animated_sprite.position.lerp(_sprite_rest + lunge, clampf(delta * 18.0, 0.0, 1.0))

func _update_facing(move_dir: Vector2) -> void:
	if not animated_sprite:
		return
	if _is_committed() or (_guard and _guard.blocking) or Time.get_ticks_msec() < _face_aim_until_ms:
		if absf(aim_direction.x) > 0.05:
			animated_sprite.flip_h = aim_direction.x < 0
	elif move_dir.x != 0:
		animated_sprite.flip_h = move_dir.x < 0

# ---------------------------------------------------------------------------------
# Aiming
# ---------------------------------------------------------------------------------

# Enemies the character can actually see: aim assist and the crosshair lock must never
# pick something behind a wall.
func _enemies() -> Array:
	var space := get_world_2d().direct_space_state
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or global_position.distance_to(e.global_position) > 320.0:
			continue
		var q := PhysicsRayQueryParameters2D.create(global_position, e.global_position, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			out.append(e)
	return out

func _assist_strength() -> float:
	var s: float = SettingsManager.aim_assist
	if s > 0.0 and using_gamepad:
		s = minf(s + Aim.PAD_STRENGTH_BONUS, 0.95)
	return s

func _assist_cone() -> float:
	return Aim.PAD_CONE_DEG if using_gamepad else Aim.MOUSE_CONE_DEG

# Range at which the aim assist and the crosshair consider an enemy "in reach".
func _weapon_range() -> float:
	return cast_range if attack_kind == AttackKind.CAST else attack_reach + 8.0

func _raw_aim_dir() -> Vector2:
	if aim_override != Vector2.ZERO:
		return aim_override.normalized()
	if using_gamepad:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.3:
			return stick.normalized()
		var n := Aim.nearest(global_position, _weapon_range() + 40.0, _enemies())
		if n:
			return (n.global_position - global_position).normalized()
		return last_direction
	var to := get_global_mouse_position() - global_position
	if to.length() < 3.0:
		return last_direction
	return to.normalized()

func _assisted_dir(max_range: float) -> Vector2:
	return Aim.assist(global_position, _raw_aim_dir(), max_range, _assist_cone(), _assist_strength(), _enemies())

func _assist_target(max_range: float) -> Node2D:
	if _assist_strength() <= 0.0:
		return null
	return Aim.find_target(global_position, _raw_aim_dir(), max_range, _assist_cone(), _enemies())

func _update_aim() -> void:
	aim_direction = _raw_aim_dir()
	var cone := maxf(_assist_cone(), attack_arc_deg * 0.5) if attack_kind == AttackKind.MELEE else _assist_cone()
	aim_locked = Aim.find_target(global_position, aim_direction, _weapon_range(), cone, _enemies()) != null

# ---------------------------------------------------------------------------------
# Attacks
# ---------------------------------------------------------------------------------

func _is_attack_busy() -> bool:
	return Time.get_ticks_msec() < _busy_until_ms

# True while the character is committed to an action (moves slower, faces the aim).
func _is_committed() -> bool:
	return _is_attack_busy()

func attack() -> void:
	if _is_attack_busy():
		return
	match attack_kind:
		AttackKind.CAST:
			_start_cast(false)
		_:
			_start_melee(false)

# --- Perks (see Progression) ---------------------------------------------------------
var _base: Dictionary = {}
var _vamp_ready_ms: int = 0

func _capture_base_stats() -> void:
	_base = {"max_health": max_health, "resistance": resistance, "speed": speed,
		"block_stamina_max": block_stamina_max, "skill_cooldown": skill_cooldown,
		"max_mana": max_mana, "intelligence": intelligence, "wisdom": wisdom}

func perk_mult(id: String) -> float:
	return 1.0 + Progression.value(id) / 100.0

# Re-derives every stat from the class base plus the perks owned. `heal_bonus` heals the
# health just gained (Vitality).
func apply_perks(heal: bool = false, heal_bonus: int = 0) -> void:
	if _base.is_empty():
		return
	max_health = _base["max_health"] + int(Progression.value("vitality"))
	resistance = _base["resistance"] + int(Progression.value("iron_skin"))
	speed = _base["speed"] * perk_mult("swiftness")
	block_stamina_max = _base["block_stamina_max"] * perk_mult("bulwark")
	skill_cooldown = _base["skill_cooldown"] * (1.0 - Progression.value("focus") / 100.0)
	max_mana = _base["max_mana"] + int(Progression.value("wisdom"))
	wisdom = _base["wisdom"] + int(Progression.value("wisdom") / 5.0)
	intelligence = _base["intelligence"] + int(Progression.value("mastery"))
	if _guard:
		var frac := _guard.stamina / maxf(_guard.max_stamina, 1.0)
		_guard.max_stamina = block_stamina_max
		_guard.stamina = block_stamina_max * frac
	if is_inside_tree():
		if heal and heal_bonus > 0:
			recover_health(heal_bonus)
		current_health = mini(current_health, max_health)
		current_mana = mini(current_mana, max_mana)

func _pay_mana(cost: int) -> bool:
	if not uses_mana or cost <= 0:
		return true
	if use_mana(cost):
		return true
	CombatFX.floating_label(global_position + Vector2(0, -8), "NO MANA (%d)" % cost, Color.SKY_BLUE, 0.8)
	AudioManager.play_bank("ui_error", -12.0, 1.1)
	return false

func use_skill() -> void:
	var now := Time.get_ticks_msec()
	if _is_attack_busy() or is_dodging():
		return
	if now < _skill_ready_ms:
		AudioManager.play_bank("ui_error", -16.0, 1.2)
		return
	if not _pay_mana(skill_mana_cost):
		return
	_skill_ready_ms = now + int(skill_cooldown * 1000.0)
	CombatFX.floating_label(global_position + Vector2(0, -8), skill_name.to_upper(), Color(0.85, 0.9, 1.0), 0.8)
	_do_skill()

func use_burst() -> void:
	if _is_attack_busy() or is_dodging():
		return
	if energy < burst_cost:
		CombatFX.floating_label(global_position, "NOT READY", Color(0.7, 0.7, 0.8), 0.7)
		AudioManager.play_bank("ui_error", -16.0, 1.0)
		return
	if not _pay_mana(burst_mana_cost):
		return
	energy = 0.0
	# A short freeze-frame so the ultimate lands as a moment.
	CombatFX.hit_stop(0.12, 0.1)
	CombatFX.shake(3.0, 0.25)
	CombatFX.shockwave(global_position, Color(1.0, 0.85, 0.4), 34.0, 0.35, 2.5)
	CombatFX.floating_label(global_position + Vector2(0, -10), burst_name.to_upper(), Color(1.0, 0.85, 0.35), 1.3)
	AudioManager.play_bank("magic_shield", -2.0, 0.8)
	_voice("effort", 3.0)
	_do_burst()

# Class hooks.
func _do_skill() -> void:
	pass

func _do_burst() -> void:
	pass

func skill_ready_fraction() -> float:
	var left := _skill_ready_ms - Time.get_ticks_msec()
	return clampf(1.0 - left / (skill_cooldown * 1000.0), 0.0, 1.0)

func burst_fraction() -> float:
	return clampf(energy / burst_cost, 0.0, 1.0)

func gain_energy(amount: float) -> void:
	energy = minf(energy + amount * perk_mult("zeal"), burst_cost)

# Called by own projectiles and abilities when they connect.
func on_hit_landed(kind: String = "basic") -> void:
	var vamp := int(Progression.value("vampirism"))
	if vamp > 0 and Time.get_ticks_msec() >= _vamp_ready_ms and current_health < max_health:
		_vamp_ready_ms = Time.get_ticks_msec() + 400
		recover_health(vamp)
	gain_energy(ENERGY_PER_SKILL_HIT if kind == "skill" else (ENERGY_PER_HIT if kind == "basic" else 0.0))

# Damages every visible enemy within `radius` of `center`. Returns those hit.
func _aoe(center: Vector2, radius: float, damage: int, element: ElementalSystem.Element, knock: float, stun: float = 0.0, kind: String = "skill") -> Array:
	var hit := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.is_alive:
			continue
		var info := _body_center_radius(e)
		var to: Vector2 = info[0] - center
		if to.length() - float(info[1]) > radius:
			continue
		e.take_elemental_hit(damage, element, self)
		if knock > 0.0 and e.has_method("apply_knockback"):
			e.apply_knockback(to.normalized() * knock if to.length() > 0.1 else Vector2.RIGHT * knock)
		if stun > 0.0 and e.has_method("apply_stun") and e.is_alive:
			e.apply_stun(stun)
		hit.append(e)
	for e in hit:
		on_hit_landed(kind)
	return hit

# A damaging dash: rides the dodge roll (same i-frames and ghosts) and hits every enemy it
# passes through once.
func _skill_dash(dir: Vector2, distance: float, duration: float, damage: int, element: ElementalSystem.Element, radius: float = 12.0) -> void:
	_cancel_actions()
	var now := Time.get_ticks_msec()
	_dodge_dir = dir.normalized()
	var saved := [dodge_distance, dodge_duration]
	dodge_distance = distance
	dodge_duration = duration
	_dodge_until_ms = now + int(duration * 1000.0)
	_invulnerable_until_ms = maxi(_invulnerable_until_ms, _dodge_until_ms + 80)
	_dash_damage = damage
	_dash_element = element
	_dash_radius = radius
	_dash_hit.clear()
	if animated_sprite and absf(_dodge_dir.x) > 0.05:
		animated_sprite.flip_h = _dodge_dir.x < 0
	await get_tree().create_timer(duration + 0.02).timeout
	dodge_distance = saved[0]
	dodge_duration = saved[1]
	_dash_damage = 0

func _dash_hits() -> void:
	if _dash_damage <= 0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if _dash_hit.has(e) or not (e is Node2D) or not e.is_alive:
			continue
		if global_position.distance_to(e.global_position) <= _dash_radius + 6.0:
			_dash_hit[e] = true
			e.take_elemental_hit(_dash_damage, _dash_element, self)
			if e.has_method("apply_knockback"):
				e.apply_knockback(_dodge_dir.orthogonal() * (90.0 if randf() < 0.5 else -90.0))
			CombatFX.hit_stop(0.035)
			on_hit_landed("skill")

# Ground point for targeted abilities: the cursor, clamped to `max_range` and pulled back
# in front of walls.
func _target_point(max_range: float) -> Vector2:
	var to := get_global_mouse_position() - global_position
	if using_gamepad or aim_override != Vector2.ZERO:
		to = aim_direction * max_range * 0.6
	if to.length() > max_range:
		to = to.normalized() * max_range
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + to, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		return global_position.lerp(hit["position"], 0.85)
	return global_position + to

# Temporary stat change that undoes itself.
func _buff(prop: String, value: float, duration: float) -> void:
	set(prop, value)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		set(prop, 1.0)

func _start_melee(heavy: bool) -> void:
	var reach := attack_reach * (1.3 if heavy else 1.0)
	var arc := minf(attack_arc_deg * (1.6 if heavy else 1.0), 200.0)
	var dmg := roundi(_melee_damage() * attack_damage_mult * damage_mult_buff * (2.0 if heavy else 1.0))
	var kb := attack_knockback * (1.6 if heavy else 1.0)
	var dir := _assisted_dir(reach + 16.0)
	aim_direction = dir
	var startup := attack_startup * (1.4 if heavy else 1.0)
	_start_action("attack2" if heavy else "Attack",
		startup, attack_cycle * (1.6 if heavy else 1.0),
		-1 if heavy else attack_impact_frame,
		_melee_impact.bind(dir, reach, arc, dmg, kb))
	# The whoosh plays as the weapon actually swings (just before the impact frame), not
	# when the button is pressed, and is dropped if the attack gets cancelled: one swing on
	# screen, one swing in the ears, even with the Barbarian's long wind-up.
	var token := _attack_token
	get_tree().create_timer(maxf(startup / attack_speed_mult - 0.08, 0.0)).timeout.connect(func():
		if token == _attack_token and is_alive:
			_play_layers(snd_swing, 0.85 if heavy else 1.0, 2.0 if heavy else 0.0)
			if heavy or randf() < effort_chance:
				_voice("effort"))

func _start_cast(heavy: bool) -> void:
	if uses_mana and not use_mana(cast_mana_cost):
		CombatFX.floating_label(global_position, "NO MANA", Color.SKY_BLUE, 0.7)
		_start_melee(false)
		return
	aim_direction = _raw_aim_dir()
	_start_action("attack2" if heavy else "Attack",
		attack_startup * (1.3 if heavy else 1.0), attack_cycle * (1.5 if heavy else 1.0),
		-1 if heavy else attack_impact_frame, _cast_impact.bind(heavy))

# Plays an attack animation stretched so its impact frame lands at `startup` and the rest
# of the animation fills the recovery. `on_impact` runs on that frame.
func _start_action(anim: String, startup: float, cycle: float, impact_frame: int, on_impact: Callable) -> void:
	var speed_k := attack_speed_mult * perk_mult("fury")
	startup /= speed_k
	cycle /= speed_k
	_attack_token += 1
	var token := _attack_token
	var now := Time.get_ticks_msec()
	_busy_until_ms = now + int(cycle * 1000.0)
	_face_aim_until_ms = now + int((cycle + 0.2) * 1000.0)
	_impact_pending = true
	_impact_callback = on_impact
	_impact_frame = -1
	var playing := _play_animation(anim, AnimPriority.ACTION)
	if playing:
		is_attacking = true
		var sf := animated_sprite.sprite_frames
		var a := animated_sprite.animation
		var n := sf.get_frame_count(a)
		var fps := maxf(sf.get_animation_speed(a), 0.01)
		var f := impact_frame if impact_frame >= 0 else n / 2
		_impact_frame = clampi(f, 1, maxi(n - 1, 1))
		animated_sprite.speed_scale = (_impact_frame / fps) / maxf(startup, 0.01)
		_recovery_speed = ((n - _impact_frame) / fps) / maxf(cycle - startup, 0.05)
	_update_facing(Vector2.ZERO)
	var tree := get_tree()
	# Safety nets: the hit still lands if the animation is missing or interrupted, and the
	# attack always ends on time even for looping animations.
	tree.create_timer(startup + (0.08 if playing else 0.0)).timeout.connect(_fire_impact.bind(token))
	tree.create_timer(cycle).timeout.connect(_end_action.bind(token))

func _apply_anim_scale() -> void:
	if not animated_sprite:
		return
	var mult: float = anim_scale.get(String(animated_sprite.animation), 1.0)
	animated_sprite.scale = base_scale * mult
	# Scaling happens around the frame centre; shift so the feet don't sink or float.
	var feet := (anim_feet_px + sprite_offset.y)
	animated_sprite.position.y = feet * (base_scale.y - animated_sprite.scale.y)

func _on_frame_changed() -> void:
	if _impact_pending and is_attacking and animated_sprite.frame == _impact_frame:
		_fire_impact(_attack_token)
	_on_attack_frame(animated_sprite.frame)

# Hook for classes that drive their own animation (the Archer holds the draw).
func _on_attack_frame(_frame: int) -> void:
	pass

func _fire_impact(token: int) -> void:
	if token != _attack_token or not _impact_pending:
		return
	_impact_pending = false
	if is_attacking and animated_sprite:
		animated_sprite.speed_scale = _recovery_speed
	if is_alive and is_inside_tree() and _impact_callback.is_valid():
		_impact_callback.call()

func _end_action(token: int) -> void:
	if token != _attack_token:
		return
	_finish_attack_anim()

func _finish_attack_anim() -> void:
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
	if is_attacking:
		is_attacking = false
		_anim_release(AnimPriority.ACTION)

func _melee_impact(dir: Vector2, reach: float, arc_deg: float, damage: int, kb: float) -> void:
	var hits := _strike_arc(dir, reach, arc_deg, damage, kb)
	var el := _attack_element()
	var col := Color(1, 1, 1) if el == ElementalSystem.Element.NONE else ElementalSystem.get_element_color(el).lightened(0.4)
	CombatFX.slash(global_position + Vector2(0, -2), dir, reach, arc_deg, col, (3.0 + reach * 0.08) * 1.5)
	_debug_swing = {"dir": dir, "reach": reach, "arc": arc_deg, "until": Time.get_ticks_msec() + 250}
	if hits > 0:
		on_hit_landed("basic")
		_play_layers(snd_hit)
		CombatFX.hit_stop(0.045)
		CombatFX.shake(1.5, 0.12)

# Damages every enemy whose body overlaps a circular sector in front of the character.
# Returns how many were hit.
func _strike_arc(dir: Vector2, reach: float, arc_deg: float, damage: int, kb: float) -> int:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = reach + 16.0
	query.shape = circle
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 4
	var half := deg_to_rad(arc_deg * 0.5)
	var hits := 0
	var seen := {}
	for res in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body = res["collider"]
		if body == self or not is_instance_valid(body) or seen.has(body):
			continue
		seen[body] = true
		var info := _body_center_radius(body)
		var to: Vector2 = info[0] - global_position
		var r: float = info[1]
		var dist := to.length()
		if dist - r > reach:
			continue
		# Anything overlapping the character itself counts even if it is slightly behind.
		if dist > r + 4.0 and absf(dir.angle_to(to)) > half + atan2(r, dist):
			continue
		if body.has_method("take_elemental_hit"):
			body.take_elemental_hit(damage, _attack_element(), self)
		elif body.has_method("receive_damage"):
			body.receive_damage(damage)
		else:
			continue
		hits += 1
		if body.has_method("apply_knockback"):
			body.apply_knockback(to.normalized() * kb)
	return hits

static func _body_center_radius(body: Node2D) -> Array:
	for c in body.get_children():
		var cs := c as CollisionShape2D
		if not cs or not cs.shape or cs.disabled:
			continue
		var sc := absf(cs.global_scale.x)
		if cs.shape is CircleShape2D:
			return [cs.global_position, cs.shape.radius * sc]
		if cs.shape is CapsuleShape2D:
			return [cs.global_position, cs.shape.radius * sc]
		if cs.shape is RectangleShape2D:
			return [cs.global_position, minf(cs.shape.size.x, cs.shape.size.y) * 0.5 * sc]
	return [body.global_position, 6.0]

func _spell_damage() -> int:
	return roundi((4 + int(intelligence * 0.6)) * perk_mult("arcana"))

func _cast_impact(heavy: bool) -> void:
	var target := _assist_target(cast_range)
	var dir := _assisted_dir(cast_range)
	aim_direction = dir
	_update_facing(Vector2.ZERO)
	var angles := [-0.26, 0.0, 0.26] if heavy else [0.0]
	for a in angles:
		var d: Vector2 = dir.rotated(a)
		var bolt := ElementBolt.create(_attack_element(), roundi(_spell_damage() * (0.8 if heavy else 1.0)), d, cast_speed, self)
		bolt.from_player = true
		bolt.size = 1.7 if heavy else 1.25
		bolt.hit_kind = "skill" if heavy else "basic"
		bolt.impact_sfx = snd_impact
		bolt.damage = roundi(bolt.damage * damage_mult_buff)
		if a == 0.0:
			bolt.homing_target = target
		get_parent().add_child(bolt)
		bolt.global_position = global_position + d * 8.0 + Vector2(0, -3)
	_play_layers(snd_cast, 0.9 if heavy else 1.0)
	var flash_col := ElementalSystem.get_element_color(_attack_element())
	CombatFX.burst(global_position + dir * 9.0 + Vector2(0, -3), flash_col, 14 if heavy else 7, 70.0, 0.25, 0.0, 1.5)
	if heavy:
		CombatFX.shockwave(global_position + dir * 9.0, flash_col, 12.0, 0.2, 1.5)
	if heavy or randf() < effort_chance:
		_voice("effort")

func _play_layers(layers: Array, pitch_mult: float = 1.0, vol_add: float = 0.0) -> void:
	for l in layers:
		AudioManager.play_bank(l[0], l[1] + vol_add, l[2] * pitch_mult)

# kind: "effort", "hurt" or "death".
func _voice(kind: String, vol_add: float = 0.0) -> void:
	AudioManager.play_bank("%s_%s" % [voice, kind], voice_volume + vol_add, voice_pitch, 0.03)

func _sfx(path: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx(path, vol, pitch)

func use_health_potion() -> void:
	if current_health >= max_health:
		mostrar_texto_flotante("HP FULL", Color.ORANGE)
		return
	if GameManager.use_health_potion():
		recover_health(30)
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_bank("bottle", -6.0, 0.9)
			am.play_bank("heal", -6.0, 1.0)
		mostrar_texto_flotante("+30 HP", Color.GREEN)

func use_mana_potion() -> void:
	# Fighters have no use for mana: the potion stays in the bag for a Transmuter.
	if not uses_mana:
		mostrar_texto_flotante("NO MANA TO RESTORE", Color(0.6, 0.65, 0.8))
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.show_message("You don't use mana. Trade mana potions for health at a Transmuter.", 3.0)
		return
	if current_mana >= max_mana:
		mostrar_texto_flotante("MP FULL", Color.SKY_BLUE)
		return
	if GameManager.use_mana_potion():
		recover_mana(20)
		mostrar_texto_flotante("+20 MP", Color(0.45, 0.6, 1.0))
		AudioManager.play_bank("bottle", -6.0, 1.05)
		AudioManager.play_bank("magic_shield", -10.0, 1.3)

func take_elemental_hit(damage: int, element: ElementalSystem.Element, source: Node = null) -> void:
	if _is_invulnerable():
		return
	if damage > 0 and source is Node2D and _guard and is_instance_valid(source):
		match _guard.try_absorb(damage, (source as Node2D).global_position):
			"parry":
				_on_parry(source)
				return
			"block":
				_on_block(source)
				return
			"break":
				_on_guard_break()
	if damage > 0 and is_instance_valid(source) and source != self and "character_name" in source:
		_last_attacker = String(source.character_name)
	super.take_elemental_hit(damage, element, source)

var _last_attacker: String = "" # shown on the death screen

# ---------------------------------------------------------------------------------
# Guard, parry, dodge
# ---------------------------------------------------------------------------------

func _on_parry(source: Node) -> void:
	var mid: Vector2 = (global_position + (source as Node2D).global_position) * 0.5
	CombatFX.hit_stop(0.09)
	CombatFX.shake(2.5, 0.15)
	CombatFX.burst(mid, Color(1.0, 0.85, 0.35), 14, 90.0, 0.3, 0.0, 1.5)
	CombatFX.shockwave(mid, Color(1.0, 0.9, 0.5), 14.0, 0.2, 1.5)
	CombatFX.floating_label(global_position, "PARRY!", Color(1.0, 0.85, 0.3), 1.1)
	AudioManager.play_bank("metal_clash", 2.0, 1.25)
	AudioManager.play_bank("magic_shield", -8.0, 1.6)
	if source.has_method("apply_stun"):
		source.apply_stun(1.0)
	if source.has_method("apply_knockback"):
		source.apply_knockback(((source as Node2D).global_position - global_position).normalized() * 120.0)
	_invulnerable_until_ms = maxi(_invulnerable_until_ms, Time.get_ticks_msec() + 250)

func _on_block(source: Node) -> void:
	var from: Vector2 = (source as Node2D).global_position
	_play_layers(snd_block)
	CombatFX.burst(global_position + aim_direction * 9.0, Color(0.85, 0.92, 1.0), 6, 55.0, 0.2, 0.0, 1.2)
	CombatFX.shake(1.2, 0.08)
	apply_knockback((global_position - from).normalized() * 70.0)
	_invulnerable_until_ms = maxi(_invulnerable_until_ms, Time.get_ticks_msec() + 150)

func _on_guard_break() -> void:
	_stunned_until_ms = Time.get_ticks_msec() + int(PlayerGuard.BREAK_STUN * 1000.0)
	CombatFX.floating_label(global_position, "GUARD BREAK", Color(1.0, 0.55, 0.2), 1.0)
	CombatFX.shake(3.0, 0.2)
	AudioManager.play_bank("heavy_clash", 0.0, 0.8)

# Parrying an enemy spell sends it back where it came from.
func deflect_projectile(bolt: Node2D) -> bool:
	if not _guard or not _guard.in_parry_window():
		return false
	var to := bolt.global_position - global_position
	if absf(aim_direction.angle_to(to)) > deg_to_rad(PlayerGuard.BLOCK_ARC_DEG * 0.5):
		return false
	var src = bolt.get("source")
	var back: Vector2 = -bolt.direction
	if src is Node2D and is_instance_valid(src):
		back = ((src as Node2D).global_position - bolt.global_position).normalized()
	bolt.direction = back
	bolt.speed *= 1.3
	bolt.from_player = true
	bolt.source = self
	bolt.collision_mask = 1 | 4
	CombatFX.hit_stop(0.07)
	CombatFX.burst(bolt.global_position, Color(1.0, 0.85, 0.35), 10, 80.0, 0.25, 0.0, 1.5)
	CombatFX.floating_label(global_position, "PARRY!", Color(1.0, 0.85, 0.3), 1.1)
	AudioManager.play_bank("metal_clash", 2.0, 1.3)
	return true

func is_dodging() -> bool:
	return Time.get_ticks_msec() < _dodge_until_ms

func dodge_ready_fraction() -> float:
	var now := Time.get_ticks_msec()
	var total := (dodge_duration + dodge_cooldown) * 1000.0
	return clampf(1.0 - (_dodge_ready_ms - now) / total, 0.0, 1.0)

func _try_dodge(move_dir: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	if now < _dodge_ready_ms or _impact_pending:
		return false
	_cancel_actions()
	_dodge_dir = move_dir.normalized() if move_dir != Vector2.ZERO else aim_direction
	_dodge_until_ms = now + int(dodge_duration * 1000.0)
	_dodge_ready_ms = _dodge_until_ms + int(dodge_cooldown * 1000.0)
	_invulnerable_until_ms = maxi(_invulnerable_until_ms, now + int(dodge_duration * 0.85 * 1000.0))
	_ghost_t = 0.0
	if animated_sprite and absf(_dodge_dir.x) > 0.05:
		animated_sprite.flip_h = _dodge_dir.x < 0
	AudioManager.play_bank("fist_swing", -4.0, 1.15)
	AudioManager.play_bank("footstep", -10.0, 0.9)
	return true

# Front-loaded burst: fast at the start, easing out (the speed curve integrates to exactly
# dodge_distance).
func _process_dodge(delta: float) -> void:
	var left := (_dodge_until_ms - Time.get_ticks_msec()) / 1000.0
	var t := clampf(1.0 - left / dodge_duration, 0.0, 1.0)
	var spd := dodge_distance / dodge_duration * (1.6 - 1.2 * t)
	velocity = _dodge_dir * spd + external_push * 0.5
	move_and_slide()
	_dash_hits()
	_move_vel = _dodge_dir * speed * 0.6
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.045
		_spawn_ghost()
	_play_animation("Run")

# Afterimage of the current frame, fading out: makes the roll read even without roll art.
func _spawn_ghost() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var g := Sprite2D.new()
	g.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	g.flip_h = animated_sprite.flip_h
	g.offset = animated_sprite.offset
	g.global_position = animated_sprite.global_position
	g.scale = animated_sprite.global_scale
	g.modulate = Color(0.55, 0.75, 1.0, 0.45)
	g.z_index = z_index - 1
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.2)
	tw.tween_callback(g.queue_free)

# Stops whatever the character is doing so a dodge can cancel an attack's recovery.
func _cancel_actions() -> void:
	if is_attacking or _is_attack_busy():
		_attack_token += 1
		_busy_until_ms = Time.get_ticks_msec()
		_finish_attack_anim()

func receive_damage(amount: int) -> void:
	if not is_alive or _is_invulnerable():
		return
	if shield_hp > 0 and amount > 0:
		var absorbed := mini(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
		CombatFX.floating_label(global_position, "-%d" % absorbed, Color.GOLDENROD, 0.8)
		if shield_hp <= 0:
			_break_shield()
		if amount <= 0:
			_start_invulnerability(INVULNERABILITY_TIME * 0.5)
			return
	if amount > 0:
		CombatFX.shake(3.0, 0.2)
		CombatFX.flash(animated_sprite, 0.1)
		_start_invulnerability(INVULNERABILITY_TIME)
		_spawn_blood_vfx()
		_play_hurt_anim()
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_bank("heavy_flesh", -6.0, 0.9)
		# A short pain grunt, not on every single hit of a flurry.
		var now := Time.get_ticks_msec()
		if now - _last_hurt_voice_ms > 450:
			_last_hurt_voice_ms = now
			_voice("hurt")
	# Run stats count the health actually lost (after armour, shields and god mode).
	var before := current_health
	super.receive_damage(amount)
	Progression.stat("taken", maxi(before - current_health, 0))



func _default_hit_color() -> Color:
	return Color(1.0, 0.35, 0.35)

func _is_invulnerable() -> bool:
	return god_mode or Time.get_ticks_msec() < _invulnerable_until_ms

func _start_invulnerability(duration: float) -> void:
	_invulnerable_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)
	if not animated_sprite:
		return
	var tw := animated_sprite.create_tween().set_loops(maxi(1, int(duration / 0.1)))
	tw.tween_property(animated_sprite, "self_modulate:a", 0.35, 0.05)
	tw.tween_property(animated_sprite, "self_modulate:a", 1.0, 0.05)

# Frozen on the player slows instead of stunning: losing control feels bad.
func apply_freeze(duration: float) -> void:
	_slow_time_left = maxf(_slow_time_left, duration * 0.6)
	CombatFX.floating_label(global_position, "SLOWED", Color.LIGHT_BLUE, 0.8)

func add_shield(amount: int, duration: float, color: Color) -> void:
	shield_hp = maxi(shield_hp, amount)
	_shield_max = shield_hp
	if not _shield_ring:
		_shield_ring = _ShieldRing.new()
		add_child(_shield_ring)
	_shield_ring.color = color
	CombatFX.floating_label(global_position, "SHIELD", color, 0.9)
	_shield_token += 1
	get_tree().create_timer(duration).timeout.connect(_expire_shield.bind(_shield_token))

func _expire_shield(token: int) -> void:
	if token == _shield_token:
		_break_shield()

func _break_shield() -> void:
	shield_hp = 0
	if _shield_ring:
		CombatFX.burst(global_position + Vector2(0, -6), _shield_ring.color, 18, 70.0, 0.4, 60.0, 2.0)
		AudioManager.play_bank("ice_crack", -6.0, 1.4)
		_shield_ring.queue_free()
		_shield_ring = null

func _regen_mana(delta: float) -> void:
	if current_mana >= max_mana:
		_mana_regen_acc = 0.0
		return
	_mana_regen_acc += wisdom * MANA_REGEN_PER_WISDOM * delta
	if _mana_regen_acc >= 1.0:
		var whole := int(_mana_regen_acc)
		_mana_regen_acc -= whole
		recover_mana(whole)

func _melee_damage() -> int:
	return roundi((7 + strength) * perk_mult("might"))

# Classes without an element of their own borrow whatever element is imbued on them,
# so getting hit by a Pyro slime turns your next swings into Pyro attacks.
func _attack_element() -> ElementalSystem.Element:
	if base_element != ElementalSystem.Element.NONE:
		return base_element
	return current_imbued_element

func _play_hurt_anim() -> void:
	if not animated_sprite or is_attacking or _is_hurt: return
	for anim in ["hurt", "hit", "Hurt", "Hit"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			_is_hurt = true
			_anim_play(animated_sprite, anim, AnimPriority.ACTION)
			var t = get_tree()
			if t: await t.create_timer(0.15).timeout
			_anim_release(AnimPriority.ACTION)
			_is_hurt = false
			return

func _spawn_blood_vfx() -> void:
	CombatFX.blood(global_position, -last_direction if knockback == Vector2.ZERO else knockback, Color(0.65, 0.06, 0.08), 7)

func interact() -> void:
	if _is_interacting or interactables_in_range.is_empty(): return
	_is_interacting = true

	var closest = null
	var min_dist = 99999.0

	for item in interactables_in_range:
		if not is_instance_valid(item): continue
		if item == self or is_ancestor_of(item) or item.is_in_group("player"): continue

		var d = global_position.distance_to(item.global_position)
		if d < min_dist:
			min_dist = d
			closest = item

	if closest:
		if closest.has_method("interact"):
			closest.interact(self)
		elif closest.get_parent() and closest.get_parent() != self and closest.get_parent().has_method("interact"):
			closest.get_parent().interact(self)

	_is_interacting = false

func _play_animation(anim_name: String, priority: AnimPriority = AnimPriority.FREE) -> bool:
	if not animated_sprite: return false
	var sf = animated_sprite.sprite_frames
	if not sf: return false

	var final_anim = ""

	if anim_name == "Attack":
		for fallback in ["Attack", "Attack1", "attack", "attack1", "Attack_1"]:
			if sf.has_animation(fallback):
				final_anim = fallback
				break
	elif anim_name == "attack2":
		for fallback in ["attack2", "Attack2", "Attack_2", "Attack", "Attack1"]:
			if sf.has_animation(fallback):
				final_anim = fallback
				break

	if final_anim == "":
		for c in [anim_name, anim_name.to_lower(), anim_name.capitalize()]:
			if sf.has_animation(c):
				final_anim = c
				break

	if final_anim == "":
		match anim_name:
			"Walk", "Run":
				for fallback in ["Walk", "Run", "Walk_Right", "Run_Right", "Idle", "idle"]:
					if sf.has_animation(fallback):
						final_anim = fallback
						break
			_:
				return false

	if final_anim != "":
		return _anim_play(animated_sprite, final_anim, priority)
	return false

func _on_animation_finished() -> void:
	if is_attacking and not _impact_pending:
		_finish_attack_anim()

# Percentage armour for the player (enemies keep the flat formula): resistance 12 blocks
# ~37% of a hit, resistance 3 only ~13%. Flat subtraction made tanks immune to small enemies.
func _mitigate(amount: int) -> int:
	return maxi(1, roundi(amount * damage_taken_mult * 20.0 / (20.0 + maxf(resistance, 0.0))))

func _draw() -> void:
	super._draw()
	if not GameManager.debug_mode or _debug_swing.is_empty():
		return
	if Time.get_ticks_msec() > int(_debug_swing["until"]):
		return
	var dir: Vector2 = _debug_swing["dir"]
	var half := deg_to_rad(float(_debug_swing["arc"]) * 0.5)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(13):
		pts.append(dir.rotated(lerpf(-half, half, i / 12.0)) * float(_debug_swing["reach"]))
	draw_colored_polygon(pts, Color(1, 0.3, 0.2, 0.35))

func _apply_class_stats() -> void:
	pass

func _on_element_applied() -> void:
	actualizar_icono_elemento()
	element_timer.start(3.0)

func _on_reaction_triggered(_name: String, _data: Dictionary) -> void:
	pass

func _on_element_refreshed() -> void:
	element_timer.start(3.0)

var _badge: ElementBadge

func actualizar_icono_elemento() -> void:
	if not _badge:
		_badge = ElementBadge.attach(self, ElementBadge.head_height_of(self, animated_sprite))
	_badge.set_element(current_imbued_element)

func limpiar_elemento() -> void:
	super.limpiar_elemento()
	if _badge:
		_badge.set_element(ElementalSystem.Element.NONE)
	if element_timer:
		element_timer.stop()

func _on_element_timer_timeout() -> void:
	limpiar_elemento()

func die() -> void:
	if not is_alive: return
	super.die()
	# The death screen shows the build and level as they were when you fell, before the
	# level's gains are rolled back.
	Progression.stats["build"] = Progression.perks.duplicate()
	Progression.stats["level"] = Progression.level
	Progression.restore()
	_voice("death", 3.0)
	velocity = Vector2.ZERO
	limpiar_elemento()
	GameManager.restore_bag()
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if animated_sprite:
		_anim_play(animated_sprite, "Death", AnimPriority.LOCKED)
		var t = get_tree()
		if t: await t.create_timer(1.5).timeout

	if not is_inside_tree(): return
	# The death screen sums up the run; TRY AGAIN reloads the level as before.
	Progression.stat("deaths")
	Progression.stats["killer"] = _last_attacker
	DeathScreen.show_for(get_tree().current_scene.scene_file_path)

func _on_interactable_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if body == self or is_ancestor_of(body): return

	if body.has_method("_collect"):
		body._collect(self)
		return
	if body.get_parent() and body.get_parent().has_method("_collect"):
		body.get_parent()._collect(self)
		return

	if body.is_in_group("interactable") or (body.get_parent() and body.get_parent().is_in_group("interactable")) or body.has_method("interact") or (body.get_parent() and body.get_parent().has_method("interact")):
		if not interactables_in_range.has(body):
			interactables_in_range.append(body)
			_update_interaction_prompt()

func _on_interactable_exited(body: Node2D) -> void:
	interactables_in_range.erase(body)
	_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_interaction_prompt"): return
	var valid_interactables = []
	for item in interactables_in_range:
		if not is_instance_valid(item): continue
		var target = item
		if not target.has_method("interact") and target.get_parent() and target.get_parent().has_method("interact"):
			target = target.get_parent()
		var already_used = false
		if "is_open" in target and target.is_open: already_used = true
		if "is_opened" in target and target.is_opened: already_used = true
		if not already_used:
			valid_interactables.append(item)
	hud.show_interaction_prompt(not valid_interactables.is_empty())

class _ShieldRing extends Node2D:
	var color: Color = Color.GOLDENROD
	var strength: float = 1.0 # shield left / shield given: fewer shards as it wears down
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		var p := get_parent() as Player
		if p and p._shield_max > 0:
			strength = clampf(float(p.shield_hp) / p._shield_max, 0.0, 1.0)
		queue_redraw()

	# A crystal barrier: a faint bubble (flattened, so it sits around the body rather than
	# on the floor), a glinting rim, and six crystal shards orbiting; shards drop out as the
	# shield takes damage.
	func _draw() -> void:
		var owner_p := get_parent() as Player
		var c := owner_p.body_center() if owner_p else Vector2(0, -6)
		var r := 13.0 + sin(_t * 3.0) * 0.6
		draw_set_transform(c, 0.0, Vector2(1.0, 0.92))
		draw_circle(Vector2.ZERO, r, Color(color, 0.1))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.35), 1.0)
		var glint := _t * 1.8
		draw_arc(Vector2.ZERO, r, glint, glint + 0.7, 10, Color(1, 1, 1, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var shards := maxi(1, ceili(6 * strength))
		for i in shards:
			var a := _t * 1.2 + TAU * i / 6.0
			var p := c + Vector2(cos(a) * (r + 1.0), sin(a) * (r + 1.0) * 0.55)
			var s := 2.6 + 0.4 * sin(_t * 5.0 + i)
			var pts := PackedVector2Array([p + Vector2(0, -s * 1.4), p + Vector2(s * 0.7, 0), p + Vector2(0, s * 1.4), p + Vector2(-s * 0.7, 0)])
			draw_colored_polygon(pts, Color(color.lightened(0.25), 0.9))
			draw_line(p + Vector2(0, -s * 1.4), p + Vector2(0, s * 1.4), Color(1, 1, 1, 0.7), 1.0)
