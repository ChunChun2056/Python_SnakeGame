#!/usr/bin/env python3
"""Builds the 40 level data files in levels/ from hand-designed chunks.

Levels are plain text so they can be tweaked by hand afterwards; see
docs in README.md ("Level format") for the legend. Every chunk respects the
player's movement limits so no level contains a blind or impossible jump:

  * normal jump rise   <= 3 tiles      * walking gap  <= 3 tiles
  * sprint gap         <= 4 tiles      * blocks sit 4 rows above the floor

Usage: python3 tools/gen_levels.py
"""
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "levels")
ROWS = 18
G = 15  # ground surface row

WORLD_NAMES = ["Green Meadows", "Sunbaked Desert", "Crystal Caverns", "Sky Islands",
               "Frozen Peaks", "Sunken Ruins", "Volcanic Depths", "Shadow Citadel"]
LEVEL_NAMES = [
    ["First Steps", "Clover Hills", "Buzzing Brook", "Windmill Way", "Grumble Keep"],
    ["Dune Road", "Quicksand Basin", "Scorpion Steps", "Mirage Market", "Sandstone Bastion"],
    ["Glowstone Gate", "Dark Tunnels", "Geode Gallery", "Echo Hollow", "Shade Sanctum"],
    ["Cloud Hop", "Gusty Gardens", "Floating Fields", "Thunder Bridge", "Storm Spire"],
    ["Snowy Trail", "Slippery Slopes", "Icicle Cavern", "Avalanche Pass", "Frost Fortress"],
    ["Tide Pools", "Coral Depths", "Drowned Plaza", "Current Canyon", "Abyssal Temple"],
    ["Ember Path", "Magma Falls", "Cinder Bridges", "Furnace Core", "Molten Throne"],
    ["Citadel Gates", "Gear Works", "Midnight Halls", "Traitor's Climb", "Umbra Throne"],
]
WORLD_ENEMIES = ["eef", "hhre", "GefG", "ffeh", "yyre", "nnef", "mmre", "emyrhG"]
BOSSES = ["walker", "hopper", "ghost", "flyer", "yeti", "fish", "magma", "umbra"]
POWERUPS = [
    "shield,speed,mega", "shield,mega,speed,magnet", "shield,blast,magnet,mega",
    "mega,shield,speed,blast", "shield,speed,blast,mega", "shield,blast,magnet,speed",
    "shield,blast,mega,speed", "shield,blast,mega,magnet,speed",
]


