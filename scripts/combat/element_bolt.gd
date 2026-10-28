extends Area2D
class_name ElementBolt

# Slow elemental orb fired by casters. Drawn procedurally so any element works without art.

var element: ElementalSystem.Element = ElementalSystem.Element.NONE
var damage: int = 10
var direction: Vector2 = Vector2.RIGHT
var speed: float = 110.0
var source: Node = null
# Player bolts hit enemies; enemy bolts (the default) hit the player.
var from_player: bool = false
# Light guidance towards the aim-assist target, only right after launch so it stays dodgeable.
var homing_target: Node2D = null
var hit_kind: String = "basic" # what the owner counts this hit as (energy)
# Played where the projectile lands.
var impact_sfx: Array = []
var homing_rate_deg: float = 60.0
var homing_time: float = 0.25
var _age: float = 0.0
# Visual size multiplier (player skill orbs are bigger than basic ones).
var size: float = 1.0
var _color: Color

const LIFETIME := 3.0

static func create(el: ElementalSystem.Element, dmg: int, dir: Vector2, spd: float, src: Node) -> ElementBolt:
	var bolt := ElementBolt.new()
	bolt.element = el
	bolt.damage = dmg
	bolt.direction = dir
	bolt.speed = spd
	bolt.source = src
	return bolt

func _ready() -> void:
	GroundShadow.attach_flying(self, 9.0, 3.5)
	_color = ElementalSystem.get_element_color(element)
	z_index = 20
	collision_layer = 0
	collision_mask = (1 | 4) if from_player else 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0 * size
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

	var light := PointLight2D.new()
	light.texture = LevelAmbience.light_texture()
	light.color = _color
	light.energy = 0.8
	light.texture_scale = 0.35
	add_child(light)

	var trail := CPUParticles2D.new()
	trail.amount = int(14 * size) + 4
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_max = 8.0
	trail.scale_amount_min = 1.0 * size
	trail.scale_amount_max = 2.0 * size
	var ramp := Gradient.new()
	ramp.set_color(0, _color.lightened(0.4))
	ramp.set_color(1, Color(_color, 0.0))
	trail.color_ramp = ramp
	add_child(trail)
	_add_spell_sprite()

# The player's spells use hand-drawn pixel art (StarsteelGaming, CC0): an ice spear for
# Cryo, a fireball for Pyro, a crackling sphere for Electro. Other elements keep the orb.
const SPELL_ART := {
	ElementalSystem.Element.CRYO: ["res://assets/VFX/Spells/ice_spear.png", 6, Vector2(-46, -16)],
	ElementalSystem.Element.PYRO: ["res://assets/VFX/Spells/fireball.png", 9, Vector2(-48, -16)],
	ElementalSystem.Element.ELECTRO: ["res://assets/VFX/Spells/thunder_sphere.png", 8, Vector2(-32, -16)],
}
var _spell: AnimatedSprite2D

func _add_spell_sprite() -> void:
	if not from_player or not SPELL_ART.has(element):
		return
	var art: Array = SPELL_ART[element]
	var tex: Texture2D = load(art[0])
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 16.0)
	for i in int(art[1]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 64, 0, 64, 32)
		sf.add_frame("default", at)
	_spell = AnimatedSprite2D.new()
	_spell.sprite_frames = sf
	_spell.centered = false
	_spell.offset = art[2] # the head of the spell sits on the bolt's position
	_spell.scale = Vector2(0.34, 0.34) * size
	_spell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spell.rotation = direction.angle()
	add_child(_spell)
	_spell.play("default")

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _age <= homing_time and is_instance_valid(homing_target):
		var want := (homing_target.global_position - global_position).normalized()
		var max_turn := deg_to_rad(homing_rate_deg) * delta
		direction = direction.rotated(clampf(direction.angle_to(want), -max_turn, max_turn))
	position += direction * speed * delta
	if _spell:
		_spell.rotation = direction.angle()
	queue_redraw()

func _draw() -> void:
	if _spell:
		draw_circle(Vector2.ZERO, 5.0 * size, Color(_color, 0.18)) # soft glow behind the art
		return
	var pulse := 1.0 + sin(_age * 18.0) * 0.15
	draw_circle(Vector2.ZERO, 6.5 * size * pulse, Color(_color, 0.25))
	draw_circle(Vector2.ZERO, 4.2 * size, Color(_color.darkened(0.4), 1.0))
	draw_circle(Vector2.ZERO, 3.4 * size, _color)
	draw_circle(Vector2(-0.9, -0.9) * size, 1.5 * size, _color.lightened(0.7))

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if not from_player and body.has_method("deflect_projectile") and body.deflect_projectile(self):
		return
	if from_player:
		if body.is_in_group("player"):
			return
		if body.is_in_group("enemies") and body.has_method("take_elemental_hit"):
			body.take_elemental_hit(damage, element, source)
			if is_instance_valid(source) and source.has_method("on_hit_landed"):
				source.on_hit_landed(hit_kind)
			if body.has_method("apply_knockback"):
				body.apply_knockback(direction * 70.0)
	else:
		if body.is_in_group("enemies"):
			return
		if body.is_in_group("player") and body.has_method("take_elemental_hit"):
			body.take_elemental_hit(damage, element, source)
	_play_impact_sfx()
	CombatFX.burst(global_position, _color, int(10 * size), 60.0 * size, 0.3)
	if from_player:
		var kind: String = {ElementalSystem.Element.CRYO: "Ice", ElementalSystem.Element.PYRO: "Fire", ElementalSystem.Element.HYDRO: "Water", ElementalSystem.Element.ANEMO: "Wind", ElementalSystem.Element.GEO: "Earth", ElementalSystem.Element.ELECTRO: "Aether"}.get(element, "")
		if kind != "":
			CombatFX.spike(kind, global_position + Vector2(0, 4), 10.0 * size)
	queue_free()

# impact_sfx: layers [SoundBank category, volume_db, pitch]; empty = by element.
func _play_impact_sfx() -> void:
	if impact_sfx.is_empty():
		var cat := "electric_hit"
		match element:
			ElementalSystem.Element.PYRO: cat = "fire_impact"
			ElementalSystem.Element.CRYO, ElementalSystem.Element.HYDRO: cat = "ice_impact"
		AudioManager.play_bank_at(cat, global_position, -6.0, 1.0)
		return
	for l in impact_sfx:
		AudioManager.play_bank_at(l[0], global_position, l[1], l[2])
