extends Area2D
class_name KeyItem

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameManager.add_keys(1)
		queue_free()
