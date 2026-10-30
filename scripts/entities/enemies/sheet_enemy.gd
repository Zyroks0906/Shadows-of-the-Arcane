extends Enemy
class_name SheetEnemy

# Base for the creatures from LuizMelo's packs (assets/sprites/enemies/LuizMelo, CC0):
# side-view strips of 150 x 150 frames, one PNG per animation, feet on row FEET_Y. Each
# creature lists its strips in `sheets`; they are cut into SpriteFrames here and the sprite
# is scaled so the body stands at `body_px` world pixels next to the ~15 px hero.

const ROOT := "res://assets/sprites/enemies/LuizMelo/%s/%s.png"
const FRAME := 150
const FEET_Y := 101

var folder := "Skeleton"
var body_px := 17.0          # how tall the creature stands, in world pixels
var art_px := 51.0           # its height in the art (opaque rows of an idle frame)
# anim -> [file, fps, loop]
var sheets := {
	"idle": ["Idle", 7.0, true], "walk": ["Walk", 9.0, true], "attack": ["Attack", 12.0, false],
	"hurt": ["TakeHit", 12.0, false], "death": ["Death", 9.0, false],
}

func _ready() -> void:
	_init_stats() # each creature names its folder and strips there (Enemy._ready runs it again)
	animated_sprite.sprite_frames = _build()
	animated_sprite.centered = false
	animated_sprite.offset = Vector2(-FRAME / 2.0, -FEET_Y)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.scale = Vector2.ONE * (body_px / art_px)
	super._ready()
	animated_sprite.play("idle")

func _build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in sheets:
		var spec: Array = sheets[anim]
		var path := ROOT % [folder, spec[0]]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, spec[1])
		sf.set_animation_loop(anim, spec[2])
		for i in tex.get_width() / FRAME:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
			sf.add_frame(anim, at)
	return sf
