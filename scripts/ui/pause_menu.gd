extends CanvasLayer

@onready var resume_btn = %ResumeButton
@onready var options_btn = %OptionsButton
@onready var menu_btn = %MenuButton
@onready var quit_btn = %QuitButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(resume_game)
	options_btn.pressed.connect(show_options)
	menu_btn.pressed.connect(go_to_menu)
	quit_btn.pressed.connect(quit_game)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		var uic = get_node_or_null("/root/UIController")
		if uic and uic.options_overlay and uic.options_overlay.visible:
			uic.options_overlay.hide_options()
		else:
			toggle_pause()

func toggle_pause() -> void:
	var new_state = not get_tree().paused
	get_tree().paused = new_state
	visible = new_state
	if not new_state:
		var uic = get_node_or_null("/root/UIController")
		if uic: uic.hide_options()

func resume_game() -> void:
	get_tree().paused = false
	visible = false

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
