extends Area2D

@export var speed: float = 250.0
@export var damage_percent: float = 0.15 # 15% de daño de la salud maxima
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.get("current_health") != null and body.get("is_alive") != null:
			if body.get("current_health") > 0 and body.get("is_alive") != false:
				if body.has_method("receive_damage"):
					var damage = int(body.max_health * damage_percent)
					if damage <= 0: damage = 1
					body.receive_damage(damage)
		queue_free()
	elif body is TileMap or body.is_in_group("world"):
		queue_free()
