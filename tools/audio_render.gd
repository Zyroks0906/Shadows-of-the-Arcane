extends Node

# Renders any audio file Godot can play (ogg, mp3, wav) to a 16-bit WAV by recording it
# on a muted bus, so external tools can analyse or split it.
# Usage (needs an audio device, not --headless):
#   Godot.exe --path . res://tools/audio_render.tscn -- <out_dir> <file> [file ...]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Render")
	var rec := AudioEffectRecord.new()
	rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, rec)
	AudioServer.set_bus_mute(0, true) # silence the speakers; Render still records
	var player := AudioStreamPlayer.new()
	player.bus = "Render"
	add_child(player)
	for path in args.slice(1):
		var stream: AudioStream
		var ext: String = path.get_extension().to_lower()
		if ext == "ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		elif ext == "mp3":
			stream = AudioStreamMP3.load_from_file(path)
		else:
			stream = AudioStreamWAV.load_from_file(path)
		if not stream:
			print("FAILED ", path)
			continue
		if "loop" in stream:
			stream.loop = false
		rec.set_recording_active(true)
		player.stream = stream
		player.play()
		await get_tree().create_timer(stream.get_length() + 0.15).timeout
		rec.set_recording_active(false)
		var out := out_dir.path_join(path.get_file().get_basename() + ".wav")
		rec.get_recording().save_to_wav(out)
		print("RENDERED ", out, " ", stream.get_length())
	get_tree().quit()
