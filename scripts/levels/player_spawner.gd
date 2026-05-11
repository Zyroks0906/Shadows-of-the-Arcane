extends Node2D

@export var player_scene: PackedScene = preload("res://Player.tscn")

func _ready() -> void:
	spawn_player()

func spawn_player() -> void:
	var spawn_marker = find_child("PlayerSpawn")
	if not spawn_marker:
		push_warning("No se encontró el Marker2D 'PlayerSpawn'. Usando posición (0,0).")
	
	if player_scene:
		var player = player_scene.instantiate()
		add_child(player)
		
		if spawn_marker:
			player.global_position = spawn_marker.global_position
		
		_apply_selected_class(player)

func _apply_selected_class(player: CharacterBody2D) -> void:
	var c_name = GameManager.get_selected_class_name()
	var class_script_path = "res://scripts/entities/classes/" + c_name + ".gd"
	var sprite_frames_path = "res://assets/sprites/sprite_frames/" + c_name + ".tres"
	
	print("--- Debug Spawner ---")
	print("Clase seleccionada: ", c_name)
	
	if FileAccess.file_exists(class_script_path):
		var script = load(class_script_path)
		player.set_script(script)
		player._init()
		if player.has_method("_ready"):
			player._ready()
		print("Script de clase cargado: ", class_script_path)
	else:
		push_error("No se encontró el script de clase: " + class_script_path)

	var animated_sprite = player.find_child("AnimatedSprite2D")
	if animated_sprite:
		if FileAccess.file_exists(sprite_frames_path):
			var frames = load(sprite_frames_path)
			animated_sprite.sprite_frames = frames
			
			if animated_sprite.sprite_frames.has_animation("Idle"):
				animated_sprite.play("Idle")
				print("Reproduciendo animación: Idle")
			elif animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
				print("Reproduciendo animación: idle")
			else:
				var anims = animated_sprite.sprite_frames.get_animation_names()
				if anims.size() > 0:
					animated_sprite.play(anims[0])
					print("No se halló 'Idle', reproduciendo: ", anims[0])
			
			print("SpriteFrames cargados: ", sprite_frames_path)
		else:
			push_warning("No se encontraron SpriteFrames en: " + sprite_frames_path)
	else:
		push_error("No se encontró un nodo 'AnimatedSprite2D' en el Player.")
	
	print("---------------------")
