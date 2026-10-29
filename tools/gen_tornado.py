"""Pixel-art tornado sprite sheet (12 looping frames, 66 x 88 each) for the Archer's
Tempest Arrow. Run: python tools/gen_tornado.py -> assets/VFX/Tornado/tornado.png

How it is built (the usual pixel-art recipe for a funnel):
- a silhouette narrow at the ground and wide at the top, around a spine that sways;
- cylinder shading: each row is a cylinder seen from the side (dark left, light right);
- spiral bands that slide diagonally from frame to frame, which reads as rotation;
- a 5-colour palette with ordered (Bayer) dithering, ragged transparent fringe at the edges;
- debris orbiting it (in front of and behind the funnel) and a dust skirt at the base."""
import math, os
from PIL import Image

W, H, N = 66, 88, 12
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'VFX', 'Tornado')
os.makedirs(OUT, exist_ok=True)
PAL = [(34, 58, 56), (70, 112, 100), (122, 170, 148), (186, 226, 204), (238, 252, 244)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DEBRIS = [(96, 140, 70), (122, 92, 60), (150, 150, 130)]


def width(h):
    return 2.5 + 21.0 * (h ** 1.5) + 2.0 * h


def spine(h, t):
    return W / 2 + 5.0 * h * math.sin(h * 4.2 + t * 2 * math.pi) + 1.5 * math.sin(h * 11 + t * 4 * math.pi)


def frame(f):
    t = f / N
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = im.load()
    ground = H - 6

    def debris(front):
        for i in range(14):
            hi = ((i * 0.377 + t * 0.6) % 1.0)
            phi = t * 2 * math.pi * 2 + i * 2.3
            if (math.sin(phi) > 0) != front:
                continue
            y = int(ground - hi * (ground - 4))
            x = int(spine(hi, t) + math.cos(phi) * (width(hi) + 3))
            col = DEBRIS[i % 3]
            for dx, dy in ([(0, 0), (1, 0)] if i % 3 == 0 else [(0, 0)]):
                if 0 <= x + dx < W and 0 <= y + dy < H:
                    px[x + dx, y + dy] = col + (255,)

    debris(False)
    for y in range(4, ground + 1):
        h = (ground - y) / (ground - 4)  # 0 at the ground, 1 at the top
        c = spine(h, t)
        w = width(h)
        for x in range(W):
            u = (x + 0.5 - c) / w
            if abs(u) > 1.0:
                continue
            theta = math.asin(u)  # angle round the cylinder
            band = math.sin(theta * 3.0 + h * 16.0 - t * 2 * math.pi * 3)
            band2 = math.sin(theta * 5.0 - h * 9.0 - t * 2 * math.pi * 2 + 1.3)
            light = 0.5 + 0.5 * u  # light from the right
            v = 0.15 + 0.45 * light + 0.28 * band + 0.12 * band2
            edge = abs(u)
            # ragged, see-through fringe and gaps between the bands near the edges
            if edge > 0.72 and band < -0.2:
                continue
            if edge > 0.9 and (x + y + f) % 3 == 0:
                continue
            if h > 0.92 and band < 0.1:
                continue
            v = max(0.0, min(0.999, v + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.22))
            col = PAL[int(v * len(PAL))]
            a = 255 if edge < 0.8 else 200
            px[x, y] = col + (a,)
    # dust skirt at the base: a flat, churning ellipse
    for y in range(ground - 4, H):
        for x in range(W):
            dx = (x + 0.5 - spine(0.0, t)) / 16.0
            dy = (y - ground) / 3.5
            r = dx * dx + dy * dy
            if r > 1.0:
                continue
            churn = math.sin(math.atan2(dy, dx) * 5 - t * 2 * math.pi * 3)
            if churn < -0.3 and r > 0.4:
                continue
            v = 0.3 + 0.3 * churn + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.25
            col = (138, 128, 104) if v > 0.35 else (98, 90, 74)
            if px[x, y][3] == 0:
                px[x, y] = col + (190,)
    debris(True)
    return im


sheet = Image.new('RGBA', (W * N, H))
for f in range(N):
    sheet.paste(frame(f), (f * W, 0))
sheet.save(os.path.join(OUT, 'tornado.png'))
big = sheet.crop((0, 0, W * 4, H)).resize((W * 4 * 4, H * 4), Image.NEAREST)
bg = Image.new('RGBA', big.size, (30, 26, 40, 255))
bg.alpha_composite(big)
bg.save(os.path.join(os.environ.get('TEMP', OUT), 'tornado_preview.png'))
print('ok')
