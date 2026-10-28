"""Pixel art for the perk screen: parchment cards framed by rarity, a banner, and a 16x16
icon per perk. Run: python tools/gen_ui_art.py  (writes assets/ui/perks/)."""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'perks')
os.makedirs(OUT, exist_ok=True)
random.seed(7)

RARITY = {  # metal (dark, mid, light), gem
    'common':    ((70, 68, 74), (128, 126, 134), (190, 188, 196), (200, 200, 210)),
    'uncommon':  ((70, 52, 30), (150, 110, 60), (215, 170, 100), (90, 220, 110)),
    'rare':      ((50, 60, 80), (120, 140, 170), (200, 215, 235), (90, 150, 255)),
    'epic':      ((50, 30, 70), (120, 70, 160), (190, 150, 230), (200, 110, 255)),
    'legendary': ((90, 60, 10), (200, 150, 40), (255, 225, 120), (255, 190, 60)),
}

def card(name, metal_d, metal_m, metal_l, gem):
    w, h = 92, 118
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    # Parchment with mottled tone, darker towards the edges, torn outline.
    for y in range(h):
        for x in range(w):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            torn = random.random() < 0.35 and edge == 4
            if edge < 4 or torn:
                continue
            n = random.randint(-8, 8)
            shade = max(0, 12 - edge) * 4
            r, g, b = 222 - shade + n, 200 - shade + n, 152 - shade - 4 + n
            if random.random() < 0.015:
                r, g, b = r - 30, g - 30, b - 30  # stains
            px[x, y] = (r, g, b, 255)
    d = ImageDraw.Draw(im)
    # Metal frame with corner plates and rivets.
    d.rectangle([2, 2, w - 3, h - 3], outline=metal_d, width=1)
    d.rectangle([3, 3, w - 4, h - 4], outline=metal_m, width=1)
    d.line([4, 4, w - 5, 4], fill=metal_l)
    for cx, cy in [(2, 2), (w - 12, 2), (2, h - 12), (w - 12, h - 12)]:
        d.rectangle([cx, cy, cx + 9, cy + 9], fill=metal_d)
        d.rectangle([cx + 1, cy + 1, cx + 8, cy + 8], fill=metal_m)
        d.line([cx + 1, cy + 1, cx + 8, cy + 1], fill=metal_l)
        d.point((cx + 4, cy + 4), fill=metal_l)
        d.point((cx + 5, cy + 5), fill=metal_d)
    # Gem socket at the top.
    gx, gy = w // 2, 4
    d.polygon([(gx, gy - 3), (gx + 6, gy + 3), (gx, gy + 9), (gx - 6, gy + 3)], fill=metal_d)
    d.polygon([(gx, gy - 1), (gx + 4, gy + 3), (gx, gy + 7), (gx - 4, gy + 3)], fill=gem)
    d.point((gx - 1, gy + 1), fill=(255, 255, 255))
    # Icon medallion area.
    # Layout (shared with scripts/ui/perk_picker.gd): medallion y 11-39, name and rarity
    # 42-65, divider at 69, description 73-100, key hint 102-110.
    d.ellipse([w // 2 - 14, 11, w // 2 + 14, 39], fill=(60, 44, 34), outline=metal_m)
    d.ellipse([w // 2 - 12, 13, w // 2 + 12, 37], fill=(84, 62, 46))
    # Divider between the name and the description.
    d.line([14, 69, w - 15, 69], fill=(150, 120, 80))
    d.point((w // 2, 69), fill=metal_l)
    im.save(os.path.join(OUT, 'card_%s.png' % name))

for k, (dk, md, lt, gem) in RARITY.items():
    card(k, dk, md, lt, gem)

# Neon glow for rare and above: the frame, corner plates and gem traced in light, blurred into
# a halo. Drawn additively over the card (12 px of padding on each side), so it reads as the
# metal itself glowing. Kept pixelated: blurred at 1x, then quantised to a few alpha steps.
from PIL import ImageFilter
GLOW = {'rare': (90, 160, 255), 'epic': (200, 110, 255), 'legendary': (255, 200, 70)}
PAD = 12
def glow(name, col):
    w, h = 92, 118
    mask = Image.new('L', (w + PAD * 2, h + PAD * 2), 0)
    d = ImageDraw.Draw(mask)
    o = PAD
    d.rectangle([o + 2, o + 2, o + w - 3, o + h - 3], outline=255, width=2)
    for cx, cy in [(2, 2), (w - 12, 2), (2, h - 12), (w - 12, h - 12)]:
        d.rectangle([o + cx, o + cy, o + cx + 9, o + cy + 9], fill=255)
    gx, gy = o + w // 2, o + 4
    d.polygon([(gx, gy - 5), (gx + 8, gy + 3), (gx, gy + 11), (gx - 8, gy + 3)], fill=255)
    halo = mask.filter(ImageFilter.GaussianBlur(4))
    core = mask.filter(ImageFilter.GaussianBlur(1))
    out = Image.new('RGBA', mask.size, (0, 0, 0, 0))
    hp, cp, op = halo.load(), core.load(), out.load()
    for y in range(mask.size[1]):
        for x in range(mask.size[0]):
            inside = o + 5 <= x <= o + w - 6 and o + 5 <= y <= o + h - 6
            a = hp[x, y] * (0.35 if inside else 1.0) * 1.6 + cp[x, y] * 0.5
            a = min(255, a)
            a = int(a / 32) * 32  # a few hard steps, like pixel-art light
            if a <= 0:
                continue
            k = cp[x, y] / 255.0  # the core runs hotter, towards white
            r, g, b = (int(c + (255 - c) * k * 0.6) for c in col)
            op[x, y] = (r, g, b, a)
    out.save(os.path.join(OUT, 'glow_%s.png' % name))

for k, col in GLOW.items():
    glow(k, col)

# Soft rays that turn slowly behind a legendary card.
def rays():
    s = 128
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    import math
    c = s / 2
    for i in range(12):
        a = i * math.pi * 2 / 12
        da = 0.09
        pts = [(c, c), (c + math.cos(a - da) * c, c + math.sin(a - da) * c), (c + math.cos(a + da) * c, c + math.sin(a + da) * c)]
        d.polygon(pts, fill=(255, 220, 120, 255))
    im = im.filter(ImageFilter.GaussianBlur(2))
    px = im.load()
    for y in range(s):
        for x in range(s):
            r, g, b, a = px[x, y]
            dist = math.hypot(x - c, y - c) / c
            px[x, y] = (r, g, b, int(a * max(0.0, 1.0 - dist) ** 1.3))
    im.save(os.path.join(OUT, 'rays.png'))
rays()

# Title ribbon.
def ribbon():
    w, h = 150, 22
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    red_d, red, red_l = (90, 18, 22), (150, 30, 36), (196, 60, 60)
    d.polygon([(0, 4), (14, 4), (14, 20), (0, 20), (6, 12)], fill=red_d)
    d.polygon([(w - 1, 4), (w - 15, 4), (w - 15, 20), (w - 1, 20), (w - 7, 12)], fill=red_d)
    d.rectangle([10, 1, w - 11, 17], fill=red)
    d.line([10, 1, w - 11, 1], fill=red_l)
    d.line([10, 17, w - 11, 17], fill=red_d)
    d.line([12, 3, w - 13, 3], fill=(220, 180, 90))
    d.line([12, 15, w - 13, 15], fill=(220, 180, 90))
    im.save(os.path.join(OUT, 'ribbon.png'))
ribbon()

# 16x16 icons (outline + 2-3 tones each).
O = (30, 20, 20, 255)
def icon(name, draw_fn):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d)
    # 1 px dark outline around everything drawn.
    src = im.copy()
    sp, op = src.load(), im.load()
    for y in range(16):
        for x in range(16):
            if sp[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < 16 and 0 <= yy < 16 and sp[xx, yy][3] > 0:
                        op[x, y] = O
                        break
    im.save(os.path.join(OUT, 'icon_%s.png' % name))

STEEL, STEEL_L, STEEL_D = (190, 196, 210), (240, 244, 250), (110, 116, 130)
GOLD, GOLD_L, GOLD_D = (230, 180, 60), (255, 230, 140), (160, 110, 30)
RED, RED_L, RED_D = (200, 40, 50), (250, 110, 110), (120, 20, 30)
BROWN = (120, 80, 45)

icon('might', lambda d: (d.line([3, 12, 12, 3], fill=STEEL, width=2), d.line([4, 12, 12, 4], fill=STEEL_L),
                          d.line([2, 10, 6, 14], fill=GOLD, width=2), d.rectangle([1, 13, 2, 14], fill=BROWN)))
icon('arcana', lambda d: (d.polygon([(8, 1), (10, 6), (15, 8), (10, 10), (8, 15), (6, 10), (1, 8), (6, 6)], fill=(150, 110, 255)),
                           d.polygon([(8, 4), (9, 7), (12, 8), (9, 9), (8, 12), (7, 9), (4, 8), (7, 7)], fill=(220, 200, 255))))
icon('vitality', lambda d: (d.ellipse([2, 3, 8, 9], fill=RED), d.ellipse([7, 3, 13, 9], fill=RED),
                             d.polygon([(2, 7), (13, 7), (8, 13)], fill=RED), d.point((4, 5), fill=RED_L), d.point((5, 4), fill=RED_L)))
icon('iron_skin', lambda d: (d.polygon([(3, 2), (12, 2), (12, 8), (8, 14), (3, 8)], fill=STEEL),
                              d.polygon([(4, 3), (7, 3), (7, 12), (4, 8)], fill=STEEL_L), d.line([8, 3, 8, 13], fill=STEEL_D)))
icon('swiftness', lambda d: (d.polygon([(3, 2), (8, 2), (8, 10), (13, 11), (13, 14), (3, 14)], fill=BROWN),
                              d.line([1, 6, 4, 6], fill=(200, 230, 255)), d.line([0, 9, 3, 9], fill=(200, 230, 255)),
                              d.polygon([(9, 3), (14, 1), (12, 6)], fill=(230, 240, 255))))
icon('fury', lambda d: (d.polygon([(8, 1), (12, 7), (10, 7), (13, 14), (6, 8), (8, 8), (4, 2)], fill=(255, 120, 40)),
                         d.polygon([(8, 4), (10, 7), (9, 7), (11, 11), (7, 8), (8, 8)], fill=(255, 220, 120))))
icon('bulwark', lambda d: (d.rectangle([3, 1, 12, 14], fill=STEEL_D), d.rectangle([4, 2, 11, 13], fill=STEEL),
                            d.line([7, 3, 7, 12], fill=GOLD, width=2), d.line([4, 6, 11, 6], fill=GOLD, width=2)))
icon('focus', lambda d: (d.rectangle([3, 1, 12, 2], fill=BROWN), d.rectangle([3, 13, 12, 14], fill=BROWN),
                          d.polygon([(4, 3), (11, 3), (8, 8), (11, 12), (4, 12), (7, 8)], fill=(200, 230, 255)),
                          d.polygon([(5, 10), (10, 10), (11, 12), (4, 12)], fill=GOLD), d.point((7, 7), fill=GOLD)))
icon('zeal', lambda d: (d.polygon([(9, 0), (3, 8), (7, 8), (5, 15), (13, 6), (9, 6), (11, 0)], fill=(255, 220, 60)),
                         d.line([9, 1, 6, 7], fill=(255, 255, 200))))
icon('vampirism', lambda d: (d.polygon([(4, 2), (12, 2), (11, 6), (8, 14), (5, 6)], fill=(235, 235, 225)),
                              d.polygon([(7, 9), (9, 9), (9, 13), (8, 15), (7, 13)], fill=RED), d.line([8, 2, 8, 8], fill=(180, 180, 170))))
icon('mastery', lambda d: (d.polygon([(8, 1), (14, 7), (8, 14), (2, 7)], fill=(120, 220, 255)),
                            d.polygon([(8, 1), (14, 7), (8, 7)], fill=(255, 120, 120)), d.polygon([(2, 7), (8, 7), (8, 14)], fill=(120, 255, 150)),
                            d.polygon([(8, 7), (14, 7), (8, 14)], fill=(255, 220, 90))))
icon('greed', lambda d: (d.ellipse([2, 8, 10, 13], fill=GOLD_D), d.ellipse([2, 6, 10, 11], fill=GOLD), d.ellipse([6, 3, 14, 8], fill=GOLD_D),
                          d.ellipse([6, 1, 14, 6], fill=GOLD), d.point((9, 3), fill=GOLD_L), d.point((5, 8), fill=GOLD_L)))
icon('wisdom', lambda d: (d.rectangle([2, 3, 13, 13], fill=(70, 50, 120)), d.rectangle([3, 3, 12, 12], fill=(110, 80, 170)),
                           d.rectangle([4, 4, 11, 11], fill=(235, 225, 200)), d.line([7, 4, 7, 11], fill=(150, 130, 100)),
                           d.point((9, 6), fill=(90, 140, 255)), d.point((5, 7), fill=(90, 140, 255))))
icon('luck', lambda d: ([d.ellipse([x, y, x + 6, y + 6], fill=(70, 190, 80)) for x, y in [(1, 4), (9, 4), (5, 0), (5, 8)]],
                         d.line([8, 9, 10, 15], fill=(50, 130, 60), width=2), d.point((7, 7), fill=(160, 240, 160))))
print('ok')
