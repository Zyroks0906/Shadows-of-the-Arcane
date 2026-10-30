extends RefCounted
class_name Lore

# The story, told in fragments scattered through the maps (stone tablets, LoreStone) and
# gathered in the Journal. Pages found are remembered across runs (user://journal.cfg):
# each tablet offers the first page of its map the player has not read yet, so every run
# can bring new ones until the whole story is known.

const SAVE := "user://journal.cfg"
static var save_path := SAVE  # tests point it elsewhere so they never touch the real Journal

# Five pages per map, in story order.
const PAGES := [
	[ # Map 1, the Forgotten Crypt: the Wardens who sealed the Arcane.
		{"title": "Warden's Log, I", "text": "We sealed the Arcane beneath the crypt, as the Archmage ordered. The Golem was raised to hold the door. It does not sleep. Neither, now, do we."},
		{"title": "A Mason's Note", "text": "Stone remembers. We cut runes into every brick so the dead below would forget the way up. The runes fade faster than we can carve them."},
		{"title": "Warden's Log, II", "text": "Brother Aldric heard singing from the lower vault. By morning his lantern was cold and his bed unslept. The Golem had not moved."},
		{"title": "An Inscription", "text": "HERE LIE THE KEEPERS OF THE LIGHT. THEY DID NOT FALL. THEY WERE TAKEN."},
		{"title": "Warden's Log, III", "text": "The seal cracks. Shadows pour through like smoke. If anyone reads this, do not follow the river. Whatever calls from the water is"},
	],
	[ # Map 2, the Whispering Caverns: the river and its Guardian.
		{"title": "A Fisherman's Plea", "text": "The river used to carry fish. Now it carries whispers. My daughter followed them to the falls. The Guardian let her pass. It never lets anyone back."},
		{"title": "Etched in Crystal", "text": "Strike us in the order we sing. We remember the song of the old Archmage. You do not. Listen."},
		{"title": "The Guardian's Oath", "text": "I swore to keep the deep water clean of shadow. I have kept it. I have kept it so long that I no longer remember what clean meant."},
		{"title": "A Drowned Scholar", "text": "The Arcane is no treasure. It is a wound in the world. The Archmage did not seal it away from us. She sealed us away from it."},
		{"title": "Scratched on a Wall", "text": "Follow the wind upward. The tower still stands. The Champion waits at the top, and he was one of us."},
	],
	[ # Map 3, the Skyhold: the Champion's fall.
		{"title": "Order of the Sigil", "text": "Seven champions were sworn to the Sun Sigil. Six fell to the shadows. The seventh drank them in, and called it victory."},
		{"title": "The Archmage's Letter", "text": "My Champion, if the light of the sigil ever dims, turn the mirrors and let the sun in. Do not try to hold the dark yourself. No one can."},
		{"title": "The Barracks Roll", "text": "Names struck out one by one, all in the same hand. The last name is the Champion's own. It is not struck out. It is underlined, twice."},
		{"title": "A Wind-Torn Page", "text": "He hears them, the six. He wears their voices like armour. He thinks he still guards the sigil. He guards the shadow."},
		{"title": "The Last Page", "text": "When you face him, do not hate him. He held the dark for a hundred years so it would not reach the world. End it gently, if you can. Then let the sun in."},
	],
]

static var _found: Dictionary = {}   # "map:index" -> true
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		for k in cfg.get_section_keys("found") if cfg.has_section("found") else []:
			_found[k] = true

static func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _found:
		cfg.set_value("found", k, true)
	cfg.save(save_path)

static func is_found(map: int, i: int) -> bool:
	_load()
	return _found.has("%d:%d" % [map, i])

static func found_count() -> int:
	_load()
	return _found.size()

static func total() -> int:
	var n := 0
	for m in PAGES:
		n += m.size()
	return n

# The page a tablet on `map` shows: the first one not read yet, else one already known.
static func next_page(map: int) -> int:
	map = clampi(map, 0, PAGES.size() - 1)
	for i in PAGES[map].size():
		if not is_found(map, i):
			return i
	return randi() % PAGES[map].size()

# Marks a page as found; true if it is new.
static func find(map: int, i: int) -> bool:
	_load()
	var k := "%d:%d" % [map, i]
	if _found.has(k):
		return false
	_found[k] = true
	_save()
	return true

# Tests: a separate, empty journal file.
static func use_test_journal() -> void:
	save_path = "user://journal_test.cfg"
	_found.clear()
	_loaded = true
	_save()
