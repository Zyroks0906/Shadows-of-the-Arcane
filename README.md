# ⚔️ Shadows of the Arcane

![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-green)
![Genre](https://img.shields.io/badge/Genre-RPG-orange)

**Shadows of the Arcane** is a 2D Top-Down RPG built with Godot 4. Explore dark dungeons, interact with mysterious entities, and master a complex **Elemental Reaction System** inspired by modern alchemy-based combat.

## ✨ Features
- **Elemental Reaction System**: Combine Pyro, Hydro, Electro, Cryo, Anemo and Geo to unleash devastating effects (Vaporize, Melt, Overloaded, and more).
- **Reactive Combat**: The environment and enemies imbue you with elements—use them to your advantage. Classes without an element of their own attack with whatever element is imbued on them.
- **Classic RPG Stats**: Strength (melee damage), Intelligence (+1% reaction damage per point), Resistance, and Wisdom (mana regeneration). Special attacks cost mana.

## 🔥 Elemental Reactions
| Reaction | Elements | Effect |
|---|---|---|
| Vaporize | Pyro + Hydro | x1.5–x2 damage, steam burst |
| Melt | Pyro + Cryo | x1.5–x2 damage |
| Overloaded | Pyro + Electro | Explosion: area damage and knockback |
| Superconduct | Cryo + Electro | Area damage, halves Resistance for 6s |
| Electro-Charged | Hydro + Electro | Damage over time that arcs to nearby enemies |
| Frozen | Hydro + Cryo | Freezes the enemy; the next hit **Shatters** for +50% |
| Swirl | Anemo + any | Spreads the absorbed element to nearby enemies |
| Crystallize | Geo + any | Drops a crystal shard that shields the player |

Combat feel: hit-stop, screen shake, white hit flash, knockback, damage numbers and short player invulnerability after a hit.

## 🗺️ Chambers
1. **Forest Depths Entrance** (`level_1.tscn`): beating the Demon unlocks the next chamber.
2. **Whispering Caverns** (`level_2.tscn`): an underground river. Shallow water imbues Hydro and slows (lure enemies in, then strike with Electro), pulsing Cryo/Electro crystals, a flooded vault with the silver key. Boss: the **Guardian**, a crystal golem.
3. **Skyhold Ruins & Tower** (`level_3.tscn`): castle ruins and an arcane library. Wind currents push you and imbue Anemo; an updraft carries you up the tower. Boss: the **Warden**, an Electro-charged golem, on the rune circle.

New enemies: **Wisp** (ranged elemental caster, one per element) and **Orc** (bruiser with a telegraphed heavy cleave).
- **Pixel Art Aesthetics**: Atmospheric dungeon exploration with high-quality pixel assets.

## 🛠️ Tech Stack
- **Engine**: Godot 4.x (Forward+).
- **Language**: GDScript (Strongly Typed).
- **Workflow**: GitFlow (main, develop, features).

## 🚀 Getting Started
1. Clone the repository: `git clone https://github.com/Zyroks0906/Shadows-of-the-Arcane.git`
2. Open the project in Godot 4.6+.
3. Run the project (main menu) or open `scenes/levels/level_1.tscn` to start exploring.

## 🧰 Tools
Chambers 2 and 3 are generated from editable ASCII layouts in `tools/levels/` (legend at the top of `tools/level_builder.gd`). After editing a layout:

```bash
Godot_v4.6.2-stable_win64_console.exe --headless --path . res://tools/level_builder.tscn
```

- `tools/render_level.tscn`: renders a level to PNG for a quick overview.
- `tools/recolor_tileset.py` / `tools/generate_wisp.py`: regenerate the recoloured tilesets and the Wisp sprites.
- Tests: `res://tests/combat_test.tscn` (reactions and combat) and `res://tests/level_smoke.tscn` (loads every chamber), run with `--headless`.

## 📂 Project Structure
- `assets/`: Raw sprites, tilesets, and audio.
- `scenes/`: Godot scenes (.tscn).
- `scripts/`: Game logic (.gd).
- `resources/`: Configuration data.
- `tools/`: Level builder, layouts and asset generators.
- `tests/`: Headless test scenes.

---
*Developed as part of the PGL project migration.*
