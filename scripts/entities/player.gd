extends BaseCharacter
class_name Player

@export var speed: float = 135.0
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var attack_lock_time: float = 0.1

@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _camera_node: Camera2D
var _is_interacting: bool = false
var _can_attack: bool = true
var _is_hurt: bool = false

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

var is_attacking: bool = false
var last_direction: Vector2 = Vector2.RIGHT
var interactables_in_range: Array[Node2D] = []

func _ready() -> void:
	_apply_class_stats()
	add_to_group("player")
	super._ready()
	
	_camera_node = Camera2D.new()
	_camera_node.zoom = Vector2(2.0, 2.0)
	_camera_node.position_smoothing_enabled = true
	_camera_node.position_smoothing_speed = 12.0
	_camera_node.drag_horizontal_enabled = true
	_camera_node.drag_vertical_enabled = true
	add_child(_camera_node)
	
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 5

	if animated_sprite:
		animated_sprite.scale = Vector2(1, 1)
		animated_sprite.offset = sprite_offset
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)

func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		last_direction = direction
		if direction.x != 0:
			animated_sprite.flip_h = direction.x < 0
		
		if not is_attacking and not _is_hurt:
			_play_animation("Run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta * 30)
		if not is_attacking and not _is_hurt:
			_play_animation("Idle")

	move_and_slide()

	if Input.is_action_just_pressed("attack_1"):
		attack()
	elif Input.is_action_just_pressed("attack_2"):
		special_attack()
	elif Input.is_action_just_pressed("interact"):
		interact()
	elif Input.is_action_just_pressed("use_health_potion"):
		use_health_potion()
	elif Input.is_action_just_pressed("use_mana_potion"):
		use_mana_potion()

func attack() -> void:
	if not _can_attack: return
	_can_attack = false
	is_attacking = true
	_play_animation("Attack", AnimPriority.ACTION)
	
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Weapons/sword_slice.wav", 2.0, randf_range(0.9, 1.1))
	
	_check_hit(25, 50.0)
	
	var t = get_tree()
	if t:
		await t.create_timer(attack_lock_time).timeout
		_can_attack = true

func special_attack() -> void:
	if not _can_attack: return
	_can_attack = false
	is_attacking = true
	_play_animation("attack2", AnimPriority.ACTION)
	
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_sfx("res://assets/audio/sfx/Weapons/sword_clash.wav", 5.0, 0.8)
	
	_check_hit(45, 80.0)
	
	var t = get_tree()
	if t:
		await t.create_timer(attack_lock_time * 2.0).timeout
		_can_attack = true

func use_health_potion() -> void:
	if current_health >= max_health:
		mostrar_texto_flotante("HP FULL", Color.ORANGE)
		return
	if GameManager.use_health_potion():
		recover_health(30)
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_sfx("res://assets/audio/sfx/Items/heart_collect.wav")
		mostrar_texto_flotante("+30 HP", Color.GREEN)

func use_mana_potion() -> void:
	if current_mana >= max_mana:
		mostrar_texto_flotante("MP FULL", Color.SKY_BLUE)
		return
	if GameManager.use_mana_potion():
		recover_mana(20)
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play_sfx("res://assets/audio/sfx/Environment/fire_lighting.wav")
		mostrar_texto_flotante("+20 MP", Color.BLUE)

func receive_damage(amount: int) -> void:
	if amount > 0:
		_spawn_blood_vfx()
		_play_hurt_anim()
		var am = get_node_or_null("/root/AudioManager")
		if am: 
			am.play_sfx("res://assets/audio/sfx/Combat and Gore/squelching_1.wav", 2.0)
			am.play_sfx("res://assets/audio/sfx/Retro/hurt.wav", 5.0, randf_range(0.9, 1.1))
	super.receive_damage(amount)



func _play_hurt_anim() -> void:
	if not animated_sprite or is_attacking or _is_hurt: return
	for anim in ["hurt", "hit", "Hurt", "Hit"]:
		if animated_sprite.sprite_frames.has_animation(anim):
			_is_hurt = true
			_anim_play(animated_sprite, anim, AnimPriority.ACTION)
			var t = get_tree()
			if t: await t.create_timer(0.15).timeout
			_anim_release(AnimPriority.ACTION)
			_is_hurt = false
			return

func _spawn_blood_vfx() -> void:
	var path := "res://scenes/vfx/vfx_blood_hit.tscn"
	if not ResourceLoader.exists(path): return
	var scene = load(path)
	var vfx = scene.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position
	if vfx.has_method("setup"):
		vfx.setup(global_position - last_direction * 15)

func interact() -> void:
	if _is_interacting or interactables_in_range.is_empty(): return
	_is_interacting = true
	
	var closest = null
	var min_dist = 99999.0
	
	for item in interactables_in_range:
		if not is_instance_valid(item): continue
		if item == self or is_ancestor_of(item) or item.is_in_group("player"): continue
		
		var d = global_position.distance_to(item.global_position)
		if d < min_dist:
			min_dist = d
			closest = item
	
	if closest:
		if closest.has_method("interact"):
			closest.interact(self)
		elif closest.get_parent() and closest.get_parent() != self and closest.get_parent().has_method("interact"):
			closest.get_parent().interact(self)
			
	_is_interacting = false

func _play_animation(anim_name: String, priority: AnimPriority = AnimPriority.FREE) -> void:
	if not animated_sprite: return
	var sf = animated_sprite.sprite_frames
	if not sf: return
	
	var final_anim = ""
	for c in [anim_name, anim_name.to_lower(), anim_name.capitalize()]:
		if sf.has_animation(c):
			final_anim = c
			break
			
	if final_anim == "":
		match anim_name:
			"Walk", "Run":
				for fallback in ["Walk", "Run", "Walk_Right", "Run_Right", "Idle", "idle"]:
					if sf.has_animation(fallback):
						final_anim = fallback
						break
			_:
				return
				
	if final_anim != "":
		_anim_play(animated_sprite, final_anim, priority)

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		_anim_release(AnimPriority.ACTION)

func _check_hit(damage: int, range_px: float) -> void:
	var t = get_tree()
	if not t: return
	await t.create_timer(0.06).timeout
	if not is_inside_tree(): return
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = range_px
	query.shape = circle
	query.transform = Transform2D(0, global_position + last_direction * 35)
	query.collision_mask = 4
	var results = space_state.intersect_shape(query)
	for res in results:
		var body = res["collider"]
		if body.has_method("receive_damage") and body != self:
			body.receive_damage(damage)

func _apply_class_stats() -> void:
	pass

func _on_element_applied() -> void:
	actualizar_icono_elemento()
	element_timer.start(3.0)

func _on_reaction_triggered(_name: String, _data: Dictionary) -> void:
	pass

func _on_element_refreshed() -> void:
	element_timer.start(3.0)

func actualizar_icono_elemento() -> void:
	if element_icon:
		element_icon.visible = true

func limpiar_elemento() -> void:
	super.limpiar_elemento()
	if element_icon:
		element_icon.visible = false
	if element_timer:
		element_timer.stop()

func _on_element_timer_timeout() -> void:
	limpiar_elemento()

func die() -> void:
	if not is_alive: return
	super.die()
	velocity = Vector2.ZERO
	limpiar_elemento()
	GameManager.reset_progress()
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if animated_sprite:
		_anim_play(animated_sprite, "Death", AnimPriority.LOCKED)
		var t = get_tree()
		if t: await t.create_timer(1.5).timeout
	
	if not is_inside_tree(): return
	var tree_final = get_tree()
	if tree_final:
		if SceneManager:
			SceneManager.load_scene(tree_final.current_scene.scene_file_path)
		else:
			tree_final.reload_current_scene()

func _on_interactable_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if body == self or is_ancestor_of(body): return
	
	if body.has_method("_collect"):
		body._collect(self)
		return
	if body.get_parent() and body.get_parent().has_method("_collect"):
		body.get_parent()._collect(self)
		return
		
	if body.is_in_group("interactable") or (body.get_parent() and body.get_parent().is_in_group("interactable")) or body.has_method("interact") or (body.get_parent() and body.get_parent().has_method("interact")):
		if not interactables_in_range.has(body):
			interactables_in_range.append(body)
			_update_interaction_prompt()

func _on_interactable_exited(body: Node2D) -> void:
	interactables_in_range.erase(body)
	_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_interaction_prompt"): return
	var valid_interactables = []
	for item in interactables_in_range:
		if not is_instance_valid(item): continue
		var target = item
		if not target.has_method("interact") and target.get_parent() and target.get_parent().has_method("interact"):
			target = target.get_parent()
		var already_used = false
		if "is_open" in target and target.is_open: already_used = true
		if "is_opened" in target and target.is_opened: already_used = true
		if not already_used:
			valid_interactables.append(item)
	hud.show_interaction_prompt(not valid_interactables.is_empty())
