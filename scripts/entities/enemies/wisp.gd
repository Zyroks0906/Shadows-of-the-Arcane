extends Enemy
class_name Wisp

# Ranged elemental caster: keeps its distance, strafes and fires slow elemental bolts.
# Its element is rolled by the spawner, so every Wisp is a reaction waiting to happen.

const SHEET_DIR := "res://assets/sprites/enemies/Wisp/wisp_%s.png"
const FRAME := 32
const ANIMS := {"idle": [0, 6, 8.0, true], "attack": [1, 6, 10.0, false], "hurt": [2, 3, 12.0, false], "death": [3, 8, 10.0, false]}

@export var preferred_distance: float = 80.0
@export var bolt_speed: float = 110.0

var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

func _init_stats() -> void:
	shadow_hover = 7.0
	max_health = 36
	resistance = 1
	character_name = "Wisp"
	body_scale = 0.55
	speed = 38.0
	detection_range = 190.0
	attack_range = 140.0
	attack_damage = 10
	attack_cooldown = 2.2
	attack_delay = 0.35
	random_element = true
	use_element_tint = false
	show_element_aura = false
	knockback_scale = 1.4

# Set at construction so spawners (which read it before _ready) give wisps the level's
# elements instead of the Pyro fallback.
func _init() -> void:
	random_element = true

func _ready() -> void:
	if base_element == ElementalSystem.Element.NONE:
		base_element = ElementalSystem.Element.PYRO
	animated_sprite.sprite_frames = _build_frames(base_element)
	super._ready()
	add_child(_make_glow())
	animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _process_knockback(delta) or is_frozen or is_attacking or is_hurt:
		return
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	animated_sprite.flip_h = to_player.x < 0
	if distance > detection_range:
		velocity = Vector2.ZERO
		_play_animation("idle")
		move_and_slide()
		return

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.0)
		_strafe_dir = [-1.0, 1.0].pick_random()

	var dir := to_player.normalized()
	var radial := 0.0
	if distance > preferred_distance + 15.0:
		radial = 1.0
	elif distance < preferred_distance - 15.0:
		radial = -1.2
	velocity = (dir * radial + dir.orthogonal() * _strafe_dir * 0.6).normalized() * speed * terrain_speed_mult + external_push
	_play_animation("idle")
	move_and_slide()

	if can_attack and distance <= attack_range:
		_perform_attack()

func _perform_attack() -> void:
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	_anim_play(animated_sprite, "attack", AnimPriority.ACTION)
	await get_tree().create_timer(attack_delay).timeout
	if not is_alive or is_frozen:
		is_attacking = false
		_anim_release(AnimPriority.ACTION)
		can_attack = true
		return
	if is_instance_valid(player):
		_fire_bolt((player.global_position - global_position).normalized())
	await get_tree().create_timer(0.3).timeout
	_anim_release(AnimPriority.ACTION)
	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive:
		can_attack = true

func _fire_bolt(dir: Vector2) -> void:
	var bolt := ElementBolt.create(base_element, attack_damage, dir, bolt_speed, self)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + dir * 8.0
	AudioManager.play_bank_at(_bolt_launch_sound(), global_position, -8.0, 1.1)

func _make_glow() -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = ElementalSystem.get_element_color(base_element)
	light.energy = 0.9
	light.texture_scale = 0.6
	return light

static func _build_frames(element: ElementalSystem.Element) -> SpriteFrames:
	var tex: Texture2D = load(SHEET_DIR % ElementalSystem.get_element_name(element).to_lower())
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ANIMS:
		var row: int = ANIMS[anim][0]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, ANIMS[anim][2])
		sf.set_animation_loop(anim, ANIMS[anim][3])
		for i in ANIMS[anim][1]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME, row * FRAME, FRAME, FRAME)
			sf.add_frame(anim, at)
	return sf

func _bolt_launch_sound() -> String:
	match base_element:
		ElementalSystem.Element.PYRO: return "fire_launch"
		ElementalSystem.Element.CRYO, ElementalSystem.Element.HYDRO: return "ice_launch"
		_: return "electric_launch"
