extends Area2D

enum ItemType { COIN, KEY, HEALTH_POTION, MANA_POTION, SILVER_KEY, GOLDEN_KEY }
@export var type: ItemType = ItemType.COIN
@export var value: int = 1

# What the pickup banner says about each item.
const INFO := {
	ItemType.KEY: ["Bronze Key", "Opens a common locked door.", Color(0.85, 0.6, 0.3)],
	ItemType.SILVER_KEY: ["Silver Key", "Opens the doors barred in silver.", Color(0.8, 0.85, 0.95)],
	ItemType.GOLDEN_KEY: ["Golden Key", "Opens the way to this place's master.", Color(1.0, 0.82, 0.3)],
	ItemType.HEALTH_POTION: ["Health Potion", "Press C to drink: restores 30 HP.", Color(0.95, 0.35, 0.35)],
	ItemType.MANA_POTION: ["Mana Potion", "Press V to drink: restores 20 MP.", Color(0.4, 0.6, 1.0)],
}

var is_collected: bool = false
var _pickup_after_ms: int = 0
var _thrown := false # pop_out picks its own landing

func _ready() -> void:
	add_to_group("interactable")
	if type in [ItemType.KEY, ItemType.SILVER_KEY, ItemType.GOLDEN_KEY]:
		add_to_group("collectible_key")
	if type == ItemType.COIN:
		add_to_group("collectible_coin")
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	monitoring = true
	monitorable = true
	_attach_shadow.call_deferred()
	_settle_on_floor.call_deferred()
	# Harder difficulties find fewer potions (Extreme: none). Decided once, when it appears.
	if type in [ItemType.HEALTH_POTION, ItemType.MANA_POTION] and randf() >= SettingsManager.diff("potions"):
		_item_root().queue_free.call_deferred()

var _shadow: GroundShadow
var _shadow_y: float = 0.0

func _attach_shadow() -> void:
	if is_inside_tree() and not _shadow:
		_shadow = GroundShadow.attach(_item_root(), 0.0, 0.8)
		_shadow_y = _shadow.position.y

# While the item flies, its shadow stays on the floor and shrinks with the height.
func _set_height(h: float) -> void:
	if _shadow:
		_shadow.position.y = _shadow_y + h
		_shadow.scale = Vector2.ONE * clampf(1.0 - h / 40.0, 0.4, 1.0)

func interact(player_node: Node2D) -> void:
	_collect(player_node)

func _physics_process(_delta: float) -> void:
	if is_collected or not monitoring or Time.get_ticks_msec() < _pickup_after_ms:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_collect(body)
			return
	for area in get_overlapping_areas():
		var parent = area.get_parent()
		if parent and parent.is_in_group("player"):
			_collect(parent)
			return

# The node that is the visible item (scenes are Node2D root > Sprite + this Area2D).
func _item_root() -> Node2D:
	var p := get_parent()
	if p is Node2D and p.get_node_or_null("AnimatedSprite2D"):
		return p
	return self

# Thrown out of a chest: flies in an arc from `from` to `to`, bounces twice, and can only be
# picked up a moment after it settles, so the player sees what dropped.
# `ground`: a floor point the thrower stands on, when `from` is up in its art (the crucible's
# basin hangs over the wall behind it): the landing must be reachable from there.
func pop_out(from: Vector2, to: Vector2, delay: float = 0.0, ground: Vector2 = Vector2.INF) -> void:
	var root := _item_root()
	_thrown = true
	to = _safe_landing(root, from if ground == Vector2.INF else ground, to)
	set_deferred("monitoring", false)
	root.global_position = from
	root.visible = false
	var tw := root.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): root.visible = true)
	var flight := 0.45
	tw.tween_method(func(t: float):
		var h := 26.0 * 4.0 * t * (1.0 - t)
		root.global_position = from.lerp(to, t) + Vector2(0, -h)
		_set_height(h), 0.0, 1.0, flight)
	tw.tween_callback(_set_height.bind(0.0))
	tw.tween_callback(func(): AudioManager.play_bank_at("item", to, -10.0, 1.2))
	tw.tween_property(root, "global_position", to + Vector2(0, -5), 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "global_position", to, 0.09).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "global_position", to + Vector2(0, -1.5), 0.05)
	tw.tween_property(root, "global_position", to, 0.05)
	tw.tween_callback(func():
		_pickup_after_ms = Time.get_ticks_msec() + 400
		monitoring = true)

