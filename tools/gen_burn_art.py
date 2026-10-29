"""Art for the necromancer's burning ground (scripts/combat/burning_ground.gd):
- burn_decal.png (84 x 50): a charred patch on stone. Ragged noise-warped outline, a
  dithered ring of soot at the edge, solid char inside, ash specks and burnt lumps.
- burn_glow.png (84 x 50): ember cracks running through the char, drawn additively and
  pulsed by the game.
- small_flame.png (6 frames of 10 x 16): a flickering pixel flame - dark-red outline,
  orange body, yellow core, white-hot root - for the flames dotted over the patch.
Writes to assets/VFX/Burn/."""
import math, os, random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'VFX', 'Burn')
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
rnd = random.Random(42)

def vnoise(x, y, seed):
    def h(i, j):
        return random.Random(i * 7919 + j * 104729 + seed).random()
    xi, yi = math.floor(x), math.floor(y)
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = h(xi, yi) + (h(xi + 1, yi) - h(xi, yi)) * fx
    b = h(xi, yi + 1) + (h(xi + 1, yi + 1) - h(xi, yi + 1)) * fx
    return a + (b - a) * fy

W, H = 84, 50
decal = Image.new('RGBA', (W, H), (0, 0, 0, 0))
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
dp, gp = decal.load(), glow.load()
depth = {}
for y in range(H):
    for x in range(W):
        nx, ny = (x - W / 2 + 0.5) / (W / 2), (y - H / 2 + 0.5) / (H / 2)
        r = math.hypot(nx, ny)
        r += (vnoise(x * 0.12, y * 0.12, 1) - 0.5) * 0.5 + (vnoise(x * 0.3, y * 0.3, 2) - 0.5) * 0.18
        d = 1.0 - r / 0.95
        if d <= 0:
            continue
        depth[(x, y)] = d
        # Soot fades smoothly onto the stone (no dither checkerboard), char deepens inward.
        a = int(255 * min(1.0, d / 0.35) * 0.88)
        k = min(1.0, d / 0.6)
        col = (int(40 - 22 * k), int(28 - 16 * k), int(28 - 14 * k))
        dp[x, y] = col + (a,)
# Ember cracks: random walks out from the middle, hot (yellow) near the centre.
inner = [k for k, v in depth.items() if v > 0.4]
for i in range(11):
    x, y = rnd.choice(inner)
    a = rnd.uniform(0, math.tau)
    for step in range(rnd.randint(10, 22)):
        a += rnd.uniform(-0.6, 0.6)
        x += math.cos(a)
        y += math.sin(a) * 0.6
        xi, yi = int(round(x)), int(round(y))
        d = depth.get((xi, yi), 0)
        if d < 0.25:
            break
        hot = d > 0.6 and step < 8
        gp[xi, yi] = (255, 214, 110, 255) if hot else (240, 110, 34, 230)
        dp[xi, yi] = (60, 18, 10, 255)
os.makedirs(OUT, exist_ok=True)
decal.save(os.path.join(OUT, 'burn_decal.png'))
glow.save(os.path.join(OUT, 'burn_glow.png'))

# Small flame, 6 frames.
FW, FH, N = 10, 16, 6
OUTL, RED, ORA, YEL, WHI = (120, 20, 14, 255), (214, 64, 24, 255), (250, 140, 40, 255), (255, 214, 90, 255), (255, 248, 210, 255)
sheet = Image.new('RGBA', (FW * N, FH), (0, 0, 0, 0))
sp = sheet.load()
for f in range(N):
    ph = f / N * math.tau
    height = 11 + 2.5 * math.sin(ph) + (1 if f % 2 else 0)
    lean = math.sin(ph * 2) * 1.2
    for y in range(FH):
        t = (FH - 1 - y) / height          # 0 at the root .. 1 at the tip
        if t > 1:
            continue
        half = 3.6 * math.sin(math.pi * min(1.0, t * 0.85 + 0.15)) * (1 - t * 0.55)
        cx = FW / 2 - 0.5 + lean * t * t
        for x in range(FW):
            d = abs(x - cx)
            if d > half:
                continue
            edge = d > half - 1.0 or t > 0.9
            if edge:
                c = OUTL if t > 0.35 else RED
            elif d < half * 0.35 and t < 0.45:
                c = WHI if t < 0.18 else YEL
            elif d < half * 0.6 and t < 0.7:
                c = YEL if t < 0.3 else ORA
            else:
                c = ORA if t < 0.6 else RED
            sp[f * FW + x, y] = c
    # A loose flicker of flame above the tip on some frames.
    if f % 3 == 1:
        tx = int(FW / 2 + lean)
        ty = int(FH - height - 2)
        if 0 <= ty < FH:
            sp[f * FW + tx, ty] = ORA
sheet.save(os.path.join(OUT, 'small_flame.png'))

prev = Image.new('RGBA', (W * 4 + FW * N * 4 + 20, H * 4), (40, 36, 46, 255))
both = decal.copy(); both.alpha_composite(glow)
prev.alpha_composite(both.resize((W * 4, H * 4), Image.NEAREST), (0, 0))
prev.alpha_composite(sheet.resize((FW * N * 4, FH * 4), Image.NEAREST), (W * 4 + 20, 0))
prev.save(os.path.join(os.environ.get('TEMP', OUT), 'burn_preview.png'))
print('ok')
