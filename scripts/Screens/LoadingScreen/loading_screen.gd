extends Control

@onready var loading_icon: AnimatedSprite2D = $IconContainer/LoadingIcon

func _ready() -> void:
	if SceneManager.target_scene == "":
		get_tree().change_scene_to_file("res://scenes/Screens/initial_screen.tscn")
		return
		
	if loading_icon:
		loading_icon.play("default")
	_load_next_scene()

func _load_next_scene() -> void:
	ResourceLoader.load_threaded_request(SceneManager.target_scene)
	
	await get_tree().create_timer(1.5).timeout
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(SceneManager.target_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return
		await get_tree().process_frame
	
	var loaded_scene = ResourceLoader.load_threaded_get(SceneManager.target_scene)
	get_tree().change_scene_to_packed(loaded_scene)