# Where a thrown item may land: short of anything solid on the way (walls, crystals, props
# on physics layer 1) and never inside it, so the player can always reach it.
func _safe_landing(root: Node2D, from: Vector2, to: Vector2) -> Vector2:
	if not root.is_inside_tree():
		return to
	var space := root.get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1))
	if hit:
		to = from.lerp(hit["position"], 0.75)
	return _free_spot(root, to, from)

# A spot the player can stand on and reach: on the map's ground and not inside anything
# solid (walls, crystals, props on physics layer 1). The spot itself, else the nearest of
# a few rings around it. With `seen_from`, only spots with nothing solid in between (never
# the room on the other side of a wall).
static func _free_spot(root: Node2D, at: Vector2, seen_from: Vector2 = Vector2.INF) -> Vector2:
	var space := root.get_world_2d().direct_space_state
	var ground := MapBounds.ground_layers(root)
	var probe := PhysicsPointQueryParameters2D.new()
	probe.collision_mask = 1
	for r in [0.0, 6.0, 10.0, 14.0, 20.0, 28.0, 36.0, 48.0]:
		for k in (1 if r == 0.0 else 12):
			var p: Vector2 = at + Vector2.RIGHT.rotated(TAU * k / 12.0) * r
			if not ground.is_empty() and not MapBounds.on_map(ground, p):
				continue
			var clear := true
			for d in [Vector2.ZERO, Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3)]:
				probe.position = p + d
				if not space.intersect_point(probe, 1).is_empty():
					clear = false
					break
			if clear and seen_from != Vector2.INF:
				clear = space.intersect_ray(PhysicsRayQueryParameters2D.create(seen_from, p, 1)).is_empty()
			if clear:
				return p
	return at

# Placed by hand or by a generator, an item can end up in a wall or past the edge of the
# floor (the coins on level 2's west wall). Once physics is up it steps onto open ground.
func _settle_on_floor() -> void:
	var root := _item_root()
	if not is_inside_tree() or not root.visible or _thrown:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(root) or not root.visible or is_collected or _thrown:
		return
	root.global_position = _free_spot(root, root.global_position)

func _icon() -> Texture2D:
	var spr := _item_root().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr and spr.sprite_frames:
		return spr.sprite_frames.get_frame_texture(spr.animation, 0)
	return null

func _collect(_player_node: Node2D) -> void:
	if is_collected or Time.get_ticks_msec() < _pickup_after_ms or not _item_root().visible:
		return
	is_collected = true

	var icon := _icon()
	var where := _item_root().global_position
	if get_parent():
		get_parent().visible = false
	visible = false

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	match type:
		ItemType.COIN:
			value = maxi(1, roundi(value * (1.0 + Progression.value("greed") / 100.0) * SettingsManager.diff("coins")))
			GameManager.add_coins(value)
			Progression.stat("coins", value)
			AudioManager.play_bank("coin", -4.0)
			CombatFX.floating_label(where, "+%d" % value, Color(1.0, 0.85, 0.3), 0.7)
		ItemType.KEY:
			GameManager.add_keys(value)
		ItemType.SILVER_KEY:
			GameManager.add_silver_key(value)
		ItemType.GOLDEN_KEY:
			GameManager.add_golden_key(value)
		ItemType.HEALTH_POTION:
			GameManager.add_health_potion(value)
		ItemType.MANA_POTION:
			GameManager.add_mana_potion(value)

	if INFO.has(type):
		var info: Array = INFO[type]
		var desc: String = info[1]
		if type == ItemType.MANA_POTION and _player_node is Player and not _player_node.uses_mana:
			desc = "No use to you: trade it for health at a Transmuter."
		ItemBanner.show_item(info[0], desc, info[2], icon)
		if type in [ItemType.HEALTH_POTION, ItemType.MANA_POTION]:
			AudioManager.play_bank("bottle", -4.0, 1.0)
		else:
			AudioManager.play_bank("chain", -2.0, 1.2)
			AudioManager.play_bank("gem", -6.0, 1.0)
		CombatFX.burst(where, info[2], 12, 50.0, 0.4, -40.0, 1.5)

	_item_root().queue_free()
