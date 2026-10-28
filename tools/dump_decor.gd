extends Node
# Dev helper: saves every distinct level_1 decoration tile (source:atlas) as one labelled
# sheet, plus whether it has collision, to classify props (solid vs walk-through).
func _ready() -> void:
	var level: Node = load("res://scenes/levels/level_1.tscn").instantiate()
	var layer := level.find_child("Decorations", true, false) as TileMapLayer
	var seen := {}
	var sheet := Image.create(16 * 4 * 12, 16 * 4 * 10, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.2, 0.25))
	var i := 0
	for c in layer.get_used_cells():
		var key := "%d:%s" % [layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c)]
		if seen.has(key):
			continue
		seen[key] = true
		if not layer.tile_set.has_source(layer.get_cell_source_id(c)):
			print("TILE missing source ", key)
			continue
		var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
		var img := src.texture.get_image()
		if img.is_compressed(): img.decompress()
		var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
		var tile := img.get_region(region)
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(64, 64, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(tile, Rect2i(0, 0, 64, 64), Vector2i((i % 12) * 64, (i / 12) * 64))
		var data := layer.get_cell_tile_data(c)
		var solid := data != null and layer.tile_set.get_physics_layers_count() > 0 and data.get_collision_polygons_count(0) > 0
		print("TILE %d %s solid=%s" % [i, key, solid])
		i += 1
	sheet.save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
