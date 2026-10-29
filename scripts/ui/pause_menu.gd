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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if (PerkPicker.is_open() or DeathScreen.is_open() or Transmuter.TransmuteMenu.is_open() or ControlsMenu.is_open()):
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
	if not new_state:
		var uic = get_node_or_null("/root/UIController")
		if uic: uic.hide_options()

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
