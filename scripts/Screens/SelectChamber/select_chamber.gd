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
		# We keep them enabled to show the error popup on click
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
	var path = ""
	if id == 1:
		path = "res://scenes/levels/Map_1.tscn"
	else:
		path = "res://scenes/levels/level_" + str(id) + ".tscn"
	
	if ResourceLoader.exists(path):
		SceneManager.load_scene(path)
