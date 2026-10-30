extends Node2D
class_name Chest

# Opening is a small event: the chest rattles, the lid swings open (~0.6 s), light spills
# out and every reward is thrown out onto the floor where the player can see it before
# picking it up. Nothing is added to the inventory behind the player's back.

@export var require_interaction: bool = true
@export var key_amount: int = 0
@export var coins_amount: int = 0
@export var hidden_item: Node2D
## Extra pickups thrown out with the rest (scene paths), e.g. a potion after an arena.
@export var bonus_items: Array[String] = []
## Sealed chest: costs this many coins to open and offers a perk choice of at least
## `perk_min_rarity` (Progression.Rarity). 0 = an ordinary chest.
@export var coin_cost: int = 0
@export var perk_min_rarity: int = 2
## Offers a perk choice when opened, without a price (boss rewards).
@export var free_perk: bool = false

const OPEN_TIME := 0.6
const COIN_SCENE := "res://assets/sprites/sprite_frames/Coin.tscn"
const MAX_COIN_DROPS := 5

var is_opened: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D

func _ready() -> void:
	if coin_cost > 0:
		var tag := _PriceTag.new()
		tag.cost = coin_cost
		tag.position = Vector2(0, -10)
		add_child(tag)
		if sprite:
			sprite.modulate = Color(1.15, 1.0, 0.7)
	if area:
		area.body_entered.connect(_on_body_entered)
	if hidden_item:
		call_deferred("_prepare_hidden_item")

func _prepare_hidden_item() -> void:
	if hidden_item:
		hidden_item.visible = false
		_set_item_collision(hidden_item, false)

func _on_body_entered(body: Node2D) -> void:
	if not require_interaction:
		open_chest(body)

func interact(body: Node2D) -> void:
	open_chest(body)

func open_chest(body: Node2D) -> void:
	_opener = body
	if is_opened or not (body is Player):
		return
	if locked_reason != "":
		_say(locked_reason)
		AudioManager.play_bank("ui_error", -6.0)
		return
	if coin_cost > 0:
		if GameManager.total_coins < coin_cost:
			_say("Sealed: it takes %d coins to break the seal (you have %d)." % [coin_cost, GameManager.total_coins])
			CombatFX.floating_label(global_position + Vector2(0, -14), "%d COINS" % coin_cost, Color(1.0, 0.8, 0.3), 0.9)
			AudioManager.play_bank("ui_error", -6.0)
			return
		GameManager.total_coins -= coin_cost
		AudioManager.play_bank("coin", 0.0, 0.8)
		for c in get_children():
			if c is _PriceTag:
				c.queue_free()
	is_opened = true
	AudioManager.play_bank_at("creak", global_position, 0.0, 1.0)
	AudioManager.play_bank_at("lock", global_position, -4.0, 0.9)

	# Rattle, then the lid opens at a readable pace.
	var shake := create_tween()
	for i in 4:
		shake.tween_property(self, "rotation", 0.06 * (1 if i % 2 == 0 else -1), 0.04)
	shake.tween_property(self, "rotation", 0.0, 0.04)
	await shake.finished
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		var n := sprite.sprite_frames.get_frame_count("default")
		var fps := maxf(sprite.sprite_frames.get_animation_speed("default"), 0.01)
		sprite.speed_scale = (n / fps) / OPEN_TIME
		sprite.play("default")
	await get_tree().create_timer(OPEN_TIME).timeout

	CombatFX.burst(global_position + Vector2(0, -4), Color(1.0, 0.85, 0.4), 18, 55.0, 0.6, -50.0, 1.5)
	AudioManager.play_bank_at("gem", global_position, -4.0, 0.9)
	_drop_rewards()
	if coin_cost > 0 or free_perk:
		await get_tree().create_timer(0.5).timeout
		if Progression.auto_pick:
			Progression.take(Progression.roll(3, perk_min_rarity)[0])
		else:
			PerkPicker.offer("SEALED CHEST" if coin_cost > 0 else "TREASURE", Progression.roll(3, perk_min_rarity))
		# Sealed chests sometimes hold a relic too.
		if coin_cost > 0 and randf() < 0.35:
			Relics.grant(Relics.roll())

