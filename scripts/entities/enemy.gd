extends BaseCharacter
class_name Enemy

## Elemento que el enemigo aplica al entrar en contacto con el jugador.
@export var attack_element: ElementalSystem.Element = ElementalSystem.Element.HYDRO
## Daño base infligido al jugador por contacto.
@export var contact_damage: int = 5

func _ready() -> void:
	super._ready()
	# La conexión de señales se recomienda hacerla desde el editor de Godot
	# para mantener la visibilidad del flujo, pero el método está listo abajo.
	pass

## Se llama cuando un cuerpo entra en el área de detección del enemigo.
## NOTA: Debes conectar la señal 'body_entered' de un Area2D a esta función en Godot.
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		_apply_contact_effect(body)

## Aplica daño y el elemento correspondiente al jugador.
func _apply_contact_effect(player: Player) -> void:
	if player.has_method("take_elemental_hit"):
		player.take_elemental_hit(contact_damage, attack_element)
		print("Enemigo aplica: ", ElementalSystem.get_element_name(attack_element))
