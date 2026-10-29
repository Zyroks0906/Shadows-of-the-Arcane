extends Node2D
class_name LevelExit

# The way on to the next chamber, opened by the level boss's death. Three styles:
#   "portal": a rune portal that only appears (rises out of a rift) once the boss falls;
#   "stairs": an existing stairway in the boss room, lit by the exit glow once it is open;
#   "none":   the final chamber: beating its boss is the victory itself, no exit needed.
# Going through (F) unlocks the next chamber and shows the victory screen.

const PORTAL_SHEET := "res://assets/tilesets/Portal/2D Isometric Portal/Isometric_Portal.png"
const FRAME_SIZE := Vector2i(112, 128)
const FRAMES := 6

@export var boss_to_track: String = ""
## Chamber index unlocked when the player walks through (2 = Whispering Caverns...).
@export var unlocks_level: int = 0
@export var glow_color: Color = Color(0.55, 1.0, 0.45)
@export_enum("portal", "stairs", "none") var style: String = "portal"

var active: bool = false
var _sprite: AnimatedSprite2D
var _light: PointLight2D
var _area: Area2D
var _used: bool = false
var _t := 0.0
var _on := 0.0
var _body_col: CollisionShape2D

func _ready() -> void:
	if style == "none":
		if boss_to_track != "":
			GameManager.boss_defeated.connect(_on_boss_defeated)
		return
	_area = Area2D.new()
	_area.collision_layer = 64 # found by the player's interaction area (press F)
	_area.collision_mask = 1 | 2
	var acol := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(24, 22) if style == "stairs" else Vector2(18, 14)
	acol.shape = arect
	acol.position = Vector2.ZERO if style == "stairs" else Vector2(0, 8)
	_area.add_child(acol)
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)
	if style == "stairs":
		_light = ExitGlow.light(glow_color)
		add_child(_light)
		if boss_to_track == "":
			active = true
		else:
			GameManager.boss_defeated.connect(_on_boss_defeated)
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2(0.42, 0.42)
	_sprite.offset = Vector2(0, -40)
	_sprite.play("default")
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.texture = LevelAmbience.light_texture()
	_light.color = glow_color
	_light.texture_scale = 1.8
	_light.position = Vector2(0, -14)
	add_child(_light)

	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 10)
	col.shape = rect
	col.position = Vector2(0, -4)
	body.add_child(col)
	add_child(body)
	_body_col = col

	if boss_to_track == "":
		_activate(false)
	else:
		# Nothing here until the boss falls: no portal waiting in plain sight.
		visible = false
		_body_col.set_deferred("disabled", true)
		_light.energy = 0.0
		GameManager.boss_defeated.connect(_on_boss_defeated)

func _activate(announce: bool = true) -> void:
	active = true
	if style == "stairs":
		if announce:
			CombatFX.shockwave(global_position, glow_color, 40.0, 0.7, 2.5)
			CombatFX.floating_label(global_position + Vector2(0, -40), "THE WAY IS OPEN", glow_color, 1.2)
			AudioManager.play_bank("teleport", -4.0, 0.7)
		return
	visible = true
	_body_col.set_deferred("disabled", false)
	CombatFX.pvfx("rift-portal", global_position + Vector2(0, -12), 0.6)
	_sprite.speed_scale = 1.0
	# The portal rises out of the rift: grows from a sliver while it flares.
	_sprite.scale = Vector2(0.42, 0.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(0.42, 0.42), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sprite, "modulate", Color(1.4, 1.4, 1.4), 0.4)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.6)
	tw.parallel().tween_property(_light, "energy", 1.4, 1.0)
	if announce:
		CombatFX.shockwave(global_position + Vector2(0, -14), glow_color, 60.0, 0.8, 3.0)
		CombatFX.floating_label(global_position + Vector2(0, -50), "THE WAY IS OPEN", glow_color, 1.2)
		AudioManager.play_bank("teleport", -2.0, 0.8)

func _on_boss_defeated(boss_name: String) -> void:
	if boss_name != boss_to_track or active:
		return
	if style == "none":
		# The last boss: its fall is the victory. A moment to watch it die, then on.
		active = true
		await get_tree().create_timer(3.5).timeout
		_finish(get_tree().get_first_node_in_group("player"))
		return
	await get_tree().create_timer(1.2).timeout # let the death play out first
	_activate()

func _process(delta: float) -> void:
	if style != "stairs":
		return
	_t += delta
	_on = move_toward(_on, 1.0 if active else 0.0, delta * 0.7)
	_light.energy = _on * (1.0 + 0.2 * sin(_t * 2.2))
	queue_redraw()

func _draw() -> void:
	if style == "stairs":
		ExitGlow.draw(self, _t, glow_color, _on, false, 40.0)

# Walking in only shows the prompt: you step through with F, so a fight or a chest nearby
# never sends you on by accident.
func _on_body_entered(body: Node2D) -> void:
	if not active or _used or not body.is_in_group("player"):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("Press F to go on to the next level", 2.5)

func interact(body: Node2D = null) -> void:
	if not (body and body.is_in_group("player")):
		return
	if not active:
		if style == "stairs":
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_message"):
				hud.show_message("Rubble and dark sorcery seal the stairs. Its master still lives.", 2.5)
		return
	_finish(body)

func _finish(body: Node2D) -> void:
	if _used:
		return
	_used = true
	if unlocks_level > 0:
		GameData.unlock_level(unlocks_level)
	if style == "portal":
		CombatFX.burst(global_position + Vector2(0, -14), glow_color, 40, 120.0, 0.8)
		AudioManager.play_bank("teleport", 0.0, 1.0)
	else:
		AudioManager.play_bank("footstep", -4.0, 0.8)
	if body:
		if style == "portal":
			body.visible = false
		body.set_physics_process(false)
	await get_tree().create_timer(1.0).timeout
	SceneManager.load_scene("res://scenes/ui/VictoryScreen.tscn")

static func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load(PORTAL_SHEET)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 8.0)
	for i in FRAMES:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		sf.add_frame("default", at)
	return sf
