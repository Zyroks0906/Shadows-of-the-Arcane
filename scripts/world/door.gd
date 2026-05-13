extends StaticBody2D
class_name Door

enum KeyType { NONE, ANY, SILVER, GOLDEN }

@export var is_open: bool = false
@export var required_key: KeyType = KeyType.NONE
@export var is_tutorial_door: bool = false
@export var lock_after_pass: bool = false
@export var boss_to_track: String = ""

var is_locked: bool = false

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D

func _ready() -> void:
	add_to_group("interactable")
	if is_open:
		open()
	else:
		close()

	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	if boss_to_track != "" and GameManager:
		GameManager.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_name: String) -> void:
	if boss_name == boss_to_track:
		is_locked = false
		lock_after_pass = false
		open()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return

	if is_tutorial_door and not is_open and not is_locked:
		open()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"): return

	if lock_after_pass and is_open and not is_locked:
		close()
		is_locked = true

func _show_message(message: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud: return
	
	if hud.has_method("show_message"):
		hud.show_message(message, 3.0)
	elif hud.has_method("show_interaction_prompt"):
		hud.show_interaction_prompt(true, message)

func open() -> void:
	if is_locked: return

	match required_key:
		KeyType.SILVER:
			if GameManager.silver_keys <= 0:
				_show_message("You need a Silver Key to open this door")
				return
			GameManager.silver_keys -= 1
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")
		KeyType.GOLDEN:
			if GameManager.golden_keys <= 0:
				_show_message("You need a Golden Key to open this door")
				return
			GameManager.golden_keys -= 1
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")
		KeyType.ANY:
			if GameManager.total_keys <= 0:
				_show_message("You need a Key to open this door")
				return
			GameManager.total_keys -= 1
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")

	var am_open = get_node_or_null("/root/AudioManager")
	if am_open: am_open.play_sfx("res://assets/audio/sfx/Environment/door_open.wav")
	
	is_open = true
	if collision: collision.set_deferred("disabled", true)
	if sprite: sprite.visible = false

func close() -> void:
	is_open = false
	if collision: collision.set_deferred("disabled", false)
	if sprite: sprite.visible = true

func unlock_by_event() -> void:
	is_locked = false
	open()

func interact(_body: Node2D) -> void:
	if is_locked:
		if boss_to_track != "":
			_show_message("The door is sealed. Defeat the boss to proceed.")
		else:
			_show_message("The door is locked from the other side.")
		return

	if not is_open:
		open()
