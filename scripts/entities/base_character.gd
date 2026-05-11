extends CharacterBody2D
class_name BaseCharacter

@export var character_name: String = "Character"
@export var level: int = 1
@export var max_health: int = 100
@export var max_mana: int = 50
@export var strength: int = 10
@export var intelligence: int = 10
@export var resistance: int = 8
@export var wisdom: int = 8

var base_scale: Vector2 = Vector2(1.0, 1.0)

var current_health: int
var current_mana: int
var is_alive: bool = true

@export var base_element: ElementalSystem.Element = ElementalSystem.Element.NONE
var current_imbued_element: ElementalSystem.Element = ElementalSystem.Element.NONE

func _ready() -> void:
	max_health = 100 + (level * 10)

	current_health = max_health
	max_mana = 50 + (level * 5)
	current_mana = max_mana

func receive_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		die()

func die() -> void:
	is_alive = false
	queue_free()

func recover_health(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)

func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

func recover_mana(amount: int) -> void:
	current_mana = clampi(current_mana + amount, 0, max_mana)
