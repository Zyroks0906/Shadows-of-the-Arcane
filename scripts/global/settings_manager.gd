extends Node

const SETTINGS_FILE = "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var selected_music_track: String = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/04 - Silent Forest.mp3"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "track", selected_music_track)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		master_volume = config.get_value("audio", "master", 1.0)
		music_volume = config.get_value("audio", "music", 0.8)
		sfx_volume = config.get_value("audio", "sfx", 1.0)
		selected_music_track = config.get_value("audio", "track", selected_music_track)
	
	call_deferred("_apply_bus_volumes")

func _apply_bus_volumes() -> void:
	_set_bus_vol("Master", master_volume)
	_set_bus_vol("Music", music_volume)
	_set_bus_vol("SFX", sfx_volume)

func _set_bus_vol(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db_val = linear_to_db(max(linear_val, 0.0001))
		AudioServer.set_bus_volume_db(idx, db_val)
		AudioServer.set_bus_mute(idx, linear_val <= 0)

func set_master_volume(v: float) -> void:
	master_volume = v
	_set_bus_vol("Master", v)

func set_music_volume(v: float) -> void:
	music_volume = v
	_set_bus_vol("Music", v)

func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	_set_bus_vol("SFX", v)
