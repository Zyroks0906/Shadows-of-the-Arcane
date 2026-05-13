extends Node

var _player: AudioStreamPlayer
var _current_track_path: String = ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var initial_track = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/04 - Silent Forest.mp3"
	if SettingsManager:
		initial_track = SettingsManager.selected_music_track
		
	play_track(initial_track)

func play_track(path: String, save_to_settings: bool = true) -> void:
	if _current_track_path == path: return
	if not ResourceLoader.exists(path): return
	
	var stream = load(path)
	if stream:
		_player.stop()
		_player.stream = stream
		_player.play()
		_current_track_path = path
		if save_to_settings and SettingsManager:
			SettingsManager.selected_music_track = path

func stop() -> void:
	_player.stop()
	_current_track_path = ""

func get_current_track_name() -> String:
	return _current_track_path.get_file().get_basename()