class Canvas:
    def __init__(self, width):
        self.w = width
        self.g = [["."] * width for _ in range(ROWS)]
        self.header = []
        self.signs = []

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < ROWS:
            self.g[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < ROWS:
            return self.g[y][x]
        return "#"

    def ground(self, x0, x1, top=G, ch="#"):
        for x in range(x0, x1):
            for y in range(top, ROWS):
                self.put(x, y, ch)

    def clear_col(self, x):
        for y in range(ROWS):
            self.put(x, y, ".")

    def row(self, x0, x1, y, ch):
        for x in range(x0, x1):
            self.put(x, y, ch)

    def text(self, w=None):
        return ["".join(r[: (w or self.w)]) for r in self.g]


class Builder:
    def __init__(self, world, level, rng):
        self.world = world  # 0..7
        self.level = level  # 0..4
        self.rng = rng
        self.c = Canvas(700)
        self.x = 0
        self.diff = (world * 5 + level) / 39.0
        self.enemies = WORLD_ENEMIES[world]
        self.secrets = 0
        self.warps = []
        self.room_x = None
        self.ice = world == 4
        self.water = world == 5
        self.lava = world == 6

    # ---------------------------------------------------------- helpers
    def enemy(self):
        return self.rng.choice(self.enemies)

    def place_enemy(self, x, ch=None):
        ch = ch or self.enemy()
        if ch == "f":
            self.c.put(x, G - 4, "f")
        elif ch == "n":
            if self.water:
                self.c.put(x, G - 3, "n")
            else:
                self.c.put(x, G - 1, "e")
        else:
            self.c.put(x, G - 1, ch)

    def coin_arc(self, x0, width, base=G - 3):
        for i in range(width):
            mid = (width - 1) / 2.0
            h = int(round(2 - abs(i - mid) / max(mid, 1) * 2))
            self.c.put(x0 + i, base - h, "o")

    def flat_ground(self, x0, x1):
        self.c.ground(x0, x1)
        if self.ice:
            self.c.row(x0, x1, G, "I")

    def gap_limit(self):
        return 2 if self.diff < 0.15 else (3 if self.diff < 0.6 else 4)

    # ---------------------------------------------------------- chunks
    def ch_flat(self):
        n = self.rng.randint(8, 12)
        x = self.x
        self.flat_ground(x, x + n)
        self.coin_arc(x + 2, 5)
        if self.rng.random() < 0.7:
            self.place_enemy(x + n - 3)
        if self.rng.random() < 0.3:
            self.c.put(x + 1, G - 1, "." if self.world in (2, 7) else "d")
        self.x += n

    def ch_gap(self):
        x = self.x
        gap = self.rng.randint(2, self.gap_limit())
        self.flat_ground(x, x + 4)
        self.flat_ground(x + 4 + gap, x + 8 + gap)
        self.coin_arc(x + 3, gap + 2, G - 3)
        if self.lava:
            for gx in range(x + 4, x + 4 + gap):
                self.c.put(gx, 16, "L")
                self.c.put(gx, 17, "L")
            if gap >= 3 and self.rng.random() < 0.6:
                self.c.put(x + 4 + gap // 2, 16, "j")
        self.x += 8 + gap

    def ch_blocks(self):
        x = self.x
        n = 12
        self.flat_ground(x, x + n)
        patterns = ["B?B?B", "?BUB?", "BB?BB", "?.?.?", "BUB", "B?BB?B"]
        p = self.rng.choice(patterns)
        bx = x + 3
        for i, ch in enumerate(p):
            if ch != ".":
                self.c.put(bx + i, G - 4, ch)
        if self.rng.random() < 0.5:
            self.c.put(bx + len(p) // 2, G - 8, "?")
            self.c.row(bx + 1, bx + len(p) - 1, G - 5, "o") if False else None
        if self.rng.random() < 0.6:
            self.place_enemy(x + n - 2)
        self.x += n

    def ch_stairs(self):
        x = self.x
        h = self.rng.randint(2, 4)
        block = "X" if self.world in (2, 7) else "#"
        self.flat_ground(x, x + 2 * h + 6)
        for i in range(h):
            for k in range(i + 1):
                self.c.put(x + 2 + i, G - 1 - k, block)
        top = x + 2 + h
        gap = 0
        if self.diff > 0.1 and self.rng.random() < 0.6:
            gap = min(self.gap_limit(), 2)
            for gx in range(top, top + gap):
                self.c.clear_col(gx)
                if self.lava:
                    self.c.put(gx, 16, "L")
                    self.c.put(gx, 17, "L")
        for i in range(h):
            for k in range(h - i):
                self.c.put(top + gap + i, G - 1 - k, block)
        self.c.row(top - 1, top + gap + 1, G - h - 3, "o")
        self.x += 2 * h + 6 + gap

    def ch_platforms(self):
        """Pit crossed by stepping-stone one-way platforms."""
        x = self.x
        n = self.rng.randint(3, 4)
        self.flat_ground(x, x + 3)
        px = x + 3
        y = G - 2
        for i in range(n):
            gap = self.rng.randint(1, 2)
            px += gap
            w = self.rng.randint(2, 4)
            ch = "c" if (self.world in (1, 4, 6) and self.rng.random() < 0.4) else "="
            self.c.row(px, px + w, y, ch)
            self.c.row(px, px + w, y - 2, "o")
            if w >= 4 and self.rng.random() < 0.3 and self.diff > 0.2:
                self.c.put(px + 1, y - 1, "e" if "e" in self.enemies else self.enemies[0])
            px += w
            y = max(G - 5, min(G - 1, y + self.rng.choice([-1, 0, 1])))
        px += self.rng.randint(1, 2)
        if self.lava:
            for gx in range(x + 3, px):
                self.c.put(gx, 16, "L")
                self.c.put(gx, 17, "L")
        self.flat_ground(px, px + 4)
        self.x = px + 4

    def ch_hill(self):
        x = self.x
        n = self.rng.randint(10, 14)
        self.flat_ground(x, x + n)
        hx = x + 2
        hw = n - 4
        self.c.ground(hx, hx + hw, G - 2)
        self.c.ground(hx + 2, hx + hw - 2, G - 3)
        if self.ice:
            for gx in range(hx, hx + hw):
                for gy in range(G - 3, G):
                    if self.c.get(gx, gy) == "#" and self.c.get(gx, gy - 1) == ".":
                        self.c.put(gx, gy, "I")
        self.c.row(hx + 2, hx + hw - 2, G - 5, "o")
        if self.rng.random() < 0.7:
            self.c.put(hx + hw // 2, G - 4, self.enemy() if self.enemy() not in "fn" else "e")
        self.x += n

    def ch_spikes(self):
        x = self.x
        n = 12
        self.flat_ground(x, x + n)
        spots = [x + 3, x + 8]
        for s in spots:
            w = self.rng.randint(1, 2)
            for k in range(w):
                self.c.put(s + k, G - 1, "^")
            self.c.put(s, G - 4, "o")
        self.x += n

    def ch_moving(self):
        x = self.x
        self.flat_ground(x, x + 3)
        span = self.rng.randint(7, 9)
        vertical = self.rng.random() < 0.35
        if vertical:
            self.c.put(x + 3 + span // 2, G - 2, "V")
        else:
            self.c.put(x + 3 + span // 2, G - 1, "M")
        self.c.row(x + 4, x + 3 + span - 1, G - 5, "o")
        if self.lava:
            for gx in range(x + 3, x + 3 + span):
                self.c.put(gx, 16, "L")
                self.c.put(gx, 17, "L")
        self.flat_ground(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def ch_crumble(self):
        x = self.x
        self.flat_ground(x, x + 3)
        span = self.rng.randint(5, 7)
        self.c.row(x + 3, x + 3 + span, G, "c")
        self.c.row(x + 3, x + 3 + span, G - 3, "o")
        if self.lava:
            for gx in range(x + 3, x + 3 + span):
                self.c.put(gx, 16, "L")
                self.c.put(gx, 17, "L")
        self.flat_ground(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def ch_enemies(self):
        x = self.x
        n = 14
        self.flat_ground(x, x + n)
        k = 2 if self.diff < 0.4 else 3
        for i in range(k):
            self.place_enemy(x + 4 + i * 4)
        if self.rng.random() < 0.5:
            self.c.row(x + 5, x + 9, G - 4, "=")
            self.c.row(x + 5, x + 9, G - 5, "o")
        self.x += n

    def ch_pillars(self):
        x = self.x
        n = 14
        self.flat_ground(x, x + n)
        for i, px in enumerate((x + 3, x + 9)):
            h = self.rng.randint(2, 3)
            for k in range(h):
                self.c.put(px, G - 1 - k, "X")
                self.c.put(px + 1, G - 1 - k, "X")
            self.c.put(px, G - h - 2, "o")
            self.c.put(px + 1, G - h - 2, "o")
        self.place_enemy(x + 6, "e" if "e" in self.enemies else None)
        self.x += n

    def ch_quicksand(self):
        x = self.x
        n = 12
        self.flat_ground(x, x + n)
        for gx in range(x + 3, x + 9):
            self.c.put(gx, G, "Q")
            self.c.put(gx, G + 1, "Q")
        self.c.row(x + 4, x + 8, G - 4, "o")
        self.x += n

    def ch_cave_ceiling(self):
        x = self.x
        n = self.rng.randint(12, 16)
        self.flat_ground(x, x + n)
        for gx in range(x, x + n):
            for gy in range(0, G - 6):
                self.c.put(gx, gy, "#")
        for rx in range(x + 3, x + n - 2, 4):
            if self.rng.random() < 0.7:
                self.c.put(rx, G - 6, "R")
        self.c.row(x + 2, x + n - 2, G - 2, "o")
        if self.rng.random() < 0.6:
            self.place_enemy(x + n - 3, "G" if "G" in self.enemies else None)
        self.x += n

    def ch_wind(self):
        x = self.x
        self.flat_ground(x, x + 3)
        span = self.rng.randint(6, 8)
        for gx in range(x + 3 + span // 2 - 1, x + 3 + span // 2 + 1):
            for gy in range(4, ROWS):
                self.c.put(gx, gy, "Z")
        self.c.row(x + 4, x + 3 + span - 1, 3, "o")
        self.flat_ground(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def ch_water_pool(self):
        x = self.x
        self.flat_ground(x, x + 3)
        span = self.rng.randint(8, 12)
        self.c.ground(x + 3, x + 3 + span, 17)
        for gx in range(x + 3, x + 3 + span):
            for gy in range(G - 1 if self.level == 0 else G, 17):
                self.c.put(gx, gy, "W")
        if span > 9:
            self.c.put(x + 3 + span // 2, 15, "n")
        self.c.put(x + 4, 16, "o")
        self.c.put(x + 2 + span, 16, "o")
        self.flat_ground(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def ch_underwater(self):
        """Fully submerged corridor with obstacles; bubbles every chunk."""
        x = self.x
        n = self.rng.randint(14, 18)
        self.flat_ground(x, x + n)
        for gx in range(x, x + n):
            for gy in range(3, G):
                if self.c.get(gx, gy) == ".":
                    self.c.put(gx, gy, "W")
        # coral pillars from floor and ceiling
        for px in range(x + 4, x + n - 2, 6):
            h = self.rng.randint(3, 5)
            for k in range(h):
                self.c.put(px, G - 1 - k, "X")
            if self.rng.random() < 0.5:
                for k in range(3):
                    self.c.put(px + 3, 3 + k, "X")
        cur = self.rng.choice("<>..")
        if cur != ".":
            for gx in range(x + 1, x + n - 1):
                self.c.put(gx, 7, cur)
                self.c.put(gx, 8, cur)
        self.c.put(x + 2, G - 1, "A")
        self.c.put(x + n // 2, 6, "n")
        self.c.row(x + 2, x + n - 2, 10, "o") if self.rng.random() < 0.5 else None
        for gx in range(x, x + n):
            for gy in range(0, 3):
                self.c.put(gx, gy, "#")
        self.x += n

    def ch_lava_jumpers(self):
        x = self.x
        self.flat_ground(x, x + 3)
        segs = 3
        px = x + 3
        for i in range(segs):
            gap = self.rng.randint(2, 3)
            for gx in range(px, px + gap):
                self.c.put(gx, 16, "L")
                self.c.put(gx, 17, "L")
            if i == 1:
                self.c.put(px + 1, 16, "j")
            px += gap
            self.c.ground(px, px + 2, G - self.rng.randint(0, 2), "X")
            self.c.put(px, G - 4, "o")
            px += 2
        self.flat_ground(px, px + 3)
        self.x = px + 3

    def ch_crushers(self):
        x = self.x
        n = 16
        self.flat_ground(x, x + n)
        for gx in range(x, x + n):
            for gy in range(0, 3):
                self.c.put(gx, gy, "X")
        for cx in (x + 4, x + 10):
            self.c.put(cx, 3, "Y")
        self.c.row(x + 2, x + n - 2, G - 1, "o")
        self.x += n

    def ch_spikeballs(self):
        x = self.x
        n = 14
        self.flat_ground(x, x + n)
        self.c.put(x + 5, G - 3, "z")
        self.c.put(x + 10, G - 6, "z")
        self.c.row(x + 3, x + 12, G - 1, "o")
        self.x += n

    def ch_secret_wall(self):
        """A hill with a fake wall hiding a treasure alcove."""
        x = self.x
        n = 12
        self.flat_ground(x, x + n)
        hx = x + 4
        self.c.ground(hx, hx + 6, G - 4, "#")
        for gx in range(hx, hx + 6):
            for gy in range(G - 3, G):
                self.c.put(gx, gy, "#" if gx == hx + 5 else "O")
        self.c.put(hx + 4, G - 1, "*")
        self.c.put(hx + 3, G - 1, "o")
        self.c.put(hx + 2, G - 1, "o")
        if self.ice:
            for gx in range(hx, hx + 6):
                self.c.put(gx, G - 4, "I")
        self.secrets += 1
        self.x += n

    def ch_secret_high(self):
        """Hidden block leads up to a high ledge with a treasure."""
        x = self.x
        n = 12
        self.flat_ground(x, x + n)
        self.c.put(x + 3, G - 4, "H")
        self.c.row(x + 6, x + 10, G - 7, "=")
        self.c.put(x + 8, G - 8, "*")
        self.c.put(x + 7, G - 8, "o")
        self.c.put(x + 9, G - 8, "o")
        self.secrets += 1
        self.x += n

    def ch_secret_warp(self):
        x = self.x
        n = 10
        self.flat_ground(x, x + n)
        # warp sits on a small ledge reached from a step
        self.c.put(x + 3, G - 1, "X")
        self.c.row(x + 4, x + 7, G - 3, "=")
        self.warps.append((x + 6, G - 4))
        self.x += n

    def ch_checkpoint(self):
        x = self.x
        self.flat_ground(x, x + 6)
        self.c.put(x + 3, G - 1, "C")
        self.x += 6

    # ---------------------------------------------------------- level assembly
    def chunk_pool(self):
        w = self.world
        common = [self.ch_flat, self.ch_gap, self.ch_blocks, self.ch_stairs, self.ch_hill, self.ch_enemies]
        pools = {
            0: common + [self.ch_platforms, self.ch_pillars],
            1: common + [self.ch_quicksand, self.ch_quicksand, self.ch_crumble, self.ch_platforms, self.ch_spikeballs],
            2: common + [self.ch_cave_ceiling, self.ch_cave_ceiling, self.ch_platforms, self.ch_spikes],
            3: [self.ch_platforms, self.ch_platforms, self.ch_moving, self.ch_moving, self.ch_wind, self.ch_wind,
                self.ch_gap, self.ch_blocks, self.ch_enemies],
            4: common + [self.ch_crumble, self.ch_platforms, self.ch_spikes, self.ch_cave_ceiling],
            5: [self.ch_water_pool, self.ch_water_pool, self.ch_flat, self.ch_blocks, self.ch_platforms,
                self.ch_enemies, self.ch_hill],
            6: [self.ch_lava_jumpers, self.ch_lava_jumpers, self.ch_crumble, self.ch_gap, self.ch_moving,
                self.ch_platforms, self.ch_enemies, self.ch_stairs, self.ch_spikeballs],
            7: [self.ch_crushers, self.ch_spikeballs, self.ch_moving, self.ch_platforms, self.ch_gap,
                self.ch_enemies, self.ch_spikes, self.ch_lava_jumpers, self.ch_cave_ceiling, self.ch_crumble],
        }
        pool = pools[w]
        if w == 5 and self.level in (1, 3):
            pool = [self.ch_underwater, self.ch_underwater, self.ch_underwater, self.ch_water_pool, self.ch_flat]
        return pool

    def build(self):
        c = self.c
        rng = self.rng
        boss = self.level == 4
        # start area
        self.flat_ground(0, 8)
        c.put(2, G - 1, "S")
        self.x = 8
        count = 10 + self.world + self.level * 2 - (5 if boss else 0)
        count = max(8, count)
        pool = self.chunk_pool()
        secret_kinds = [self.ch_secret_wall, self.ch_secret_high, self.ch_secret_warp]
        rng.shuffle(secret_kinds)
        n_secrets = 1 if self.diff < 0.1 else (2 if self.diff < 0.5 else 3)
        if boss:
            n_secrets = 1
        secret_at = sorted(rng.sample(range(1, count), n_secrets))
        cp_at = [count // 2] if count < 16 else [count // 3, (2 * count) // 3]
        if self.level == 2 and self.world == 0:
            pool = pool + [self.ch_platforms]
        # every level of a world features that world's signature mechanics
        must = {
            1: [self.ch_quicksand, self.ch_crumble],
            2: [self.ch_cave_ceiling, self.ch_cave_ceiling],
            3: [self.ch_wind, self.ch_moving],
            4: [self.ch_crumble, self.ch_hill],
            5: [self.ch_water_pool] if self.level not in (1, 3) else [self.ch_underwater],
            6: [self.ch_lava_jumpers, self.ch_crumble],
            7: [self.ch_crushers, self.ch_spikeballs],
        }.get(self.world, [])
        must_at = {}
        for k, fn in enumerate(must):
            must_at[1 + k * max(2, count // (len(must) + 1))] = fn
        last = None
        for i in range(count):
            if i in cp_at:
                self.ch_checkpoint()
            if i in secret_at:
                secret_kinds[secret_at.index(i) % 3]()
            if i in must_at:
                fn = must_at[i]
            else:
                fn = rng.choice(pool)
                while fn == last and len(pool) > 1:
                    fn = rng.choice(pool)
            last = fn
            fn()
            # a short safe floor between chunks keeps landings fair
            self.flat_ground(self.x, self.x + 2)
            self.x += 2
        if boss:
            self.boss_arena()
        else:
            self.goal_area()
        main_end = self.x
        self.bonus_room(main_end)
        return main_end

    def goal_area(self):
        x = self.x
        self.flat_ground(x, x + 18)
        for i in range(5):
            for k in range(i + 1):
                self.c.put(x + 2 + i, G - 1 - k, "X")
        self.c.put(x + 11, G - 1, "F")
        self.c.row(x + 13, x + 18, G - 1, ".")
        for y in range(0, ROWS):
            self.c.put(x + 18, y, "X")
        self.x = x + 19

    def boss_arena(self):
        x = self.x
        self.ch_checkpoint()
        x = self.x
        n = 22
        self.flat_ground(x, x + n)
        for gx in range(x, x + n):
            self.c.put(gx, 1, "X")
        for y in range(0, ROWS):
            self.c.put(x + n, y, "X")
        self.c.row(x + 3, x + 7, G - 4, "=")
        self.c.row(x + n - 7, x + n - 3, G - 4, "=")
        self.c.put(x + n - 6, G - 2, "K")
        self.c.put(x + n - 3, G - 1, "F")
        self.c.put(x + 2, G - 4, "U")
        self.arena = (x, x + n)
        self.x = x + n + 1

    def bonus_room(self, main_end):
        x = main_end + 4
        n = 16
        if not self.warps:
            self.room_x = None
            return
        self.c.ground(x, x + n, G)
        for y in range(0, ROWS):
            self.c.put(x, y, "X")
            self.c.put(x + n - 1, y, "X")
        for gx in range(x, x + n):
            self.c.put(gx, 2, "X")
        for gx in range(x + 2, x + n - 2):
            self.c.put(gx, G - 1, "o")
            self.c.put(gx, G - 5, "o" if gx % 2 == 0 else ".")
        self.c.row(x + 4, x + n - 4, G - 3, "=")
        self.c.put(x + n // 2, G - 4, "*")
        self.c.put(x + 3, G - 6, "g")
        self.c.put(x + n - 4, G - 6, "g")
        self.secrets += 1
        src = self.warps[0]
        dest = (x + 2, G - 1)
        back_src = (x + n - 3, G - 1)
        back_dst = (src[0] + 4, G - 1)
        self.c.header.append("warp=%d,%d>%d,%d" % (src[0], src[1], dest[0], dest[1]))
        self.c.header.append("warp=%d,%d>%d,%d" % (back_src[0], back_src[1], back_dst[0], back_dst[1]))
        self.c.header.append("room=%d,%d" % (x, x + n))
        self.room_x = x + n

    def finalize(self, main_end):
        c = self.c
        width = (self.room_x or main_end) + 1
        # water worlds: seal the sea bed so swimming never drops out of the map
        if self.water:
            for gx in range(width):
                if c.get(gx, 17) == ".":
                    c.put(gx, 17, "#")
                    for gy in range(G, 17):
                        if c.get(gx, gy) == ".":
                            c.put(gx, gy, "W")
        # decorations on the ground surface
        for gx in range(width):
            if c.get(gx, G) in "#" and c.get(gx, G - 1) == "." and self.rng.random() < 0.12:
                c.put(gx, G - 1, "d")
        for y in range(ROWS):
            for gx in range(width):
                if c.g[y][gx] == "d" and self.world in (2, 7) and self.rng.random() < 0.5:
                    c.g[y][gx] = "D"
        return width


def tutorial_level():
    """World 1-1: hand-designed to teach every core control.

    Returns (rows, header, signs, main_end)."""
    c = Canvas(190)
    put, row, ground = c.put, c.row, c.ground
    ground(0, 30)
    put(2, 14, "S")
    put(5, 14, "T")                      # walk
    put(11, 14, "T")                     # jump
    put(14, 14, "X")
    row(15, 18, 11, "o")
    put(18, 14, "T")                     # blocks
    for i, ch in enumerate("B?BUB?B"):
        put(21 + i, 11, ch)
    put(24, 7, "?")
    put(27, 14, "T")                     # gaps: 30-31 is a pit
    ground(32, 52)
    row(29, 34, 12, "o")
    put(36, 14, "T")                     # stomp
    put(44, 14, "e")
    row(40, 44, 10, "o")
    for k in range(2):
        put(48, 14 - k, "X")
        put(49, 14 - k, "X")
    row(48, 50, 11, "o")
    put(53, 14, "T") if False else None
    ground(52, 56)
    put(54, 14, "T")                     # sprint, pit 56-58
    row(56, 59, 11, "o")
    ground(59, 80)
    put(62, 14, "T")                     # checkpoint
    put(64, 14, "C")
    put(68, 14, "T")                     # secrets
    put(70, 11, "H")
    # hill with a fake wall hiding a treasure
    ground(74, 82, 11)
    for gx in range(74, 81):
        for gy in range(12, 15):
            put(gx, gy, "O")
    put(79, 14, "*")
    row(76, 79, 14, "o")
    row(75, 81, 9, "o")
    # stepping stones over a pit (80..94)
    ground(80, 84)
    row(86, 89, 13, "=")
    row(91, 94, 12, "=")
    row(96, 98, 13, "=")
    row(86, 89, 11, "o")
    row(91, 94, 10, "o")
    ground(99, 140)
    put(104, 14, "e")
    put(112, 10, "f")
    for i, ch in enumerate("?B?"):
        put(116 + i, 11, ch)
    put(124, 14, "e")
    # high secret ledge reachable from a hidden block
    put(128, 11, "H")
    row(131, 136, 8, "=")
    put(134, 7, "*")
    row(131, 134, 7, "o")
    # warp ledge
    put(139, 14, "T")                    # portal hint
    ground(140, 160)
    put(142, 14, "X")
    row(143, 147, 12, "=")
    warp_src = (146, 11)
    # staircase and goal
    for i in range(5):
        for k in range(i + 1):
            put(150 + i, 14 - k, "X")
    put(157, 14, "T")
    put(160 - 1, 14, ".")
    put(158, 14, "F")
    ground(160, 166)
    for y in range(ROWS):
        put(166, y, "X")
    main_end = 166
    # bonus room
    x = 168
    n = 16
    ground(x, x + n)
    for y in range(ROWS):
        put(x, y, "X")
        put(x + n - 1, y, "X")
    row(x, x + n, 2, "X")
    row(x + 2, x + n - 2, 14, "o")
    row(x + 4, x + n - 4, 12, "=")
    row(x + 4, x + n - 4, 9, "o")
    put(x + n // 2, 11, "*")
    put(x + 3, 9, "g")
    put(x + n - 4, 9, "g")
    header = ["warp=%d,%d>%d,14" % (warp_src[0], warp_src[1], x + 2),
              "warp=%d,14>%d,14" % (x + n - 3, warp_src[0] + 4),
              "room=%d,%d" % (x, x + n)]
    rows = c.text(x + n + 1)
    return rows, header, main_end


def write_level(world, level, rows, header, signs, main_end, par):
    name = LEVEL_NAMES[world][level]
    lines = [
        "name=%s" % name,
        "world=%d" % (world + 1),
        "level=%d" % (level + 1),
        "par=%d" % par,
        "music=w%d" % (world + 1),
        "powerups=%s" % POWERUPS[world],
        "main_end=%d" % main_end,
    ]
    lines += header
    for s in signs:
        lines.append("sign=%s" % s)
    lines.append("---")
    lines += rows
    path = os.path.join(OUT, "w%d_%d.txt" % (world + 1, level + 1))
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def validate(rows):
    w = len(rows[0])
    assert all(len(r) == w for r in rows), "ragged rows"
    flat = "".join(rows)
    assert flat.count("S") == 1, "need one start"
    assert flat.count("F") == 1, "need one goal"


def main():
    os.makedirs(OUT, exist_ok=True)
    # 1-1 tutorial
    rows, header, main_end = tutorial_level()
    validate(rows)
    signs = [
        "Welcome, explorer! Hold the arrow pads to walk.",
        "Tap JUMP to hop. Hold it longer to jump higher!",
        "Jump into blocks from below to reveal coins and power-ups.",
        "Hold the RUN button while moving to sprint across gaps.",
        "Stomp enemies by landing on top of them!",
        "Flags are checkpoints. Lose a life and you restart here.",
        "Secrets hide everywhere. Look for odd walls and invisible blocks!",
        "A glowing portal! Portals lead to hidden bonus rooms.",
        "Touch the beacon to finish the level. Good luck!",
    ]
    write_level(0, 0, rows, header, signs, main_end, 70)

    for world in range(8):
        for level in range(5):
            if world == 0 and level == 0:
                continue
            rng = random.Random(world * 100 + level * 7 + 3)
            b = Builder(world, level, rng)
            main_end = b.build()
            width = b.finalize(main_end)
            header = list(b.c.header)
            if level == 4:
                header.append("boss=%s" % BOSSES[world])
                header.append("arena=%d,%d" % b.arena)
                if world == 7:
                    header[-2] = "boss=umbra"
            if world == 2 and level in (1, 3) or world == 7 and level == 2:
                header.append("dark=1")
            if world == 5 and level in (1, 3):
                header.append("underwater=1")
            rows = b.c.text(width)
            validate(rows)
            par = int(main_end / 3.2) + 20 + (30 if level == 4 else 0)
            write_level(world, level, rows, header, [], main_end, par)
    print("levels generated")


if __name__ == "__main__":
    main()
