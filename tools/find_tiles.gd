extends Node
# Lists cells of level_1 that use the FG_Cellar_Doors atlas (doors, hatches). Dev helper.
func _ready() -> void:
	var level: Node = load("res://scenes/levels/level_1.tscn").instantiate()
	for n in level.find_children("*", "TileMapLayer", true, false):
		var l := n as TileMapLayer
		print("LAYER ", l.name, " cells ", l.get_used_cells().size(), " sources ", l.tile_set.get_source_count() if l.tile_set else -1)
		for c in l.get_used_cells():
			var src := l.get_cell_source_id(c)
			if src < 0 or not l.tile_set.has_source(src):
				continue
			var s := l.tile_set.get_source(src) as TileSetAtlasSource
			var w := l.to_global(l.map_to_local(c))
			if w.x > 820 and w.x < 880 and w.y > 550 and w.y < 600:
				print(l.get_path(), " cell ", c, " atlas ", l.get_cell_atlas_coords(c), " world ", l.to_global(l.map_to_local(c)))
	for n in level.find_children("*", "Node2D", true, false):
		var p: Vector2 = n.global_position
		if p.x > 780 and p.x < 1000 and p.y > 540 and p.y < 660:
			print("NODE ", level.get_path_to(n), " ", n.get_class(), " ", p, " ", n.scene_file_path)
	level.free()
	get_tree().quit()
