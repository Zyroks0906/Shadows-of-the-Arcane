extends StaticBody2D
class_name Door

@export var is_open: bool = false
@export var require_key: bool = false

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if is_open:
		open()
	else:
		close()

func open() -> void:
	if require_key and GameManager.total_keys <= 0:
		return
	
	if require_key:
		GameManager.total_keys -= 1
		
	is_open = true
	collision.disabled = true
	sprite.visible = false

func close() -> void:
	is_open = false
	collision.disabled = false
	sprite.visible = true

func toggle() -> void:
	if is_open:
		close()
	else:
		open()
