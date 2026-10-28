extends Node2D

# Prints how tall every class and enemy stands on screen (opaque pixels of the idle frame,
# in world px), to keep the cast in proportion. Dev helper.
const ENEMIES := ["Skeleton", "slime_base", "Rat", "Bat", "Orc", "Wisp"]

func _ready() -> void:
	EliteAffix.enabled = false
	var level: Node = load("res://scenes/levels/level_2.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(1.5).timeout
	var p := get_tree().get_first_node_in_group("player") as Node2D
	for cls in GameManager.CharacterClass.values():
		GameManager.set_selected_class(cls)
	for e in ENEMIES:
		var n: Node2D = load("res://scenes/entities/Enemies/%s.tscn" % e).instantiate()
		n.detection_range = 0
		level.add_child(n)
		n.global_position = p.global_position + Vector2(400, 400)
	await get_tree().create_timer(0.5).timeout
	for n in get_tree().get_nodes_in_group("base_character"):
		var spr := n.get_node_or_null("AnimatedSprite2D") as Node2D
		if spr:
			var m := GroundShadow._measure(spr)
			print("SIZE %-14s h=%.1f w=%.1f" % [n.character_name, (m["foot"].y - m["top"]) * absf(n.scale.y), m["width"] * absf(n.scale.x)])
	get_tree().quit()
