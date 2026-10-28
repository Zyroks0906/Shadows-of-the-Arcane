extends Node2D
class_name PlayerGuard

# Blocking and parrying for the player.
#
# Hold block to raise the guard: hits from the front (within BLOCK_ARC_DEG of the aim) are
# stopped and cost stamina equal to their damage. If stamina runs out the guard breaks:
# the hit goes through, the player is stunned and can't block for a while. Raising the
# guard just before a hit lands (parry_window) is a parry: no stamina cost and the
# attacker is stunned. Sounds only play when a hit is actually blocked or parried.

const BLOCK_ARC_DEG := 140.0
const REGEN_DELAY := 1.0
const REGEN_RATE := 30.0 # stamina per second
const BREAK_STUN := 0.6
const BREAK_LOCKOUT := 2.0

var max_stamina: float = 50.0
var stamina: float = 50.0
var parry_window: float = 0.15
var blocking: bool = false
var aim: Vector2 = Vector2.RIGHT

var _raised_at_ms: int = -100000
var _last_strain_ms: int = -100000
var _broken_until_ms: int = 0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE

func setup(max_st: float, parry_s: float) -> void:
	max_stamina = max_st
	stamina = max_st
	parry_window = parry_s

func is_broken() -> bool:
	return Time.get_ticks_msec() < _broken_until_ms

func in_parry_window() -> bool:
	return blocking and Time.get_ticks_msec() - _raised_at_ms <= int(parry_window * 1000.0)

# Called every physics frame by the player. Returns whether the guard is up.
func update(delta: float, wants_block: bool, aim_dir: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	aim = aim_dir
	var can := wants_block and not is_broken() and stamina > 0.0
	if can and not blocking:
		_raised_at_ms = now
		_last_strain_ms = now
	blocking = can
	if not blocking and now - _last_strain_ms > int(REGEN_DELAY * 1000.0):
		stamina = minf(stamina + REGEN_RATE * delta, max_stamina)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	queue_redraw()
	return blocking

# Decides what happens to a hit coming from `from_pos`:
# "none" (not guarding / from behind), "parry", "block" or "break".
func try_absorb(damage: int, from_pos: Vector2) -> String:
	if not blocking:
		return "none"
	var to := from_pos - global_position
	if to.length() > 2.0 and absf(aim.angle_to(to)) > deg_to_rad(BLOCK_ARC_DEG * 0.5):
		return "none"
	if in_parry_window():
		_flash = 1.0
		_flash_color = Color(1.0, 0.85, 0.3)
		return "parry"
	stamina -= damage
	_last_strain_ms = Time.get_ticks_msec()
	if stamina <= 0.0:
		stamina = 0.0
		blocking = false
		_broken_until_ms = Time.get_ticks_msec() + int(BREAK_LOCKOUT * 1000.0)
		return "break"
	_flash = 0.7
	_flash_color = Color(0.75, 0.9, 1.0)
	return "block"

# The raised guard: a curved shield line in front of the character that thins as stamina
# drains and flashes on every block (gold on a parry).
func _draw() -> void:
	if not blocking and _flash <= 0.0:
		return
	var frac := stamina / maxf(max_stamina, 1.0)
	var col := Color(0.7, 0.85, 1.0, 0.55 + 0.3 * frac).lerp(_flash_color, _flash)
	var half := deg_to_rad(BLOCK_ARC_DEG * 0.5) * 0.75
	var a := aim.angle()
	draw_arc(Vector2.ZERO, 11.0, a - half, a + half, 14, Color(0, 0, 0, 0.35), 3.0)
	draw_arc(Vector2.ZERO, 11.0, a - half, a + half, 14, col, 1.0 + frac * 1.0 + _flash * 1.5)
