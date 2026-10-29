extends Area2D
class_name ElementZone

# A patch of the environment that imbues whoever stands in it with an element.
# WATER: shallow water, applies Hydro and slows. WIND: an air current that applies
# Anemo and pushes everyone along `push`. Works on the player and enemies alike, so
# luring enemies into water before an Electro hit is a real tactic.

enum Style { WATER, WIND, EMBERS }

@export var style: Style = Style.WATER
@export var element: ElementalSystem.Element = ElementalSystem.Element.HYDRO
@export var size: Vector2 = Vector2(32, 32)
@export var speed_mult: float = 1.0
@export var push: Vector2 = Vector2.ZERO
@export var tick_interval: float = 0.8

var _t: float = 0.0
var _tick: float = 0.0
var _bodies: Array[BaseCharacter] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 | 4
	z_index = -1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# A puddle is drawn as a blob inside its rect: only its wet middle slows you down.
	rect.size = size * (0.78 if style == Style.WATER else 1.0)
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if style == Style.WATER:
		# The pool itself is a shader (shaders/shallow_water.gdshader): ragged shore, light
		# bands, glints. _draw only adds the drifting ripples on top.
		var pool := ColorRect.new()
		pool.size = size
		pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/shallow_water.gdshader")
		mat.set_shader_parameter("rect_size", size)
		pool.material = mat
		add_child(pool)
		pool.show_behind_parent = true

func _on_body_entered(body: Node2D) -> void:
	var c := body as BaseCharacter
	if not c or _bodies.has(c):
		return
	_bodies.append(c)
	# A character can stand in several touching zones (a current built from two
	# rectangles); each one registers itself and the most recent one applies.
	var zones: Array = c.get_meta("zones", [])
	zones.append(self)
	c.set_meta("zones", zones)
	_apply_to(c)
	if style == Style.WATER:
		CombatFX.burst(c.global_position + Vector2(0, 6), Color(0.6, 0.85, 1.0), 6, 40.0, 0.3, 80.0)
		AudioManager.play_bank_at("slime", c.global_position, -16.0, 1.4)
	_imbue(c)

func _on_body_exited(body: Node2D) -> void:
	var c := body as BaseCharacter
	if not c:
		return
	_bodies.erase(c)
	var zones: Array = c.get_meta("zones", [])
	zones.erase(self)
	zones = zones.filter(func(z): return is_instance_valid(z))
	c.set_meta("zones", zones)
	if zones.is_empty():
		c.terrain_speed_mult = 1.0
		c.external_push = Vector2.ZERO
	else:
		zones[-1]._apply_to(c)

func _apply_to(c: BaseCharacter) -> void:
	c.terrain_speed_mult = speed_mult
	c.external_push = push

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_interval
	for c in _bodies.duplicate():
		if is_instance_valid(c):
			_imbue(c)
		else:
			_bodies.erase(c)

func _imbue(c: BaseCharacter) -> void:
	if not c.is_alive or c.current_imbued_element == element:
		return
	c.take_elemental_hit(0, element, null)

func _draw() -> void:
	match style:
		Style.WATER:
			# Drifting ripple highlights.
			for i in int(size.x * size.y / 220.0):
				var seed_v := float(i) * 12.9898
				var px := fposmod(sin(seed_v) * 43758.5453, 1.0) * size.x
				var py := fposmod(sin(seed_v * 1.7) * 24634.6345, 1.0) * size.y
				var phase := fposmod(_t * 0.6 + fposmod(seed_v, 1.0), 1.0)
				var w := 2.0 + phase * 5.0
				draw_line(Vector2(px - w, py), Vector2(px + w, py), Color(0.7, 0.9, 1.0, 0.38 * (1.0 - phase)), 1.0)
		Style.WIND:
			var dir := push.normalized() if push != Vector2.ZERO else Vector2.RIGHT
			var span := size.dot(dir.abs())
			for i in int(size.x * size.y / 160.0):
				var seed_v := float(i) * 78.233
				var lane := fposmod(sin(seed_v) * 43758.5453, 1.0)
				var travel := fposmod(_t * 0.8 + fposmod(seed_v * 0.37, 1.0), 1.0)
				var along := travel * span
				var across := lane * size.dot(dir.orthogonal().abs())
				var p := dir * along + dir.orthogonal().abs() * across
				if dir.x < 0 or dir.y < 0:
					p += size * dir.abs()
				var alpha := sin(travel * PI) * 0.7
				draw_line(p, p + dir * 10.0, Color(0.8, 1.0, 0.95, alpha), 1.0)
		Style.EMBERS:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.35, 0.1, 0.12 + sin(_t * 2.0) * 0.04))
