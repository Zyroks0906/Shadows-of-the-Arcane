extends Node

var _player_exploration: AudioStreamPlayer
var _player_battle: AudioStreamPlayer
var _current_exploration_path: String = ""
var _battle_track_path: String = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/05 - Battle 1.mp3"

var _is_in_battle: bool = false
var _crossfade_speed: float = 2.0

func _ready() -> void:
	_player_exploration = AudioStreamPlayer.new()
	_player_exploration.bus = "Music"
	add_child(_player_exploration)
	
	_player_battle = AudioStreamPlayer.new()
	_player_battle.bus = "Music"
	_player_battle.volume_db = -80
	add_child(_player_battle)

	process_mode = Node.PROCESS_MODE_ALWAYS

	# Default exploration track
	_current_exploration_path = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/04 - Silent Forest.mp3"
	if SettingsManager and SettingsManager.selected_music_track:
		_current_exploration_path = SettingsManager.selected_music_track

	_player_exploration.stream = load(_current_exploration_path)
	_player_exploration.play()
	
	if ResourceLoader.exists(_battle_track_path):
		_player_battle.stream = load(_battle_track_path)
		_player_battle.play()

func _process(delta: float) -> void:
	_check_battle_status()
	_update_volumes(delta)

func _check_battle_status() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var player = get_tree().get_first_node_in_group("player")
	
	if not player or enemies.is_empty():
		_is_in_battle = false
		return

	var combat_detected = false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get("is_alive") != false:
			var detection = enemy.get("detection_range")
			if detection == null: detection = 150.0 # Fallback
			
			if enemy.global_position.distance_to(player.global_position) <= detection:
				combat_detected = true
				break
	
	_is_in_battle = combat_detected

func _update_volumes(delta: float) -> void:
	var target_exploration = 0.0 if not _is_in_battle else -80.0
	var target_battle = 0.0 if _is_in_battle else -80.0
	
	# Smoothly interpolate volume (using linear_to_db would be better but lerping dB works for simple crossfade)
	_player_exploration.volume_db = lerp(_player_exploration.volume_db, target_exploration, _crossfade_speed * delta)
	_player_battle.volume_db = lerp(_player_battle.volume_db, target_battle, _crossfade_speed * delta)

func play_track(path: String, save_to_settings: bool = true) -> void:
	if _current_exploration_path == path: return
	if not ResourceLoader.exists(path): return

	var stream = load(path)
	if stream:
		_player_exploration.stop()
		_player_exploration.stream = stream
		_player_exploration.play()
		_current_exploration_path = path
		if save_to_settings and SettingsManager:
			SettingsManager.selected_music_track = path

func stop() -> void:
	_player_exploration.stop()
	_player_battle.stop()

func get_current_track_name() -> String:
	return _current_exploration_path.get_file().get_basename()
