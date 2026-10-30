extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/entities/player.tscn")

func _ready() -> void:
	spawn_player()

func spawn_player() -> void:
	var spawn_marker = find_child("PlayerSpawn")
	var spawn_pos = spawn_marker.global_position if spawn_marker else global_position

	if player_scene:
		var player = player_scene.instantiate()


		var c_name = GameManager.get_selected_class_name()
		var class_script_path = "res://scripts/entities/classes/" + c_name + ".gd"
		var sprite_frames_path = "res://assets/sprites/sprite_frames/" + c_name.to_lower() + ".tres"

		print("--- Spawner: Configurando ", c_name, " ---")


		if FileAccess.file_exists(class_script_path):
			var script = load(class_script_path)
			player.set_script(script)
			if player.has_method("_init"):
				player._init()


		var animated_sprite = player.find_child("AnimatedSprite2D")
		if animated_sprite and FileAccess.file_exists(sprite_frames_path):
			animated_sprite.sprite_frames = RunCycles.with_run(load(sprite_frames_path), c_name) # + its RUN cycle


		if c_name.to_lower() == "necromancer":
			player.set_meta("hovers", true) # its robe floats: no steps to keep in time
		add_child(player)
		player.global_position = spawn_pos
		# Progression snapshot: dying in this map rolls back to here.
		DecorPhysics.apply(get_tree().current_scene, false) # bones crunch underfoot everywhere
		Progression.snapshot()
		# Keys open this level's doors only; coins and potions travel on.
		GameManager.total_keys = 0
		GameManager.silver_keys = 0
		GameManager.golden_keys = 0
		GameManager.snapshot_bag()
		if get_tree().current_scene:
			GameManager.current_map = get_tree().current_scene.scene_file_path
		player.add_to_group("player")


		player.collision_layer = 1
		player.collision_mask = 1 | 2 | 4 | 8


		var hud = get_tree().get_first_node_in_group("hud")
		if not hud:

			hud = get_tree().root.find_child("HUD", true, false)

		# Health and mana are drawn by CombatHud, which follows the player itself.
		if not hud:
			push_warning("Spawner: ¡No se encontró el HUD en la escena!")


		if animated_sprite and player.get("base_scale"):
			animated_sprite.scale = player.base_scale
			if player.has_method("_apply_anim_scale"):
				player._apply_anim_scale()

		print("Jugador listo y spawneado en: ", spawn_pos)
		print("---------------------------------------")
