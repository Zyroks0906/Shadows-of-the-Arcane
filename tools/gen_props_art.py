"""Pixel art for world props drawn by hand in code. Run: python tools/gen_props_art.py
Writes assets/sprites/props/.

transmuter.png (40 x 34): the Alchemist's Crucible. A crypt-stone plinth with a carved rune,
a column with a skull, a bowl-shaped stone basin, and a glass flask on each side on its own
iron stand, joined to the basin by copper pipes. The liquids, bubbles and glow are drawn
over it by scripts/world/transmuter.gd (anchors in TRANSMUTER_ANCHORS below), so the art
leaves the glass and the basin empty."""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'props')
os.makedirs(OUT, exist_ok=True)

# Liquid anchors used by transmuter.gd (sprite pixels, origin top-left):
TRANSMUTER_ANCHORS = {'basin': (20, 11), 'left_flask': (5, 14), 'right_flask': (34, 14)}

W, H = 40, 34
im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
px = im.load()

OUT_C = (16, 12, 20, 255)
S_DARK = (50, 46, 60, 255)
S_MID = (76, 72, 90, 255)
S_LIGHT = (104, 100, 120, 255)
S_HI = (136, 132, 152, 255)
MOSS = (70, 96, 70, 255)
IRON = (38, 38, 46, 255)
IRON_L = (84, 86, 98, 255)
COPPER = (170, 98, 52, 255)
COPPER_L = (226, 156, 92, 255)
COPPER_D = (104, 54, 32, 255)
GLASS = (170, 205, 225, 90)
GLASS_EDGE = (205, 230, 245, 230)
GLASS_HI = (245, 252, 255, 230)
BONE = (204, 194, 168, 255)
BONE_D = (136, 126, 104, 255)
RUNE = (130, 90, 185, 255)


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def rect(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(x, y, c)


def hline(x0, x1, y, c):
    rect(x0, y, x1, y, c)


# --- Plinth: two stone steps -------------------------------------------------------------
rect(7, 30, 32, 33, OUT_C)
rect(8, 31, 31, 32, S_MID)
hline(8, 31, 31, S_LIGHT)
for x in (13, 20, 26):
    put(x, 32, S_DARK)
rect(10, 27, 29, 30, OUT_C)
rect(11, 28, 28, 29, S_MID)
hline(11, 28, 28, S_HI)
# Carved rune (a small circle with a cross) on the lower step's front.
for x, y in [(19, 31), (20, 31), (18, 32), (21, 32)]:
    put(x, y, S_DARK)
put(19, 32, RUNE); put(20, 32, RUNE)
put(9, 32, MOSS); put(10, 33, MOSS); put(30, 31, MOSS)

# --- Column with a skull -----------------------------------------------------------------
rect(15, 16, 24, 27, OUT_C)
rect(16, 16, 23, 27, S_MID)
rect(16, 16, 16, 27, S_LIGHT)
rect(23, 16, 23, 27, S_DARK)
rect(17, 19, 22, 23, BONE)
hline(17, 22, 23, BONE_D)
put(17, 19, BONE_D); put(22, 19, BONE_D)
for (x, y) in [(18, 20), (18, 21), (21, 20), (21, 21)]:
    put(x, y, OUT_C)                    # eye sockets
put(19, 22, BONE_D); put(20, 22, BONE_D)  # nose
for x in range(17, 23):
    put(x, 24, BONE if x % 2 else OUT_C)  # teeth

# --- Basin: a bowl on the column ---------------------------------------------------------
bowl = [(9, 30, 9), (9, 30, 10), (10, 29, 11), (11, 28, 12), (12, 27, 13), (14, 25, 14), (15, 24, 15)]
for x0, x1, y in bowl:
    hline(x0 - 1, x1 + 1, y, OUT_C)
for x0, x1, y in bowl:
    hline(x0, x1, y, S_MID)
hline(9, 30, 9, S_HI)                   # rim highlight
hline(10, 29, 10, OUT_C)                # inside of the bowl: the liquid is drawn here
hline(11, 28, 11, OUT_C)
for x0, x1, y in bowl[3:]:
    put(x0, y, S_LIGHT)
    put(x1, y, S_DARK)
for x in (13, 20, 26):
    put(x, 12, S_DARK)                  # carved notches

# --- Flasks on iron stands, copper pipes into the basin ----------------------------------
for side in (0, 1):
    cx = 5 if side == 0 else 34
    s = 1 if side == 0 else -1
    # stand: a little stone foot, an iron rod, a ring cradle under the flask
    rect(cx - 2, 31, cx + 2, 33, OUT_C)
    rect(cx - 1, 32, cx + 1, 32, S_LIGHT)
    rect(cx, 19, cx, 30, IRON)
    put(cx + s, 30, IRON_L)
    hline(cx - 3, cx + 3, 18, IRON)
    put(cx - 3, 17, IRON_L); put(cx + 3, 17, IRON_L)
    # round flask, radius ~3.5, centre (cx, 14)
    for y in range(9, 19):
        for x in range(cx - 5, cx + 6):
            d = (x - cx) ** 2 + (y - 14) ** 2
            if d <= 12:
                put(x, y, GLASS)
            elif d <= 20:
                put(x, y, OUT_C)
    # neck and stopper
    rect(cx - 1, 6, cx + 1, 10, OUT_C)
    put(cx, 7, GLASS); put(cx, 8, GLASS); put(cx, 9, GLASS); put(cx, 10, GLASS)
    hline(cx - 2, cx + 2, 5, COPPER_D)
    hline(cx - 1, cx + 1, 4, COPPER)
    put(cx - 2 * s, 12, GLASS_HI); put(cx - 2 * s, 13, GLASS_EDGE)
    # copper pipe: up from the stopper, across, then down into the basin rim
    path = [(cx, 3), (cx, 2), (cx + s, 1)]
    x = cx + s
    while x != (11 if side == 0 else 28):
        x += s
        path.append((x, 1))
    tx = x
    path += [(tx + s, 2), (tx + s, 3), (tx + s, 4), (tx + s, 5), (tx + s, 6), (tx + s, 7), (tx + s, 8)]
    for (x, y) in path:
        put(x, y, COPPER)
    for (x, y) in path:
        if (x, y + 1) not in path and y < 8:
            put(x, y + 1, COPPER_D)
    for i, (x, y) in enumerate(path):
        if i % 3 == 1:
            put(x, y, COPPER_L)
    # a brass clamp where the pipe meets the basin
    put(tx + s - 1, 8, COPPER_D); put(tx + s + 1, 8, COPPER_D)

im.save(os.path.join(OUT, 'transmuter.png'))
big = im.resize((W * 8, H * 8), Image.NEAREST)
bg = Image.new('RGBA', big.size, (34, 26, 40, 255))
bg.alpha_composite(big)
bg.save(os.path.join(os.environ.get('TEMP', OUT), 'transmuter_preview.png'))
print('ok')


# --- Puzzle pieces (scripts/world/push_puzzle.gd, rune_puzzle.gd) --------------------------
def _img(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))

