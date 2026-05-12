extends Area2D

enum ItemType { COIN, KEY, HEALTH_POTION, MANA_POTION, SILVER_KEY, GOLDEN_KEY }
@export var type: ItemType = ItemType.COIN
@export var value: int = 1

var is_collected: bool = false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 0xFFFFFFFF 
	monitoring = true
	monitorable = true

func interact(player_node: Node2D) -> void:
	_collect(player_node)

func _physics_process(_delta: float) -> void:
	if is_collected or not monitoring: return
	
	for body in get_overlapping_bodies():
		if body.is_in_group("player") or body.name.to_lower().contains("player") or body is CharacterBody2D:
			_collect(body)
			return
	for area in get_overlapping_areas():
		var parent = area.get_parent()
		if parent and (parent.is_in_group("player") or parent is CharacterBody2D):
			_collect(parent)
			return

func _collect(player_node: Node2D) -> void:
	if is_collected: return
	is_collected = true
	
	if get_parent():
		get_parent().visible = false
	visible = false
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	print("!!! OBJETO RECOGIDO POR CONTACTO TOTAL: ", type, " !!!")
	
	match type:
		ItemType.COIN:
			GameManager.add_coins(value)
		ItemType.KEY:
			GameManager.add_keys(value)
		ItemType.HEALTH_POTION:
			GameManager.add_health_potion(value)
			if player_node.has_method("recover_health"):
				player_node.recover_health(value)
		ItemType.MANA_POTION:
			GameManager.add_mana_potion(value)
			if player_node.has_method("recover_mana"):
				player_node.recover_mana(value)
		ItemType.SILVER_KEY:
			GameManager.add_silver_key(value)
		ItemType.GOLDEN_KEY:
			GameManager.add_golden_key(value)
	
	queue_free()
