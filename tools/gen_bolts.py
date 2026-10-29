"""Pixel-art bolts for the elements that had no spell art (Hydro, Anemo, Geo), in the same
format as assets/VFX/Spells/fireball.png: a strip of 64x32 frames, the head at (48, 16)
pointing right, the trail behind it. Six frames: the head's swirl turns, the trail ripples
and sheds drops/motes/grit. Writes assets/VFX/Spells/{hydro,anemo,geo}_bolt.png."""
import math, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'VFX', 'Spells')
W, H, N = 64, 32, 6
HX, HY = 48, 16
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

PAL = {
    'hydro': [(18, 44, 100), (36, 96, 186), (70, 158, 236), (150, 214, 255), (236, 250, 255)],
    'anemo': [(24, 80, 64), (52, 160, 116), (118, 226, 168), (198, 255, 224), (250, 255, 250)],
    'geo':   [(64, 40, 18), (134, 90, 38), (200, 146, 58), (242, 202, 118), (255, 240, 200)],
}

def bolt(kind):
    pal = PAL[kind]
    img = Image.new('RGBA', (W * N, H), (0, 0, 0, 0))
    px = img.load()
    def put(fx, x, y, c, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            px[fx * W + x, y] = c + (a,)
    for f in range(N):
        ph = f / N * math.tau
        # Trail: a tapering ribbon, wavier towards its end, dithered away at the tail.
        for x in range(8, HX - 4):
            k = (x - 8) / (HX - 4 - 8)                  # 0 tail .. 1 near the head
            half = 0.6 + k * 4.2
            wave = math.sin(x * 0.42 - ph * 2) * (1 - k) * 2.2
            if kind == 'anemo':
                wave = math.sin(x * 0.55 - ph * 2) * (1.2 + (1 - k) * 2.5)
            for dy in range(-6, 7):
                d = abs(dy - wave)
                if d > half:
                    continue
                if BAYER[(x + f) % 4][(dy + 8) % 4] > k * 22 + 2:
                    continue
                band = d / max(half, 0.01)
                c = pal[3] if band < 0.35 else (pal[2] if band < 0.7 else pal[1])
                put(f, x, HY + dy, c)
        # Loose drops / motes / grit falling behind.
        for i in range(5):
            t = (i * 0.21 + f / N) % 1.0
            x = HX - 8 - t * 34
            y = HY + math.sin(i * 2.3 + ph) * (2 + t * 5) + (t * 4 if kind != 'anemo' else 0)
            c = pal[3] if i % 2 else pal[2]
            put(f, x, y, c)
            if kind == 'geo':
                put(f, x + 1, y, pal[1])
        # Head.
        if kind == 'geo':
            # An angular shard of stone, tumbling a little.
            pts = []
            for y in range(-6, 7):
                for x in range(-7, 8):
                    if abs(x) * 0.8 + abs(y) <= 6.2 + (1 if (x + y + f) % 5 == 0 else 0):
                        pts.append((x, y))
            for x, y in pts:
                edge = abs(x) * 0.8 + abs(y) > 5.0
                c = pal[0] if edge else (pal[3] if (x < 0 and y < 0) else (pal[1] if x > 1 else pal[2]))
                put(f, HX + x, HY + y, c)
            put(f, HX - 2, HY - 3, pal[4]); put(f, HX - 1, HY - 3, pal[4])
        else:
            r = 6.5
            for y in range(-8, 9):
                for x in range(-8, 9):
                    d = math.hypot(x, y)
                    if d > r:
                        continue
                    if d > r - 1.2:
                        c = pal[0]
                    elif d > r - 2.6:
                        c = pal[1] if (x > 0 or y > 0) else pal[2]
                    else:
                        c = pal[2]
                    put(f, HX + x, HY + y, c)
            # The swirl: an arc of light turning inside the orb.
            for s in range(9):
                a = ph + s * 0.32
                rr = 3.6 - s * 0.18
                put(f, HX + math.cos(a) * rr, HY + math.sin(a) * rr, pal[3] if s > 2 else pal[4])
            # Highlight.
            put(f, HX - 3, HY - 3, pal[4]); put(f, HX - 2, HY - 4, pal[4]); put(f, HX - 3, HY - 2, pal[3])
    return img

os.makedirs(OUT, exist_ok=True)
prev = []
for k in PAL:
    im = bolt(k)
    im.save(os.path.join(OUT, '%s_bolt.png' % k))
    prev.append(im)
big = Image.new('RGBA', (W * N * 4, H * 4 * 3), (30, 24, 36, 255))
for i, im in enumerate(prev):
    big.alpha_composite(im.resize((W * N * 4, H * 4), Image.NEAREST), (0, i * H * 4))
big.save(os.path.join(os.environ.get('TEMP', OUT), 'bolts_preview.png'))
print('ok')
