extends BaseCharacter
class_name Player

@export var speed: float = 200.0

@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

func _ready() -> void:
	super._ready()
	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)
	
	if element_icon:
		element_icon.visible = false

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	
	_handle_movement()
	_update_animations()

func _handle_movement() -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

func _update_animations() -> void:
	if not animated_sprite: return
	
	if animated_sprite.animation == "Attack" and animated_sprite.is_playing():
		return
	
	if Input.is_action_just_pressed("ui_accept"):
		play_animation("Attack")
		return

	if velocity.length() > 0:
		play_animation("Walk")
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
	else:
		play_animation("Idle")

func play_animation(anim_name: String) -> void:
	if not animated_sprite: return
	
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
