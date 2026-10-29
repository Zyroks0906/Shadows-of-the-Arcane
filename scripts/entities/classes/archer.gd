extends Player
class_name Archer

# The bow charges: pressing starts drawing, the arrow can't leave before MIN_DRAW (a tap
# still shoots a weak arrow once the string is back) and reaches full power at FULL_DRAW.
const MIN_DRAW := 0.35
const FULL_DRAW := 0.9
const HOLD_FRAME := 2 # frame of Attack.png where the bow is fully drawn
const RELEASE_FRAME := 3 # first frame after the arrow has left
const RECOVERY := 0.2
const ARROW_RANGE := 260.0
const ARROW_SCENE := "res://scenes/Proyectiles/arrow.tscn"

var _drawing := false
var _draw_time := 0.0
var _release_requested := false
var _full_cue_played := false
# E "Gale Volley": for a while she draws twice as fast and her arrows carry Anemo.
const GALE_TIME := 8.0
const GALE_DAMAGE := 3.0
var _gale_until_ms: int = 0

func _init() -> void:
	character_name = "Archer"
	# Plain (physical) arrows; the wind only answers during Gale Volley.
	base_element = ElementalSystem.Element.NONE
	max_health = 90
	max_mana = 60
	strength = 12
	intelligence = 10
	resistance = 5
	wisdom = 9
	speed = 88.0
	base_scale = Vector2(0.4, 0.4)
	aim_tilt = true
	# Elven archer: her own (female) voice; the bow itself sounds the same as any bow.
	voice = "f1"
	voice_pitch = 1.03
	voice_volume = -5.0
	effort_chance = 0.0
	block_stamina_max = 25.0
	snd_block = [["metal_clash", -4.0, 1.2]]
	dodge_distance = 52.0
	dodge_cooldown = 0.55
	attack_move_mult = 0.6
	attack_reach = 14.0
	skill_name = "Gale Volley"
	skill_cooldown = 12.0
	burst_name = "Tempest Arrow"
	burst_cost = 60.0

var _nock: _NockedArrow

func _ready() -> void:
	super._ready()
	_nock = _NockedArrow.new()
	_nock.archer = self
	add_child(_nock)

func _gale() -> bool:
	return Time.get_ticks_msec() < _gale_until_ms

# Fury (attack speed) draws the bow faster, as it speeds up every other class's swing.
func _min_draw() -> float:
	return MIN_DRAW * (0.5 if _gale() else 1.0) / (attack_speed_mult * perk_mult("fury"))

func _full_draw() -> float:
	return FULL_DRAW * (0.5 if _gale() else 1.0) / (attack_speed_mult * perk_mult("fury"))

func _attack_element() -> ElementalSystem.Element:
	return ElementalSystem.Element.ANEMO if _gale() else super._attack_element()

func _weapon_range() -> float:
	return ARROW_RANGE

func _is_committed() -> bool:
	return _drawing or super._is_committed()

func _handle_attack_input(delta: float) -> void:
	if not _drawing:
		if Input.is_action_just_pressed("attack_1") and not _is_attack_busy():
			_start_draw()
		return
	_draw_time += delta
	aim_charge = clampf(_draw_time / _full_draw(), 0.0, 1.0)
	if not Input.is_action_pressed("attack_1"):
		_release_requested = true
	if _draw_time >= _full_draw() and not _full_cue_played:
		_full_cue_played = true
		AudioManager.play_bank("bow_draw", -14.0, 1.4)
		CombatFX.burst(global_position + aim_direction * 8.0, Color(1.0, 0.9, 0.5), 6, 25.0, 0.25)
	if _release_requested and _draw_time >= _min_draw():
		_loose()

func _cancel_actions() -> void:
	if _drawing:
		_drawing = false
		aim_charge = -1.0
		_finish_attack_anim()
	super._cancel_actions()

func _start_draw() -> void:
	_attack_token += 1
	_drawing = true
	_draw_time = 0.0
	_release_requested = false
	_full_cue_played = false
	aim_charge = 0.0
	_impact_pending = false
	AudioManager.play_bank("bow_draw", -4.0, 1.0)
	if _play_animation("Attack", AnimPriority.ACTION):
		is_attacking = true
		var sf := animated_sprite.sprite_frames
		var fps := maxf(sf.get_animation_speed(animated_sprite.animation), 0.01)
		animated_sprite.speed_scale = (HOLD_FRAME / fps) / _min_draw()

# Hold the fully drawn frame for as long as the button is held.
func _on_attack_frame(frame: int) -> void:
	if _drawing and frame == HOLD_FRAME and animated_sprite.animation == &"Attack":
		animated_sprite.pause()

func _loose() -> void:
	var charge := clampf((_draw_time - _min_draw()) / (_full_draw() - _min_draw()), 0.0, 1.0)
	_drawing = false
	aim_charge = -1.0
	var dir := _assisted_dir(ARROW_RANGE)
	aim_direction = dir
	_update_facing(Vector2.ZERO)
	_spawn_arrow(dir, charge, _assist_target(ARROW_RANGE))
	AudioManager.play_bank("bow_shoot", lerpf(-5.0, 0.0, charge), lerpf(1.08, 0.95, charge))
	if charge >= 1.0:
		_voice("effort")

	var token := _attack_token
	var now := Time.get_ticks_msec()
	_busy_until_ms = now + int(RECOVERY * 1000.0)
	_face_aim_until_ms = now + int((RECOVERY + 0.2) * 1000.0)
	if is_attacking and animated_sprite.animation == &"Attack":
		var sf := animated_sprite.sprite_frames
		var n := sf.get_frame_count(&"Attack")
		var fps := maxf(sf.get_animation_speed(&"Attack"), 0.01)
		animated_sprite.frame = RELEASE_FRAME
		animated_sprite.speed_scale = ((n - RELEASE_FRAME) / fps) / RECOVERY
		animated_sprite.play()
	get_tree().create_timer(RECOVERY).timeout.connect(_end_action.bind(token))

