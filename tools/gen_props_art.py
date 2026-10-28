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
