extends Node

var pause_menu: CanvasLayer
var options_overlay: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var pm_scene = load("res://scenes/ui/PauseMenu.tscn")
	if pm_scene:
		pause_menu = pm_scene.instantiate()
		add_child(pause_menu)
	
	var oo_scene = load("res://scenes/ui/OptionsOverlay.tscn")
	if oo_scene:
		options_overlay = oo_scene.instantiate()
		add_child(options_overlay)

func show_options() -> void:
	if options_overlay: options_overlay.show_options()

func hide_options() -> void:
	if options_overlay: options_overlay.hide_options()
