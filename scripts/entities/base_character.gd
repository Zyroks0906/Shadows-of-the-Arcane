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

# Knockback impulse added on top of normal movement; decays every physics frame.
@export var knockback_scale: float = 1.0
var knockback: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION := 900.0

# Set by environment zones: shallow water slows, wind currents push.
var terrain_speed_mult: float = 1.0
var external_push: Vector2 = Vector2.ZERO

# Colour of the next damage number; reset after every hit.
var next_hit_color: Color = Color.WHITE
var _next_hit_big: bool = false
var _resistance_shredded: bool = false

@export var base_element: ElementalSystem.Element = ElementalSystem.Element.NONE
var current_imbued_element: ElementalSystem.Element = ElementalSystem.Element.NONE

# Height above the floor for the ground shadow (flyers set it in _init_stats).
var shadow_hover: float = 0.0

func _ready() -> void:
	current_health = max_health
	current_mana = max_mana
	current_imbued_element = base_element
	add_to_group("base_character")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Deferred: subclasses scale their sprite in their own _ready.
	(func(): if is_inside_tree(): GroundShadow.attach(self, shadow_hover)).call_deferred()

var _step_timer: float = 0.0

func receive_damage(amount: int) -> void:
	var final_amount = _mitigate(amount)
	current_health = clampi(current_health - final_amount, 0, max_health)
	CombatFX.damage_number(global_position, final_amount, next_hit_color, _next_hit_big)
	next_hit_color = _default_hit_color()
	_next_hit_big = false
	if current_health <= 0:
		die()

func _mitigate(amount: int) -> int:
	return clampi(amount - resistance, 1, maxi(amount, 1))

func _default_hit_color() -> Color:
	return Color.WHITE

func apply_knockback(impulse: Vector2) -> void:
	knockback += impulse * knockback_scale

# Returns true while a knockback is still moving the character this frame.
func _process_knockback(delta: float) -> bool:
	if knockback.length() < 10.0:
		knockback = Vector2.ZERO
		return false
	velocity = knockback
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	move_and_slide()
	return true

func apply_resistance_shred(ratio: float, duration: float) -> void:
	if _resistance_shredded or not is_inside_tree():
		return
	_resistance_shredded = true
	var lost := int(ceil(resistance * ratio))
	resistance -= lost
	get_tree().create_timer(duration).timeout.connect(_restore_resistance.bind(lost))

func _restore_resistance(lost: int) -> void:
	resistance += lost
	_resistance_shredded = false

func _physics_process(delta: float) -> void:
	if is_alive and velocity.length() > 20 and is_in_group("player"):
		_step_timer += delta
		if _step_timer >= 0.34:
			_step_timer = 0.0
			if _in_water():
				# Wading: a splash instead of a step, and a ring of ripples at the feet.
				AudioManager.play_sfx("res://assets/audio/sfx/water/splash_%d.wav" % (randi() % 3), -9.0, randf_range(0.9, 1.15))
				CombatFX.shockwave(global_position + Vector2(0, 2), Color(0.7, 0.9, 1.0, 0.7), 9.0, 0.45, 1.0)
			else:
				AudioManager.play_bank("footstep", -20.0, 1.0, 0.1)

func _in_water() -> bool:
	for z in get_meta("zones", []):
		if is_instance_valid(z) and z is ElementZone and z.style == ElementZone.Style.WATER:
			return true
	return false

func die() -> void:
	if not is_alive: return
	is_alive = false

func recover_health(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)

func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

func recover_mana(amount: int) -> void:
	current_mana = clampi(current_mana + amount, 0, max_mana)

func take_elemental_hit(damage: int, element: ElementalSystem.Element, source: Node = null) -> void:
	if not is_alive:
		return
	var final_damage = damage
	next_hit_color = _default_hit_color() if element == ElementalSystem.Element.NONE else ElementalSystem.get_element_color(element).lightened(0.3)

	if element != ElementalSystem.Element.NONE:
		if current_imbued_element != ElementalSystem.Element.NONE:
			var reaction_info = ElementalSystem.get_reaction(current_imbued_element, element)
			var reaction_name: String = reaction_info["name"]
			if reaction_name != "None":
				var multiplier = reaction_info["data"].get("multiplier", 1.5)
				final_damage = int(damage * multiplier * _reaction_bonus(source))
				next_hit_color = reaction_info["data"]["color"]
				_next_hit_big = true
				var aura := current_imbued_element
				limpiar_elemento()
				_on_reaction_triggered(reaction_name, reaction_info["data"])
				Reactions.trigger(self, reaction_name, aura, element, damage, source)
			elif current_imbued_element == element:
				_on_element_refreshed()
		else:
			current_imbued_element = element
			_on_element_applied()

	if final_damage > 0:
		receive_damage(final_damage)

# Intelligence works like elemental mastery: +1% reaction damage per point.
func _reaction_bonus(source: Node) -> float:
	if source is BaseCharacter:
		return 1.0 + (source as BaseCharacter).intelligence / 100.0
	return 1.0

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
