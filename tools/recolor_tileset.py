"""Palette-shift Dungeon_Tileset.png into per-level variants.

Usage: python tools/recolor_tileset.py
Writes assets/tilesets/generated/dungeon_<theme>.png
"""
import colorsys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/tilesets/character and tileset/Dungeon_Tileset.png"
OUT = ROOT / "assets/tilesets/generated"

# hue in degrees, saturation multiplier, value multiplier, value offset
THEMES = {
    # Whispering Caverns: wet blue-teal rock
    "caverns": {"hue": 192, "sat": 0.85, "val": 0.92, "add": 0.0},
    # Skyhold Ruins: pale weathered stone with a violet arcane cast
    "skyhold": {"hue": 255, "sat": 0.35, "val": 1.25, "add": 0.04},
}

def recolor(img: Image.Image, hue: float, sat: float, val: float, add: float) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Keep relative hue differences (mortar vs brick) but rotate the whole palette.
            h = ((hue / 360.0) + (h - 0.8) * 0.35) % 1.0
            s = min(1.0, s * sat)
            v = min(1.0, v * val + add)
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    for name, t in THEMES.items():
        recolor(src, t["hue"], t["sat"], t["val"], t["add"]).save(OUT / f"dungeon_{name}.png")
        print("wrote", OUT / f"dungeon_{name}.png")

if __name__ == "__main__":
    main()
