extends Area2D

@export var door_path: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var door = get_node_or_null(door_path)
		if door and door.has_method("close_door"):
			door.close_door()
			queue_free()
