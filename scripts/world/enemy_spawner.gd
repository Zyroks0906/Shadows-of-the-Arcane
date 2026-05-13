extends Marker2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var random_pool: Array[PackedScene] = []
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
@export var spawn_on_ready: bool = true
@export var spawn_delay: float = 1.0

func _ready() -> void:
	if spawn_on_ready:
		if spawn_delay > 0:
			await get_tree().create_timer(spawn_delay).timeout
		spawn_enemy()

func spawn_enemy() -> Enemy:
	var scene_to_spawn = enemy_scene

	if not random_pool.is_empty():
		scene_to_spawn = random_pool.pick_random()

	if not scene_to_spawn:
		push_warning("EnemySpawner: No enemy scene assigned and random pool is empty")
		return null

	var enemy = scene_to_spawn.instantiate()
	if enemy is Enemy:
		var is_slime = enemy.character_name.to_lower().contains("slime")

		if is_slime:
			var elements = [
				ElementalSystem.Element.PYRO,
				ElementalSystem.Element.HYDRO,
				ElementalSystem.Element.ELECTRO,
				ElementalSystem.Element.CRYO,
				ElementalSystem.Element.ANEMO,
				ElementalSystem.Element.GEO
			]
			enemy.base_element = elements.pick_random()
		else:
			enemy.base_element = ElementalSystem.Element.NONE

		enemy.position = position
		get_parent().add_child.call_deferred(enemy)
		return enemy
	else:
		enemy.queue_free()
		push_error("EnemySpawner: Assigned scene is not an Enemy")
		return null
