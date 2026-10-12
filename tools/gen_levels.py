#!/usr/bin/env python3
"""Builds the 40 level data files in levels/.

World 1-1 is drawn by hand (the tutorial). Every other level follows an
authored PLAN: an ordered list of set pieces chosen for that level's theme.
Set pieces are small level-design building blocks (rolling hills, pillar
gardens, brick bridges, two-route sections, spring launches, gauntlets...)
that adapt to the current ground height, world mechanics and difficulty.
Small details (exact heights, coin trails, enemy picks) are seeded so the
output is reproducible.

Movement limits respected by every piece (checked by validate_levels.py):
  * normal jump rise   <= 4 tiles      * walking gap  <= 3 tiles
  * sprint gap         <= 4 tiles      * spring rise  ~  9 tiles

Usage: python3 tools/gen_levels.py
"""
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "levels")
ROWS = 18
G = 15          # default ground surface row
TOP_G = 10      # highest ground surface allowed

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
WORLD_ENEMIES = ["eer", "hhre", "GeGr", "ffeh", "yyre", "nef", "mmre", "emyrhG"]
BOSSES = ["walker", "hopper", "ghost", "flyer", "yeti", "fish", "magma", "umbra"]
POWERUPS = [
    "shield,speed,mega", "shield,mega,speed,magnet", "shield,blast,magnet,mega",
    "mega,shield,speed,blast", "shield,speed,blast,mega", "shield,blast,magnet,speed",
    "shield,blast,mega,speed", "shield,blast,mega,magnet,speed",
]

