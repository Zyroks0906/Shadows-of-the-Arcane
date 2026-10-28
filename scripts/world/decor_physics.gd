extends Node2D
class_name DecorPhysics

# Makes a level's decoration behave like real objects:
#  - bones and skulls lying on the floor can be walked over and crunch underfoot,
#  - (with `solid_props`) every other floor prop — pots, urns, pillars, sarcophagi — blocks
#    the way like a wall does; things hung on a wall (cobwebs, chains, banners) never block.
# Bones are the Dungeon tileset's (8,6) and (7,7) in source 1 (also what the level builder
# scatters on levels 2 and 3).

const BONES := [Vector2i(8, 6), Vector2i(7, 7)]
const BONE_SOURCE := 1
const CRUNCH_COOLDOWN_MS := 350

static var _last_crunch_ms := 0

static func apply(level: Node, solid_props: bool) -> void:
	for layer in level.find_children("*", "TileMapLayer", true, false):
		if String(layer.name) not in ["Decorations", "Decor", "Decoration"]:
			continue
		var walls := _walls_of(level)
		# Safe to call more than once: each part is done a single time per layer.
		var do_crunch := not layer.has_meta("decor_crunch")
		var do_solid := solid_props and not layer.has_meta("decor_solid")
		layer.set_meta("decor_crunch", true)
		if solid_props:
			layer.set_meta("decor_solid", true)
		for c in layer.get_used_cells():
			var src: int = layer.get_cell_source_id(c)
			if not layer.tile_set.has_source(src):
				layer.erase_cell(c) # stale cells pointing at a tileset that no longer exists
				continue
			var atlas: Vector2i = layer.get_cell_atlas_coords(c)
			var center: Vector2 = layer.to_global(layer.map_to_local(c))
			if src == BONE_SOURCE and atlas in BONES:
				if do_crunch:
					_add_crunch(layer, center)
			elif do_solid and not _hung(walls, layer, c) and not _has_physics(layer, c):
				_add_block(layer, center)

static func _walls_of(level: Node) -> TileMapLayer:
	for name in ["Tileset", "Walls"]:
		var w := level.find_child(name, true, false) as TileMapLayer
		if w:
			return w
	return null

# A prop with a wall tile right above it hangs on that wall.
static func _hung(walls: TileMapLayer, layer: TileMapLayer, c: Vector2i) -> bool:
	if not walls:
		return false
	var above: Vector2 = layer.to_global(layer.map_to_local(c + Vector2i(0, -1)))
	return walls.get_cell_source_id(walls.local_to_map(walls.to_local(above))) != -1

static func _has_physics(layer: TileMapLayer, c: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(c)
	return data != null and layer.tile_set.get_physics_layers_count() > 0 and data.get_collision_polygons_count(0) > 0

static func _add_block(layer: TileMapLayer, center: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6) # the foot of the prop, so you can walk close behind it
	shape.shape = r
	shape.position = Vector2(0, 3)
	body.add_child(shape)
	layer.add_child(body)
	body.global_position = center

static func _add_crunch(layer: TileMapLayer, center: Vector2) -> void:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 1
	a.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	a.add_child(shape)
	layer.add_child(a)
	a.global_position = center
	a.body_entered.connect(func(b: Node2D):
		if b is BaseCharacter and b.is_alive:
			var now := Time.get_ticks_msec()
			if now - _last_crunch_ms > CRUNCH_COOLDOWN_MS:
				_last_crunch_ms = now
				AudioManager.play_bank_at("bones", center, -14.0, randf_range(1.2, 1.5)))
