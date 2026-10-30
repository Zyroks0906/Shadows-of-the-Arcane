extends RefCounted
class_name RunCycles

# Running cycles for the heroes whose packs have one. The class SpriteFrames (.tres) only
# carry a slow "Walk" whose feet barely move: at the game's pace the hero skated. The packs'
# RUN sheets stride much further, so the spawner adds them as "Run" (the animation the
# player asks for first when moving). Same cell size and feet row as each class's other
# animations, so they line up.

const RUN := {
	"knight": ["res://assets/sprites/player/Knight 2D Pixel Art/Sprites/with_outline/RUN.png", 8],
	"assassin": ["res://assets/sprites/player/Assassin/Sprites/RUN/run_right.png", 8],
	"archer": ["res://assets/sprites/player/Archer/Sprites/Character/Run.png", 8],
	"necromancer": ["res://assets/sprites/player/Necromancer/Sprites/Run.png", 8],
	"samurai": ["res://assets/sprites/player/Samurai 2D Pixel Art v1.2/Sprites/RUN.png", 16],
	"mage": ["res://assets/sprites/player/Wizard/Run.png", 8],
}
const FPS := 12.0

static func with_run(sf: SpriteFrames, cls: String) -> SpriteFrames:
	var spec: Array = RUN.get(cls.to_lower(), [])
	if spec.is_empty() or sf.has_animation("Run") or not ResourceLoader.exists(spec[0]):
		return sf
	var out := sf.duplicate() as SpriteFrames # the shared .tres stays as it is
	var tex: Texture2D = load(spec[0])
	var n: int = spec[1]
	var w := tex.get_width() / n
	out.add_animation("Run")
	out.set_animation_speed("Run", FPS)
	out.set_animation_loop("Run", true)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, tex.get_height())
		out.add_frame("Run", at)
	return out