# Authored level plans. Tokens: piece name followed by integer/str args.
# sw/sh/sx = secret (fake wall / hidden-block ledge / warp to bonus room),
# cp = checkpoint. Boss levels end in the arena automatically.
PLANS = {
    (1, 2): "run 6|hills 3|blocks|up 1|gap 2|sw|hills 2|cp|tworoute 20|down 1|garden 3|parade|sh|bridge 6|up 1|run 6",
    (1, 3): "run 6|islands zig 4|swarm|blocks|cp|spring|islands climb 4|sx|gap 3|platenemies|moving|cp|blockstairs|sh|swarm|run 5",
    (1, 4): "up 2|pyramid|down 1|garden 4|staircase|cp|tworoute 22|vmove|parade|sw|up 2|islands descend 4|cp|corridor 14|sx|gap 3|spring|run 6",
    (1, 5): "run 6|corridor 14|spikes 12|blockstairs|cp|platenemies|sw|garden 3",
    (2, 1): "run 6|hills 3|quicksand|gap 3|sh|hills 2|cp|crumble|tworoute 20|garden 3|sw|quicksand|spikeballs|run 6",
    (2, 2): "quicksand|islands zig 4|quicksand|sw|cp|crumble|platenemies|quicksand|sx|spring|blockstairs|cp|parade|crumble|run 6",
    (2, 3): "up 2|staircase|garden 4|cp|spikeballs|pyramid|sh|down 2|hills 3|crumble|cp|sx|parade|gap 4|islands climb 4|run 6",
    (2, 4): "bridge 7|corridor 16|cp|quicksand|spring|sw|tworoute 24|crumble|spikeballs|cp|islands descend 4|sx|garden 4|gap 4|run 6",
    (2, 5): "corridor 14|spikeballs|crumble|sw|cp|blockstairs|quicksand",
    (3, 1): "run 6|cave 14|gap 3|sw|islands zig 4|cp|cave 16|garden 3|sh|spikes 12|cave 12|run 6",
    (3, 2): "cave 14|corridor 14|sw|cave 12|cp|islands climb 4|spikes 12|sx|cave 16|platenemies|cp|blockstairs|run 6",
    (3, 3): "up 2|pyramid|down 2|cave 14|sh|spring|cp|garden 4|cave 12|sw|bridge 7|swarm|cp|sx|parade|run 6",
    (3, 4): "cave 16|islands descend 4|sw|corridor 16|cp|spikes 14|cave 14|sx|tworoute 22|cp|gap 4|blockstairs|sh|cave 12|run 6",
    (3, 5): "cave 14|spikes 12|sw|cp|platenemies|cave 12",
    (4, 1): "run 6|islands zig 4|wind|sh|moving|cp|swarm|islands climb 4|sw|wind|gap 3|run 6",
    (4, 2): "wind|garden 4|moving|sx|cp|wind|platenemies|spring|islands descend 4|cp|wind|sw|vmove|run 6",
    (4, 3): "islands zig 5|moving|wind|sh|cp|blockstairs|wind|swarm|sx|moving|cp|islands climb 5|spring|vmove|run 6",
    (4, 4): "bridge 8|moving|wind|sw|cp|swarm|moving|wind|sx|tworoute 22|cp|vmove|islands zig 5|sh|wind|run 6",
    (4, 5): "wind|islands climb 4|moving|sw|cp|wind",
    (5, 1): "run 6|hills 3|crumble|sh|gap 3|cp|parade|iceslide|sw|garden 3|crumble|run 6",
    (5, 2): "up 2|iceslide|down 2|staircase|sw|cp|crumble|spikes 12|sx|islands zig 4|cp|parade|iceslide|sh|run 6",
    (5, 3): "cave 14|crumble|sh|cave 16|cp|iceslide|spikes 12|sw|cave 12|cp|sx|blockstairs|crumble|run 6",
    (5, 4): "up 2|parade|down 1|crumble|sw|iceslide|cp|cave 14|garden 4|sx|platenemies|cp|crumble|spring|sh|gap 4|run 6",
    (5, 5): "corridor 14|crumble|iceslide|sw|cp|spikes 12",
    (6, 1): "run 6|pool|hills 3|pool|sh|cp|islands zig 4|pool|sw|platenemies|sx|pool|run 6",
    (6, 2): "uw pillars|uw tunnel|sw|cp|uw maze|uw pillars|sh|cp|uw tunnel|sx|uw maze|run 4",
    (6, 3): "pool|garden 3|pool|sw|cp|bridge 7|pool|sh|corridor 14|cp|pool|sx|spring|pool|run 6",
    (6, 4): "uw tunnel|uw maze|sh|cp|uw pillars|uw tunnel|sw|cp|uw maze|sx|uw pillars|uw tunnel|run 4",
    (6, 5): "pool|corridor 14|sw|cp|pool",
    (7, 1): "run 6|lavajump|gap 3|sw|cp|crumble|hills 3|sh|moving|lavajump|sx|run 6",
    (7, 2): "lavajump|islands zig 4|crumble|sw|cp|spikeballs|lavajump|sh|moving|cp|garden 4|sx|crumble|run 6",
    (7, 3): "bridge 8|crumble|lavajump|sw|cp|crumble|moving|spikeballs|sx|islands climb 4|cp|crumble|lavajump|sh|run 6",
    (7, 4): "corridor 14|lavajump|spikeballs|sw|cp|crushers|moving|blockstairs|sx|lavajump|cp|parade|crumble|sh|islands descend 4|run 6",
    (7, 5): "lavajump|crumble|sw|cp|spikeballs",
    (8, 1): "run 6|crushers|spikes 12|sw|cp|moving|parade|spikeballs|sh|lavajump|sx|run 6",
    (8, 2): "crushers|moving|vmove|sw|cp|spikeballs|crushers|islands zig 5|sx|cp|crumble|crushers|sh|run 6",
    (8, 3): "corridor 16|cave 14|sw|crushers|cp|spikes 14|platenemies|sx|cave 14|cp|spikeballs|blockstairs|sh|run 6",
    (8, 4): "up 2|staircase|garden 4|crushers|sw|cp|islands climb 5|moving|spikeballs|sx|lavajump|cp|crumble|crushers|parade|sh|gap 4|run 6",
    (8, 5): "crushers|spikeballs|lavajump|sw|cp|moving",
}


