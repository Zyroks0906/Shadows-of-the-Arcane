extends Node2D
class_name ElementBadge

# Small element icon floating over a character's head (Genshin style): tells the player at
# a glance which element a creature carries, so reactions can be planned. Replaces the old
# looping "spike from the ground" auras.

const ICONS := {
	ElementalSystem.Element.PYRO: preload("res://assets/sprites/elements/icon_pyro.png"),
	ElementalSystem.Element.HYDRO: preload("res://assets/sprites/elements/icon_hydro.png"),
	ElementalSystem.Element.ELECTRO: preload("res://assets/sprites/elements/icon_electro.png"),
	ElementalSystem.Element.CRYO: preload("res://assets/sprites/elements/icon_cryo.png"),
	ElementalSystem.Element.ANEMO: preload("res://assets/sprites/elements/icon_anemo.png"),
	ElementalSystem.Element.GEO: preload("res://assets/sprites/elements/icon_geo.png"),
}
const WORLD_SIZE := 8.0 # px the icon occupies in the world

var _sprite: Sprite2D
var _t: float = 0.0
var _element: ElementalSystem.Element = ElementalSystem.Element.NONE

# Creates a badge on `host`, `head_height` world px above its origin.
static func attach(host: Node2D, head_height: float) -> ElementBadge:
	var b := ElementBadge.new()
	b.name = "ElementBadge"
	host.add_child(b)
	var s := host.global_scale
	b.scale = Vector2(1.0 / maxf(absf(s.x), 0.01), 1.0 / maxf(absf(s.y), 0.01))
	b.position = Vector2(0, -head_height) * b.scale
	return b

# Distance from the host's origin up to the top of its visible sprite (opaque pixels).
static func head_height_of(host: Node2D, sprite: AnimatedSprite2D) -> float:
	if not sprite or not sprite.sprite_frames:
		return 16.0
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not tex:
		return 16.0
	var img := tex.get_image()
	if not img:
		return 16.0
	if img.is_compressed():
		img.decompress()
	var top_px := float(img.get_used_rect().position.y) - (img.get_height() / 2.0 if sprite.centered else 0.0) + sprite.offset.y
	var top_world := sprite.global_position.y + top_px * absf(sprite.global_scale.y) - host.global_position.y
	return -top_world + 3.0

func _ready() -> void:
	z_index = 60
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * (WORLD_SIZE / 26.0)
	add_child(_sprite)
	visible = false

func set_element(el: ElementalSystem.Element) -> void:
	if el == _element:
		return
	_element = el
	if not ICONS.has(el):
		visible = false
		return
	_sprite.texture = ICONS[el]
	visible = true
	# Pop in so a newly applied element is noticed.
	_sprite.scale = Vector2.ONE * (WORLD_SIZE / 26.0) * 1.8
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE * (WORLD_SIZE / 26.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 1.0
	_sprite.modulate.a = 0.85 + sin(_t * 4.0) * 0.15
