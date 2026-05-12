extends Control

@onready var loading_icon: AnimatedSprite2D = $IconContainer/LoadingIcon

func _ready() -> void:
	if SceneManager.target_scene == "":
		get_tree().change_scene_to_file("res://scenes/Screens/initial_screen.tscn")
		return
		
	if loading_icon:
		loading_icon.play("default")
	_load_next_scene()

var progress_val: float = 0.0

func _load_next_scene() -> void:
	ResourceLoader.load_threaded_request(SceneManager.target_scene)
	
	var progress_array = []
	var displayed_progress: float = 0.0
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(SceneManager.target_scene, progress_array)
		var actual_progress = progress_array[0] if progress_array.size() > 0 else 0.0
		
		# Suavizar el progreso (avanza máximo un 2% por frame para que se vea la animación)
		displayed_progress = lerp(displayed_progress, actual_progress, 0.1)
		displayed_progress = move_toward(displayed_progress, actual_progress, 0.02)
		
		# Actualizar el frame de la animación basado en el progreso si fuera necesario, 
		# o simplemente dejar que la animación fluya mientras el progreso sube.
		
		if status == ResourceLoader.THREAD_LOAD_LOADED and displayed_progress >= 0.99:
			# Asegurarnos de que la animación ha tenido tiempo de lucirse
			await get_tree().create_timer(0.2).timeout
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Error al cargar la escena: " + SceneManager.target_scene)
			return
			
		await get_tree().process_frame
	
	var loaded_scene = ResourceLoader.load_threaded_get(SceneManager.target_scene)
	get_tree().change_scene_to_packed(loaded_scene)
