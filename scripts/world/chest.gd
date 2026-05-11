extends Node2D
class_name Chest

@export var require_interaction: bool = false
@export var key_amount: int = 0
@export var coins_amount: int = 0
@export var hidden_item: Node2D

var is_opened: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)
	
	if hidden_item:
		call_deferred("_prepare_hidden_item")

func _prepare_hidden_item() -> void:
	if hidden_item:
		hidden_item.visible = false
		_set_item_collision(hidden_item, false)

func _on_body_entered(body: Node2D) -> void:
	if not require_interaction:
		open_chest(body)

func open_chest(body: Node2D) -> void:
	if is_opened or not (body is Player):
		return
		
	is_opened = true
	GameManager.add_keys(key_amount)
	GameManager.add_coins(coins_amount)
	
	if sprite:
		sprite.play("default")
		
	if hidden_item:
		hidden_item.visible = true
		_set_item_collision(hidden_item, true)

func _set_item_collision(item: Node2D, enabled: bool) -> void:
	var target_area = item if item is Area2D else item.get_node_or_null("Area2D")
	if target_area:
		target_area.set_deferred("monitoring", enabled)
		target_area.set_deferred("monitorable", enabled)
