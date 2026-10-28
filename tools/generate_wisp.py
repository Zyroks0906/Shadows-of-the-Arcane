"""Procedurally draw the Elemental Wisp enemy as 32x32 pixel-art sprite sheets.

Usage: python tools/generate_wisp.py
Writes assets/sprites/enemies/Wisp/wisp_<element>.png, one row per animation:
  row 0 idle (6), row 1 attack (6), row 2 hurt (3), row 3 death (8)
"""
import math
import random
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/enemies/Wisp"
SIZE = 32
COLS = 8
ROWS = {"idle": 6, "attack": 6, "hurt": 3, "death": 8}

# outline, dark, mid, light, core (hex)
PALETTES = {
    "pyro":    ["#2a0a0a", "#a3201a", "#ff5a1f", "#ffb347", "#fff4c2"],
    "hydro":   ["#08142e", "#1546a8", "#2f8cff", "#8fd3ff", "#effaff"],
    "electro": ["#1a0a2a", "#5a1f9e", "#9b4dff", "#d7a6ff", "#fbf0ff"],
    "cryo":    ["#0a1e26", "#2a7f9c", "#5fd8ef", "#c4f6ff", "#ffffff"],
    "anemo":   ["#0a2420", "#1f8a6e", "#47d6a8", "#b5ffe6", "#f2fffb"],
    "geo":     ["#241808", "#8a5a12", "#d99a2b", "#ffd877", "#fff7d6"],
}


def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def draw_frame(pal, t: float, anim: str, step: int, total: int) -> Image.Image:
    """Return one frame. `t` is a 0..1 loop phase."""
    outline, dark, mid, light, core = [hex_rgb(c) for c in pal]
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(step * 7919 + len(anim))

    cx, cy = 16.0, 20.0 + math.sin(t * math.tau) * 1.5
    radius = 7.0
    flame_h = 14.0 + math.sin(t * math.tau * 2) * 2.0
    fade = 1.0
    if anim == "attack":
        # Inhale then flare: shrink, then grow bigger and brighter.
        k = step / (total - 1)
        radius = 7.0 + (-1.5 if k < 0.4 else 3.0 * math.sin((k - 0.4) / 0.6 * math.pi))
        flame_h += 3.0 * max(0.0, k - 0.4)
    elif anim == "hurt":
        cx += (-1.5, 1.5, 0.0)[step]
    elif anim == "death":
        k = step / (total - 1)
        radius = 7.0 * (1.0 - k * 0.85)
        flame_h *= (1.0 - k)
        fade = 1.0 - k * 0.6

    def body_value(x: float, y: float) -> float:
        """Signed field: >0 inside the wisp (orb + flickering flame tail on top)."""
        dx, dy = x - cx, y - cy
        orb = radius - math.hypot(dx, dy * 1.05)
        # Flame: a narrowing tongue above the orb, swaying sideways.
        if y < cy:
            h = (cy - y) / max(flame_h, 0.1)
            if h <= 1.0:
                sway = math.sin(t * math.tau + h * 3.5) * 3.0 * h
                width = radius * 1.05 * (1.0 - h) ** 0.85
                # A second, thinner tongue gives the silhouette a forked flame tip.
                fork = radius * 0.5 * (1.0 - h) ** 0.6 - abs(x - cx - sway * 1.6 + 2.5 * h)
                orb = max(orb, fork)
                orb = max(orb, width - abs(x - cx - sway))
        return orb

    for y in range(SIZE):
        for x in range(SIZE):
            v = body_value(x + 0.5, y + 0.5)
            if v <= 0:
                continue
            dist_core = math.hypot(x + 0.5 - (cx - 1), y + 0.5 - (cy - 1))
            if v < 1.0:
                col = outline
            elif dist_core < radius * 0.35:
                col = core
            elif dist_core < radius * 0.65:
                col = light
            elif v < 2.2:
                col = dark
            else:
                col = mid
            if anim == "hurt" and step == 0 and col != outline:
                col = (255, 255, 255, 255)
            px[x, y] = col[:3] + (int(255 * fade),)

    # Eyes: two dark pixels that blink on one idle frame.
    if anim != "death" or step < total // 2:
        blink = anim == "idle" and step == 3
        for ex in (-2, 2):
            x, y = int(cx + ex), int(cy + 0.5)
            if 0 <= x < SIZE and 0 <= y < SIZE and not blink:
                px[x, y] = outline[:3] + (int(255 * fade),)
                if 0 <= y - 1 < SIZE:
                    px[x, y - 1] = outline[:3] + (int(255 * fade),)

    # Orbiting sparks.
    sparks = 3 if anim != "death" else 6
    for i in range(sparks):
        ang = t * math.tau + i * math.tau / sparks
        r = radius + 3 + (step * 1.2 if anim == "death" else math.sin(ang * 2))
        x, y = int(cx + math.cos(ang) * r), int(cy + math.sin(ang) * r * 0.6)
        if 0 <= x < SIZE and 0 <= y < SIZE and rng.random() < 0.9:
            px[x, y] = light[:3] + (int(220 * fade),)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, pal in PALETTES.items():
        sheet = Image.new("RGBA", (SIZE * COLS, SIZE * len(ROWS)), (0, 0, 0, 0))
        for row, (anim, count) in enumerate(ROWS.items()):
            for i in range(count):
                frame = draw_frame(pal, i / count, anim, i, count)
                sheet.alpha_composite(frame, (i * SIZE, row * SIZE))
        sheet.save(OUT / f"wisp_{name}.png")
        print("wrote", OUT / f"wisp_{name}.png")


if __name__ == "__main__":
    main()
