extends Node2D
class_name BossReward

# Reward chests that stay hidden until `boss_name` is defeated, then rise into view one by
# one, so a boss room never shows its loot before the fight.

@export var boss_name: String = ""

func _ready() -> void:
	_hide_all.call_deferred()
	GameManager.boss_defeated.connect(_on_boss_defeated)

func _hide_all() -> void:
	for c in get_children():
		c.visible = false
		var a := c.get_node_or_null("Area2D") as Area2D
		if a:
			a.monitoring = false
			a.monitorable = false

func _on_boss_defeated(n: String) -> void:
	if n != boss_name:
		return
	await get_tree().create_timer(1.2).timeout
	for c in get_children():
		if not is_instance_valid(c):
			continue
		c.visible = true
		var a := c.get_node_or_null("Area2D") as Area2D
		if a:
			a.monitoring = true
			a.monitorable = true
		c.scale = Vector2(0.2, 0.2)
		c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		CombatFX.shockwave(c.global_position, Color(1.0, 0.85, 0.4), 18.0, 0.35, 2.0)
		CombatFX.burst(c.global_position, Color(1.0, 0.85, 0.4), 16, 50.0, 0.5, -40.0, 1.5)
		AudioManager.play_bank_at("teleport", c.global_position, -4.0, 1.1)
		await get_tree().create_timer(0.35).timeout
