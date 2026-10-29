"""Ability slots for the combat HUD: carved stone frames with gold rivets (plain and lit)
and three engraved glyphs (dash, rune seal, sunburst), light grey so the HUD can tint them.
Writes assets/sprites/ui/ability_slot*.png and glyph_*.png."""
import math, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'ui')
O = (12, 8, 16, 255)
ST = [(46, 40, 54, 255), (72, 64, 82, 255), (100, 92, 112, 255), (132, 124, 146, 255)]
GD = [(96, 64, 26, 255), (168, 120, 46, 255), (226, 178, 82, 255), (252, 228, 152, 255)]
REC = (20, 14, 26, 255)

def slot(lit):
    S = 36
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); p = im.load()
    for y in range(S):
        for x in range(S):
            corner = (x in (0, S - 1) and y in (0, 1, S - 2, S - 1)) or (y in (0, S - 1) and x in (0, 1, S - 2, S - 1))
            if corner:
                continue
            if x in (0, S - 1) or y in (0, S - 1):
                p[x, y] = O
            elif 5 <= x <= S - 6 and 5 <= y <= S - 6:
                p[x, y] = REC
            else:
                # Bevel: light on top-left faces, dark on bottom-right; a little grain.
                tl = x < 5 or y < 5
                br = x > S - 6 or y > S - 6
                c = ST[2] if tl and not br else (ST[0] if br and not tl else ST[1])
                if (x * 7 + y * 13) % 11 == 0:
                    c = ST[3] if c != ST[0] else ST[1]
                p[x, y] = c
    # Inner lip around the recess.
    for i in range(4, S - 4):
        for (x, y) in [(i, 4), (4, i)]:
            p[x, y] = GD[2] if lit else ST[0]
        for (x, y) in [(i, S - 5), (S - 5, i)]:
            p[x, y] = GD[1] if lit else ST[3]
    # Gold rivets in the corners.
    for cx, cy in [(2, 2), (S - 3, 2), (2, S - 3), (S - 3, S - 3)]:
        p[cx, cy] = GD[3] if lit else GD[2]
        p[cx + (1 if cx < S // 2 else -1), cy] = GD[1]
        p[cx, cy + (1 if cy < S // 2 else -1)] = GD[0]
    return im

def glyph(kind):
    G = 20
    im = Image.new('RGBA', (G, G), (0, 0, 0, 0)); p = im.load()
    L, M, D = (240, 236, 228, 255), (190, 184, 176, 255), (120, 114, 108, 255)
    def put(x, y, c=L):
        if 0 <= x < G and 0 <= y < G:
            p[x, y] = c
    if kind == 'dodge':
        # Two chevrons racing right with speed lines behind.
        for o in (0, 6):
            for i in range(6):
                put(6 + o + i, 4 + i); put(6 + o + i, 15 - i)
                put(5 + o + i, 4 + i, M); put(5 + o + i, 15 - i, M)
        for y, x0, x1 in [(7, 1, 5), (10, 0, 6), (13, 1, 5)]:
            for x in range(x0, x1):
                put(x, y, D if x < x0 + 2 else M)
    elif kind == 'skill':
        # A rune seal: a diamond, a ring inside it, a vertical stroke and two ticks.
        for i in range(9):
            for (x, y) in [(10 + i, 1 + i), (10 - i, 1 + i), (10 + i, 19 - i), (10 - i, 19 - i)]:
                put(x, y, M)
        for a in range(32):
            t = a / 32 * math.tau
            put(int(round(10 + math.cos(t) * 4.5)), int(round(10 + math.sin(t) * 4.5)))
        for y in range(5, 16):
            put(10, y)
        put(8, 7, L); put(12, 13, L); put(7, 7, M); put(13, 13, M)
    else:
        # A sunburst: eight rays of two lengths round a bright core.
        for k in range(8):
            t = k / 8 * math.tau
            ln = 8.5 if k % 2 == 0 else 6.0
            for s in range(4, int(ln) + 1):
                put(int(round(10 + math.cos(t) * s)), int(round(10 + math.sin(t) * s)), L if s < ln - 1 else M)
                if k % 2 == 0:  # the four main rays are two pixels thick
                    put(int(round(10 + math.cos(t) * s - math.sin(t))), int(round(10 + math.sin(t) * s + math.cos(t))), M)
        for y in range(7, 14):
            for x in range(7, 14):
                if (x - 10) ** 2 + (y - 10) ** 2 <= 9:
                    put(x, y, L if (x - 10) ** 2 + (y - 10) ** 2 > 2 else M)
    return im

os.makedirs(OUT, exist_ok=True)
slot(False).save(os.path.join(OUT, 'ability_slot.png'))
slot(True).save(os.path.join(OUT, 'ability_slot_lit.png'))
for k in ('dodge', 'skill', 'burst'):
    glyph(k).save(os.path.join(OUT, 'glyph_%s.png' % k))
prev = Image.new('RGBA', (36 * 3 * 6 + 24, 36 * 6 + 12), (30, 24, 36, 255))
for i, (k, lit) in enumerate([('dodge', False), ('skill', True), ('burst', True)]):
    s = slot(lit).copy(); s.alpha_composite(glyph(k), (8, 8))
    prev.alpha_composite(s.resize((216, 216), Image.NEAREST), (6 + i * 222, 6))
prev.save(os.path.join(os.environ.get('TEMP', OUT), 'hud_preview.png'))
print('ok')
