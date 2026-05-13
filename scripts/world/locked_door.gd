extends StaticBody2D

@export_enum("Normal", "Silver", "Gold") var key_type: String = "Normal"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea

var is_open: bool = false

func _ready() -> void:
	if interaction_area:
		interaction_area.add_to_group("interactable")

func interact(_player: Player) -> void:
	if is_open: return

	var has_key = false
	match key_type:
		"Normal":
			if GameManager.total_keys > 0:
				GameManager.total_keys -= 1
				has_key = true
		"Silver":
			if GameManager.silver_keys > 0:
				GameManager.silver_keys -= 1
				has_key = true
		"Gold":
			if GameManager.golden_keys > 0:
				GameManager.golden_keys -= 1
				has_key = true

	if has_key:
		open_door()
	else:
		print("Se requiere una llave ", key_type)

func open_door() -> void:
	is_open = true
	if sprite:
		sprite.play("open")
		await sprite.animation_finished
	collision.disabled = true
	if interaction_area:
		interaction_area.monitoring = false
