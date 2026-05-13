extends BaseCharacter
class_name Enemy

@export var speed: float = 24.0
@export var detection_range: float = 150.0
@export var attack_range: float = 25.0
@export var attack_damage: int = 24
@export var attack_cooldown: float = 1.5
@export var attack_delay: float = 0.5

func _init_stats() -> void:
	max_health = 95
	resistance = 5
	character_name = name

@export_group("VFX")
@export var override_aura_scene: PackedScene = null
@export var override_blood_scene: PackedScene = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Player = null
var can_attack: bool = true
var is_attacking: bool = false
var is_hurt: bool = false
var shader_material: ShaderMaterial = null

func _ready() -> void:
	_init_stats()
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
	shader_material.set_shader_parameter("tint_intensity", 0.65 if base_element != ElementalSystem.Element.NONE else 0.0)

func _setup_elemental_vfx_aura() -> void:
	for child in get_children():
		if child.has_meta("vfx_aura") and child.has_meta("vfx_runtime"):
			child.queue_free()

	var element := base_element
	if element == ElementalSystem.Element.NONE:
		element = current_imbued_element

	var has_scene_auras := false
	for child in get_children():
		if not child.has_meta("vfx_aura") or child.has_meta("vfx_runtime"):
			continue
		has_scene_auras = true
		var matches := _child_matches_element(child, element)
		child.visible = matches
		if matches and child.has_method("play"):
			child.play("default")

	if not has_scene_auras and element != ElementalSystem.Element.NONE:
		_create_runtime_aura(element)

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
	if amount > 0:
		_spawn_blood_hit_vfx()
		_play_hurt_anim()
	super.receive_damage(amount)

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
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Combat/squelching_4.wav", 5.0, randf_range(0.8, 1.2))
	
	var blood_hit := get_node_or_null("BloodHit") as AnimatedSprite2D
	if blood_hit and blood_hit.sprite_frames:
		if player and is_instance_valid(player):
			var dir := (global_position - player.global_position).normalized()
			blood_hit.rotation = dir.angle()
		blood_hit.visible = true
		blood_hit.play("default")
		return

	var scene: PackedScene = override_blood_scene
	if not scene:
		var path := "res://scenes/vfx/vfx_blood_hit.tscn"
		if ResourceLoader.exists(path):
			scene = load(path)
	if not scene:
		return
	var parent_node := get_parent()
	if not parent_node:
		return
	var vfx := scene.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position
	if vfx.has_method("setup") and player and is_instance_valid(player):
		vfx.setup(player.global_position)

func _on_blood_hit_done() -> void:
	var blood_hit := get_node_or_null("BloodHit") as AnimatedSprite2D
	if blood_hit:
		blood_hit.visible = false

func _physics_process(_delta: float) -> void:
	if not is_alive or is_attacking or is_hurt:
		return
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			_perform_attack()
		else:
			_play_animation("idle")
	elif distance <= detection_range:
		var direction := (player.global_position - global_position).normalized()
		velocity = direction * speed
		_update_animations(direction)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")

	move_and_slide()

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
	is_attacking = true
	can_attack = false
	_anim_play(animated_sprite, "attack", AnimPriority.ACTION)
	
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Combat/swipe.wav", -2.0, randf_range(0.7, 0.9))

	await get_tree().create_timer(attack_delay).timeout
	if not is_alive: return

	if is_instance_valid(player):
		_check_hit()

	await get_tree().create_timer(0.4).timeout
	if not is_alive: return
	
	_anim_release(AnimPriority.ACTION)
	is_attacking = false
	_anim_play(animated_sprite, "idle", AnimPriority.FREE)

	await get_tree().create_timer(attack_cooldown).timeout
	if is_alive: can_attack = true

func _on_element_applied() -> void:
	_setup_elemental_vfx_aura()

func _on_reaction_triggered(_reaction_name: String, _data: Dictionary) -> void:
	_setup_elemental_vfx_aura()

func limpiar_elemento() -> void:
	super.limpiar_elemento()
	_setup_elemental_vfx_aura()

func _check_hit() -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance <= attack_range + 15:
		if player.has_method("take_elemental_hit"):
			player.take_elemental_hit(attack_damage, base_element)

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Combat/squelching_2.wav", 5.0, 0.8)

	if _anim_play(animated_sprite, "death", AnimPriority.LOCKED):
		await animated_sprite.animation_finished
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
