extends Node2D

@onready var label: Label = $Label

func set_text(text: String, color: Color) -> void:
	scale = Vector2(0.25, 0.25)
	if label:
		label.text = text
		label.modulate = color

	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -40), 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