class Canvas:
    def __init__(self, width):
        self.w = width
        self.g = [["."] * width for _ in range(ROWS)]
        self.header = []

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
        self.c = Canvas(900)
        self.x = 0
        self.g = G
        self.diff = (world * 5 + level) / 39.0
        self.enemies = WORLD_ENEMIES[world]
        self.warps = []
        self.room_x = None
        self.arena = None
        self.ice = world == 4
        self.water = world == 5
        self.lava = world == 6

    # ---------------------------------------------------------- helpers
    def r(self, a, b):
        return self.rng.randint(a, b)

    def chance(self, p):
        return self.rng.random() < p

    def land(self, x0, x1, top=None):
        """Solid ground from `top` (default current height) to the bottom."""
        top = self.g if top is None else top
        self.c.ground(x0, x1, top)
        if self.ice:
            self.c.row(x0, x1, top, "I")

    def pit(self, x0, x1):
        """An open pit (lava or water filled in the matching worlds).
        Only terrain is removed, so platforms/blocks placed earlier stay."""
        for x in range(x0, x1):
            for y in range(ROWS):
                if self.c.get(x, y) in "#IX":
                    self.c.put(x, y, ".")
            if self.lava:
                self.c.put(x, 16, "L")
                self.c.put(x, 17, "L")
            elif self.water:
                for y in range(self.g, 17):
                    self.c.put(x, y, "W")
                self.c.put(x, 17, "#")

    def ground_enemy(self):
        e = [ch for ch in self.enemies if ch not in "fnG"] or ["e"]
        return self.rng.choice(e)

    def enemy(self, x, row=None, kind=None):
        kind = kind or self.ground_enemy()
        self.c.put(x, (self.g - 1) if row is None else row, kind)

    def maybe_enemy(self, x, p=0.5, row=None):
        if self.chance(min(0.95, p + self.diff * 0.5)):
            self.enemy(x, row)

    def flyer(self, x, row):
        kind = "G" if "G" in self.enemies and self.chance(0.5) else "f"
        if self.water:
            kind = "n"
        self.c.put(x, row, kind)

    def coins(self, x, w, row, style=None):
        style = style or self.rng.choice(["arc", "line", "zig", "dots"])
        for i in range(w):
            if style == "arc":
                mid = (w - 1) / 2.0
                h = int(round(2 - abs(i - mid) / max(mid, 1) * 2))
                self.c.put(x + i, row - h, "o")
            elif style == "line":
                self.c.put(x + i, row, "o")
            elif style == "zig":
                self.c.put(x + i, row - (i % 2), "o")
            elif style == "dots" and i % 2 == 0:
                self.c.put(x + i, row, "o")

    def safe_floor(self, n=2):
        self.land(self.x, self.x + n)
        self.x += n

    # ---------------------------------------------------------- terrain pieces
    def p_run(self, n=8):
        x = self.x
        self.land(x, x + n)
        style = self.rng.choice(["arc", "line", "zig", "block", "none"])
        if style == "block" and n >= 6:
            self.c.put(x + n // 2, self.g - 4, self.rng.choice("?B?U"))
        elif style != "none":
            self.coins(x + 1, min(5, n - 2), self.g - 2 - (2 if style == "arc" else 0), style)
        if n >= 7:
            self.maybe_enemy(x + n - 2, 0.3)
        self.x += n

    def p_up(self, h=1):
        h = min(h, self.g - TOP_G)
        x = self.x
        for i in range(1, h + 1):
            self.land(x + 2 * (i - 1), x + 2 * i, self.g - i)
        self.g -= h
        self.land(x + 2 * h, x + 2 * h + 4)
        self.coins(x + 2 * h, 3, self.g - 2, "line")
        self.x = x + 2 * h + 4

    def p_down(self, h=1):
        h = min(h, G - self.g)
        x = self.x
        self.land(x, x + 3)
        self.g += h
        self.land(x + 3, x + 7)
        self.coins(x + 2, 3, self.g - h - 2, "line")
        self.maybe_enemy(x + 6, 0.3)
        self.x = x + 7

    def p_gap(self, w=3):
        x = self.x
        lim = 4 if self.diff > 0.2 else 3
        w = min(w, lim)
        self.land(x, x + 3)
        self.pit(x + 3, x + 3 + w)
        rise = self.r(-1, 1) if self.g > TOP_G and self.g < G else 0
        self.g += rise
        self.land(x + 3 + w, x + 7 + w)
        self.coins(x + 2, w + 2, self.g - 3, "arc")
        if w >= 3 and self.chance(0.4 + self.diff):
            self.flyer(x + 3 + w // 2, self.g - 5)
        self.x = x + 7 + w

    def p_hills(self, n=3):
        x = self.x
        self.land(x, x + 2)
        x += 2
        for i in range(n):
            valley = self.r(3, 5)
            bw = self.r(4, 6)
            bh = self.r(1, 2) if self.g > TOP_G + 1 else 1
            self.land(x, x + valley)
            if self.chance(0.6):
                self.enemy(x + valley // 2)
            self.land(x + valley, x + valley + bw, self.g - bh)
            if bw >= 5 and self.chance(0.5):
                self.land(x + valley + 1, x + valley + bw - 1, self.g - bh - 1)
                top = self.g - bh - 1
            else:
                top = self.g - bh
            self.coins(x + valley + 1, bw - 2, top - 2, self.rng.choice(["line", "zig"]))
            x += valley + bw
        self.land(x, x + 3)
        self.x = x + 3

    def p_garden(self, k=3):
        """Pillars of varying heights; later ones stand in pits."""
        x = self.x
        self.land(x, x + 3)
        x += 3
        prev_h = 0
        for i in range(k):
            sp = self.r(2, 4)
            is_pit = self.diff > 0.04 and self.chance(0.35 + self.diff) and i > 0
            if is_pit:
                sp = min(sp, 3)
                self.pit(x, x + sp)
            else:
                self.land(x, x + sp)
                if sp >= 3 and self.chance(0.5):
                    self.enemy(x + 1)
            ph = self.r(2, 4)
            if is_pit:
                ph = max(1, min(ph, prev_h + 2)) if prev_h else ph
            self.land(x + sp, x + sp + 2)
            for k2 in range(ph):
                self.c.put(x + sp, self.g - 1 - k2, "X")
                self.c.put(x + sp + 1, self.g - 1 - k2, "X")
            self.c.put(x + sp, self.g - ph - 2, "o")
            self.c.put(x + sp + 1, self.g - ph - 2, "o")
            if self.chance(0.3 + self.diff * 0.5):
                self.flyer(x + sp // 2, self.g - ph - 3)
            prev_h = ph
            x += sp + 2
        sp = 2
        self.land(x, x + 4)
        self.x = x + 4

    def p_bridge(self, w=6):
        """A brick bridge over a pit with coin blocks overhead."""
        x = self.x
        self.land(x, x + 3)
        self.pit(x + 3, x + 3 + w)
        self.c.row(x + 3, x + 3 + w, self.g, "B")
        for i in range(x + 4, x + 3 + w, 3):
            self.c.put(i, self.g - 4, "?")
        self.coins(x + 3, w, self.g - 2, "line")
        if w >= 5:
            self.enemy(x + 3 + w // 2)
        self.land(x + 3 + w, x + 7 + w)
        self.x = x + 7 + w

    def p_islands(self, style="zig", n=4):
        n = int(n)
        x = self.x
        self.land(x, x + 3)
        if style == "descend":
            self.c.put(x + 1, self.g - 1, "X")
            self.c.put(x + 1, self.g - 2, "X")
        px = x + 3
        y = self.g - 1
        base = self.g
        for i in range(n):
            px += self.r(1, 2) if style != "zig" else self.r(2, 3)
            w = self.r(2, 4)
            if style == "zig":
                y = base - 1 if i % 2 == 0 else base - 3
            elif style == "climb":
                y = max(4, y - self.r(1, 2))
            elif style == "descend":
                y = min(base - 1, base - 5 + i)
            ch = "c" if self.world in (1, 4, 6, 7) and self.chance(0.4) else "="
            self.c.row(px, px + w, y, ch)
            self.coins(px, w, y - 2, self.rng.choice(["line", "dots"]))
            if w >= 4 and self.chance(0.3 + self.diff):
                self.c.put(px + 1, y - 1, self.ground_enemy())
            if self.chance(0.25 + self.diff * 0.5):
                self.flyer(px + w + 1, y - 3)
            px += w
        if style == "climb":
            # reward at the top, then drop to the ground ahead
            self.c.put(px - 1, y - 3, "g")
        px += self.r(1, 2)
        self.pit(x + 3, px)
        self.land(px, px + 4)
        self.x = px + 4

    def p_tworoute(self, n=20):
        """Low road with hazards, high road with treasure."""
        x = self.x
        self.land(x, x + n)
        for k in range(2):
            self.c.put(x + 2, self.g - 1 - k, "X")
        hy = self.g - 5
        self.c.row(x + 4, x + n - 3, hy, "=")
        self.coins(x + 5, n - 9, hy - 1, "line")
        self.c.put(x + n // 2, hy - 2, "g")
        sx = x + 6
        while sx < x + n - 4:
            if self.chance(0.5):
                for k in range(self.r(1, 2)):
                    self.c.put(sx + k, self.g - 1, "^")
            else:
                self.enemy(sx)
            sx += self.r(3, 5)
        if self.chance(0.5 + self.diff):
            self.c.put(x + n // 2 + 3, hy - 1, self.ground_enemy())
        self.x += n

    def p_corridor(self, n=14):
        """Low brick ceiling packed with blocks; enemies inside."""
        x = self.x
        self.land(x, x + n)
        ceil = self.g - 4
        for gx in range(x, x + n):
            for gy in range(0, ceil):
                self.c.put(gx, gy, "X" if self.world in (0, 4, 7) else "#")
            self.c.put(gx, ceil, "B")
        for i in range(x + 2, x + n - 1, self.r(3, 4)):
            self.c.put(i, ceil, "?")
        self.c.put(x + n // 2, ceil, "U")
        self.c.row(x + 1, x + n - 1, self.g - 2, "o") if self.chance(0.5) else None
        for i in range(x + 4, x + n - 2, 5):
            self.enemy(i)
        self.x += n

    def p_parade(self):
        """Stairs up to a ledge with a shell enemy, gauntlet down the far side."""
        x = self.x
        h = min(3, self.g - TOP_G + 1)
        self.land(x, x + 2)
        for i in range(h):
            self.land(x + 2 + i * 2, x + 4 + i * 2, self.g - i - 1)
        top = self.g - h
        px = x + 2 + h * 2
        self.land(px, px + 4, top)
        self.c.put(px + 2, top - 1, "r" if "r" in self.enemies else self.ground_enemy())
        for i in range(h):
            sx = px + 4 + i * 3
            self.land(sx, sx + 3, top + i + 1 if i < h - 1 else self.g)
            self.c.put(sx + 1, top + i, self.ground_enemy())
        end = px + 4 + h * 3
        self.land(end, end + 5)
        self.enemy(end + 2)
        self.coins(px, 4, top - 3, "arc")
        self.x = end + 5

    def p_pyramid(self):
        x = self.x
        n = 13
        self.land(x, x + n)
        for lvl in range(4):
            for gx in range(x + 3 + lvl, x + 10 - lvl):
                self.c.put(gx, self.g - 1 - lvl, "B" if lvl < 3 else "?")
        self.c.put(x + 6, self.g - 7, "g")
        self.enemy(x + 1)
        self.enemy(x + 11)
        self.x += n

    def p_spring(self):
        """Spring launch to a high treasure road above the main path."""
        x = self.x
        n = 18
        self.land(x, x + n)
        self.c.put(x + 3, self.g - 1, "k")
        hy = max(4, self.g - 8)
        self.c.row(x + 5, x + n - 2, hy, "=")
        self.coins(x + 6, n - 9, hy - 1, "line")
        self.c.put(x + n - 4, hy - 2, "g")
        for i in range(x + 7, x + n - 2, 4):
            self.enemy(i)
        self.x += n

    def p_blockstairs(self):
        """Solid blocks as stepping stones across a pit."""
        x = self.x
        self.land(x, x + 3)
        px = x + 4
        heights = [1, 2, 3, 2, 1]
        for i, h in enumerate(heights):
            y = self.g - h
            ch = "?" if i == 2 else "B"
            self.c.put(px, y, ch)
            self.c.put(px + 1, y, "B")
            self.c.put(px, y - 2, "o")
            self.c.put(px + 1, y - 2, "o")
            px += 2 + self.r(1, 2)
        self.pit(x + 3, px)
        self.land(px, px + 4)
        self.x = px + 4

    def p_platenemies(self):
        x = self.x
        n = 18
        self.land(x, x + n)
        for i, px in enumerate((x + 2, x + 7, x + 12)):
            y = self.g - 3 - (i % 2)
            self.c.row(px, px + 4, y, "=")
            self.c.put(px + 2, y - 1, self.ground_enemy())
            self.coins(px, 4, y - 3, "line")
        for i in range(x + 4, x + n - 2, 5):
            if self.chance(0.5):
                self.c.put(i, self.g - 1, "^")
        self.x += n

    def p_swarm(self):
        """Flyers patrol over a pit with a single resting platform."""
        x = self.x
        self.land(x, x + 3)
        w = 9
        self.pit(x + 3, x + 3 + w)
        self.c.row(x + 6, x + 9, self.g - 1, "=")
        for fx in (x + 4, x + 8, x + 11):
            self.flyer(fx, self.g - 4 - self.r(0, 2))
        self.coins(x + 4, 7, self.g - 6, "zig")
        self.land(x + 3 + w, x + 7 + w)
        self.x = x + 7 + w

    def p_staircase(self):
        x = self.x
        h = self.r(3, 4)
        h = min(h, self.g - TOP_G + 2)
        block = "X" if self.world in (2, 7) else "#"
        self.land(x, x + 2 * h + 8)
        for i in range(h):
            for k in range(i + 1):
                self.c.put(x + 2 + i, self.g - 1 - k, block)
        top = x + 2 + h
        gap = 2 if self.diff < 0.3 else 3
        for gx in range(top, top + gap):
            self.c.clear_col(gx)
        self.pit(top, top + gap)
        for i in range(h):
            for k in range(h - i):
                self.c.put(top + gap + i, self.g - 1 - k, block)
        self.coins(top - 1, gap + 2, self.g - h - 3, "arc")
        self.maybe_enemy(top + gap + h + 2, 0.5)
        self.x = x + 2 * h + 8

    def p_blocks(self):
        x = self.x
        n = 12
        self.land(x, x + n)
        p = self.rng.choice(["B?B?B", "?BUB?", "BB?BB", "?.?.?", "B?UB"])
        for i, ch in enumerate(p):
            if ch != ".":
                self.c.put(x + 3 + i, self.g - 4, ch)
        self.c.put(x + 3 + len(p) // 2, self.g - 8, "?") if self.g >= 13 else None
        self.maybe_enemy(x + n - 2, 0.4)
        self.x += n

    def p_spikes(self, n=12):
        x = self.x
        self.land(x, x + n)
        gx = x + 2
        while gx < x + n - 3:
            w = self.r(1, 3 if self.diff > 0.3 else 2)
            for k in range(w):
                self.c.put(gx + k, self.g - 1, "^")
            self.c.put(gx + w // 2, self.g - 4, "o")
            gx += w + self.r(2, 3)
        self.x += n

    # ---------------------------------------------------------- moving parts
    def p_moving(self):
        x = self.x
        self.land(x, x + 3)
        span = self.r(7, 9)
        self.pit(x + 3, x + 3 + span)
        self.c.put(x + 3 + span // 2, self.g - 1, "M")
        self.coins(x + 4, span - 2, self.g - 4, "line")
        if self.chance(0.3 + self.diff):
            self.flyer(x + 3 + span // 2, self.g - 6)
        self.land(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def p_vmove(self):
        x = self.x
        self.land(x, x + 3)
        span = self.r(7, 8)
        self.pit(x + 3, x + 3 + span)
        self.c.put(x + 3 + span // 2, self.g - 2, "V")
        self.coins(x + 3 + span // 2 - 1, 3, self.g - 6, "line")
        self.land(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def p_crumble(self):
        x = self.x
        self.land(x, x + 3)
        span = self.r(5, 7)
        self.pit(x + 3, x + 3 + span)
        y = self.g - self.r(0, 1)
        self.c.row(x + 3, x + 3 + span, y, "c")
        self.coins(x + 3, span, y - 3, "zig")
        self.land(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    # ---------------------------------------------------------- world pieces
    def p_quicksand(self):
        x = self.x
        n = 14
        self.land(x, x + n)
        for gx in range(x + 3, x + 11):
            self.c.put(gx, self.g, "Q")
            self.c.put(gx, self.g + 1, "Q")
        self.c.row(x + 5, x + 9, self.g - 3, "=")
        self.coins(x + 5, 4, self.g - 5, "line")
        if self.chance(0.5 + self.diff):
            self.c.put(x + 7, self.g - 4, self.ground_enemy())
        self.x += n

    def p_spikeballs(self):
        x = self.x
        n = 14
        self.land(x, x + n)
        self.c.put(x + 5, self.g - 3, "z")
        self.c.put(x + 10, self.g - 6, "z")
        self.coins(x + 3, 9, self.g - 1, "dots")
        self.x += n

    def p_cave(self, n=14):
        x = self.x
        self.land(x, x + n)
        ceil = self.g - 6
        for gx in range(x, x + n):
            dip = 1 if (gx - x) % 7 in (3, 4) else 0
            for gy in range(0, ceil + dip):
                self.c.put(gx, gy, "#")
        for rx in range(x + 3, x + n - 2, 4):
            if self.chance(0.7):
                self.c.put(rx, ceil + (1 if (rx - x) % 7 in (3, 4) else 0), "R")
        self.coins(x + 2, n - 4, self.g - 2, "dots")
        if self.chance(0.6):
            self.c.put(x + n - 3, self.g - 3, "G" if "G" in self.enemies else self.ground_enemy())
        self.maybe_enemy(x + n // 2, 0.4)
        self.x += n

    def p_wind(self):
        x = self.x
        self.land(x, x + 3)
        span = self.r(7, 9)
        self.pit(x + 3, x + 3 + span)
        for gx in range(x + 3 + span // 2 - 1, x + 3 + span // 2 + 1):
            for gy in range(4, ROWS):
                self.c.put(gx, gy, "Z")
        self.coins(x + 4, span - 2, 3, "line")
        if self.chance(0.4 + self.diff):
            self.c.put(x + 3 + span - 1, 6, "f")
        self.land(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def p_iceslide(self):
        x = self.x
        n = 18
        self.land(x, x + n)
        for gx in (x + 6, x + 12):
            self.c.put(gx, self.g - 1, "^")
        self.c.put(x + 9, self.g - 1, "y" if "y" in self.enemies else self.ground_enemy())
        self.coins(x + 5, 9, self.g - 3, "zig")
        self.x += n

    def p_pool(self):
        x = self.x
        self.land(x, x + 3)
        span = self.r(8, 12)
        self.c.ground(x + 3, x + 3 + span, 17)
        for gx in range(x + 3, x + 3 + span):
            for gy in range(self.g - (1 if self.level == 0 else 0), 17):
                self.c.put(gx, gy, "W")
        if span > 9:
            self.c.put(x + 3 + span // 2, 16, "n")
        self.c.put(x + 4, 16, "o")
        self.c.put(x + 2 + span, 16, "o")
        self.c.row(x + 5, x + 3 + span - 2, self.g - 3, "=") if self.chance(0.5) else None
        self.land(x + 3 + span, x + 7 + span)
        self.x += 7 + span

    def p_uw(self, layout="pillars"):
        """Fully submerged section; layouts: pillars, tunnel, maze."""
        self.g = G
        x = self.x
        n = self.r(14, 18)
        self.land(x, x + n)
        for gx in range(x, x + n):
            for gy in range(3, G):
                if self.c.get(gx, gy) == ".":
                    self.c.put(gx, gy, "W")
            for gy in range(0, 3):
                self.c.put(gx, gy, "#")
        if layout == "pillars":
            for px in range(x + 4, x + n - 2, 6):
                for k in range(self.r(3, 5)):
                    self.c.put(px, G - 1 - k, "X")
                if self.chance(0.6):
                    for k in range(3):
                        self.c.put(px + 3, 3 + k, "X")
        elif layout == "tunnel":
            for gx in range(x + 2, x + n - 2):
                h = 2 + ((gx - x) // 3) % 3
                for k in range(h):
                    self.c.put(gx, 3 + k, "#")
                if (gx - x) % 6 == 0:
                    self.c.put(gx, G - 1, "^")
        else:  # maze of shelves with spikes
            for i, sx in enumerate(range(x + 2, x + n - 4, 5)):
                y = 7 if i % 2 == 0 else 10
                self.c.row(sx, sx + 4, y, "X")
                self.c.put(sx + 2, y + 1, "^") if False else None
        cur = self.rng.choice("<>.")
        if cur != ".":
            for gx in range(x + 1, x + n - 1):
                for gy in (8, 9):
                    if self.c.get(gx, gy) == "W":
                        self.c.put(gx, gy, cur)
        self.c.put(x + 2, G - 1, "A")
        self.c.put(x + n // 2, 6, "n")
        if self.diff > 0.6:
            self.c.put(x + n - 3, 11, "n")
        self.coins(x + 3, n - 6, 12, "dots")
        self.x += n

    def p_lavajump(self):
        x = self.x
        self.land(x, x + 3)
        px = x + 3
        for i in range(3):
            gap = self.r(2, 3)
            self.pit(px, px + gap)
            if i == 1 or (i == 2 and self.diff > 0.7):
                self.c.put(px + gap // 2, 16, "j")
            px += gap
            h = self.r(0, 2)
            self.c.ground(px, px + 2, self.g - h, "X")
            self.c.put(px, self.g - h - 3, "o")
            self.c.put(px + 1, self.g - h - 3, "o")
            px += 2
        self.land(px, px + 3)
        self.x = px + 3

    def p_crushers(self):
        x = self.x
        n = 16
        self.g = G
        self.land(x, x + n)
        for gx in range(x, x + n):
            for gy in range(0, 3):
                self.c.put(gx, gy, "X")
        for cx in (x + 4, x + 10):
            self.c.put(cx, 3, "Y")
        self.coins(x + 2, n - 4, self.g - 1, "dots")
        self.x += n

    # ---------------------------------------------------------- secrets
    def p_sw(self):
        """Hill with a fake wall hiding a treasure alcove."""
        x = self.x
        n = 12
        self.land(x, x + n)
        hx = x + 4
        top = self.g - 4
        self.c.ground(hx, hx + 6, top)
        for gx in range(hx, hx + 6):
            for gy in range(top + 1, self.g):
                self.c.put(gx, gy, "#" if gx == hx + 5 else "O")
            if self.ice:
                self.c.put(gx, top, "I")
        self.c.put(hx + 4, self.g - 1, "*")
        self.c.put(hx + 3, self.g - 1, "o")
        self.c.put(hx + 2, self.g - 1, "o")
        self.x += n

    def p_sh(self):
        """Hidden block leads up to a high ledge with a treasure."""
        x = self.x
        n = 12
        self.land(x, x + n)
        self.c.put(x + 3, self.g - 4, "H")
        ly = max(3, self.g - 7)
        self.c.row(x + 6, x + 10, ly, "=")
        self.c.put(x + 8, ly - 1, "*")
        self.c.put(x + 7, ly - 1, "o")
        self.c.put(x + 9, ly - 1, "o")
        self.x += n

    def p_sx(self):
        x = self.x
        n = 10
        self.land(x, x + n)
        self.c.put(x + 3, self.g - 1, "X")
        self.c.row(x + 4, x + 7, self.g - 3, "=")
        self.warps.append((x + 6, self.g - 4, self.g))
        self.x += n

    def p_cp(self):
        x = self.x
        self.land(x, x + 6)
        self.c.put(x + 3, self.g - 1, "C")
        self.x += 6

    # ---------------------------------------------------------- assembly
    def build(self):
        c = self.c
        boss = self.level == 4
        self.land(0, 8)
        c.put(2, self.g - 1, "S")
        self.x = 8
        plan = PLANS[(self.world + 1, self.level + 1)].split("|")
        for token in plan:
            parts = token.split()
            name, args = parts[0], parts[1:]
            conv = [int(a) if a.lstrip("-").isdigit() else a for a in args]
            getattr(self, "p_" + name)(*conv)
            if name not in ("cp",):
                self.safe_floor(self.r(1, 3))
        if boss:
            self.boss_arena()
        else:
            self.goal_area()
        main_end = self.x
        self.bonus_room(main_end)
        return main_end

    def to_ground(self, target=G):
        while self.g < target:
            self.p_down(min(3, target - self.g))
        while self.g > target:
            self.p_up(min(3, self.g - target))

    def goal_area(self):
        x = self.x
        self.land(x, x + 18)
        for i in range(5):
            for k in range(i + 1):
                self.c.put(x + 2 + i, self.g - 1 - k, "X")
        self.c.put(x + 11, self.g - 1, "F")
        for y in range(0, ROWS):
            self.c.put(x + 18, y, "X")
        self.x = x + 19

    def boss_arena(self):
        self.to_ground(G)
        self.p_cp()
        x = self.x
        n = 22
        self.land(x, x + n)
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
        sx, sy, sg = self.warps[0]
        dest = (x + 2, G - 1)
        back_src = (x + n - 3, G - 1)
        back_dst = (sx + 4, sg - 1)
        self.c.header.append("warp=%d,%d>%d,%d" % (sx, sy, dest[0], dest[1]))
        self.c.header.append("warp=%d,%d>%d,%d" % (back_src[0], back_src[1], back_dst[0], back_dst[1]))
        self.c.header.append("room=%d,%d" % (x, x + n))
        self.room_x = x + n

    def finalize(self, main_end):
        c = self.c
        width = (self.room_x or main_end) + 1
        if self.water:
            for gx in range(width):
                if c.get(gx, 17) == ".":
                    c.put(gx, 17, "#")
                    for gy in range(G, 17):
                        if c.get(gx, gy) == ".":
                            c.put(gx, gy, "W")
        for gx in range(width):
            for gy in range(TOP_G, G + 1):
                if c.get(gx, gy) == "#" and c.get(gx, gy - 1) == "." and self.rng.random() < 0.12:
                    c.put(gx, gy - 1, "D" if self.world in (2, 7) and self.rng.random() < 0.5 else "d")
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
    # spring launch to a high coin road
    put(103, 14, "T")                    # springs
    put(106, 14, "k")
    row(108, 123, 6, "=")
    row(109, 122, 5, "o")
    put(120, 4, "g")
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
        "Springs launch you sky-high. Look for treasure up there!",
        "A glowing portal! Portals lead to hidden bonus rooms.",
        "Touch the beacon to finish the level. Good luck!",
    ]
    write_level(0, 0, rows, header, signs, main_end, 80)

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
            if world == 2 and level in (1, 3) or world == 7 and level == 2:
                header.append("dark=1")
            if world == 5 and level in (1, 3):
                header.append("underwater=1")
            rows = b.c.text(width)
            validate(rows)
            par = int(main_end / 2.8) + 25 + (30 if level == 4 else 0)
            write_level(world, level, rows, header, [], main_end, par)
    print("levels generated")


if __name__ == "__main__":
    main()
