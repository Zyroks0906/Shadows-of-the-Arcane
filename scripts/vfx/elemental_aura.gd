@tool
extends AnimatedSprite2D

@export var element_name: String = "PYRO":
	set(val):
		element_name = val
		_load_frames()
		if sprite_frames and sprite_frames.has_animation("default"):
			play("default")

@export var anim_fps: float = 10.0:
	set(val):
		anim_fps = val
		if sprite_frames:
			sprite_frames.set_animation_speed("default", anim_fps)

static var _cache: Dictionary = {}

func _ready() -> void:
	set_meta("vfx_aura", true)
	if not Engine.is_editor_hint():
		visible = false
	_load_frames()
	if sprite_frames and sprite_frames.has_animation("default"):
		play("default")

func _load_frames() -> void:
	if _cache.has(element_name):
		sprite_frames = _cache[element_name]
		return
	var paths := _get_paths()
	if paths.is_empty():
		return
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("default")
	sf.set_animation_loop("default", true)
	sf.set_animation_speed("default", anim_fps)
	for p in paths:
		if ResourceLoader.exists(p):
			sf.add_frame("default", load(p))
	if sf.get_frame_count("default") > 0:
		sprite_frames = sf
		_cache[element_name] = sf

func _get_paths() -> Array[String]:
	match element_name:
		"PYRO":
			return _range_paths(
				"res://assets/VFX/Elemental_Spikes/Fire Spike From Ground Tier 1/Fire Spikes From Ground Tier 1_Frames/Fire Spikes From Ground Tier 1_%02d.png",
				1, 16)
		"HYDRO":
			return _range_paths(
				"res://assets/VFX/Elemental_Spikes/Water Spike From Ground Tier 1/Water Spike From Ground Tier 1_Frames/Water Spike From Ground Tier 1_%02d.png",
				1, 16)
		"ANEMO":
			return _range_paths(
				"res://assets/VFX/Elemental_Spikes/Wind Spike From Ground Tier 1/Wind Spike From Ground Tier 1_Frames/Wind Spike From Ground Tier 1_%02d.png",
				1, 16)
		"CRYO":
			return _range_paths(
				"res://assets/VFX/Elemental_Spikes/Ice Spike From Ground Tier 1/Ice Spike From Ground Tier 1_Frames/Ice Spike From Ground Tier 1_%02d.png",
				1, 16)
		"ELECTRO":
			return _range_paths(
				"res://assets/VFX/Lightning/VFX5/Frames/lightning_skill5_frame%d.png",
				1, 4)
	return []

static func _range_paths(template: String, from: int, to: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(from, to + 1):
		out.append(template % i)
	return out
