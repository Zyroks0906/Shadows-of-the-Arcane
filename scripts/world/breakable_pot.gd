extends StaticBody2D
class_name BreakablePot

# A clay pot or jar from a level's decoration tiles that can be smashed by any attack.
# It blocks like a prop until it breaks; then it bursts, leaves its sherds on the floor for
# good, and sometimes holds a little something. Loot is kept modest: most pots are empty.

# Pot tiles, by tileset image and atlas cell (see DecorPhysics.apply).
const POT_TILES := {
	# Row 8: whole pots; row 9: the same pots already cracked open (half the loot).
	"decorative.png": [Vector2i(9, 8), Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8),
		Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9)],
	"FG_Cellar.png": [Vector2i(23, 8), Vector2i(24, 8), Vector2i(25, 8), Vector2i(26, 8), Vector2i(27, 8),
		Vector2i(24, 9), Vector2i(25, 9), Vector2i(26, 9), Vector2i(27, 9)],
}
const COIN := "res://assets/sprites/sprite_frames/Coin.tscn"
const HEALTH := "res://scenes/world/HealthPotion.tscn"
const COIN_CHANCE := 0.3 # one coin
const POTION_CHANCE := 0.06 # a health potion (rolled first; never both)

var texture: Texture2D
var region: Rect2
var _broken := false
var cracked := false # already broken open: its leftovers are worth less
var _shake := 0.0

static func is_pot(layer: TileMapLayer, cell: Vector2i) -> bool:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	if not src or not src.texture:
		return false
	var cells: Array = POT_TILES.get(src.texture.resource_path.get_file(), [])
	return layer.get_cell_atlas_coords(cell) in cells

# Swap a pot tile for a breakable pot standing in the same place.
static func from_tile(layer: TileMapLayer, cell: Vector2i) -> BreakablePot:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var p := BreakablePot.new()
	p.texture = src.texture
	p.region = src.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
	p.cracked = layer.get_cell_atlas_coords(cell).y == 9 # both tilesets: row 9 holds the broken ones
	var center := layer.to_global(layer.map_to_local(cell))
	layer.erase_cell(cell)
	layer.add_child(p)
	p.global_position = center
	return p

func _ready() -> void:
	add_to_group("breakables")
	collision_layer = 1 | 4 # blocks like a prop, and attacks find it like an enemy body
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6) # its foot, so you can walk close behind it
	shape.shape = r
	shape.position = Vector2(0, 3)
	add_child(shape)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var off := Vector2(sin(_shake * 90.0) * 1.0, 0.0) if _shake > 0.0 else Vector2.ZERO
	draw_texture_rect_region(texture, Rect2(-region.size / 2.0 + off, region.size), region)

# Any hit breaks it; melee, projectiles and skills all call this.
func receive_damage(_amount: int = 0) -> void:
	break_open(Vector2.ZERO)

func take_elemental_hit(_amount: int, _element = null, _from = null) -> void:
	break_open(Vector2.ZERO)

func break_open(from_dir: Vector2) -> void:
	if _broken:
		return
	_broken = true
	var at := global_position
	var cols := _palette()
	AudioManager.play_bank_at("bottle", at, -4.0, randf_range(0.55, 0.7))
	AudioManager.play_bank_at("stomp", at, -12.0, 1.6)
	CombatFX.burst(at, cols[1], 10, 55.0, 0.35, 90.0, 1.5)
	CombatFX.burst(at + Vector2(0, 2), Color(0.55, 0.5, 0.45, 0.6), 6, 25.0, 0.5, -10.0, 2.0) # dust
	# The sherds stay on the floor (under the characters), scattered away from the blow.
	var sherds := Sherds.new()
	sherds.colors = cols
	sherds.away = from_dir
	get_parent().add_child(sherds)
	sherds.global_position = at + Vector2(0, 4)
	_drop_loot(at)
	queue_free()

func _drop_loot(at: Vector2) -> void:
	var roll := randf() * (2.0 if cracked else 1.0)
	var path := ""
	if roll < POTION_CHANCE:
		path = HEALTH
	elif roll < POTION_CHANCE + COIN_CHANCE:
		path = COIN
	if path == "":
		return
	var item: Node2D = load(path).instantiate()
	get_tree().current_scene.add_child.call_deferred(item)
	item.set_deferred("global_position", at + Vector2(randf_range(-4, 4), 4))

# Dark, mid and light tones of the pot's own pixels, so the sherds match it.
func _palette() -> Array[Color]:
	var img := texture.get_image()
	var lums: Array = []
	if img:
		img = img.get_region(Rect2i(region))
		if img.is_compressed():
			img.decompress()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					lums.append(c)
	if lums.size() < 3:
		return [Color(0.3, 0.18, 0.12), Color(0.6, 0.38, 0.24), Color(0.8, 0.58, 0.4)]
	lums.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return [lums[int(lums.size() * 0.15)], lums[int(lums.size() * 0.5)], lums[int(lums.size() * 0.88)]]


class Sherds extends Node2D:
	var colors: Array[Color] = []
	var away := Vector2.ZERO
	var _pieces: Array = [] # [pos, points, color]

	func _ready() -> void:
		# Same layer as the decoration it came from: over the floor, under the characters.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in rng.randi_range(6, 8):
			var dir := Vector2.from_angle(rng.randf() * TAU)
			if away != Vector2.ZERO:
				dir = (dir + away.normalized() * 0.8).normalized()
			var pos := dir * rng.randf_range(2.0, 9.0) * Vector2(1.0, 0.6)
			var s := rng.randf_range(1.5, 3.0)
			var pts := PackedVector2Array()
			var n := rng.randi_range(3, 4)
			var a0 := rng.randf() * TAU
			for k in n:
				pts.append(pos + Vector2.from_angle(a0 + TAU * k / n + rng.randf_range(-0.4, 0.4)) * s * rng.randf_range(0.6, 1.0))
			_pieces.append([pos, pts, colors[rng.randi_range(0, 1)]])
		queue_redraw()

	func _draw() -> void:
		for p in _pieces:
			var pts: PackedVector2Array = p[1]
			var col: Color = p[2]
			# A soft shadow, the sherd, and a glazed lip catching the light.
			var shadow := PackedVector2Array()
			for q in pts:
				shadow.append(q + Vector2(0, 1))
			draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
			draw_colored_polygon(pts, col)
			draw_line(pts[0], pts[1], colors[2], 1.0)
