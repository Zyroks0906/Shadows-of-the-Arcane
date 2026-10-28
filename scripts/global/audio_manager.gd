extends Node

# Sound effects. play_bank() picks a variant from SoundBank (never the same one twice in a
# row), adds a little pitch variation so repeats don't sound mechanical, and caps how
# many copies of one category can start at once. play_bank_at() is positional: enemies
# off to the side or far away sound quieter.

const POOL_SIZE := 16
const POOL_2D_SIZE := 24
const MIN_GAP_MS := 45 # same category can't restart faster than this (stacked hits)

var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _last_variant: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in range(POOL_2D_SIZE):
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 520.0
		p2.attenuation = 1.6
		add_child(p2)
		_pool_2d.append(p2)

# Let go of every stream on quit, so nothing is still playing or cached when the engine
# tears the resources down.
func _exit_tree() -> void:
	release_all()

# Stops every sound and the music and drops the streams. Await a couple of frames after it
# before quitting so the audio thread lets go of them too (headless test runs).
func release_all() -> void:
	MusicManager.stop()
	for mp: AudioStreamPlayer in MusicManager.find_children("*", "AudioStreamPlayer", false, false):
		mp.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	for p in _pool_2d:
		p.stop()
		p.stream = null
	_cache.clear()

func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s

func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _stream(path)
	if stream:
		_start(_free_player(), stream, volume_db, pitch_scale)

# Picks a variant of a SoundBank category. Returns false if the category is unknown or
# was played a moment ago.
func play_bank(category: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.05) -> bool:
	var stream := _pick(category)
	if not stream:
		return false
	_start(_free_player(), stream, volume_db, pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var))
	return true

func play_bank_at(category: String, world_pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.05) -> bool:
	var stream := _pick(category)
	if not stream:
		return false
	var p := _free_player_2d()
	p.global_position = world_pos
	_start(p, stream, volume_db, pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var))
	return true

func has_category(category: String) -> bool:
	return SoundBank.BANK.has(category)

func _pick(category: String) -> AudioStream:
	var list: Array = SoundBank.BANK.get(category, [])
	if list.is_empty():
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(category, -1000)) < MIN_GAP_MS:
		return null
	_last_play_ms[category] = now
	var i := randi() % list.size()
	if list.size() > 1 and i == int(_last_variant.get(category, -1)):
		i = (i + 1 + randi() % (list.size() - 1)) % list.size()
	_last_variant[category] = i
	return _stream(list[i])

func _start(p: Node, stream: AudioStream, volume_db: float, pitch: float) -> void:
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer = _pool.pop_front()
	_pool.push_back(oldest)
	return oldest

func _free_player_2d() -> AudioStreamPlayer2D:
	for p in _pool_2d:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer2D = _pool_2d.pop_front()
	_pool_2d.push_back(oldest)
	return oldest
