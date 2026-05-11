extends Area2D

enum ItemType { COIN, KEY, HEALTH_POTION, MANA_POTION }
@export var type: ItemType = ItemType.COIN
@export var value: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		visible = false
		set_deferred("monitoring", false)
		
		match type:
			ItemType.COIN:
				GameManager.add_coins(value)
			ItemType.KEY:
				GameManager.add_keys(value)
			ItemType.HEALTH_POTION:
				if body.has_method("recover_health"):
					body.recover_health(value)
			ItemType.MANA_POTION:
				if body.has_method("recover_mana"):
					body.recover_mana(value)
		
		queue_free()
