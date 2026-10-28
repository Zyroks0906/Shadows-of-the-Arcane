extends Node

const SETTINGS_FILE = "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
# Aim assist strength: 0 (off), 0.5 (low), 0.75 (normal), 0.9 (high). See Aim.STRENGTHS.
var aim_assist: float = 0.75
var selected_music_track: String = "res://assets/audio/music/xDeviruchi - 16 bit Fantasy & Adventure (2025)/mp3/04 - Silent Forest.mp3"
var screen_shake: bool = true

# --- Key bindings ---------------------------------------------------------------------
# Every rebindable action has two slots (primary, secondary); either one triggers it. Only
# keyboard and mouse events are managed here: gamepad bindings stay as project.godot sets
# them. A binding is stored as text: "key:<physical keycode>", "mouse:<button>" or "".
const REBINDABLE := [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"],
	["move_right", "Move right"], ["attack_1", "Attack"], ["block", "Block / parry"],
	["skill", "Skill"], ["burst", "Ultimate"], ["dodge", "Dodge"], ["interact", "Interact"],
	["use_health_potion", "Health potion"], ["use_mana_potion", "Mana potion"],
]
var bindings: Dictionary = {} # action -> [primary, secondary]
var default_bindings: Dictionary = {}

func _ready() -> void:
	_capture_defaults()
	load_settings()

func _capture_defaults() -> void:
	for a in REBINDABLE:
		var slots := ["", ""]
		var i := 0
		for ev in InputMap.action_get_events(a[0]):
			var code := event_to_code(ev)
			if code != "" and i < 2:
				slots[i] = code
				i += 1
		default_bindings[a[0]] = slots
	bindings = default_bindings.duplicate(true)

static func event_to_code(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return "key:%d" % k
	if ev is InputEventMouseButton:
		return "mouse:%d" % ev.button_index
	return ""

static func code_to_event(code: String) -> InputEvent:
	if code.begins_with("key:"):
		var e := InputEventKey.new()
		e.physical_keycode = int(code.substr(4)) as Key
		return e
	if code.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(code.substr(6)) as MouseButton
		return m
	return null

static func code_name(code: String) -> String:
	if code.begins_with("key:"):
		return OS.get_keycode_string(int(code.substr(4)))
	if code.begins_with("mouse:"):
		match int(code.substr(6)):
			MOUSE_BUTTON_LEFT: return "Left click"
			MOUSE_BUTTON_RIGHT: return "Right click"
			MOUSE_BUTTON_MIDDLE: return "Middle click"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
			var b: return "Mouse %d" % b
	return "-"

# Actions (other than `action`) that already use `code` in `table`.
static func conflicts(table: Dictionary, action: String, code: String) -> Array:
	var out := []
	if code == "":
		return out
	for a in table:
		if a != action and code in table[a]:
			out.append(a)
	return out

static func action_label(action: String) -> String:
	for a in REBINDABLE:
		if a[0] == action:
			return a[1]
	return action

# Puts `bindings` into the InputMap, keeping gamepad events.
func apply_bindings() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if event_to_code(ev) != "":
				InputMap.action_erase_event(action, ev)
		for code in bindings[action]:
			var ev := code_to_event(code)
			if ev:
				InputMap.action_add_event(action, ev)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "track", selected_music_track)
	config.set_value("gameplay", "aim_assist", aim_assist)
	config.set_value("gameplay", "screen_shake", screen_shake)
	for action in bindings:
		config.set_value("controls", action, bindings[action])
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		master_volume = config.get_value("audio", "master", 1.0)
		music_volume = config.get_value("audio", "music", 0.8)
		sfx_volume = config.get_value("audio", "sfx", 1.0)
		selected_music_track = config.get_value("audio", "track", selected_music_track)
		aim_assist = config.get_value("gameplay", "aim_assist", 0.75)
		screen_shake = config.get_value("gameplay", "screen_shake", true)
		for action in bindings:
			var saved = config.get_value("controls", action, [])
			if saved is Array and saved.size() == 2:
				bindings[action] = [str(saved[0]), str(saved[1])]
		apply_bindings()

	call_deferred("_apply_bus_volumes")

func _apply_bus_volumes() -> void:
	_set_bus_vol("Master", master_volume)
	_set_bus_vol("Music", music_volume)
	_set_bus_vol("SFX", sfx_volume)

func _set_bus_vol(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db_val = linear_to_db(max(linear_val, 0.0001))
		AudioServer.set_bus_volume_db(idx, db_val)
		AudioServer.set_bus_mute(idx, linear_val <= 0)

func set_master_volume(v: float) -> void:
	master_volume = v
	_set_bus_vol("Master", v)

func set_music_volume(v: float) -> void:
	music_volume = v
	_set_bus_vol("Music", v)

func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	_set_bus_vol("SFX", v)
