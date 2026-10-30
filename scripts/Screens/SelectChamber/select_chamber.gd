extends Node2D

@onready var layers: Array[CanvasLayer] = [
	$Capa1,
	$Capa2,
	$Capa3
]

@onready var buttons: Array[Button] = [
	$UILayer/Buttons/on_map_1_pressed,
	$UILayer/Buttons/on_map_2_pressed,
	$UILayer/Buttons/on_map_3_pressed
]

@onready var popup: AcceptDialog = _create_popup()

func _ready() -> void:
	_add_nav_buttons()
	_setup_buttons()
	_refresh_map()

func _create_popup() -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = "Level Locked"
	dialog.dialog_text = "You must complete the previous levels to unlock this chamber."
	add_child(dialog)
	return dialog

func _setup_buttons() -> void:
	$UILayer/Buttons/on_map_1_pressed.pressed.connect(_on_map_1_pressed)
	$UILayer/Buttons/on_map_2_pressed.pressed.connect(_on_map_2_pressed)
	$UILayer/Buttons/on_map_3_pressed.pressed.connect(_on_map_3_pressed)

func _refresh_map() -> void:
	var progress = GameData.unlocked_levels
	for i in range(layers.size()):
		layers[i].visible = (progress >= i + 1)

		buttons[i].modulate = Color.WHITE if progress >= i + 1 else Color(0.5, 0.5, 0.5)

func _on_map_1_pressed() -> void:
	_load_level(1)

func _on_map_2_pressed() -> void:
	if GameData.unlocked_levels >= 2:
		_load_level(2)
	else:
		popup.popup_centered()

func _on_map_3_pressed() -> void:
	if GameData.unlocked_levels >= 3:
		_load_level(3)
	else:
		popup.popup_centered()

func _load_level(id: int) -> void:
	# Every run from here is a new seed: its own layout for each level.
	GameManager.start_run()
	var path := GameManager.map_for(id - 1)

	if ResourceLoader.exists(path):
		DifficultyPopup.ask(func(): SceneManager.load_scene(path)) # each run picks its difficulty

# Ways out besides entering a map: back to the character screen or to the title screen.
func _add_nav_buttons() -> void:
	var layer := get_node_or_null("UILayer") as CanvasLayer
	if not layer:
		return
	var vp := get_viewport().get_visible_rect().size
	var gold := Color(0.95, 0.78, 0.35)
	var specs := [["CHARACTERS", "res://scenes/Screens/SelectCharacter.tscn"], ["MAIN MENU", "res://scenes/Screens/initial_screen.tscn"]]
	for i in specs.size():
		var b := Button.new()
		b.text = specs[i][0]
		b.size = Vector2(190, 40)
		b.position = Vector2(16 + i * 202, vp.y - 56)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_constant_override("outline_size", 0)
		b.add_theme_color_override("font_hover_color", gold)
		for state in ["normal", "hover", "pressed"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.07, 0.04, 0.08, 0.92) if state == "normal" else Color(0.18, 0.1, 0.2, 0.95)
			st.border_color = gold if state != "normal" else Color(gold, 0.6)
			st.set_border_width_all(2)
			b.add_theme_stylebox_override(state, st)
		var path: String = specs[i][1]
		b.pressed.connect(func(): SceneManager.load_scene(path))
		layer.add_child(b)
