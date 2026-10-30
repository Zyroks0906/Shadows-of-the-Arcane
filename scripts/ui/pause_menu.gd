extends CanvasLayer

@onready var resume_btn = %ResumeButton
@onready var restart_btn = %RestartButton
@onready var options_btn = %OptionsButton
@onready var menu_btn = %MenuButton
@onready var quit_btn = %QuitButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(resume_game)
	restart_btn.pressed.connect(restart_map)
	options_btn.pressed.connect(show_options)
	menu_btn.pressed.connect(go_to_menu)
	quit_btn.pressed.connect(quit_game)
	# The Journal: the story pages found so far (kept across runs).
	var journal: Button = options_btn.duplicate()
	journal.name = "JournalButton"
	journal.text = "JOURNAL"
	options_btn.get_parent().add_child(journal)
	options_btn.get_parent().move_child(journal, options_btn.get_index() + 1)
	journal.pressed.connect(JournalMenu.open_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if (PerkPicker.is_open() or DeathScreen.is_open() or Transmuter.TransmuteMenu.is_open() or ControlsMenu.is_open() or JournalMenu.is_open() or LoreStone.LorePage.is_open()):
			return  # the perk choice owns the pause until a card is picked
		var uic = get_node_or_null("/root/UIController")
		if uic and uic.options_overlay and uic.options_overlay.visible:
			uic.options_overlay.hide_options()
		else:
			toggle_pause()

func toggle_pause() -> void:
	var new_state = not get_tree().paused
	_arm_restart(false)
	get_tree().paused = new_state
	visible = new_state
	if new_state:
		_show_seed()
	if not new_state:
		var uic = get_node_or_null("/root/UIController")
		if uic: uic.hide_options()

# The run's seed and which layout of this map it drew, so a run can be told apart and
# shared (it can be typed in on the chamber screen to play the same layouts).
var _seed_label: Label

func _show_seed() -> void:
	if not _seed_label:
		_seed_label = Label.new()
		var f: FontFile = load("res://assets/fonts/PixelifySans.ttf")
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_seed_label.add_theme_font_override("font", f)
		_seed_label.add_theme_font_size_override("font_size", 22)
		_seed_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
		_seed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_seed_label.add_theme_constant_override("outline_size", 4)
		_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_seed_label)
	var vp := get_viewport().get_visible_rect().size
	_seed_label.text = GameManager.variant_text()
	_seed_label.size = Vector2(vp.x, 30)
	_seed_label.position = Vector2(0, vp.y - 44)

func resume_game() -> void:
	get_tree().paused = false
	visible = false

# Back to the start of this map, as you were when you entered it (coins, potions, level
# and perks roll back like after a death): the way out if something goes wrong. The first
# click only asks; the second one restarts.
var _restart_armed := false

func restart_map() -> void:
	if not _restart_armed:
		_arm_restart(true)
		return
	var scene := get_tree().current_scene
	if not scene or scene.scene_file_path == "":
		return
	Progression.restore()
	GameManager.restore_bag()
	get_tree().paused = false
	visible = false
	_arm_restart(false)
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.load_scene(scene.scene_file_path)
	else:
		get_tree().change_scene_to_file(scene.scene_file_path)

func _arm_restart(armed: bool) -> void:
	_restart_armed = armed
	if restart_btn:
		restart_btn.text = "SURE? CLICK AGAIN" if armed else "RESTART MAP"
		restart_btn.modulate = Color(1.0, 0.75, 0.6) if armed else Color.WHITE

func show_options() -> void:
	var uic = get_node_or_null("/root/UIController")
	if uic: uic.show_options()

func go_to_menu() -> void:
	get_tree().paused = false
	visible = false
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.load_scene("res://scenes/Screens/initial_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Screens/initial_screen.tscn")

func quit_game() -> void:
	get_tree().quit()
