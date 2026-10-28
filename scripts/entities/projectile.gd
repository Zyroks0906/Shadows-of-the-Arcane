extends Area2D

@export var speed: float = 500.0
@export var damage: int = 10
@export var element: ElementalSystem.Element = ElementalSystem.Element.NONE
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var knockback_force: float = 90.0
# Light guidance towards the aim-assist target, only right after release (dodgeable).
var homing_target: Node2D = null
var hit_kind: String = "basic" # what the owner counts this hit as (energy)
# Played where the projectile lands.
var impact_sfx: Array = []
var homing_rate_deg: float = 60.0
var homing_time: float = 0.25
var _age: float = 0.0
# Pierce: flies through enemies (each is hit once) and only stops at walls.
var pierce: bool = false
# Called with the final position when the projectile stops (wall or end of range).
var on_end: Callable
var _hit: Dictionary = {}
var _ended: bool = false

func _ready() -> void:
	GroundShadow.attach_flying(self, 9.0, 3.5)
	get_tree().create_timer(lifetime).timeout.connect(_end)

	body_entered.connect(_on_body_entered)

	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age <= homing_time and is_instance_valid(homing_target):
		var want := (homing_target.global_position - global_position).normalized()
		var max_turn := deg_to_rad(homing_rate_deg) * delta
		direction = direction.rotated(clampf(direction.angle_to(want), -max_turn, max_turn))
		rotation = direction.angle()
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		return

	if body.is_in_group("enemies"):
		if _hit.has(body):
			return
		_hit[body] = true
		if body.has_method("take_elemental_hit"):
			body.take_elemental_hit(damage, element, source)
			if is_instance_valid(source) and source.has_method("on_hit_landed"):
				source.on_hit_landed(hit_kind)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction * knockback_force)
		CombatFX.burst(global_position, ElementalSystem.get_element_color(element), 6, 60.0, 0.25)
		if pierce:
			_play_impact_sfx()
			return

	_play_impact_sfx()
	_end()

func _end() -> void:
	if _ended:
		return
	_ended = true
	if on_end.is_valid():
		on_end.call(global_position)
	queue_free()

# impact_sfx: layers [SoundBank category, volume_db, pitch].
func _play_impact_sfx() -> void:
	for l in impact_sfx:
		AudioManager.play_bank_at(l[0], global_position, l[1], l[2])
