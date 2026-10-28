"""Hand-designed layouts for maps 2 and 3, written as code so rooms stay rectangular and
aligned. Run `python tools/levels/design_levels.py` to regenerate the .txt plans, then the
Godot level builder (see tools/level_builder.gd for the legend).

Design (both maps follow level_1's logic: a hub, keyed zones, a boss behind a golden door):
- Every room has one job: entrance, hub, combat arena (doors seal, waves, reward), hazard
  route, rest room, antechamber, boss.
- The silver key is the reward of the first arena, the golden key of the second arena,
  which sits behind the silver door. The golden door leads to the boss.
- Rooms are one screen or less (about 13x9 to 22x15 tiles) and corridors are short.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))


class Plan:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [[' '] * w for _ in range(h)]

    def rect(self, x, y, w, h, c='.'):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.g[yy][xx] = c

    def put(self, x, y, c):
        assert self.g[y][x] != ' ', 'entity on rock at %d,%d (%s)' % (x, y, c)
        self.g[y][x] = c

    def door(self, x, y, c):
        # Doors and gates are cut through rock.
        self.g[y][x] = c

    def rock(self, x, y):
        self.g[y][x] = ' '

    def save(self, name):
        rows = [''.join(r).rstrip() for r in self.g]
        while rows and not rows[-1]:
            rows.pop()
        with open(os.path.join(HERE, name), 'w', encoding='utf8', newline='\n') as f:
            f.write('\n'.join(rows) + '\n')
        floor = sum(1 for r in self.g for c in r if c != ' ')
        print('%s: %dx%d, %d walkable cells' % (name, self.w, self.h, floor))


# Doors that need a key always sit in a horizontal wall (the door art is drawn facing the
# camera); only arena gates, drawn as portcullis bars, may close a side passage.
# Potions: always more health than mana in a level.

def caverns():
    p = Plan(66, 52)
    # 1. Entrance grotto: safe, a potion to start. The rest room hangs below it.
    p.rect(3, 24, 11, 8)
    p.put(5, 27, 'P')
    p.put(11, 25, 'h')
    p.rect(14, 27, 7, 2)                      # -> hub
    p.rect(7, 32, 2, 5)                       # -> rest room
    # Rest room (optional): a potion and a chest, a breather next to the start.
    p.rect(3, 37, 11, 7)
    p.put(5, 39, 'h')
    p.put(8, 42, 'C')
    p.put(12, 42, 'Y')                        # sealed chest: worth saving coins for
    p.put(12, 39, '$')
    p.put(4, 42, '$')
    # 2. Echo Hall (hub): a shallow pool in the middle, a couple of rats.
    p.rect(21, 22, 17, 11)
    p.rect(26, 25, 6, 4, ',')
    p.put(34, 30, 'e')
    p.put(23, 24, 'e')
    p.put(36, 23, '$')
    # North: silver door, then a short climb to the flooded gallery.
    p.door(29, 21, 'D')
    p.rect(29, 13, 2, 8)
    p.rock(30, 20)
    # South: arena 1 behind gates.
    p.rect(28, 33, 2, 4)
    p.door(28, 37, '=')
    p.door(29, 37, '=')
    # East: an open passage to the vestibule before the boss.
    p.rect(38, 26, 6, 2)
    # 3. Arena 1 "Slime Pools": slimes, pools to lure them into, an electro crystal.
    p.rect(22, 38, 15, 11)
    p.rect(24, 40, 3, 3, ',')
    p.rect(32, 45, 3, 3, ',')
    p.put(29, 43, 'R')
    p.put(29, 40, 'z')
    for x, y in [(25, 41), (33, 41), (24, 47), (33, 46)]:
        p.put(x, y, 's')
    for x, y in [(23, 43), (35, 43), (29, 47)]:
        p.put(x, y, 'E')
    p.put(34, 39, 'k')
    p.put(26, 45, 'T')                        # transmuter: rises once the arena is cleared
    # 4. Flooded Gallery: a deep river split by one shallow ford, wisps over the water.
    p.rect(20, 2, 18, 11)
    p.rect(20, 6, 18, 2, '~')
    p.rect(27, 5, 3, 4, ',')
    p.rect(20, 8, 6, 1, ',')
    p.rect(32, 5, 6, 1, ',')
    p.put(23, 3, 'w')
    p.put(35, 11, 'w')
    p.put(33, 3, 'e')
    p.put(21, 11, 'c')
    p.put(36, 3, 'm')
    p.rect(38, 3, 5, 2)
    p.door(43, 3, '=')
    p.door(43, 4, '=')
    # 5. Arena 2 "Wisp Shrine": casters and slimes, the golden key.
    p.rect(44, 1, 15, 11)
    p.put(51, 6, 'R')
    p.put(47, 6, 'p')
    p.put(55, 6, 'p')
    for x, y in [(46, 3), (56, 3), (51, 10)]:
        p.put(x, y, 'w')
    p.put(47, 9, 's')
    for x, y in [(45, 6), (57, 6), (51, 2)]:
        p.put(x, y, 'E')
    p.put(56, 10, 'g')
    # 6. Vestibule: supplies; the golden door in its floor leads down to the lair.
    p.rect(44, 22, 9, 8)
    p.put(45, 23, 'h')
    p.put(51, 23, 'h')
    p.put(51, 28, 'm')
    p.door(48, 30, 'G')
    p.rect(48, 31, 1, 4)
    p.door(48, 33, 'd')
    # 7. Guardian's lair.
    p.rect(39, 35, 20, 14)
    p.put(48, 41, 'B')
    p.put(48, 46, 'X')
    for x, y in [(41, 37), (56, 37)]:
        p.put(x, y, 'c')
    for x, y in [(41, 46), (56, 46)]:
        p.put(x, y, 'z')
    p.rect(40, 39, 2, 6, ',')
    p.rect(56, 39, 2, 6, ',')
    p.save('whispering_caverns.txt')


def skyhold():
    p = Plan(86, 48)
    # 1. Entrance hall.
    p.rect(4, 24, 11, 8)
    p.put(6, 27, 'P')
    p.put(12, 25, 'h')
    p.rect(15, 27, 6, 2)
    # 2. Courtyard (hub): rune circle, four columns, a light patrol.
    p.rect(21, 21, 17, 13)
    p.rect(27, 25, 5, 5, '*')
    for x, y in [(23, 23), (35, 23), (23, 31), (35, 31)]:
        p.put(x, y, 'p')
    p.put(33, 24, 'e')
    p.put(25, 30, 'e')
    # North: silver door, then an updraft corridor that pushes back down (headwind).
    p.door(29, 20, 'D')
    p.rect(29, 12, 2, 8, 'V')
    p.rock(30, 19)
    # 3. Bell tower: wisps above the updraft.
    p.rect(21, 1, 17, 11)
    p.put(24, 3, 'w')
    p.put(34, 9, 'w')
    p.put(31, 2, 'e')
    p.put(22, 10, 'z')
    p.put(36, 2, 'm')
    p.put(24, 9, 'Y')                         # sealed chest in the bell tower
    p.rect(38, 5, 5, 2)
    p.door(43, 5, '=')
    p.door(43, 6, '=')
    # 4. Arena 2 "Sanctum Guard": the golden key.
    p.rect(44, 1, 15, 11)
    p.rect(49, 4, 5, 5, '*')
    p.put(51, 6, 'R')
    p.put(46, 3, 'w')
    p.put(56, 3, 'w')
    p.put(51, 10, 'O')
    p.put(46, 9, 'e')
    for x, y in [(45, 6), (57, 6), (51, 2)]:
        p.put(x, y, 'E')
    p.put(57, 10, 'g')
    # East: an open passage to the vestibule.
    p.rect(38, 26, 6, 2)
    # 5. Vestibule: supplies; the golden door in its north wall, then the boss door.
    p.rect(44, 23, 9, 8)
    p.put(45, 24, 'h')
    p.put(51, 24, 'h')
    p.put(51, 29, 'm')
    p.door(48, 22, 'G')
    p.rect(48, 15, 1, 7)
    p.door(48, 19, 'd')
    p.rect(48, 15, 14, 2)
    # 6. The Warden's hall: columns to hide behind, wind lanes along the sides.
    p.rect(62, 2, 20, 17)
    p.rect(67, 7, 10, 7, '*')
    p.put(72, 10, 'B')
    p.put(72, 4, 'X')
    for x, y in [(65, 5), (78, 5), (65, 15), (78, 15)]:
        p.put(x, y, 'p')
    p.rect(63, 4, 1, 13, 'V')
    p.rect(80, 4, 1, 13, 'A')
    # South: the wind bridge to the barracks. A crosswind shoves you towards the spikes.
    p.rect(28, 34, 3, 3)
    p.rect(28, 37, 18, 2, 'V')
    p.rect(28, 39, 18, 1)
    for x in range(31, 45, 3):
        p.put(x, 39, 'x')
    for y in range(37, 40):
        p.door(46, y, '=')
    # 7. Arena 1 "Barracks": orcs and skeletons, silver key.
    p.rect(47, 34, 15, 11)
    p.put(54, 39, 'R')
    for x, y in [(50, 36), (58, 36), (50, 42), (58, 42)]:
        p.put(x, y, 'p')
    for x, y in [(51, 39), (57, 39)]:
        p.put(x, y, 'O')
    for x, y in [(54, 35), (54, 43)]:
        p.put(x, y, 'e')
    for x, y in [(48, 35), (60, 35), (60, 43)]:
        p.put(x, y, 'E')
    p.put(60, 40, 'k')
    p.put(48, 43, 'T')                        # transmuter: rises once the arena is cleared
    p.save('skyhold_ruins.txt')


def crypt():
    # The Undercroft, under the Golem's hatch (level_1 style). You drop in at the ladder; the
    # dead rise from the far end in two waves; clearing it earns a perk and frees the ladder.
    p = Plan(25, 16)
    p.rect(2, 2, 21, 11)
    p.rect(11, 13, 3, 2)                      # ladder alcove
    p.put(12, 13, 'P')
    p.put(12, 14, 'L')
    p.put(12, 7, 'R')
    p.put(14, 9, 'T')                         # transmuter: rises once the dead are put down
    for x, y in [(3, 3), (21, 3), (3, 11), (21, 11)]:
        p.put(x, y, 'i')
    for x, y in [(6, 3), (18, 3), (6, 11), (18, 11)]:
        p.put(x, y, 'o')
    for x, y in [(8, 3), (16, 3), (5, 6), (19, 6)]:
        p.put(x, y, 's' if x in (5, 19) else 'e')
    for x, y in [(10, 3), (14, 3), (12, 4)]:
        p.put(x, y, 'E')
    p.save('crypt.txt')


if __name__ == '__main__':
    caverns()
    skyhold()
    crypt()
