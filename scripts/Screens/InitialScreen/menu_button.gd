extends Area2D

@onready var sprite = get_parent() 

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _on_mouse_entered():
	sprite.frame = 1
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.1)

func _on_mouse_exited():
	sprite.frame = 0
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_animate_and_execute()

func _animate_and_execute():
	sprite.frame = 2
	await get_tree().create_timer(0.1).timeout
	sprite.frame = 3
	await get_tree().create_timer(0.1).timeout
	
	match sprite.name:
		"PlayButton":
			get_tree().change_scene_to_file("res://scenes/Screens/CharacterSelection.tscn")
		"QuitButton":
			get_tree().quit()
		"OptionButton":
			print("Abriendo menú de opciones...")
