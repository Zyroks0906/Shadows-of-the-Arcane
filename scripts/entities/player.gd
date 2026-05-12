extends BaseCharacter
class_name Player

@export var speed: float = 100.0
@export var sprite_offset: Vector2 = Vector2.ZERO

@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

var is_attacking: bool = false
var last_direction: Vector2 = Vector2.RIGHT
var interactables_in_range: Array[Node2D] = []

func _on_interactable_entered(body: Node2D) -> void:
	if body.has_method("_collect"):
		body._collect(self)
		return
	if body.get_parent().has_method("_collect"):
		body.get_parent()._collect(self)
		return
		
	if body.is_in_group("interactable") or body.get_parent().is_in_group("interactable") or body.has_method("interact") or body.get_parent().has_method("interact"):
		if not interactables_in_range.has(body):
			interactables_in_range.append(body)
			_update_interaction_prompt()

func _on_interactable_exited(body: Node2D) -> void:
	interactables_in_range.erase(body)
	_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_interaction_prompt"):
		hud.show_interaction_prompt(not interactables_in_range.is_empty())

func _ready() -> void:
	add_to_group("player")
	super._ready()
	
	if animated_sprite:
		animated_sprite.scale = Vector2(1, 1)
		animated_sprite.offset = sprite_offset
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)
	
	if element_icon:
		element_icon.visible = false

func _on_animation_finished() -> void:
	if animated_sprite.animation.begins_with("Attack"):
		is_attacking = false

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	
	_handle_movement()
	_update_animations()

func _handle_movement() -> void:
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		last_direction = direction
		
	velocity = direction * speed
	move_and_slide()

func _perform_attack(anim_name: String) -> void:
	if is_attacking: return
	
	is_attacking = true
	if animated_sprite:
		var final_anim = anim_name
		if not animated_sprite.sprite_frames.has_animation(final_anim):
			if final_anim == "Attack2":
				final_anim = "Attack1"
			if not animated_sprite.sprite_frames.has_animation(final_anim):
				final_anim = "Attack"
		
		if animated_sprite.sprite_frames.has_animation(final_anim):
			animated_sprite.stop()
			animated_sprite.play(final_anim)
			
	attack()
	
	await get_tree().create_timer(0.8).timeout
	is_attacking = false

func _update_animations() -> void:
	if not animated_sprite: return
	
	if is_attacking:
		return
	
	if Input.is_action_just_pressed("attack_1"):
		_perform_attack("Attack1")
		return

	if Input.is_action_just_pressed("attack_2"):
		_perform_attack("Attack2")
		return

	if Input.is_action_just_pressed("interact"):
		_handle_interaction()
		return

	if Input.is_action_just_pressed("use_health_potion"):
		if GameManager.use_health_potion():
			receive_damage(-20)

	if Input.is_action_just_pressed("use_mana_potion"):
		if GameManager.use_mana_potion():
			pass

	if velocity.length() > 0:
		play_animation("Walk")
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
	else:
		play_animation("Idle")

func _handle_interaction() -> void:
	if interactables_in_range.is_empty():
		return
		
	var closest = interactables_in_range[0]
	var min_dist = global_position.distance_to(closest.global_position)
	
	for item in interactables_in_range:
		var dist = global_position.distance_to(item.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = item
			
	if closest.has_method("interact"):
		closest.interact(self)
	elif closest.get_parent().has_method("interact"):
		closest.get_parent().interact(self)

func attack() -> void:
	if not is_inside_tree(): return
	
	var hitbox = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(30, 30)
	collision.shape = shape
	hitbox.add_child(collision)
	add_child(hitbox)
	hitbox.position = last_direction.normalized() * 20
	
	await get_tree().physics_frame
	
	if is_instance_valid(hitbox):
		var bodies = hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemies") and body != self:
				if body.has_method("take_elemental_hit"):
					body.take_elemental_hit(strength, base_element)
		hitbox.queue_free()

func play_animation(anim_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames: return
	
	var final_anim = anim_name
	
	if anim_name == "Walk" and not animated_sprite.sprite_frames.has_animation("Walk"):
		if animated_sprite.sprite_frames.has_animation("Run"):
			final_anim = "Run"
	
	if animated_sprite.animation != final_anim:
		if animated_sprite.sprite_frames.has_animation(final_anim):
			animated_sprite.play(final_anim)

func aplicar_elemento(nuevo_elemento: ElementalSystem.Element) -> void:
	if nuevo_elemento == ElementalSystem.Element.NONE:
		return
	
	if current_imbued_element == ElementalSystem.Element.NONE:
		current_imbued_element = nuevo_elemento
		actualizar_icono_elemento()
		element_timer.start(3.0)
	else:
		procesar_reaccion(nuevo_elemento)

func procesar_reaccion(segundo_elemento: ElementalSystem.Element) -> void:
	var reaction_info: Dictionary = ElementalSystem.get_reaction(current_imbued_element, segundo_elemento)
	var reaction_name: String = reaction_info["name"]
	var data: Dictionary = reaction_info["data"]
	
	if reaction_name != "None":
		mostrar_texto_flotante(reaction_name, data["color"])
		limpiar_elemento()
	else:
		if current_imbued_element == segundo_elemento:
			element_timer.start(3.0)

func mostrar_texto_flotante(texto: String, color: Color) -> void:
	if FLOATING_TEXT_SCENE:
		var ft: Node2D = FLOATING_TEXT_SCENE.instantiate()
		get_parent().add_child(ft)
		ft.global_position = global_position + Vector2(0, -50)
		if ft.has_method("set_text"):
			ft.set_text(texto, color)

func actualizar_icono_elemento() -> void:
	if element_icon:
		element_icon.visible = true

func limpiar_elemento() -> void:
	current_imbued_element = ElementalSystem.Element.NONE
	if element_icon:
		element_icon.visible = false
	if element_timer:
		element_timer.stop()

func _on_element_timer_timeout() -> void:
	limpiar_elemento()

func die() -> void:
	if not is_alive: return
	is_alive = false
	
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
		await get_tree().create_timer(1.5).timeout
	
	if SceneManager:
		SceneManager.load_scene(get_tree().current_scene.scene_file_path)
	else:
		get_tree().reload_current_scene()

func take_elemental_hit(damage: int, element: ElementalSystem.Element) -> void:
	receive_damage(damage)
	aplicar_elemento(element)
