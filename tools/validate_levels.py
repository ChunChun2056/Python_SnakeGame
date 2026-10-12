#!/usr/bin/env python3
"""Reachability validator for all levels.

Simulates the player's real movement physics (same constants as
scripts/game/player.gd) frame by frame and runs a breadth-first search over
standing positions. Reports, per level, whether the goal (or boss arena) can
be reached from the start, and which secret treasures are reachable.

Enemies are ignored and moving platforms are approximated as static bridges,
so this is a check that the *terrain* never requires an impossible jump.

Usage: python3 tools/validate_levels.py [w_l ...]
"""
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = 16
DT = 1.0 / 60.0
W, H = 10.0, 14.0
WALK, RUN = 92.0, 150.0
ACCEL, AIR_ACCEL = 950.0, 700.0
GRAV, FALL_GRAV, MAX_FALL = 1000.0, 1250.0, 400.0
JUMP_V, JUMP_CUT = 378.0, 0.45
SPRING_V = 560.0
SOLID = set("#XIB?UH")
ONEWAY = set("=c")
WATER = set("W<>A")


def load(path):
    header, rows, grid = {}, [], False
    warps = []
    for line in open(path).read().split("\n"):
        if not grid:
            if line == "---":
                grid = True
            elif "=" in line:
                k, v = line.split("=", 1)
                if k == "warp":
                    a, b = v.split(">")
                    warps.append((tuple(map(int, a.split(","))), tuple(map(int, b.split(",")))))
                else:
                    header[k] = v
        elif line:
            rows.append(list(line))
    return header, rows, warps


