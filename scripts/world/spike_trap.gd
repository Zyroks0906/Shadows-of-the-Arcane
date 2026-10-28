extends Area2D
class_name SpikeTrap

@export var damage_percent: float = 0.3
@export var activation_delay: float = 0.5
@export var active_duration: float = 2.5
@export var reset_delay: float = 0.8
@export var animation_speed: float = 6.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = Timer.new()

var is_active: bool = false
var has_hit_this_cycle: bool = false
var _hit_this_cycle: Array = [] # monsters already pierced this cycle

func _ready() -> void:
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	body_entered.connect(_on_body_entered)
	collision_mask |= 4 # monsters walk into spikes too
	if sprite:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.speed_scale = animation_speed
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
	_hit_this_cycle.clear()
	if sprite:
		sprite.play("default")
	for body in get_overlapping_bodies():
		_check_damage(body)
	timer.start(active_duration)

func _on_sprite_frame_changed() -> void:
	if is_active and sprite and (sprite.frame == 2 or sprite.frame == 3):
		for body in get_overlapping_bodies():
			_check_damage(body)

func _on_body_entered(body: Node2D) -> void:
	_check_damage(body)

func _check_damage(body: Node) -> void:
	# Monsters get pierced by the same share of their health as the hero (bosses stride
	# over them).
	if body is Enemy and not (body is BossBase):
		if is_active and body.is_alive and not body in _hit_this_cycle and sprite and (sprite.frame == 2 or sprite.frame == 3):
			_hit_this_cycle.append(body)
			body.receive_damage(int(body.max_health * damage_percent))
		return
	if not is_active or has_hit_this_cycle or not body.is_in_group("player"):
		return
	if body.get("current_health") <= 0 or body.get("is_alive") == false:
		return
	if sprite and (sprite.frame == 2 or sprite.frame == 3):
		if body.has_method("receive_damage"):
			has_hit_this_cycle = true
			var damage = int(body.max_health * damage_percent)
			body.receive_damage(damage)
