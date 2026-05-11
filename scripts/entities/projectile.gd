extends Area2D

@export var speed: float = 500.0
@export var damage: int = 10
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	body_entered.connect(_on_body_entered)
	
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		return
		
	if body.is_in_group("enemies"):
		if body.has_method("take_elemental_hit"):
			body.take_elemental_hit(damage, element)
			print("Proyectil impacta en ", body.name, " con daño ", damage)
	
	queue_free()
