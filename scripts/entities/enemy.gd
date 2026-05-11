extends BaseCharacter
class_name Enemy

@export var attack_element: ElementalSystem.Element = ElementalSystem.Element.HYDRO
@export var contact_damage: int = 5

func _ready() -> void:
	super._ready()
	add_to_group("enemies")

	pass

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		_apply_contact_effect(body)

func _apply_contact_effect(player: Player) -> void:
	if player.has_method("take_elemental_hit"):
		player.take_elemental_hit(contact_damage, attack_element)
		print("Enemigo aplica: ", ElementalSystem.get_element_name(attack_element))
