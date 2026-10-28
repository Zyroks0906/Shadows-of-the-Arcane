extends "res://scripts/entities/enemies/golem.gd"

# Skyhold Ruins final boss: the tower's Golem, overcharged with arcane Electro.
# Keeps the Golem's shockwave and tracking laser; at half health it calls the
# tower winds, summoning Anemo wisps that can Swirl its own Electro onto you.

const WISP_SCENE := "res://scenes/entities/Enemies/Wisp.tscn"

var _called_winds: bool = false

func _init_stats() -> void:
	max_health = 750
	resistance = 3
	character_name = "Warden"

func _ready() -> void:
	super._ready()
	base_element = ElementalSystem.Element.ELECTRO
	current_imbued_element = base_element
	speed = 26.0
	attack_damage = 22
	special_attack_cooldown = 4.5
	_setup_elemental_shader()
	_setup_elemental_vfx_aura()
	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = Color(0.7, 0.5, 1.0)
	light.texture_scale = 2.0
	add_child(light)

func receive_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_alive and not _called_winds and current_health < max_health * 0.5:
		_called_winds = true
		mostrar_texto_flotante("TOWER WINDS", Color.AQUAMARINE)
		CombatFX.shockwave(global_position, Color.AQUAMARINE, 90.0, 0.6, 4.0)
		var scene: PackedScene = load(WISP_SCENE)
		for offset in [Vector2(-40, -10), Vector2(40, -10), Vector2(0, 35)]:
			var wisp: Enemy = scene.instantiate()
			wisp.base_element = ElementalSystem.Element.ANEMO
			get_parent().add_child.call_deferred(wisp)
			wisp.set_deferred("global_position", global_position + offset)