var _opener: Node2D
# Set by puzzles: while not empty the chest won't open and says why.
var locked_reason: String = ""

func _drop_rewards() -> void:
	var from := global_position + Vector2(0, -6)
	var drops := []
	if hidden_item:
		drops.append(_collectible_of(hidden_item))
	# Coins come out as a few heavier coins rather than a dozen tiny ones.
	if coins_amount > 0 and ResourceLoader.exists(COIN_SCENE):
		var count := mini(coins_amount, MAX_COIN_DROPS)
		var each := coins_amount / count
		var rest := coins_amount - each * count
		for i in count:
			var coin: Node2D = load(COIN_SCENE).instantiate()
			get_parent().add_child(coin)
			var c := _collectible_of(coin)
			if c:
				c.value = each + (1 if i < rest else 0)
			drops.append(c)
	for path in bonus_items:
		if ResourceLoader.exists(path):
			var b: Node2D = load(path).instantiate()
			get_parent().add_child(b)
			drops.append(_collectible_of(b))
	if key_amount > 0:
		GameManager.add_keys(key_amount)
		ItemBanner.show_item("Bronze Key", "Opens a common locked door.", Color(0.85, 0.6, 0.3))
	var i := 0
	for d in drops:
		if not d:
			continue
		# The loot fans out towards whoever opened the chest, landing in front of them.
		var facing := PI * 0.5
		if is_instance_valid(_opener):
			facing = (_opener.global_position - global_position).angle()
		var spread := deg_to_rad(110.0)
		var angle := facing - spread / 2.0 + spread * (i + 0.5) / maxf(drops.size(), 1.0)
		var dist := randf_range(14.0, 22.0)
		var to := _safe_landing(from, from + Vector2.RIGHT.rotated(angle) * dist)
		d.pop_out(from, to, i * 0.08)
		i += 1

# Shortens the throw if a wall is in the way so nothing lands inside the scenery.
func _safe_landing(from: Vector2, to: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		return from.lerp(hit["position"], 0.7)
	return to

func _collectible_of(item: Node) -> Node:
	if item.has_method("pop_out"):
		return item
	var a := item.get_node_or_null("Area2D")
	if a and a.has_method("pop_out"):
		return a
	return null

func _set_item_collision(item: Node2D, enabled: bool) -> void:
	var target_area = item if item is Area2D else item.get_node_or_null("Area2D")
	if target_area:
		target_area.set_deferred("monitoring", enabled)
		target_area.set_deferred("monitorable", enabled)

func _say(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(text, 3.0)

# Gold padlock with the price floating over a sealed chest.
class _PriceTag extends Node2D:
	const FONT: FontFile = preload("res://assets/fonts/PressStart2P-Regular.ttf")
	var cost: int = 0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y := sin(_t * 3.0) * 1.0
		var gold := Color(1.0, 0.8, 0.3)
		var dark := Color(0.08, 0.05, 0.02)
		var txt := str(cost)
		var tw := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 0.5
		var total := 7.0 + 1.0 + tw
		var x0 := -total / 2.0
		# Padlock.
		draw_arc(Vector2(x0 + 3.5, -3 + y), 2.2, PI, TAU, 8, dark, 2.0)
		draw_arc(Vector2(x0 + 3.5, -3 + y), 2.2, PI, TAU, 8, gold, 1.0)
		draw_rect(Rect2(Vector2(x0, -3 + y), Vector2(7, 5)), dark)
		draw_rect(Rect2(Vector2(x0 + 0.5, -2.5 + y), Vector2(6, 4)), gold)
		draw_rect(Rect2(Vector2(x0 + 3, -1.5 + y), Vector2(1, 2)), dark)
		# Price, drawn at half scale so the pixel font stays crisp.
		draw_set_transform(Vector2(x0 + 8.0, 1.5 + y), 0.0, Vector2(0.5, 0.5))
		draw_string_outline(FONT, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, dark)
		draw_string(FONT, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)
