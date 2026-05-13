extends CharacterBody2D
class_name BaseCharacter

enum AnimPriority { FREE = 0, ACTION = 1, LOCKED = 2 }
var _anim_priority: AnimPriority = AnimPriority.FREE

@export var character_name: String = "Character"
@export var level: int = 1
@export var max_health: int = 100
@export var max_mana: int = 50
@export var strength: int = 10
@export var intelligence: int = 10
@export var resistance: int = 10
@export var wisdom: int = 10

var base_scale: Vector2 = Vector2(1.0, 1.0)

signal health_changed(current, max)
signal mana_changed(current, max)

var current_health: int:
	set(value):
		current_health = value
		health_changed.emit(current_health, max_health)
var current_mana: int:
	set(value):
		current_mana = value
		mana_changed.emit(current_mana, max_mana)

var is_alive: bool = true

@export var base_element: ElementalSystem.Element = ElementalSystem.Element.NONE
var current_imbued_element: ElementalSystem.Element = ElementalSystem.Element.NONE

func _ready() -> void:
	current_health = max_health
	current_mana = max_mana
	current_imbued_element = base_element
	add_to_group("base_character")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

var _step_timer: float = 0.0

func receive_damage(amount: int) -> void:
	var final_amount = clampi(amount - resistance, 1, amount)
	current_health = clampi(current_health - final_amount, 0, max_health)
	print(character_name, ": Recibe ", final_amount, " de daño. Salud -> ", current_health, "/", max_health)
	if current_health <= 0:
		die()

func _physics_process(delta: float) -> void:
	if is_alive and velocity.length() > 20:
		_step_timer += delta
		if _step_timer >= 0.35:
			_step_timer = 0.0
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Movement/gravel_1.wav", -15.0, randf_range(0.8, 1.2))

func die() -> void:
	if not is_alive: return
	is_alive = false
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Combat/squelching_3.wav", 8.0)

func recover_health(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)

func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

func recover_mana(amount: int) -> void:
	current_mana = clampi(current_mana + amount, 0, max_mana)

func take_elemental_hit(damage: int, element: ElementalSystem.Element) -> void:
	var final_damage = damage
	var reaction_name = ""

	if element != ElementalSystem.Element.NONE:
		if current_imbued_element != ElementalSystem.Element.NONE:
			var reaction_info = ElementalSystem.get_reaction(current_imbued_element, element)
			reaction_name = reaction_info["name"]
			if reaction_name != "None":
				var multiplier = reaction_info["data"].get("multiplier", 1.5)
				final_damage = int(damage * multiplier)
				_on_reaction_triggered(reaction_name, reaction_info["data"])
				mostrar_texto_flotante(reaction_name, reaction_info["data"]["color"])
				limpiar_elemento()
			else:
				if current_imbued_element == element:
					_on_element_refreshed()
		else:
			current_imbued_element = element
			_on_element_applied()

	receive_damage(final_damage)

	if reaction_name != "" and reaction_name != "None":
		print("[REACCIÓN: ", reaction_name, "] Daño total: ", final_damage, " (Base: ", damage, ")")

func aplicar_elemento(nuevo_elemento: ElementalSystem.Element) -> void:
	take_elemental_hit(0, nuevo_elemento)
	take_elemental_hit(0, nuevo_elemento)

func procesar_reaccion(_segundo_elemento: ElementalSystem.Element) -> void:
	pass

func _on_element_applied() -> void:
	pass

func _on_reaction_triggered(_name: String, _data: Dictionary) -> void:
	pass

func _on_element_refreshed() -> void:
	pass

func limpiar_elemento() -> void:
	current_imbued_element = ElementalSystem.Element.NONE

func mostrar_texto_flotante(texto: String, color: Color) -> void:
	var ft_scene = load("res://scenes/ui/floating_text.tscn")
	if ft_scene:
		var ft: Node2D = ft_scene.instantiate()
		get_parent().add_child(ft)
		ft.global_position = global_position + Vector2(0, -30)
		if ft.has_method("set_text"):
			ft.set_text(texto, color)

func _anim_play(sprite: AnimatedSprite2D, anim: String, priority: AnimPriority = AnimPriority.FREE) -> bool:
	if priority < _anim_priority:
		return false
	if not sprite or not sprite.sprite_frames:
		return false
	if not sprite.sprite_frames.has_animation(anim):
		return false
	_anim_priority = priority
	if sprite.animation != anim or priority >= AnimPriority.ACTION:
		sprite.play(anim)
	return true

func _anim_release(priority: AnimPriority = AnimPriority.ACTION) -> void:
	if _anim_priority <= priority:
		_anim_priority = AnimPriority.FREE

func _process(_delta: float) -> void:
	if GameManager.debug_mode:
		queue_redraw()

func _draw() -> void:
	if not GameManager.debug_mode: return

	for child in get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape is CapsuleShape2D:
				var h = shape.height / 2.0 - shape.radius
				draw_arc(child.position + Vector2(0, -h), shape.radius, PI, TAU, 16, Color.GREEN, 1.0)
				draw_arc(child.position + Vector2(0, h), shape.radius, 0, PI, 16, Color.GREEN, 1.0)
				draw_line(child.position + Vector2(-shape.radius, -h), child.position + Vector2(-shape.radius, h), Color.GREEN, 1.0)
				draw_line(child.position + Vector2(shape.radius, -h), child.position + Vector2(shape.radius, h), Color.GREEN, 1.0)
			elif shape is RectangleShape2D:
				draw_rect(Rect2(child.position - shape.size/2, shape.size), Color.GREEN, false, 1.0)
			elif shape is CircleShape2D:
				draw_arc(child.position, shape.radius, 0, TAU, 32, Color.GREEN, 1.0)

	var interaction_area = get_node_or_null("InteractionArea")
	if interaction_area:
		for child in interaction_area.get_children():
			if child is CollisionShape2D:
				var shape = child.shape
				if shape is CircleShape2D:
					draw_arc(child.position + interaction_area.position, shape.radius, 0, TAU, 32, Color.RED, 0.5)
