extends CharacterBody2D
class_name BaseCharacter

# Estadísticas base (Tipado fuerte)
@export var character_name: String = "Character"
@export var level: int = 1
@export var max_health: int = 100
@export var max_mana: int = 50

# Estadísticas del sistema Java
@export var strength: int = 10
@export var intelligence: int = 10
@export var resistance: int = 8
@export var wisdom: int = 8

var current_health: int
var current_mana: int
var is_alive: bool = true

# Elemento propio (si tiene)
@export var base_element: ElementalSystem.Element = ElementalSystem.Element.NONE

# Elemento actual imbuido
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
	queue_free() # O lógica de derrota

func recover_health(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)

func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false

func recover_mana(amount: int) -> void:
	current_mana = clampi(current_mana + amount, 0, max_mana)