class Level:
    def __init__(self, rows, header):
        self.rows = rows
        self.h = len(rows)
        self.w = len(rows[0])
        self.under = header.get("underwater") == "1"
        # approximate moving platforms as one-way bridges
        for y in range(self.h):
            for x in range(self.w):
                ch = rows[y][x]
                if ch == "M":
                    r = min(y + 1, self.h - 1)
                    l = x
                    while l > 0 and rows[r][l] not in "#XI":
                        l -= 1
                    rr = x
                    while rr < self.w - 1 and rows[r][rr] not in "#XI":
                        rr += 1
                    for bx in range(l + 1, rr):
                        if rows[r][bx] == ".":
                            rows[r][bx] = "="
                elif ch == "V":
                    for bx in (x - 1, x, x + 1):
                        if rows[y + 1][bx] == ".":
                            rows[y + 1][bx] = "="

    def cell(self, x, y):
        if x < 0 or x >= self.w:
            return "#"
        if y < 0 or y >= self.h:
            return "."
        return self.rows[y][x]

    def ch_at(self, px, py):
        return self.cell(int(px // T), int(py // T))

    def is_water(self, ch):
        return ch in WATER or (self.under and ch in "nogfe*ACT" )


def overlaps_solid(lv, x, y):
    x0, x1 = int((x - W / 2) // T), int((x + W / 2 - 0.01) // T)
    y0, y1 = int((y - H) // T), int((y - 0.01) // T)
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            if lv.cell(cx, cy) in SOLID:
                return True
    return False


def touches(lv, x, y, chars, inset=0):
    x0, x1 = int((x - W / 2 + 1) // T), int((x + W / 2 - 1.01) // T)
    y0, y1 = int((y - H + 1) // T), int((y - 1.01) // T)
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            if lv.cell(cx, cy) in chars:
                if inset and (y - 1) < cy * T + inset:
                    continue
                return (cx, cy)
    return None


def simulate(lv, x, y, vx, direction, run, hold, max_frames=150, collect=None):
    """Returns list of landing positions (x, y) and touched special cells."""
    vy = 0.0
    jumping = False
    if hold > 0:
        vy = -JUMP_V
        jumping = True
    in_q = lv.ch_at(x, y - 2) == "Q"
    if in_q and hold > 0:
        vy *= 0.72
    swim_cd = 0
    for f in range(max_frames):
        c_center = lv.ch_at(x, y - 7)
        water = lv.is_water(c_center)
        wind = c_center == "Z" or lv.ch_at(x, y - 2) == "Z"
        quick = lv.ch_at(x, y - 2) == "Q" or c_center == "Q"
        maxs = RUN if run else WALK
        if water:
            maxs = 72.0 * (1.3 if run else 1.0)
        if quick:
            maxs *= 0.4
        target = direction * maxs
        acc = 500.0 if water else AIR_ACCEL
        if vx < target:
            vx = min(target, vx + acc * DT)
        else:
            vx = max(target, vx - acc * DT)
        held = f < hold
        if water:
            vy = min(vy + 320 * DT, 75)
            swim_cd -= 1
            if held and swim_cd <= 0:
                swim_cd = 11
                head = lv.ch_at(x, y - H + 2)
                vy = -330.0 if not lv.is_water(head) else -150.0
        else:
            if wind:
                vy = max(vy - 1800 * DT, -175)
            else:
                vy = min(vy + (FALL_GRAV if vy > 0 else GRAV) * DT, MAX_FALL)
            if jumping and not held and vy < 0:
                vy *= JUMP_CUT
                jumping = False
            if vy >= 0:
                jumping = False
        if quick:
            vy = min(vy, 22)
        # horizontal move
        nx = x + vx * DT
        if overlaps_solid(lv, nx, y):
            nx = x
            vx = 0
        x = nx
        # vertical move
        ny = y + vy * DT
        landed = False
        if vy > 0:
            if overlaps_solid(lv, x, ny):
                ny = (int(ny // T)) * T
                while overlaps_solid(lv, x, ny) and ny > y - T:
                    ny -= T
                landed = True
            else:
                # one-way platforms: crossing a platform top while falling
                x0, x1 = int((x - W / 2) // T), int((x + W / 2 - 0.01) // T)
                top_cell = int(ny // T)
                for cx in range(x0, x1 + 1):
                    if lv.cell(cx, top_cell) in ONEWAY:
                        top = top_cell * T
                        if y <= top + 0.01 and ny >= top:
                            ny = top
                            landed = True
                            break
        elif vy < 0 and overlaps_solid(lv, x, ny):
            ny = y
            vy = 0
            jumping = False
        y = ny
        if collect is not None:
            hit = touches(lv, x, y, collect)
            if hit:
                yield ("touch", hit)
        if touches(lv, x, y, "L", 6) or touches(lv, x, y, "^", 8):
            return
        if vy >= 0 and touches(lv, x, y, "k", 8):
            vy = -SPRING_V
            jumping = False
            continue
        if y > lv.h * T + 40:
            return
        if landed:
            vy = 0
            yield ("land", (x, y))
            return
        if water and f > 30:
            yield ("land", (x, y))
            return
    yield ("land", (x, y))


def validate(path):
    header, rows, warps = load(path)
    lv = Level(rows, header)
    start = goal = None
    specials = {}
    gems_all = set()
    for y in range(lv.h):
        for x in range(lv.w):
            ch = rows[y][x]
            if ch == "S":
                start = (x * T + 8.0, (y + 1) * T)
            elif ch == "F":
                goal = (x, y)
            elif ch == "*":
                specials[(x, y)] = "*"
            elif ch == "g":
                gems_all.add((x, y))
    targets = set("F*g")
    warp_src = {s: d for s, d in warps}
    seen = set()
    q = deque()

    def push(px, py):
        key = (int(px // 4), int(py // 4))
        if key in seen:
            return
        seen.add(key)
        q.append((px, py))

    push(*start)
    touched = set()
    arena = header.get("arena")
    arena_x = int(arena.split(",")[0]) * T if arena else None
    reached_arena = False
    collect_chars = set(targets)
    actions = []
    for d in (-1, 1):
        for run in (False, True):
            for hold in (0, 6, 12, 40):
                actions.append((d, run, hold))
    actions.append((0, False, 40))
    while q:
        x, y = q.popleft()
        if arena_x is not None and x > arena_x + 40:
            reached_arena = True
        for d, run, hold in actions:
            vx0 = d * (RUN if run else WALK) if hold else d * 30.0
            for ev, val in simulate(lv, x, y, vx0, d, run, hold, collect=collect_chars):
                if ev == "touch":
                    touched.add(val)
                    if val in warp_src or (val[0], val[1]) in warp_src:
                        pass
                else:
                    push(*val)
            # warps: touching a warp cell
        for (sx, sy), (dx, dy) in warp_src.items():
            if abs(x - (sx * T + 8)) < 12 and abs(y - (sy + 1) * T) < 16:
                push(dx * T + 8.0, (dy + 1) * T)
    goal_ok = goal in touched or (header.get("boss") and reached_arena)
    stars = [p for p in specials if p in touched]
    gems = [p for p in gems_all if p in touched]
    return goal_ok, len(stars), len(specials), len(seen), len(gems), len(gems_all)


def main():
    names = sys.argv[1:] or ["w%d_%d" % (w, l) for w in range(1, 9) for l in range(1, 6)]
    bad = 0
    for n in names:
        ok, s, st, nodes, gm, gt = validate(os.path.join(ROOT, "levels", n + ".txt"))
        flag = "OK  " if ok else "FAIL"
        if not ok:
            bad += 1
        if s < st:
            flag = "WARN" if ok else flag
        print("%s %-6s goal=%s secrets reachable %d/%d gems %d/%d (states %d)" % (flag, n, ok, s, st, gm, gt, nodes), flush=True)
    print("failures:", bad)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
