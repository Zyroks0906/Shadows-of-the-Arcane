extends Node2D

@export var item_inside: Node2D
@export var open_animation: String = "Open"

var is_open: bool = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if item_inside:
		item_inside.visible = false
		item_inside.process_mode = Node.PROCESS_MODE_DISABLED
	
	var detection_area = find_child("*", true, false)
	for child in get_children():
		if child is Area2D:
			child.body_entered.connect(_on_body_entered)
			break

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_open:
		open_chest()

func open_chest() -> void:
	is_open = true
	if animated_sprite and animated_sprite.sprite_frames.has_animation(open_animation):
		animated_sprite.play(open_animation)
	
	await get_tree().create_timer(0.3).timeout
	
	if item_inside:
		item_inside.visible = true
		item_inside.process_mode = Node.PROCESS_MODE_INHERIT
		var tween = create_tween()
		var target_pos = item_inside.position + Vector2(0, -15)
		tween.tween_property(item_inside, "position", target_pos, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
