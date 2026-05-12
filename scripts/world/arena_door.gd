extends StaticBody2D

@export var boss_to_track: String = "Demon"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_closed: bool = false

func _ready() -> void:
	visible = false
	collision.disabled = true
	GameManager.boss_defeated.connect(_on_boss_defeated)

func close_door() -> void:
	if is_closed: return
	is_closed = true
	visible = true
	collision.disabled = false
	if sprite: sprite.play("close")

func _on_boss_defeated(boss_name: String) -> void:
	if boss_name == boss_to_track:
		open_door()

func open_door() -> void:
	is_closed = false
	if sprite:
		sprite.play("open")
		await sprite.animation_finished
	visible = false
	collision.disabled = true