def _save(im, name):
    im.save(os.path.join(OUT, name))

O = (14, 10, 18, 255)
ST_D, ST_M, ST_L, ST_H = (54, 50, 64, 255), (82, 78, 96, 255), (112, 108, 128, 255), (150, 146, 166, 255)
MOSS_D, MOSS = (46, 70, 48, 255), (74, 104, 70, 255)
RUNE_D = (40, 30, 56, 255)

# Push block, 16 x 18: top face (lit), front face with a carved ring rune, cracks, moss.
b = _img(16, 18); p = b.load()
for y in range(18):
    for x in range(16):
        if x in (0, 15) or y in (0, 17):
            p[x, y] = O
        elif y <= 5:
            p[x, y] = ST_H if y == 1 else ST_L
        else:
            p[x, y] = ST_M if x > 2 else ST_L
for x in range(1, 15):
    p[x, 6] = O if x % 5 else ST_D           # edge between top and front
for y in range(7, 17):
    p[14, y] = ST_D                          # shaded right side
for (x, y) in [(5, 9), (6, 9), (7, 9), (8, 9), (9, 9), (4, 10), (10, 10), (4, 11), (10, 11), (4, 12), (10, 12), (5, 13), (6, 13), (7, 13), (8, 13), (9, 13), (7, 10), (7, 11), (7, 12)]:
    p[x, y] = RUNE_D                         # engraved ring with a bar
for (x, y) in [(2, 3), (3, 4), (11, 8), (12, 9), (12, 10)]:
    p[x, y] = ST_D                           # cracks
for (x, y) in [(1, 16), (2, 16), (3, 15), (1, 15), (13, 16), (14, 16)]:
    p[x, y] = MOSS if (x + y) % 2 else MOSS_D
_save(b, 'push_block.png')

# Rune plate, 16 x 16: a sunken slab, bevelled, with a ring of rune ticks.
pl = _img(16, 16); p = pl.load()
for y in range(16):
    for x in range(16):
        e = min(x, y, 15 - x, 15 - y)
        p[x, y] = O if e == 0 else (ST_L if e == 1 and (x < 8 or y < 8) else (ST_D if e == 1 else ST_M))
import math
for k in range(12):
    a = k * math.pi / 6
    p[int(round(7.5 + math.cos(a) * 5)), int(round(7.5 + math.sin(a) * 5))] = RUNE_D
for (x, y) in [(7, 7), (8, 7), (7, 8), (8, 8)]:
    p[x, y] = RUNE_D
_save(pl, 'rune_plate.png')

# Vault floor rune stone, 18 x 12: a flat carved disc set in the floor.
rs = _img(18, 12); p = rs.load()
for y in range(12):
    for x in range(18):
        d = ((x - 8.5) / 8.5) ** 2 + ((y - 5.5) / 5.5) ** 2
        if d <= 1.0:
            p[x, y] = O if d > 0.8 else (ST_L if y < 5 else ST_M)