func _spawn_arrow(dir: Vector2, charge: float, target: Node2D) -> void:
	var arrow_scene := load(ARROW_SCENE) as PackedScene
	if not arrow_scene:
		push_error("Archer: arrow scene missing")
		return
	var arrow = arrow_scene.instantiate()
	arrow.damage = roundi(strength * lerpf(0.7, 1.6, charge) * perk_mult("might"))
	# Gale: a short burst window, so every quick arrow hits about three times as hard.
	if _gale():
		arrow.damage = roundi(arrow.damage * GALE_DAMAGE)
	arrow.speed = lerpf(260.0, 460.0, charge)
	arrow.knockback_force = lerpf(60.0, 150.0, charge)
	arrow.element = _attack_element()
	arrow.source = self
	arrow.direction = dir
	arrow.homing_target = target
	arrow.impact_sfx = [["arrow_hit", -3.0, 1.0]]
	if _gale():
		arrow.modulate = Color(0.75, 1.3, 1.05)
	elif charge >= 1.0:
		arrow.modulate = Color(1.3, 1.2, 0.8)
	get_parent().add_child(arrow)
	arrow.global_position = global_position + dir * 10.0
	arrow.rotation = dir.angle()

func _do_skill() -> void:
	_gale_until_ms = Time.get_ticks_msec() + int(GALE_TIME * 1000.0)
	CombatFX.spike_ring("Wind", global_position, 14.0, 5, 12.0)
	AudioManager.play_bank("teleport", -4.0, 1.3)
	_gale_aura()
	_voice("effort")
	# A green tint on her while the wind is with her.
	var tw := animated_sprite.create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(0.85, 1.2, 1.0), 0.2)
	tw.tween_interval(GALE_TIME - 0.4)
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

# Q "Tempest Arrow": a huge arrow that pierces everything in its path and leaves a
# vortex that drags enemies together where it stops.
func _do_burst() -> void:
	aim_direction = _nearest_dir()
	_start_action("Attack", 0.3, 0.6, RELEASE_FRAME, _tempest)

# The ultimate is an auto-shot: straight at the closest enemy in sight (the crosshair only
# matters when nobody is around).
func _nearest_dir() -> Vector2:
	var best := _nearest_visible_enemy(ARROW_RANGE) # never at one behind a wall
	return (best.global_position - global_position).normalized() if best else _raw_aim_dir()

func _tempest() -> void:
	var dir := _nearest_dir()
	var arrow = (load(ARROW_SCENE) as PackedScene).instantiate()
	arrow.damage = roundi(strength * 2.2 * perk_mult("might"))
	arrow.speed = 360.0
	arrow.lifetime = 0.55
	arrow.knockback_force = 160.0
	arrow.element = ElementalSystem.Element.ANEMO
	arrow.source = self
	arrow.direction = dir
	arrow.pierce = true
	arrow.hit_kind = "burst"
	arrow.scale = Vector2(2.0, 2.0)
	arrow.modulate = Color(0.7, 1.4, 1.1)
	arrow.impact_sfx = [["arrow_hit", 0.0, 0.8]]
	arrow.on_end = func(pos: Vector2):
		AbilityZone.spawn(self, pos, {"radius": 40.0, "duration": 3.6, "tick": 0.45, "damage": roundi(strength * 0.6 * perk_mult("might")),
			"element": ElementalSystem.Element.ANEMO, "pull": 55.0, "style": "wind"})
	get_parent().add_child(arrow)
	arrow.global_position = global_position + dir * 10.0
	arrow.rotation = dir.angle()
	AudioManager.play_bank("bow_shoot", 4.0, 0.75)
	CombatFX.shake(2.0, 0.15)

# The arrow on the string while drawing, pointing exactly at the crosshair (any angle) and
# pulled back as the draw charges; gold when fully charged.
class _NockedArrow extends Node2D:
	var archer: Archer

	func _ready() -> void:
		z_index = 2

	func _process(_delta: float) -> void:
		visible = archer._drawing
		if visible:
			queue_redraw()

	func _draw() -> void:
		var dir := archer.aim_direction.normalized()
		var charge := clampf(archer.aim_charge, 0.0, 1.0)
		var grip := Vector2(0, -3) + dir * 4.0
		var tail := grip - dir * (3.0 + 4.0 * charge)
		var tip := grip + dir * 8.0
		var col := Color(1.0, 0.85, 0.35) if charge >= 1.0 else (Color(0.75, 1.0, 0.9) if archer._gale() else Color(0.92, 0.88, 0.8))
		draw_line(tail, tip, Color(0.1, 0.07, 0.05), 2.0)
		draw_line(tail, tip, col, 1.0)
		var side := dir.orthogonal() * 1.6
		draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tip - side, tip + side]), col)
		draw_line(tail, tail - dir * 2.0 + side, Color(0.8, 0.3, 0.25), 1.0)
		draw_line(tail, tail - dir * 2.0 - side, Color(0.8, 0.3, 0.25), 1.0)

# While the gale lasts, wind keeps whipping round the archer: gusts of leaves (PVFX
# leaf-gust) at her feet, so the mode is always visible.
func _gale_aura() -> void:
	while _gale() and is_alive:
		CombatFX.pvfx("leaf-gust", global_position + Vector2(randf_range(-6, 6), -2), 0.3, randf() * TAU, Color(0.85, 1.0, 0.9), 1.2, 25)
		await get_tree().create_timer(0.35, false).timeout
