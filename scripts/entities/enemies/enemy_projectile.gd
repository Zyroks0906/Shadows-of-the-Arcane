extends Area2D

@export var speed: float = 300.0
@export var damage: int = 15
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		return
	
	if body is Player or body.has_method("take_elemental_hit"):
		body.take_elemental_hit(damage, element)
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free()
