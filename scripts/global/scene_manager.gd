extends Node

var target_scene: String = ""

func load_scene(path: String) -> void:
	target_scene = path
	if ResourceLoader.exists("res://scenes/Screens/LoadingScreen.tscn"):
		get_tree().change_scene_to_file("res://scenes/Screens/LoadingScreen.tscn")
	else:
		get_tree().change_scene_to_file(path)
