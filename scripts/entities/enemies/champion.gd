extends BossBase

# The Fallen Champion, Skyhold's final boss: a spear duellist charged with Electro. Where the
# Golem is a slow wall, he is fast and reads you: every blow is telegraphed, and after his
# big leap he is left kneeling for a moment, the window to punish him.
#   Thrust  (basic): a narrow cone, then the spear jab.
#   Lunge:  a red line marks his path, then he charges down it.
#   Leap:   a circle marks where he will land (on you); he comes down with a quake, then
#           kneels, stunned, for a second.
#   Phase 2 (below half health): the tower winds bring Anemo wisps, he moves faster,
#   specials come sooner and he adds a rain of falling spears (rock rain).
# Art: Dark Fantasy Enemy #1 by Volva Studio (assets/sprites/enemies/Bosses/Champion).

const ART := "res://assets/sprites/enemies/Bosses/Champion/"
const FRAME := 384
const SPRITE_SCALE := 0.27
const FEET_Y := 246.0 # bottom of the figure inside its 384 px frame
const WISP_SCENE := "res://scenes/entities/Enemies/Wisp.tscn"

var _phase2 := false
var _move_i := 0

func _init_stats() -> void:
	max_health = 1250
	resistance = 3
	character_name = "Champion"

func _ready() -> void:
	_build_frames()
	use_element_tint = false # the art is already coloured; the Electro tint turned him pink
	base_element = ElementalSystem.Element.ELECTRO
	speed = 46.0
	attack_range = 34.0
	detection_range = 170.0
	attack_damage = 26
	attack_cooldown = 1.0
	special_attack_cooldown = 3.2
	leash = 190.0
	super._ready()
	current_imbued_element = base_element
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = Color(0.7, 0.55, 1.0)
	light.energy = 0.6
	light.texture_scale = 1.4
	add_child(light)

func _build_frames() -> void:
	var anims := {"walk": ["Walk", 10.0, true], "idle": ["Walk", 4.0, true], "attack1": ["Light_Attack", 12.0, false],
		"attack2": ["Heavy_Attack", 12.0, false], "jump": ["Jump", 10.0, false], "magic": ["Magic", 10.0, false],
		"stun": ["Stun", 8.0, true], "death": ["Death", 10.0, false], "kneel": ["on_his_knees", 4.0, true]}
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		var tex: Texture2D = load(ART + anims[a][0] + ".png")
		sf.add_animation(a)
		sf.set_animation_speed(a, anims[a][1])
		sf.set_animation_loop(a, anims[a][2])
		var n := int(tex.get_width() / FRAME)
		for i in (2 if a == "idle" else n):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
			sf.add_frame(a, at)
	animated_sprite.sprite_frames = sf
	animated_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	animated_sprite.position = Vector2(0, -(FEET_Y - FRAME / 2.0) * SPRITE_SCALE + 6.0)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("idle")

func receive_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_alive and not _phase2 and current_health < max_health * 0.5:
		_phase2 = true
		speed *= 1.2
		mostrar_texto_flotante("TOWER WINDS", Color.AQUAMARINE)
		CombatFX.shockwave(global_position, Color.AQUAMARINE, 90.0, 0.6, 4.0)
		var scene: PackedScene = load(WISP_SCENE)
		for offset in [Vector2(-40, -10), Vector2(40, -10), Vector2(0, 35)]:
			var wisp: Enemy = scene.instantiate()
			wisp.base_element = ElementalSystem.Element.ANEMO
			get_parent().add_child.call_deferred(wisp)
			wisp.set_deferred("global_position", global_position + offset)

func _face(at: Vector2) -> void:
	animated_sprite.flip_h = at.x < global_position.x

