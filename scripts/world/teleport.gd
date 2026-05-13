extends StaticBody2D
class_name Teleport

@export var target_marker: Marker2D

func interact(body: Node2D) -> void:
	if body is Player and target_marker:
		body.global_position = target_marker.global_position
