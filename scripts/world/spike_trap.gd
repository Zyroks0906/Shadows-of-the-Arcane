extends Area2D
class_name SpikeTrap

@export var damage_percent: float = 0.5
@export var activation_delay: float = 1.0
@export var active_duration: float = 1.5
@export var reset_delay: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = Timer.new()

var is_active: bool = false
var has_hit_this_cycle: bool = false

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	body_entered.connect(_on_body_entered)
	
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.speed_scale = 4.0 
	
	
	_start_deactive_phase()

func _start_deactive_phase() -> void:
	is_active = false
	if sprite:
		sprite.frame = 0
		sprite.stop()
	timer.start(reset_delay)

func _on_timer_timeout() -> void:
	if not is_active:
		_activate_trap()
	else:
		_start_deactive_phase()

func _activate_trap() -> void:
	
	await get_tree().create_timer(activation_delay).timeout
	
	is_active = true
	has_hit_this_cycle = false
	if sprite:
		sprite.play("default")
	
	
	for body in get_overlapping_bodies():
		_check_damage(body)
		
	timer.start(active_duration)

func _on_sprite_frame_changed() -> void:
	
	if is_active and sprite and (sprite.frame == 0 or sprite.frame == 1):
		for body in get_overlapping_bodies():
			_check_damage(body)

func _on_body_entered(body: Node2D) -> void:
	_check_damage(body)

func _check_damage(body: Node) -> void:
	if not is_active or has_hit_this_cycle or not (body is Player):
		return
	
	
	if body.get("current_health") <= 0 or body.get("is_alive") == false:
		return
		
	
	if sprite and (sprite.frame == 0 or sprite.frame == 1):
		if body.has_method("receive_damage"):
			has_hit_this_cycle = true
			var damage = int(body.max_health * damage_percent)
			body.receive_damage(damage)
			print("Trampa de pinchos golpea a ", body.name, " en frame ", sprite.frame)
