extends Node2D
class_name LevelAmbience

# Per-level mood: darkness tint, music, a light that follows the player and
# ambient particles that drift around the camera.

@export var level_title: String = ""
@export var level_subtitle: String = ""
@export_file("*.mp3", "*.ogg") var music_path: String = ""
@export var darkness: Color = Color(0.5, 0.5, 0.6)
@export var player_light_color: Color = Color(1.0, 0.85, 0.7)
@export var player_light_scale: float = 2.2
@export var mote_color: Color = Color(0.6, 0.8, 1.0, 0.6)
## Negative y drifts upwards (embers, arcane motes), positive falls (drips, dust).
@export var mote_gravity: Vector2 = Vector2(0, -6)
@export var mote_amount: int = 40

static var _light_tex: GradientTexture2D = null

static func light_texture() -> GradientTexture2D:
	if _light_tex:
		return _light_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	_light_tex = GradientTexture2D.new()
	_light_tex.gradient = g
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	_light_tex.width = 128
	_light_tex.height = 128
	return _light_tex

var _motes: CPUParticles2D

func _ready() -> void:
	var cm := CanvasModulate.new()
	cm.color = darkness
	add_child(cm)

	_motes = CPUParticles2D.new()
	_motes.amount = mote_amount
	_motes.lifetime = 6.0
	_motes.preprocess = 6.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(260, 160)
	_motes.gravity = mote_gravity
	_motes.direction = Vector2(1, 0)
	_motes.spread = 180.0
	_motes.initial_velocity_min = 2.0
	_motes.initial_velocity_max = 8.0
	# Soft round motes (a square pixel read as a dead pixel, not as drifting dust).
	_motes.texture = CombatFX._dot_tex()
	_motes.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_motes.scale_amount_min = 0.22
	_motes.scale_amount_max = 0.38
	_motes.local_coords = false
	_motes.z_index = 30
	var ramp := Gradient.new()
	ramp.set_color(0, Color(mote_color, 0.0))
	ramp.add_point(0.3, mote_color)
	ramp.set_color(1, Color(mote_color, 0.0))
	_motes.color_ramp = ramp
	add_child(_motes)

	if music_path != "" and has_node("/root/MusicManager"):
		MusicManager.play_track(music_path, false)

	# The player is spawned by PlayerSpawner during the same frame.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var light := PointLight2D.new()
		light.texture = light_texture()
		light.color = player_light_color
		light.texture_scale = player_light_scale
		light.energy = 1.0
		light.shadow_enabled = false
		player.add_child(light)
	if level_title != "":
		_show_title()

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and _motes:
		_motes.global_position = cam.get_screen_center_position()

func _show_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# A dark band behind the text, fading out at the top and bottom, so the title reads as an
	# overlay instead of colliding with whatever props sit behind it.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = 66
	band.offset_bottom = 156
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 90
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	for entry in [[level_title, 28, Color(1, 0.95, 0.85)], [level_subtitle, 12, Color(0.75, 0.8, 0.95)]]:
		if entry[0] == "":
			continue
		var label := Label.new()
		label.text = entry[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", CombatFX.FONT)
		label.add_theme_font_size_override("font_size", entry[1])
		label.add_theme_color_override("font_color", entry[2])
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 8)
		box.add_child(label)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.5)
	tw.tween_property(root, "modulate:a", 0.0, 1.5)
	tw.tween_callback(layer.queue_free)
