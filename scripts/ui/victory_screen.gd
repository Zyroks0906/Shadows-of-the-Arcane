extends Control

@export var hero_scale: float = 4.0

@onready var coins_label: Label = $ContentPanel/ContentCenter/VBoxLayout/StatsContainer/CoinsLabel
@onready var hero_sprite: AnimatedSprite2D = $HeroAnchor/HeroSprite
@onready var hero_guide: ColorRect = $HeroAnchor/HeroGuide
@onready var hero_scale_box: ColorRect = $HeroAnchor/HeroScaleBox
@onready var hero_anchor: Control = $HeroAnchor
@onready var stats_container: VBoxContainer = $ContentPanel/ContentCenter/VBoxLayout/StatsContainer
@onready var buttons_group: VBoxContainer = $ContentPanel/ContentCenter/VBoxLayout/ButtonsGroup
@onready var title_label: Label = $ContentPanel/ContentCenter/VBoxLayout/Title
@onready var dark_overlay: ColorRect = $DarkOverlay

func _ready() -> void:
	_set_initial_state()
	coins_label.text = "COINS: %d" % GameManager.total_coins
	await _setup_hero_display()

	var mm = get_node_or_null("/root/MusicManager")
	if mm:
		mm.play_track("res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/06 - Victory!.mp3", false)

	_run_entrance()

func _set_initial_state() -> void:
	dark_overlay.color.a = 0.0
	hero_anchor.modulate.a = 0.0
	title_label.scale = Vector2(0, 0)
	stats_container.modulate.a = 0.0
	buttons_group.modulate.a = 0.0
	hero_guide.visible = false
	hero_scale_box.visible = false

func _run_entrance() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dark_overlay, "color:a", 0.6, 0.7)
	tween.tween_property(hero_anchor, "modulate:a", 1.0, 0.9).set_delay(0.3)
	tween.tween_property(title_label, "scale", Vector2(1, 1), 0.6).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stats_container, "modulate:a", 1.0, 0.6).set_delay(1.3)
	tween.tween_property(buttons_group, "modulate:a", 1.0, 0.6).set_delay(1.9)
	await tween.finished
	$ContentPanel/ContentCenter/VBoxLayout/ButtonsGroup/ContinueButton.grab_focus()

func _setup_hero_display() -> void:
	var class_name_str := GameManager.get_selected_class_name()
	var frames_path := "res://assets/sprites/sprite_frames/%s.tres" % class_name_str
	if not ResourceLoader.exists(frames_path):
		return
	hero_sprite.sprite_frames = load(frames_path)
	var anim := _find_idle_animation()
	if anim != "":
		hero_sprite.play(anim)
	await get_tree().process_frame
	_fit_hero_to_panel()

func _find_idle_animation() -> String:
	var frames := hero_sprite.sprite_frames
	if not frames:
		return ""
	for anim in ["Idle", "idle", "IDLE"]:
		if frames.has_animation(anim):
			return anim
	return ""

func _fit_hero_to_panel() -> void:
	var bx: float = hero_scale_box.offset_left
	var by: float = hero_scale_box.offset_top
	var bw: float = hero_scale_box.offset_right - bx
	var bh: float = hero_scale_box.offset_bottom - by
	if bw <= 0 or bh <= 0:
		return
	hero_sprite.scale = Vector2(hero_scale, hero_scale)
	hero_sprite.position = Vector2(bx + bw * 0.5, by + bh * 0.6)

func _on_continue_button_pressed() -> void:
	SceneManager.load_scene("res://scenes/Screens/SelectChamber.tscn")

func _on_menu_button_pressed() -> void:
	SceneManager.load_scene("res://scenes/Screens/initial_screen.tscn")
