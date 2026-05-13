extends Area2D

enum ItemType { COIN, KEY, HEALTH_POTION, MANA_POTION, SILVER_KEY, GOLDEN_KEY }
@export var type: ItemType = ItemType.COIN
@export var value: int = 1

var is_collected: bool = false

func _ready() -> void:
	add_to_group("interactable")
	if type in [ItemType.KEY, ItemType.SILVER_KEY, ItemType.GOLDEN_KEY]:
		add_to_group("collectible_key")
	if type == ItemType.COIN:
		add_to_group("collectible_coin")
	collision_layer = 0
	collision_mask = 0xFFFFFFFF 
	monitoring = true
	monitorable = true

func interact(player_node: Node2D) -> void:
	_collect(player_node)

func _physics_process(_delta: float) -> void:
	if is_collected or not monitoring: return
	
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_collect(body)
			return
	for area in get_overlapping_areas():
		var parent = area.get_parent()
		if parent and parent.is_in_group("player"):
			_collect(parent)
			return

func _collect(_player_node: Node2D) -> void:
	if is_collected: return
	is_collected = true
	
	if get_parent():
		get_parent().visible = false
	visible = false
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	match type:
		ItemType.COIN:
			GameManager.add_coins(value)
			AudioManager.play_sfx("res://assets/audio/sfx/Items/coin_collect.wav")
		ItemType.KEY:
			GameManager.add_keys(value)
			AudioManager.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")
		ItemType.SILVER_KEY:
			GameManager.add_silver_key(value)
			AudioManager.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")
		ItemType.GOLDEN_KEY:
			GameManager.add_golden_key(value)
			AudioManager.play_sfx("res://assets/audio/sfx/Environment/lock_unlock.wav")
		ItemType.HEALTH_POTION:
			GameManager.add_health_potion(value)
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Items/gem_collect.wav", 0.0, 1.2)
		ItemType.MANA_POTION:
			GameManager.add_mana_potion(value)
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play_sfx("res://assets/audio/sfx/Items/gem_collect.wav", 0.0, 0.8)
	
	queue_free()
