extends Node

var _pool: Array[AudioStreamPlayer] = []
var _pool_size: int = 12

func _ready() -> void:
	for i in range(_pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not ResourceLoader.exists(path): return
	
	var stream = load(path)
	if not stream: return
	
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	
	var oldest = _pool[0]
	oldest.stream = stream
	oldest.volume_db = volume_db
	oldest.pitch_scale = pitch_scale
	oldest.play()
	_pool.push_back(_pool.pop_front())
