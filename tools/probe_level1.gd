extends Node
# Inventory of level_1 decoration: sprite nodes (with texture size) and decoration tile cells.
func _ready() -> void:
	var level: Node = load("res://scenes/levels/level_1.tscn").instantiate()
	var counts := {}
	for n in level.find_children("*", "", true, false):
		var size := Vector2.ZERO
		if n is AnimatedSprite2D and n.sprite_frames:
			var t: Texture2D = n.sprite_frames.get_frame_texture(n.animation, 0)
			if t: size = t.get_size()
		elif n is Sprite2D and n.texture:
			size = n.texture.get_size() if not n.region_enabled else n.region_rect.size
		else:
			continue
		var key := "%s | %s | %s | scale %s" % [n.get_parent().name, n.get_class(), size, n.scale]
		counts[key] = counts.get(key, 0) + 1
	for k in counts:
		print("SPRITE x%d  %s" % [counts[k], k])
	for n in level.find_children("*", "TileMapLayer", true, false):
		var atl := {}
		for c in n.get_used_cells():
			var key := "%d:%s" % [n.get_cell_source_id(c), n.get_cell_atlas_coords(c)]
			atl[key] = atl.get(key, 0) + 1
		print("LAYER ", n.name, " z ", n.z_index, " cells ", n.get_used_cells().size(), " distinct ", atl.size())
		if n.name == "Decorations":
			print("  ", atl)
	level.free()
	get_tree().quit()
