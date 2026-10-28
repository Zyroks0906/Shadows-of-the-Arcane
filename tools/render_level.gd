extends Node2D
# Args: scene_path out_png zoom keep_ambience(0/1) [cx cy w h] (optional crop in px)
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node2D = load(args[0]).instantiate()
	var zoom := float(args[2])
	for n in ["HUD", "Spawner"]:
		if level.has_node(n): level.get_node(n).free()
	if args[3] == "0" and level.has_node("Ambience"): level.get_node("Ambience").free()
	var rect := Rect2(0, 0, 1280, 720)
	var floor_layer := level.get_node_or_null("Floor") as TileMapLayer
	if floor_layer:
		var r := floor_layer.get_used_rect()
		rect = Rect2(Vector2(r.position * 16) - Vector2(48, 48), Vector2(r.size * 16) + Vector2(96, 96))
	if args.size() >= 8:
		rect = Rect2(float(args[4]), float(args[5]), float(args[6]), float(args[7]))
	var vp := SubViewport.new()
	vp.size = Vector2i(rect.size * zoom)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.add_child(level)
	var cam := Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = rect.get_center()
	vp.add_child(cam)
	add_child(vp)
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(args[1])
	print("saved ", args[1])
	get_tree().quit()
