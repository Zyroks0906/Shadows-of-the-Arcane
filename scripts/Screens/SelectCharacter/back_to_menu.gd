extends Node

# A way back from the character screen to the title screen: a MAIN MENU button in the
# bottom-left corner (same look as the chamber screen's) and the Esc key.

const MENU := "res://scenes/Screens/initial_screen.tscn"

func _ready() -> void:
	var layer := get_parent().get_node_or_null("CanvasLayer") as CanvasLayer
	if not layer:
		return
	var vp := get_viewport().get_visible_rect().size
	var gold := Color(0.95, 0.78, 0.35)
	var b := Button.new()
	b.text = "MAIN MENU"
	b.size = Vector2(190, 40)
	b.position = Vector2(16, vp.y - 56)
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
	b.pressed.connect(_back)
	layer.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	AudioManager.play_bank("ui_back", -6.0)
	SceneManager.load_scene(MENU)
