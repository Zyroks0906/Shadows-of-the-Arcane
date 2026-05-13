extends CanvasLayer

@onready var master_slider = %MasterSlider
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SFXSlider
@onready var track_dropdown_btn = %TrackDropdownButton
@onready var track_dropdown_panel = %TrackDropdownPanel
@onready var music_list = %MusicList
@onready var back_button = %BackButton

var music_tracks: Array[String] = []

func _ready() -> void:
	visible = false
	track_dropdown_panel.visible = false
	_load_tracks()
	_update_ui()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	track_dropdown_btn.pressed.connect(_toggle_dropdown)
	back_button.pressed.connect(hide_options)

func _toggle_dropdown() -> void:
	track_dropdown_panel.visible = not track_dropdown_panel.visible
	if track_dropdown_panel.visible:
		var btn_pos = track_dropdown_btn.global_position
		track_dropdown_panel.size.x = track_dropdown_btn.size.x
		track_dropdown_panel.global_position = btn_pos + Vector2(0, track_dropdown_btn.size.y + 2)

		var sm = get_node_or_null("/root/SettingsManager")
		if sm: _highlight_current_track(sm.selected_music_track)

func _load_tracks() -> void:
	for child in music_list.get_children():
		child.queue_free()
	music_tracks.clear()

	var base_path = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/"
	var dir = DirAccess.open(base_path)
	if dir:
		dir.list_dir_begin()
		var fn = dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and fn.ends_with(".mp3"):
				var full_path = base_path + fn
				music_tracks.append(full_path)

				var track_name = fn.get_basename()
				if track_name.length() > 5: track_name = track_name.substr(5)

				var btn = Button.new()
				btn.text = track_name
				btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
				btn.flat = true
				btn.pressed.connect(_on_track_selected.bind(full_path, track_name))
				music_list.add_child(btn)
			fn = dir.get_next()

	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		_update_dropdown_label(sm.selected_music_track)

func _highlight_current_track(path: String) -> void:
	var children = music_list.get_children()
	for i in range(music_tracks.size()):
		if i < children.size() and children[i] is Button:
			if music_tracks[i] == path:
				children[i].add_theme_color_override("font_color", Color.YELLOW)
				children[i].add_theme_color_override("font_hover_color", Color.YELLOW)
				children[i].text = "> " + children[i].text.replace("> ", "")
			else:
				children[i].remove_theme_color_override("font_color")
				children[i].remove_theme_color_override("font_hover_color")
				children[i].text = children[i].text.replace("> ", "")

func _update_dropdown_label(path: String) -> void:
	var track_name = path.get_file().get_basename()
	if track_name.length() > 5: track_name = track_name.substr(5)
	track_dropdown_btn.text = track_name if track_name != "" else "Select Track..."

func _update_ui() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		master_slider.value = sm.master_volume
		music_slider.value = sm.music_volume
		sfx_slider.value = sm.sfx_volume

func _on_master_changed(v: float) -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		sm.set_master_volume(v)
		sm.save_settings()

func _on_music_changed(v: float) -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		sm.set_music_volume(v)
		sm.save_settings()

func _on_sfx_changed(v: float) -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		sm.set_sfx_volume(v)
		sm.save_settings()

func _on_track_selected(path: String, track_name: String) -> void:
	var mm = get_node_or_null("/root/MusicManager")
	var sm = get_node_or_null("/root/SettingsManager")
	if mm: mm.play_track(path)
	if sm:
		sm.selected_music_track = path
		sm.save_settings()
	track_dropdown_btn.text = track_name
	track_dropdown_panel.visible = false

func show_options() -> void:
	visible = true
	_update_ui()
	var sm = get_node_or_null("/root/SettingsManager")
	if sm: _highlight_current_track(sm.selected_music_track)

func hide_options() -> void:
	visible = false
	track_dropdown_panel.visible = false
