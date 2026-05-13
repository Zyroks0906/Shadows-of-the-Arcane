extends Node2D

@export var fire_rate: float = 2.0
@export var initial_delay: float = 0.0

@onready var spawn_point: Marker2D = $ArrowSpawnPoint
var arrow_scene: PackedScene = preload("res://scenes/world/trap_arrow.tscn")
var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = fire_rate
	timer.autostart = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	if initial_delay > 0:
		await get_tree().create_timer(initial_delay).timeout
	timer.start()

func _on_timer_timeout() -> void:
	_fire_arrow()

func _fire_arrow() -> void:
	if not arrow_scene:
		return
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = spawn_point.global_position
	arrow.direction = -global_transform.x.normalized()
