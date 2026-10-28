extends Area2D
class_name EventTrigger

@export var door_to_open: Door
@export var door_to_close: Door
@export var enemies_to_watch: Array[Node2D] = []
@export var once: bool = true

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_process(enemies_to_watch.size() > 0)

func _process(_delta: float) -> void:
	if enemies_to_watch.size() > 0:
		var all_dead = true
		for enemy in enemies_to_watch:
			if is_instance_valid(enemy):
				all_dead = false
				break
		if all_dead:
			if door_to_open:
				door_to_open.open()
			set_process(false)

func _on_body_entered(body: Node2D) -> void:
	if triggered and once:
		return

	if body is Player:
		if door_to_close:
			door_to_close.close()
		if door_to_open and enemies_to_watch.size() == 0:
			door_to_open.open()
		triggered = true
