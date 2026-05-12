extends StaticBody2D
class_name Door

enum KeyType { NONE, ANY, SILVER, GOLDEN }

@export var is_open: bool = false
@export var required_key: KeyType = KeyType.NONE
@export var is_tutorial_door: bool = false
@export var lock_after_pass: bool = false

var is_locked: bool = false

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D

func _ready() -> void:
	add_to_group("interactable")
	if is_open:
		open()
	else:
		close()
	
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	
	if is_tutorial_door and not is_open and not is_locked:
		open()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"): return
	
	if lock_after_pass and is_open and not is_locked:
		close()
		is_locked = true
		print("Puerta bloqueada tras el paso del jugador")

func open() -> void:
	if is_locked: return
	
	match required_key:
		KeyType.SILVER:
			if GameManager.silver_keys <= 0:
				print("!!! BLOQUEADO: Se requiere SILVER_KEY. Tienes: ", GameManager.silver_keys)
				return
			GameManager.silver_keys -= 1
		KeyType.GOLDEN:
			if GameManager.golden_keys <= 0:
				print("!!! BLOQUEADO: Se requiere GOLDEN_KEY. Tienes: ", GameManager.golden_keys)
				return
			GameManager.golden_keys -= 1
		KeyType.ANY:
			if GameManager.total_keys <= 0:
				print("!!! BLOQUEADO: Se requiere ANY_KEY. Tienes: ", GameManager.total_keys)
				return
			GameManager.total_keys -= 1
	
	is_open = true
	if collision: collision.set_deferred("disabled", true)
	if sprite: sprite.visible = false
	print("Puerta abierta!")

func close() -> void:
	is_open = false
	if collision: collision.set_deferred("disabled", false)
	if sprite: sprite.visible = true
	print("Puerta cerrada")

func unlock_by_event() -> void:
	is_locked = false
	print("Puerta desbloqueada por evento (Boss derrotado)")
	open()

func interact(_body: Node2D) -> void:
	if is_locked:
		if is_tutorial_door:
			print("La puerta está sellada por una fuerza oscura (Mata al Boss)")
		else:
			print("La puerta está bloqueada por el otro lado")
		return
		
	if not is_open:
		open()
	else:
		print("La puerta ya está abierta")