# --- Thrust ---------------------------------------------------------------------------------
func _perform_basic_attack() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	if not is_instance_valid(player):
		await _end_move(attack_cooldown)
		return
	var dir := (player.global_position - global_position).normalized()
	_face(player.global_position)
	_play_animation("attack1")
	BossMoves.warn_cone(self, dir, 46.0, 40.0, 0.45)
	await get_tree().create_timer(0.45, false).timeout
	if is_alive and is_instance_valid(player):
		var to := player.global_position - global_position
		if to.length() <= 48.0 and absf(dir.angle_to(to)) < deg_to_rad(28.0):
			player.take_elemental_hit(attack_damage, base_element, self)
			player.apply_knockback(dir * 220.0)
		CombatFX.slash(global_position + Vector2(0, -4), dir, 40.0, 30.0, Color(0.75, 0.6, 1.0), 4.0)
		AudioManager.play_bank_at("blade_flesh", global_position, -4.0, 1.1)
	await _end_move(attack_cooldown)

# --- Specials -------------------------------------------------------------------------------
func _perform_special_attack() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	_move_i += 1
	if not is_instance_valid(player):
		await _end_move(0.5)
		return
	if _phase2 and _move_i % 3 == 0:
		_play_animation("magic")
		mostrar_texto_flotante("SPEAR RAIN", Color(0.75, 0.6, 1.0))
		await BossMoves.rock_rain(self, 7, int(attack_damage * 0.7), 0.9)
	elif _move_i % 2 == 0:
		await _lunge()
	else:
		await _leap()
	special_timer = special_attack_cooldown * (0.65 if _phase2 else 1.0)
	await _end_move(attack_cooldown * 0.5)

func _lunge() -> void:
	var dir := (player.global_position - global_position).normalized()
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 120.0, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var dist: float = (global_position.distance_to(hit["position"]) - 10.0) if hit else 120.0
	_face(player.global_position)
	_play_animation("attack2")
	BossMoves.warn_cone(self, dir, dist, 12.0, 0.6)
	await get_tree().create_timer(0.6, false).timeout
	if not is_alive:
		return
	var from := global_position
	var to := global_position + dir * dist
	var struck := false
	var t := 0.0
	while t < 0.22:
		t += get_physics_process_delta_time()
		global_position = from.lerp(to, minf(t / 0.22, 1.0))
		if not struck and is_instance_valid(player) and player.global_position.distance_to(global_position) < 14.0:
			struck = true
			player.take_elemental_hit(int(attack_damage * 1.3), base_element, self)
			player.apply_knockback(dir * 320.0)
		await get_tree().physics_frame
	CombatFX.burst(global_position, Color(0.75, 0.6, 1.0), 14, 60.0, 0.3)
	AudioManager.play_bank_at("dagger_swing", global_position, 0.0, 0.7)

func _leap() -> void:
	var land := player.global_position
	_play_animation("jump")
	BossMoves.warn_circle(get_parent(), land, 28.0, 0.8)
	CombatFX.pvfx("landing-dust", global_position, 0.4)
	var from := global_position
	var t := 0.0
	var rest := animated_sprite.position
	while t < 0.8:
		t += get_physics_process_delta_time()
		var k := minf(t / 0.8, 1.0)
		global_position = from.lerp(land, k)
		animated_sprite.position.y = rest.y - 26.0 * 4.0 * k * (1.0 - k)
		await get_tree().physics_frame
	animated_sprite.position = rest
	if not is_alive:
		return
	CombatFX.pvfx("earth-rupture", global_position, 0.55)
	CombatFX.shockwave(global_position, Color(0.75, 0.6, 1.0), 28.0, 0.3, 3.0)
	CombatFX.shake(5.0, 0.3)
	AudioManager.play_bank_at("stomp", global_position, 3.0, 0.7)
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= 28.0:
		player.take_elemental_hit(int(attack_damage * 1.4), base_element, self)
		player.apply_knockback((player.global_position - global_position).normalized() * 300.0)
	# The punish window: he kneels after the landing.
	_play_animation("kneel")
	mostrar_texto_flotante("OPENING!", Color(1.0, 0.85, 0.4))
	await get_tree().create_timer(1.1, false).timeout

func _end_move(cooldown: float) -> void:
	if not is_alive:
		return
	is_attacking = false
	boss_state = BossState.CHASE
	await get_tree().create_timer(cooldown, false).timeout
	if is_alive:
		can_attack = true
