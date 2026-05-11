extends Area2D
class_name Teleport

@export var target_marker: Marker2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and target_marker:
		body.global_position = target_marker.global_position
