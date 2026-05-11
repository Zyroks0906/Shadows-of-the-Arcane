extends Player
class_name Archer

func _init() -> void:
	character_name = "Archer"
	base_element = ElementalSystem.Element.ANEMO
	max_health = 90
	max_mana = 60
	strength = 12
	intelligence = 10
	resistance = 7
	wisdom = 9
	speed = 220.0
	base_scale = Vector2(0.4, 0.4)
func attack() -> void:
	var arrow_scene = load("res://scenes/Proyectiles/arrow.tscn")
	var arrow = arrow_scene.instantiate()
	
	if arrow.get_script() == null:
		arrow.set_script(load("res://scripts/entities/projectile.gd"))

	arrow.damage = strength
	arrow.element = base_element
	arrow.direction = last_direction.normalized()
	
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	
	print("Arquero dispara flecha de elemento: ", ElementalSystem.get_element_name(base_element))