_save(rs, 'rune_stone.png')

# Tablet (stele), 30 x 26: bevelled frame, dark inset where the runes light up.
tb = _img(30, 26); p = tb.load()
for y in range(26):
    for x in range(30):
        if x in (0, 29) or y in (0, 25):
            p[x, y] = O
        elif x in (1, 2) or y in (1, 2):
            p[x, y] = ST_H
        elif x in (27, 28) or y in (23, 24):
            p[x, y] = ST_D
        elif 4 <= x <= 25 and 5 <= y <= 18:
            p[x, y] = (24, 18, 32, 255)
        else:
            p[x, y] = ST_M
for x in range(4, 26):
    p[x, 4] = O
    p[x, 19] = ST_L
for (x, y) in [(3, 21), (4, 21), (25, 21), (26, 21), (5, 22)]:
    p[x, y] = MOSS
_save(tb, 'rune_tablet.png')
print('puzzle art ok')

# --- Fortune shrine (scripts/world/fortune_shrine.gd), 32 x 40 ------------------------------
# A carved stone cabinet: an arch with a star medallion, three reel windows (the reels are
# drawn by the game), a coin slot, gold trim, and a lever with a red knob on the right side.
GOLD_D, GOLD_M, GOLD_L, GOLD_H = (96, 64, 26, 255), (164, 116, 44, 255), (224, 176, 80, 255), (252, 226, 150, 255)
RED_D, RED_L = (120, 24, 34, 255), (214, 64, 70, 255)
fs = _img(32, 40); p = fs.load()
def fill(x0, y0, x1, y1, c):
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            p[xx, yy] = c
# Body: 2..26 wide, arch top, plinth.
for y in range(4, 36):
    for x in range(2, 27):
        r = 12.5
        if y < 9 and (x - 14) ** 2 + (y - 9) ** 2 > r * r:
            continue
        edge = x in (2, 26) or y == 35
        p[x, y] = O if edge else (ST_L if x < 6 else (ST_D if x > 22 else ST_M))
for x in range(2, 27):
    for y in range(4, 10):
        if p[x, y][3] and (x - 14) ** 2 + (y - 9) ** 2 > 11.6 ** 2:
            p[x, y] = O
# Gold trim along the arch and the base.
for x in range(4, 25):
    for y in range(5, 10):
        d = ((x - 14) ** 2 + (y - 9) ** 2) ** 0.5
        if 9.6 < d < 10.6 and p[x, y][3]:
            p[x, y] = GOLD_L if x < 14 else GOLD_M
fill(3, 32, 25, 32, GOLD_M); fill(3, 33, 25, 34, ST_D)
for x in range(3, 26, 4):
    p[x, 32] = GOLD_H
# Star medallion in the arch.
fill(12, 4, 16, 8, GOLD_D)
for (x, y) in [(14, 3), (14, 4), (14, 5), (14, 6), (14, 7), (14, 8), (14, 9), (12, 6), (13, 6), (15, 6), (16, 6), (13, 5), (15, 5), (13, 7), (15, 7)]:
    p[x, y] = GOLD_H if y < 6 else GOLD_L
# Reel frame: a gold-rimmed panel with three dark windows.
fill(3, 13, 25, 28, GOLD_D)
fill(3, 14, 25, 27, O)
for x0 in (4, 11, 18):                      # three 7-px windows: the reel icons are 7 x 7
    fill(x0, 15, x0 + 6, 26, (20, 14, 26, 255))
    fill(x0, 15, x0 + 6, 15, (36, 28, 44, 255))
for x in (11, 18):                          # thin gold mullions between the reels
    fill(x, 14, x, 27, GOLD_D)
for x in range(3, 26):
    p[x, 13] = GOLD_L
p[3, 28] = GOLD_M; p[25, 28] = GOLD_M
# Coin slot under the reels.
fill(12, 30, 16, 30, O); fill(13, 30, 15, 30, (10, 8, 12, 255))
# Lever on the right: iron rod up from a socket, red knob on top.
fill(27, 20, 29, 24, IRON); fill(27, 20, 29, 20, IRON_L)
for y in range(9, 21):
    p[28, y] = IRON_L if y % 3 else IRON
fill(27, 6, 30, 9, RED_D); fill(27, 6, 29, 8, RED_L); p[27, 6] = (250, 150, 150, 255)
# Plinth shadow and a crack.
for (x, y) in [(8, 31), (9, 30), (21, 11), (22, 12)]:
    p[x, y] = ST_D
_save(fs, 'fortune_shrine.png')
big = fs.resize((fs.width * 8, fs.height * 8), Image.NEAREST)
bg = Image.new('RGBA', big.size, (34, 26, 40, 255)); bg.alpha_composite(big)
bg.save(os.path.join(os.environ.get('TEMP', OUT), 'fortune_preview.png'))
print('fortune shrine ok')
