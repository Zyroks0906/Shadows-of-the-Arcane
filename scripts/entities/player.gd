extends BaseCharacter
class_name Player

@export var speed: float = 200.0
@export var sprite_offset: Vector2 = Vector2.ZERO


@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

var is_attacking: bool = false
var last_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	get_tree().debug_collisions_hint = true
	
	if animated_sprite:
		animated_sprite.offset = sprite_offset
		animated_sprite.scale = base_scale
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)
	
	if element_icon:
		element_icon.visible = false

func _on_animation_finished() -> void:
	if animated_sprite.animation == "Attack":
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
		
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		last_direction = direction
		
	velocity = direction * speed
	move_and_slide()


func _update_animations() -> void:
	if not animated_sprite: return
	
	if is_attacking:
		return
	
	if Input.is_action_just_pressed("ui_accept"):
		is_attacking = true
		play_animation("Attack")
		attack()
		return



	if velocity.length() > 0:
		play_animation("Walk")
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
	else:
		play_animation("Idle")

func attack() -> void:
	var hitbox = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()

	shape.size = Vector2(30, 30)
	collision.shape = shape
	hitbox.add_child(collision)
	
	add_child(hitbox)
	hitbox.position = last_direction.normalized() * 20
	
	await get_tree().physics_frame
	
	var bodies = hitbox.get_overlapping_bodies()

	for body in bodies:
		if body.is_in_group("enemies") and body != self:
			if body.has_method("take_elemental_hit"):
				body.take_elemental_hit(strength, base_element)
				print("Jugador golpea a ", body.name, " con daño ", strength)
	
	hitbox.queue_free()


func play_animation(anim_name: String) -> void:
	if not animated_sprite: return
	
	var final_anim = anim_name
	if anim_name == "Walk" and animated_sprite.sprite_frames and not animated_sprite.sprite_frames.has_animation("Walk"):
		if animated_sprite.sprite_frames.has_animation("Run"):
			final_anim = "Run"
	
	if animated_sprite.animation != final_anim:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(final_anim):
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
		pass

func limpiar_elemento() -> void:
	current_imbued_element = ElementalSystem.Element.NONE
	if element_icon:
		element_icon.visible = false
	if element_timer:
		element_timer.stop()

func _on_element_timer_timeout() -> void:
	limpiar_elemento()

func die() -> void:
	is_alive = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
		await animated_sprite.animation_finished
	queue_free()

func take_elemental_hit(damage: int, element: ElementalSystem.Element) -> void:
	receive_damage(damage)
	aplicar_elemento(element)
