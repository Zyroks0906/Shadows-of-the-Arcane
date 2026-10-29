extends Marker2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var random_pool: Array[PackedScene] = []
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
## Elements a random-element enemy may roll. Empty = any element.
@export var element_pool: Array[ElementalSystem.Element] = []
@export var spawn_on_ready: bool = true
@export var spawn_delay: float = 1.0
## Always an elite (a random affix), e.g. the second wave of an ambush room.
@export var elite: bool = false

func _ready() -> void:
	if spawn_on_ready:
		if spawn_delay > 0:
			await get_tree().create_timer(spawn_delay).timeout
		spawn_enemy()

# summon = true (arena waves): the creature materialises out of a dark rune instead of
# just popping in, and can't attack until it has fully appeared.
func spawn_enemy(summon: bool = false) -> Enemy:
	var scene_to_spawn = enemy_scene

	if not random_pool.is_empty():
		scene_to_spawn = random_pool.pick_random()

	if not scene_to_spawn:
		push_warning("EnemySpawner: No enemy scene assigned and random pool is empty")
		return null

	var enemy = scene_to_spawn.instantiate()
	if enemy is Enemy:
		var is_slime = enemy.character_name.to_lower().contains("slime")

		if is_slime or enemy.random_element:
			var elements = [
				ElementalSystem.Element.PYRO,
				ElementalSystem.Element.HYDRO,
				ElementalSystem.Element.ELECTRO,
				ElementalSystem.Element.CRYO,
				ElementalSystem.Element.ANEMO,
				ElementalSystem.Element.GEO
			]
			enemy.base_element = element_pool.pick_random() if not element_pool.is_empty() else elements.pick_random()
		else:
			enemy.base_element = ElementalSystem.Element.NONE

		enemy.position = position
		if summon:
			enemy.tree_entered.connect(_materialise.bind(enemy), CONNECT_ONE_SHOT)
		enemy.force_elite = elite
		get_parent().add_child.call_deferred(enemy)
		return enemy
	else:
		enemy.queue_free()
		push_error("EnemySpawner: Assigned scene is not an Enemy")
		return null

func _materialise(enemy: Enemy) -> void:
	CombatFX.shockwave(global_position, Color(0.7, 0.4, 1.0), 16.0, 0.35, 2.0)
	CombatFX.burst(global_position, Color(0.6, 0.35, 0.95), 14, 45.0, 0.5, -30.0, 1.5)
	AudioManager.play_bank_at("teleport", global_position, -8.0, 0.75)
	enemy.modulate.a = 0.0
	enemy.can_attack = false
	var tw := enemy.create_tween()
	tw.tween_property(enemy, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func():
		if is_instance_valid(enemy) and enemy.is_alive:
			enemy.can_attack = true)
