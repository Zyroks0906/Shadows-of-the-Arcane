extends BaseCharacter
class_name Enemy

@export var speed: float = 40.0
@export var detection_range: float = 150.0
@export var attack_range: float = 25.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 2.0
@export var attack_delay: float = 0.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Player = null
var can_attack: bool = true
var is_attacking: bool = false
var shader_material: ShaderMaterial = null

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	
	player = get_tree().get_first_node_in_group("player")
	_setup_elemental_shader()

func _setup_elemental_shader() -> void:
	if not animated_sprite: return
	
	var shader = load("res://assets/shaders/elemental_tint.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		animated_sprite.material = shader_material
		
		var color = ElementalSystem.get_element_color(base_element)
		var secondary_color = ElementalSystem.get_element_secondary_color(base_element)
		shader_material.set_shader_parameter("tint_color", color)
		shader_material.set_shader_parameter("secondary_tint_color", secondary_color)
		shader_material.set_shader_parameter("tint_intensity", 0.7 if base_element != ElementalSystem.Element.NONE else 0.0)

func _physics_process(_delta: float) -> void:
	if not is_alive or is_attacking:
		return
		
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance = global_position.distance_to(player.global_position)
	
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			_perform_attack()
		else:
			_play_animation("idle")
	elif distance <= detection_range:
		var direction = (player.global_position - global_position).normalized()
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
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _perform_attack() -> void:
	is_attacking = true
	can_attack = false
	
	_play_animation("attack")
	
	var tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_delay).timeout
	
	if is_alive and is_instance_valid(player):
		_check_hit()
		
	tree = get_tree()
	if not tree: return
	await tree.create_timer(0.4).timeout
	is_attacking = false
	_play_animation("idle")
	
	tree = get_tree()
	if not tree: return
	await tree.create_timer(attack_cooldown).timeout
	can_attack = true

func _on_reaction_triggered(_reaction_name: String, _data: Dictionary) -> void:
	pass

func _check_hit() -> void:
	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range + 15:
		if player.has_method("take_elemental_hit"):
			player.take_elemental_hit(attack_damage, base_element)

func die() -> void:
	if not is_alive: return
	is_alive = false
	velocity = Vector2.ZERO
	
	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	
	queue_free()
