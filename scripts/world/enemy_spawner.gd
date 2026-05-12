extends Marker2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
@export var spawn_on_ready: bool = true
@export var spawn_delay: float = 1.0

func _ready() -> void:
	if spawn_on_ready:
		if spawn_delay > 0:
			await get_tree().create_timer(spawn_delay).timeout
		spawn_enemy()

func spawn_enemy() -> Enemy:
	if not enemy_scene:
		push_warning("EnemySpawner: No enemy scene assigned")
		return null
		
	var enemy = enemy_scene.instantiate()
	if enemy is Enemy:
		enemy.base_element = element
		get_parent().add_child.call_deferred(enemy)
		enemy.global_position = global_position
		return enemy
	else:
		enemy.queue_free()
		push_error("EnemySpawner: Assigned scene is not an Enemy")
		return null
