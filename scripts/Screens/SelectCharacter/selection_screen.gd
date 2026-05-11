extends Area2D

var _tween: Tween
var _base_scale: Vector2
@onready var _sprite = get_parent()
@onready var popup: AcceptDialog = _create_character_popup()

static var selected_character: Area2D = null

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_base_scale = _sprite.scale
	if _sprite is AnimatedSprite2D and _sprite.name.contains("Selector"):
		_sprite.self_modulate.a = 0

func _create_character_popup() -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = "Selection Required"
	dialog.dialog_text = "Please select a character before proceeding."
	add_child(dialog)
	return dialog

func _on_mouse_entered() -> void:
	if not _sprite is AnimatedSprite2D: return
	if _sprite.name.contains("Selector"): _sprite.self_modulate.a = 1
	_sprite.frame = 1
	_animate(_base_scale * 1.05)
	for node in _sprite.get_children():
		if node is AnimatedSprite2D:
			node.play()

func _on_mouse_exited() -> void:
	if not _sprite is AnimatedSprite2D: return
	if selected_character == self: return
	if _sprite.name.contains("Selector"): _sprite.self_modulate.a = 0
	else: _sprite.frame = 0
	_animate(_base_scale)
	for node in _sprite.get_children():
		if node is AnimatedSprite2D:
			node.stop()
			node.frame = 0

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _sprite.name.contains("Selector"):
			if selected_character and selected_character != self:
				selected_character.deselect()
			selected_character = self
			_update_game_manager_selection()
		
		if _sprite is AnimatedSprite2D:
			_sprite.frame = 2
			await get_tree().create_timer(0.1).timeout
			_sprite.frame = 3
			await get_tree().create_timer(0.1).timeout
			match _sprite.name:
				"Confirm":
					if selected_character:
						get_tree().change_scene_to_file("res://scenes/levels/Map_1.tscn")
					else:
						popup.popup_centered()
				"SelectChamber":
					get_tree().change_scene_to_file("res://scenes/Screens/Initial_screen.tscn")

func _update_game_manager_selection() -> void:
	for child in _sprite.get_children():
		if child is AnimatedSprite2D:
			match child.name:
				"Archer": GameManager.set_selected_class(GameManager.CharacterClass.ARCHER)
				"Knight": GameManager.set_selected_class(GameManager.CharacterClass.KNIGHT)
				"Warrior": GameManager.set_selected_class(GameManager.CharacterClass.WARRIOR)
				"Necromancer": GameManager.set_selected_class(GameManager.CharacterClass.NECROMANCER)
				"Samurai": GameManager.set_selected_class(GameManager.CharacterClass.ASSASSIN)
				"Mage": GameManager.set_selected_class(GameManager.CharacterClass.MAGE)
				"Cleric": GameManager.set_selected_class(GameManager.CharacterClass.CLERIC)
				"Gladiator": GameManager.set_selected_class(GameManager.CharacterClass.BARBARIAN)

func deselect() -> void:
	if _sprite.name.contains("Selector"): _sprite.self_modulate.a = 0
	_animate(_base_scale)
	for node in _sprite.get_children():
		if node is AnimatedSprite2D:
			node.stop()
			node.frame = 0

func _animate(target: Vector2) -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sprite, "scale", target, 0.1).set_trans(Tween.TRANS_SINE)
