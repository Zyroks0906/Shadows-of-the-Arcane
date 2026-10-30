"""Seeded level variants: maps 1, 2 and 3 assembled from a library of hand-designed rooms.

`python tools/levels/assemble.py` writes, for each themed map, the layouts of seeds 2..5
(whispering_caverns_s2.txt ... skyhold_ruins_s5.txt) plus a .json beside each with its arena
names; the Godot level builder turns them into level_2_s2.tscn ... level_3_s5.tscn. Seed 1
of each map is the hand-made layout in design_levels.py. A run draws one layout per map
(GameManager.start_run), so no two runs need look alike.

How a layout is put together (same logic as the hand-made maps):
- The map is a 4 x 3 grid of cells. The main route is a random path through 7 of them:
  entrance -> hub -> arena 1 (silver key) -> silver door -> gallery (hazards) -> arena 2
  (golden key) -> vestibule (peddler, potions) -> golden door + boss door -> boss lair.
  The two door crossings are always vertical: key doors sit in horizontal walls.
- Two or three optional rooms hang off the route in free cells: an ambush cellar, a shrine
  room, and the puzzle rooms (sluices, echo crystals, sun mirrors) copied cell for cell from
  the hand-made maps so they stay solvable. Puzzle rooms keep their entrance side.
- Arena entrances get gates; corridors are short and straight.
- Every layout is checked before it is written: the boss and the exit can be reached, each
  key before its door, health potions outnumber mana potions, nothing stands on rock.
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design_levels import Plan, HERE  # noqa: E402

COLS, ROWS = 4, 3
CW, CH = 26, 18          # cell size in tiles (26: the sun sanctum and its reliquary fit)
MARGIN = 2
SEEDS = range(2, 6)


class Room:
    """A placed room: its main rectangle (x, y, w, h) and the cell it sits in."""

    def __init__(self, kind, w, h, cell, extra=(0, 0, 0, 0), entry=None):
        self.kind, self.w, self.h, self.cell = kind, w, h, cell
        # extra: how far the template reaches beyond the main rectangle (left, top, right, bottom)
        self.extra = extra
        self.entry = entry  # None, or (side, first row) for puzzle rooms with a fixed doorway
        self.x = self.y = 0

    def rows(self):
        return range(self.y, self.y + self.h)

    def cols(self):
        return range(self.x, self.x + self.w)


# --- Room sizes and painters ---------------------------------------------------------------
# Each painter fills the room's main rectangle (already carved) relative to (x, y).

SIZES = {
    'entrance': (11, 8), 'hub': (17, 12), 'arena': (15, 11), 'gallery': (18, 11),
    'vestibule': (9, 8), 'boss': (20, 14), 'cellar': (11, 7), 'shrine': (9, 7),
    'sluice': (17, 12), 'echo': (15, 8), 'mirror': (16, 12),
}
EXTRA = {'echo': (0, 4, 0, 0), 'mirror': (0, 0, 6, 0)}
ENTRY = {'sluice': ('E', 7), 'echo': ('W', 3), 'mirror': ('W', 5)}

ARENA_NAMES = {
    'crypt': ['THE OSSUARY', 'BONE HALL', 'CHAPEL OF ASH', 'THE CATACOMB', 'WARDENS REST', 'THE CHARNEL PIT'],
    'caverns': ['SLIME POOLS', 'WISP SHRINE', 'DROWNED HALL', 'GLOWWORM DEN', 'THE UNDERTOW', 'MOSS CATHEDRAL'],
    'skyhold': ['BARRACKS', 'SANCTUM GUARD', 'WIND ROOST', 'BROKEN CHAPEL', 'THE GALE YARD', 'WATCHERS RING'],
}
AMBUSH_NAMES = {'crypt': ['FORGOTTEN CELLAR', 'SEALED TOMB'], 'caverns': ['FORGOTTEN CELLAR', 'SUNKEN STORE'], 'skyhold': ['OLD ARMOURY', 'COLLAPSED CRYPT']}


def paint(p, r, theme, rng, role=None):
    x, y = r.x, r.y
    put = lambda dx, dy, c: p.put(x + dx, y + dy, c)
    area = lambda dx, dy, w, h, c: p.rect(x + dx, y + dy, w, h, c)
    k = r.kind
    if k == 'entrance':
        put(2, 3, 'P')
        put(8, 1, 'h')
        put(0, 7, 'o')
        put(10, 7, 'o')
    elif k == 'hub':
        if theme == 'caverns':
            area(6, 4, 5, 4, ',')
        elif theme == 'crypt':
            for dx, dy in [(2, 2), (14, 2), (2, 9), (14, 9)]:
                put(dx, dy, 'p')
            for dx, dy in [(7, 1), (9, 1)]:
                put(dx, dy, 'o')
        else:
            area(6, 4, 5, 5, '*')
            for dx, dy in [(2, 2), (14, 2), (2, 9), (14, 9)]:
                put(dx, dy, 'p')
        put(3, 7, 'e')
        put(13, 4, 'e')
        put(15, 10, '$')
        put(1, 1, 'h')
    elif k == 'arena':
        if theme == 'caverns':
            area(2, 2, 3, 3, ',')
            area(10, 7, 3, 3, ',')
            put(7, 2, 'z' if role == 'k' else 'c')
            first = ['s', 's', 'e', 'w'] if role == 'k' else ['w', 'w', 's', 'e']
        elif theme == 'crypt':
            for dx, dy in [(3, 2), (11, 2), (3, 8), (11, 8)]:
                put(dx, dy, 'p')
            first = ['e', 'e', 'e', 'e']
        else:
            area(5, 3, 5, 5, '*')
            for dx, dy in [(3, 2), (11, 2), (3, 8), (11, 8)]:
                put(dx, dy, 'p')
            first = ['O', 'e', 'e', 'w'] if role == 'k' else ['w', 'w', 'O', 'e']
        put(7, 5, 'R')                # after the floor patterns, which would cover it
        for (dx, dy), c in zip([(2, 6), (12, 3), (12, 8), (5, 9)], first):
            put(dx, dy, c)
        for dx, dy in [(1, 4), (13, 5), (7, 1)]:
            put(dx, dy, 'E')
        if role == 'g':
            put(7, 9, 'H')            # the second arena's second wave brings an elite
        put(13, 9, role)
        if role == 'k':
            wall_put(p, r, 'T', rng)  # transmuter against the back wall: rises once cleared
    elif k == 'gallery':
        if theme == 'caverns':
            area(0, 4, 18, 2, '~')    # a deep river, one shallow ford
            area(7, 3, 4, 4, ',')
            area(0, 6, 4, 1, ',')
            area(14, 3, 4, 1, ',')
            put(2, 1, 'w')
            put(15, 9, 'w')
            put(13, 1, 'e')
            put(1, 9, 'c')
            put(16, 1, 'm')
        elif theme == 'crypt':
            for dx in range(1, 17, 2):    # a floor of spike traps across the hall, two gaps
                if dx not in (7, 13):
                    put(dx, 4, 'x')
                    put(dx + 1, 6, 'x')
            for dx, dy in [(0, 0), (17, 0), (0, 10), (17, 10)]:
                put(dx, dy, 'o')
            put(2, 1, 'e')
            put(15, 9, 'e')
            put(13, 1, 'e')
            put(16, 1, 'm')
            put(8, 9, 'Y')
        else:
            area(0, 4, 18, 2, '>')    # a crosswind towards the spikes
            for dx in range(1, 17, 3):
                put(dx, 7, 'x')
            put(2, 1, 'w')
            put(15, 9, 'w')
            put(13, 1, 'e')
            put(1, 9, 'z')
            put(16, 1, 'm')
            put(8, 9, 'Y')            # a sealed chest by the far wall
    elif k == 'vestibule':
        put(4, 1, 'h')
        put(7, 6, 'm')
        wall_put(p, r, 'v', rng)      # the peddler, against the back wall
    elif k == 'boss':
        put(9, 6, 'B')
        put(9, 11, 'X')
        if theme == 'caverns':
            area(3, 4, 4, 3, ',')
            area(13, 4, 4, 3, ',')
            for dx, dy in [(2, 2), (17, 2)]:
                put(dx, dy, 'c')
            for dx, dy in [(2, 11), (17, 11)]:
                put(dx, dy, 'z')
        elif theme == 'crypt':
            for dx, dy in [(3, 2), (16, 2), (3, 11), (16, 11), (6, 6), (13, 6)]:
                put(dx, dy, 'p')
        else:
            area(5, 4, 10, 6, '*')
            for dx, dy in [(3, 2), (16, 2), (3, 12), (16, 12)]:
                put(dx, dy, 'p')
            area(1, 2, 1, 10, 'V')
            area(18, 2, 1, 10, 'A')
            put(9, 6, 'B')
    elif k == 'cellar':
        put(5, 3, 'R')
        for dx, dy in [(1, 1), (9, 1), (5, 5), (2, 4)]:
            put(dx, dy, 'e')
        for dx, dy in [(1, 5), (9, 3), (5, 1)]:
            put(dx, dy, 'E')
        put(8, 5, 'H')
        put(7, 3, 'u')
        put(9, 5, 'Y')
    elif k == 'shrine':
        wall_put(p, r, 'J', rng)      # fortune shrine against the back wall
        put(1, 5, 'C')
        put(7, 5, '$')
        put(0, 6, 'o')
        put(8, 6, 'o')
    elif k == 'sluice':               # Sluice Hall (caverns), entrance on the east side
        for x0 in (5, 8, 11):
            area(x0, 0, 2, 12, 'W')
        for dy in (2, 5, 9):
            put(14, dy, 'l')
        put(1, 2, 'C')
        put(1, 9, 'C')
        put(3, 7, '$')
    elif k == 'echo':                 # Echo Grotto, entrance on the west, reliquary above
        for dx, dy in [(2, 2), (12, 2), (2, 6), (12, 6)]:
            put(dx, dy, 'K')
        put(7, 4, 'Q')
        p.door(x + 7, y - 1, '%')
        p.rect(x + 4, y - 4, 7, 3)
        put(5, -3, 'C')
        put(9, -3, 'C')
    elif k == 'mirror':               # Sun Sanctum, entrance on the west, reliquary east
        put(2, 0, 'S')
        for dx, dy in [(2, 9), (9, 9), (9, 2), (6, 5), (12, 7)]:
            put(dx, dy, 'M')
        put(14, 2, 'N')
        put(13, 10, 'p')
        put(1, 11, 'p')
        p.door(x + 16, y + 6, '%')
        p.rect(x + 17, y + 4, 5, 5)
        put(19, 5, 'C')
        put(19, 7, 'C')


# --- Props against the back wall -------------------------------------------------------------
# A fortune shrine, a transmuter or the peddler faces the camera, so it stands against the
# room's back (top) wall: never in front of a doorway, never boxed in by a column, never
# narrowing a way through. These are the rules, used both to place them and to check maps.

CLUTTER = set('pczKMSNQWl~TJv')


def wall_ok(g, x, y):
    H, W = len(g), len(g[0])
    if not (2 <= x < W - 2 and 1 <= y < H - 2):
        return False
    # Solid wall above it and two tiles either side: no doorway in the back wall nearby.
    if any(g[y - 1][x + k] != ' ' for k in range(-2, 3)):
        return False
    # Floor under it and on both sides, floor in front.
    if any(g[y][x + k] in ' ' for k in (-1, 1)) or g[y + 1][x] == ' ':
        return False
    # No corridor coming in through a side wall right by it (rows y .. y+2).
    for k in (-3, -2, -1, 1, 2, 3):
        xx = x + k
        if g[y][xx] == ' ':      # reached the side wall: is there an opening in it below?
            break
    for side in (-1, 1):
        xx = x
        while 0 < xx < W - 1 and g[y][xx] != ' ':
            xx += side
        if abs(xx - x) <= 3 and any(g[yy][xx] != ' ' for yy in range(y + 1, min(y + 3, H))):
            return False
    # Nothing in the way around it (columns, crystals, puzzles, other back-wall props).
    for yy in range(y, min(y + 3, H)):
        for xx in range(x - 2, x + 3):
            if (xx, yy) != (x, y) and g[yy][xx] in CLUTTER:
                return False
    return True


def wall_put(p, r, c, rng):
    spots = [r.x + dx for dx in range(1, r.w - 1) if wall_ok(p.g, r.x + dx, r.y)]
    assert spots, 'no free back wall for %s in the %s' % (c, r.kind)
    # Near a corner (left or right, whichever is free), out of the middle of the room.
    spots.sort(key=lambda x: min(x - r.x, r.x + r.w - 1 - x))
    p.g[r.y][spots[0]] = c


# --- Layout ---------------------------------------------------------------------------------

MAIN = ['entrance', 'hub', 'arena_k', 'gallery', 'arena_g', 'vestibule', 'boss']
VERTICAL_STEPS = {2, 5}  # arena_k -> gallery (silver door), vestibule -> boss (golden + boss door)
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def main_path(rng):
    cells = [(cx, cy) for cx in range(COLS) for cy in range(ROWS)]
    for _ in range(4000):
        path = [rng.choice(cells)]
        ok = True
        while len(path) < len(MAIN):
            step = len(path) - 1
            options = []
            for dx, dy in DIRS:
                if step in VERTICAL_STEPS and dx != 0:
                    continue
                n = (path[-1][0] + dx, path[-1][1] + dy)
                if 0 <= n[0] < COLS and 0 <= n[1] < ROWS and n not in path:
                    options.append(n)
            if not options:
                ok = False
                break
            path.append(rng.choice(options))
        if ok:
            return path
    raise RuntimeError('no main path')


def place(r, rng, align_rows=None):
    """Puts a room somewhere inside its cell (with its reach beyond the main rectangle)."""
    ox, oy = MARGIN + r.cell[0] * CW, MARGIN + r.cell[1] * CH
    el, et, er, eb = r.extra
    xs = range(ox + 1 + el, ox + CW - 3 - r.w - er + 1)
    ys = range(oy + 1 + et, oy + CH - 3 - r.h - eb + 1)
    if align_rows:
        ys = [y for y in ys if align_rows(y)]
    if not xs or not ys:
        return False
    r.x, r.y = rng.choice(list(xs)), rng.choice(list(ys))
    return True


def carve_link(p, a, b, door=None, gates=()):
    """A straight corridor between rooms in neighbouring cells. door: None, 'D' or 'GD'.
    gates: the rooms (arenas) whose doorway gets a gate."""
    if a.cell[1] == b.cell[1]:   # side by side
        left, right = (a, b) if a.cell[0] < b.cell[0] else (b, a)
        fixed = right.entry if right.entry and right.entry[0] == 'W' else left.entry if left.entry and left.entry[0] == 'E' else None
        if fixed:
            owner = right if fixed[0] == 'W' else left
            y0 = owner.y + fixed[1]
        else:
            common = sorted(set(left.rows()) & set(right.rows()))
            choices = [y for y in common[1:-2] if y + 1 in common]
            y0 = choices[len(choices) // 2]
        for yy in (y0, y0 + 1):
            for xx in range(left.x + left.w, right.x):
                p.g[yy][xx] = '.'
        for room in gates:
            gx = left.x + left.w if room is left else right.x - 1
            for yy in (y0, y0 + 1):
                p.g[yy][gx] = '='
    else:                        # one above the other
        top, bottom = (a, b) if a.cell[1] < b.cell[1] else (b, a)
        common = sorted(set(top.cols()) & set(bottom.cols()))
        width = 1 if door else 2
        choices = [x for x in common[1:-2] if x + width - 1 in common]
        x0 = choices[len(choices) // 2]
        for yy in range(top.y + top.h, bottom.y):
            for xx in range(x0, x0 + width):
                p.g[yy][xx] = '.'
        if door == 'D':
            p.g[top.y + top.h][x0] = 'D'
        elif door == 'GD':
            # The golden door on the vestibule's side, the boss door on the lair's side.
            vest_top = top.kind == 'vestibule'
            p.g[top.y + top.h][x0] = 'G' if vest_top else 'd'
            p.g[bottom.y - 1][x0] = 'd' if vest_top else 'G'
        for room in gates:
            gy = top.y + top.h if room is top else bottom.y - 1
            for xx in range(x0, x0 + width):
                if p.g[gy][xx] == '.':
                    p.g[gy][xx] = '='


def build(theme, seed):
    rng = random.Random(seed * 7919 + {'caverns': 1, 'skyhold': 2, 'crypt': 3}[theme])
    p = Plan(MARGIN * 2 + COLS * CW, MARGIN * 2 + ROWS * CH)
    path = main_path(rng)
    rooms = {}
    for name, cell in zip(MAIN, path):
        kind = 'arena' if name.startswith('arena') else name
        r = Room(kind, *SIZES[kind], cell)
        place(r, rng)
        rooms[name] = r
    # Optional rooms: a puzzle or two and an ambush / shrine, in free cells next to the
    # quieter rooms of the route.
    puzzles = ['sluice', 'echo'] if theme in ('caverns', 'crypt') else ['mirror', 'echo']
    rng.shuffle(puzzles)
    wanted = puzzles[: rng.choice([1, 2])] + [rng.choice(['cellar', 'shrine'])]
    if 'shrine' not in wanted and rng.random() < 0.5:
        wanted.append('shrine')
    used = set(path)
    sides = []
    for kind in wanted:
        hosts = ['hub', 'gallery', 'vestibule', 'entrance']
        rng.shuffle(hosts)
        done = False
        for host in hosts:
            h = rooms[host]
            for dx, dy in rng.sample(DIRS, 4):
                cell = (h.cell[0] + dx, h.cell[1] + dy)
                if cell in used or not (0 <= cell[0] < COLS and 0 <= cell[1] < ROWS):
                    continue
                entry = ENTRY.get(kind)
                if entry:
                    if dy != 0:
                        continue      # puzzle rooms open sideways
                    if entry[0] == 'W' and dx != 1:
                        continue      # the host must be on its west
                    if entry[0] == 'E' and dx != -1:
                        continue
                r = Room(kind, *SIZES[kind], cell, EXTRA.get(kind, (0, 0, 0, 0)), entry)
                if entry:
                    ok = place(r, rng, lambda y, e=entry, hh=h: hh.y + 1 <= y + e[1] and y + e[1] + 1 <= hh.y + hh.h - 2)
                else:
                    ok = place(r, rng)
                if not ok:
                    continue
                used.add(cell)
                sides.append((r, h))
                done = True
                break
            if done:
                break
    # Carve rooms, then corridors, then contents (contents last: corridors may not cover them).
    allrooms = list(rooms.values()) + [r for r, _ in sides]
    for r in allrooms:
        p.rect(r.x, r.y, r.w, r.h)
    order = [rooms[n] for n in MAIN]
    for i in range(len(order) - 1):
        a, b = order[i], order[i + 1]
        door = 'D' if i == 2 else 'GD' if i == 5 else None
        gates = [x for x in (a, b) if x.kind == 'arena' and not (door and x is a)]
        carve_link(p, a, b, door, gates)
    for r, h in sides:
        carve_link(p, h, r, None, [r] if r.kind == 'cellar' else [])
    for name, r in rooms.items():
        role = 'k' if name == 'arena_k' else 'g' if name == 'arena_g' else None
        paint(p, r, theme, rng, role)
    for r, _ in sides:
        paint(p, r, theme, rng)
    # Arena names in the builder's scan order (rows top to bottom, then left to right).
    arenas = sorted([r for r in allrooms if r.kind in ('arena', 'cellar')], key=lambda r: (r.y + (5 if r.kind == 'arena' else 3), r.x))
    names = []
    pool = ARENA_NAMES[theme][:]
    rng.shuffle(pool)
    amb = AMBUSH_NAMES[theme][:]
    rng.shuffle(amb)
    for r in arenas:
        names.append(amb.pop() if r.kind == 'cellar' else pool.pop())
    return p, names, [r.kind for r, _ in sides]


# --- Checks -----------------------------------------------------------------------------------

PASSABLE_LOCKED = {'D': 'silver', 'G': 'golden'}
SOLID = set(' ~pWo')


def check(p):
    g = p.g
    H, W = len(g), len(g[0])
    cells = {c: (x, y) for y in range(H) for x in range(W) for c in [g[y][x]]}
    find = lambda ch: [(x, y) for y in range(H) for x in range(W) if g[y][x] == ch]
    start = find('P')[0]
    keys = set()

    def flood():
        seen, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for dx, dy in DIRS:
                n = (x + dx, y + dy)
                if not (0 <= n[0] < W and 0 <= n[1] < H) or n in seen:
                    continue
                c = g[n[1]][n[0]]
                if c in SOLID:
                    continue
                if c in PASSABLE_LOCKED and PASSABLE_LOCKED[c] not in keys:
                    continue
                seen.add(n)
                todo.append(n)
        return seen

    reach = flood()
    assert find('k')[0] in reach, 'silver key unreachable before the silver door'
    keys.add('silver')
    reach = flood()
    assert find('g')[0] in reach, 'golden key unreachable before the golden door'
    keys.add('golden')
    reach = flood()
    for ch in 'BXv':
        for c in find(ch):
            assert c in reach, '%s unreachable' % ch
    for ch in 'JTv':
        for x, y in find(ch):
            assert wall_ok(g, x, y), '%s at %d,%d is not clear against a back wall' % (ch, x, y)
    h, m = len(find('h')), len(find('m'))
    assert h > m, 'more mana potions than health potions'
    return len(reach)


def main():
    for theme, base in [('crypt', 'forgotten_crypt'), ('caverns', 'whispering_caverns'), ('skyhold', 'skyhold_ruins')]:
        for seed in SEEDS:
            for attempt in range(50):
                try:
                    p, names, sides = build(theme, seed * 100 + attempt)
                    assert any(k in ('sluice', 'echo', 'mirror') for k in sides), 'no puzzle room'
                    cells = check(p)
                    break
                except (AssertionError, RuntimeError, IndexError) as e:
                    last = e
            else:
                raise SystemExit('%s seed %d: no valid layout (%s)' % (theme, seed, last))
            name = '%s_s%d' % (base, seed)
            p.save(name + '.txt')
            with open(os.path.join(HERE, name + '.json'), 'w', encoding='utf8') as f:
                json.dump({'room_names': names, 'side_rooms': sides}, f)
            print('   arenas %s, side rooms %s, %d reachable cells' % (names, sides, cells))


if __name__ == '__main__':
    main()
