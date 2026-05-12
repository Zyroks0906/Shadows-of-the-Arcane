extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/entities/player.tscn")

func _ready() -> void:
	spawn_player()

func spawn_player() -> void:
	var spawn_marker = find_child("PlayerSpawn")
	var spawn_pos = spawn_marker.global_position if spawn_marker else global_position
	
	if player_scene:
		var player = player_scene.instantiate()
		
		# 1. Configurar Script de Clase y SpriteFrames ANTES de add_child
		var c_name = GameManager.get_selected_class_name()
		var class_script_path = "res://scripts/entities/classes/" + c_name + ".gd"
		var sprite_frames_path = "res://assets/sprites/sprite_frames/" + c_name.to_lower() + ".tres"
		
		print("--- Spawner: Configurando ", c_name, " ---")
		
		# Aplicar Script
		if FileAccess.file_exists(class_script_path):
			var script = load(class_script_path)
			player.set_script(script)
			if player.has_method("_init"):
				player._init()
		
		# Aplicar SpriteFrames
		var animated_sprite = player.find_child("AnimatedSprite2D")
		if animated_sprite and FileAccess.file_exists(sprite_frames_path):
			animated_sprite.sprite_frames = load(sprite_frames_path)
		
		# 2. Añadir al árbol (Esto dispara el _ready() con todo ya configurado)
		add_child(player)
		player.global_position = spawn_pos
		player.add_to_group("player")
		
		# Asegurar capas de colisión (Capa 1 = Mundo/Player)
		player.collision_layer = 1
		player.collision_mask = 1 | 2 | 4 | 8 
		
		# Conectar HUD a señales del jugador
		var hud = get_tree().get_first_node_in_group("hud")
		if not hud:
			# Reintentar buscando por nombre si el grupo falla
			hud = get_tree().root.find_child("HUD", true, false)
			
		if hud:
			print("Spawner: HUD encontrado. Conectando señales...")
			if hud.has_method("update_health"):
				player.health_changed.connect(hud.update_health)
				player.mana_changed.connect(hud.update_mana)
				hud.update_health(player.current_health, player.max_health)
				hud.update_mana(player.current_mana, player.max_mana)
		else:
			push_warning("Spawner: ¡No se encontró el HUD en la escena!")
		
		# Forzar actualización de escala si por algún motivo no se aplicó en _ready
		if animated_sprite and player.get("base_scale"):
			animated_sprite.scale = player.base_scale
			
		print("Jugador listo y spawneado en: ", spawn_pos)
		print("---------------------------------------")
