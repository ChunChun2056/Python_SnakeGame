#!/usr/bin/env python3
"""Generates every sprite, tileset, background and the app icon for
Adventure Quest: Pixel Kingdom. All art is original and procedurally drawn.

Usage: python3 tools/gen_art.py   (run from the repository root)
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
TIL = os.path.join(ROOT, "assets", "tiles")
BG = os.path.join(ROOT, "assets", "bg")
OUTLINE = (27, 20, 40, 255)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3])


def new(w=16, h=16):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def outline(img, color=OUTLINE):
    """Adds a 1px dark outline around opaque pixels (classic pixel-art look)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0 and src[nx, ny] != color:
                    dst[x, y] = color
                    break
    return out


def from_ascii(rows, pal):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = new(w, h)
    px = img.load()
    for y, row in enumerate(rows):
        assert len(row) == w, "row %d width %d != %d: %r" % (y, len(row), w, row)
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = pal[ch]
    return img


def sheet(frames):
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def save(img, *path):
    p = os.path.join(*path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


# ---------------------------------------------------------------- hero
HERO_PAL = {
    "K": OUTLINE, "T": hexc("2fb3a0"), "t": hexc("1f7f73"), "S": hexc("ffcf9e"),
    "s": hexc("e0a070"), "W": hexc("ffffff"), "J": hexc("ff6a2b"), "j": hexc("c4421a"),
    "B": hexc("9c6b3a"), "b": hexc("6e4824"), "P": hexc("34508f"), "O": hexc("5a3420"),
    "Y": hexc("ffd23f"),
}
HERO_TOP = [
    "................",
    "......KKKK......",
    ".....KTTTTK.....",
    "....KTTTTTTK....",
    "....KttttttttK..",
    "....KSSSSWKSK...",
    "....KsSSSSSSK...",
    ".....KSSSSSK....",
    "..KBBKJJJYJK....",
    "..KBbKJJJYJSK...",
    "..KBbKjJJYJSK...",
    "..KKKKjjjjjK....",
]
LEGS_IDLE = [".....KPPPPPK....", ".....KPPKPPK....", "....KOOK.KOOK...", "....KKKK.KKKK..."]
LEGS_A = [".....KPPPPPK....", "....KPPKKPPK....", "...KOOK..KOOK...", "...KKK....KKK..."]
LEGS_B = [".....KPPPPPK....", "......KPPPK.....", "......KOOOK.....", "......KKKKK....."]
LEGS_C = [".....KPPPPPK....", ".....KPPKPPK....", "....KOOKKOOK....", "....KKK..KKK...."]
LEGS_TUCK = [".....KPPPPPK....", ".....KPPKPPK....", ".....KOOKOOK....", "......KK.KK....."]
ARMS_UP = [
    "..KBBKJJJYJKSK..",
    "..KBbKJJJYJK....",
    "..KBbKjJJYJK....",
    "..KKKKjjjjjK....",
]
VICTORY = [
    ".....KSSSSSK.SK.",
    "..KBBKJJJYJKKK..",
    "..KBbKJJJYJK....",
    "..KBbKjJJYJK....",
    "..KKKKjjjjjK....",
]
HURT_FACE = ["....KSSSKKSSK...", "....KsSSSSKSK..."]


def hero():
    idle0 = HERO_TOP + LEGS_IDLE
    idle1 = ["." * 16] + HERO_TOP + LEGS_IDLE[1:]
    run_a = HERO_TOP + LEGS_A
    run_b = ["." * 16] + HERO_TOP + LEGS_B[1:]
    run_c = HERO_TOP + LEGS_C
    jump = HERO_TOP[:8] + ARMS_UP + LEGS_TUCK
    fall = HERO_TOP + LEGS_A
    hurt = HERO_TOP[:5] + HURT_FACE + HERO_TOP[7:] + LEGS_A
    victory = HERO_TOP[:7] + VICTORY + LEGS_IDLE
    frames = [idle0, idle1, run_a, run_b, run_c, run_b, jump, fall, hurt, victory, jump, fall]
    imgs = [from_ascii(f, HERO_PAL) for f in frames]
    save(sheet(imgs), SPR, "hero.png")
    return imgs[0]


# ---------------------------------------------------------------- enemies
def eyes(d, x1, x2, y, look=1, big=False):
    for x in (x1, x2):
        d.rectangle([x, y, x + 1, y + (2 if big else 1)], fill=hexc("ffffff"))
        d.point((x + (1 if look > 0 else 0), y + 1), fill=OUTLINE)


def walker_frames(body, feet, leaf):
    frames = []
    for i in range(3):
        img = new()
        d = ImageDraw.Draw(img)
        if i < 2:
            d.ellipse([2, 3, 13, 13], fill=body)
            d.ellipse([3, 4, 12, 8], fill=shade(body, 1.18))
            d.line([7, 1, 8, 3], fill=leaf)
            d.point((9, 1), fill=leaf)
            d.point((6, 1), fill=leaf)
            eyes(d, 5, 9, 6, -1, True)
            d.line([4, 5, 6, 6], fill=OUTLINE)
            d.line([9, 6, 11, 5], fill=OUTLINE)
            d.line([6, 11, 9, 11], fill=hexc("5a1020"))
            if i == 0:
                d.rectangle([3, 13, 6, 14], fill=feet)
                d.rectangle([9, 13, 12, 14], fill=feet)
            else:
                d.rectangle([2, 13, 5, 14], fill=feet)
                d.rectangle([10, 13, 13, 14], fill=feet)
        else:
            d.ellipse([1, 9, 14, 14], fill=body)
            d.line([4, 11, 6, 11], fill=OUTLINE)
            d.line([9, 11, 11, 11], fill=OUTLINE)
        frames.append(outline(img))
    return frames


def roller_frames(shell, head):
    frames = []
    band = shade(shell, 0.65)
    for i in range(4):
        img = new()
        d = ImageDraw.Draw(img)
        if i < 2:
            d.pieslice([1, 3, 13, 21], 180, 360, fill=shell)
            for x in (4, 7, 10):
                d.line([x, 5, x, 11], fill=band)
            d.line([2, 12, 12, 12], fill=band)
            d.ellipse([11, 7, 15, 11], fill=head)
            d.point((13, 8), fill=OUTLINE)
            lx = 3 if i == 0 else 4
            d.rectangle([lx, 13, lx + 1, 14], fill=shade(head, 0.7))
            d.rectangle([lx + 6, 13, lx + 7, 14], fill=shade(head, 0.7))
        else:
            d.ellipse([2, 3, 13, 14], fill=shell)
            if i == 2:
                for x in (5, 8, 11):
                    d.line([x - 1, 4, x - 1, 13], fill=band)
            else:
                for k in range(3):
                    d.line([3 + k * 3, 13, 7 + k * 3, 4], fill=band)
        frames.append(outline(img.crop((0, 0, 16, 16))))
    return frames


def flyer_frames(body, wing):
    frames = []
    for i in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        if i == 0:
            d.ellipse([1, 1, 7, 7], fill=wing)
            d.ellipse([8, 1, 14, 7], fill=wing)
        else:
            d.ellipse([0, 5, 6, 10], fill=wing)
            d.ellipse([9, 5, 15, 10], fill=wing)
        d.ellipse([4, 5, 11, 13], fill=body)
        d.line([7, 5, 7, 12], fill=shade(body, 0.7))
        eyes(d, 5, 9, 8)
        d.line([5, 3, 4, 1], fill=OUTLINE)
        d.line([10, 3, 11, 1], fill=OUTLINE)
        frames.append(outline(img))
    return frames


def hopper_frames(body, spot):
    frames = []
    for i in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        if i == 0:
            d.ellipse([1, 7, 14, 14], fill=body)
            d.ellipse([2, 4, 6, 8], fill=body)
            d.ellipse([9, 4, 13, 8], fill=body)
            eyes(d, 3, 10, 5)
            d.point((5, 11), fill=spot)
            d.point((9, 12), fill=spot)
            d.line([5, 10, 10, 10], fill=OUTLINE)
        else:
            d.ellipse([3, 2, 12, 11], fill=body)
            d.ellipse([3, 0, 6, 4], fill=body)
            d.ellipse([9, 0, 12, 4], fill=body)
            eyes(d, 4, 9, 1)
            d.line([3, 11, 1, 15], fill=body)
            d.line([12, 11, 14, 15], fill=body)
            d.point((7, 7), fill=spot)
        frames.append(outline(img))
    return frames


def ghost_frames(body):
    frames = []
    for i in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        d.ellipse([2, 1, 13, 12], fill=body)
        d.rectangle([2, 7, 13, 12], fill=body)
        for k in range(4):
            d.polygon([(2 + k * 3, 12), (4 + k * 3, 12), (3 + k * 3, 14)], fill=body)
        if i == 0:
            d.rectangle([5, 5, 6, 7], fill=OUTLINE)
            d.rectangle([9, 5, 10, 7], fill=OUTLINE)
            d.ellipse([6, 8, 9, 11], fill=hexc("40204a"))
        else:
            d.rectangle([3, 5, 7, 7], fill=shade(body, 0.85))
            d.rectangle([8, 5, 12, 7], fill=shade(body, 0.85))
            d.line([6, 10, 9, 10], fill=OUTLINE)
        frames.append(outline(img))
    return frames


def yeti_frames(fur, face):
    frames = []
    for i in range(3):
        img = new()
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([2, 2, 13, 14], radius=4, fill=fur)
        d.rectangle([4, 5, 11, 10], fill=face)
        eyes(d, 5, 9, 6, 1)
        d.line([6, 9, 9, 9], fill=hexc("ffffff"))
        d.point((3, 1), fill=hexc("dfe9ff"))
        d.point((12, 1), fill=hexc("dfe9ff"))
        if i == 2:
            d.rectangle([0, 0, 2, 5], fill=fur)
            d.rectangle([13, 0, 15, 5], fill=fur)
        else:
            off = 0 if i == 0 else 1
            d.rectangle([3 + off, 14, 5 + off, 15], fill=shade(fur, 0.8))
            d.rectangle([10 - off, 14, 12 - off, 15], fill=shade(fur, 0.8))
        frames.append(outline(img))
    return frames


def fish_frames(body, fin):
    frames = []
    for i in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        d.ellipse([3, 4, 14, 12], fill=body)
        if i == 0:
            d.polygon([(4, 8), (0, 4), (0, 12)], fill=fin)
        else:
            d.polygon([(4, 8), (1, 5), (1, 11)], fill=fin)
        d.polygon([(7, 4), (10, 1), (11, 4)], fill=fin)
        d.ellipse([4, 8, 13, 12], fill=shade(body, 1.25))
        d.rectangle([10, 5, 11, 6], fill=hexc("ffffff"))
        d.point((11, 6), fill=OUTLINE)
        for x in (11, 13):
            d.point((x, 9), fill=hexc("ffffff"))
        frames.append(outline(img))
    return frames


def magma_frames(rock, lava):
    frames = []
    for i in range(3):
        img = new()
        d = ImageDraw.Draw(img)
        d.polygon([(2, 14), (1, 7), (4, 2), (11, 1), (14, 6), (14, 14)], fill=rock)
        d.line([4, 4, 6, 8, 5, 12], fill=lava)
        d.line([11, 3, 10, 7, 12, 11], fill=lava)
        d.rectangle([5, 6, 6, 7], fill=hexc("ffe14a"))
        d.rectangle([9, 6, 10, 7], fill=hexc("ffe14a"))
        if i == 2:
            d.rectangle([5, 9, 10, 12], fill=hexc("ffb020"))
        else:
            d.line([6, 10, 9, 10], fill=lava)
        off = 0 if i != 1 else 1
        d.rectangle([3 + off, 14, 5 + off, 15], fill=shade(rock, 0.7))
        d.rectangle([10 - off, 14, 12 - off, 15], fill=shade(rock, 0.7))
        frames.append(outline(img))
    return frames


def umbra_frames():
    frames = []
    cloak = hexc("3b1e5c")
    for i in range(3):
        img = new()
        d = ImageDraw.Draw(img)
        d.polygon([(8, 3), (1, 15), (15, 15)], fill=cloak)
        d.polygon([(8, 5), (4, 15), (12, 15)], fill=shade(cloak, 1.4))
        d.ellipse([5, 2, 11, 8], fill=hexc("1a0f2a"))
        eye = hexc("ff3b5c") if i != 2 else hexc("ffffff")
        d.point((6, 5), fill=eye)
        d.point((9, 5), fill=eye)
        d.point((7, 5), fill=eye)
        d.point((10, 5), fill=eye)
        d.polygon([(5, 2), (5, 0), (6, 1), (8, 0), (10, 1), (11, 0), (11, 2)], fill=hexc("ffd23f"))
        sx = 14 if i == 0 else 13
        d.line([sx, 4, sx, 14], fill=hexc("c9c2d6"))
        d.ellipse([sx - 1, 2, sx + 1, 4], fill=hexc("ff3b5c"))
        frames.append(outline(img))
    return frames


def add_crown(img):
    img = img.copy()
    d = ImageDraw.Draw(img)
    gold = hexc("ffd23f")
    d.polygon([(4, 3), (4, 0), (6, 2), (8, 0), (10, 2), (12, 0), (12, 3)], fill=gold)
    d.line([4, 3, 12, 3], fill=shade(gold, 0.7))
    d.point((8, 1), fill=hexc("ff3b5c"))
    return img


def enemies():
    sets = {
        "walker": walker_frames(hexc("8a5cd6"), hexc("5a3a1a"), hexc("4caf50")),
        "roller": roller_frames(hexc("d98a3a"), hexc("f0d090")),
        "flyer": flyer_frames(hexc("3fae5a"), hexc("d8f4ff", 200)),
        "hopper": hopper_frames(hexc("e0b060"), hexc("a06a28")),
        "ghost": ghost_frames(hexc("d8d0ff", 215)),
        "yeti": yeti_frames(hexc("f2f6ff"), hexc("7fb2e8")),
        "fish": fish_frames(hexc("2fa6c8"), hexc("ff7a59")),
        "magma": magma_frames(hexc("4a3a40"), hexc("ff6a1a")),
        "umbra": umbra_frames(),
    }
    for name, frames in sets.items():
        save(sheet(frames), SPR, "enemy_%s.png" % name)
        if name != "umbra":
            save(sheet([outline(add_crown(f)) for f in frames]), SPR, "boss_%s.png" % name)
    save(sheet(sets["umbra"]), SPR, "boss_umbra.png")


# ---------------------------------------------------------------- items & props
def items():
    # coins: 4 frame spin
    gold, dark = hexc("ffd23f"), hexc("c98a12")
    coin = []
    for w in (5, 3, 1, 3):
        img = new()
        d = ImageDraw.Draw(img)
        d.ellipse([8 - w, 2, 7 + w, 13], fill=gold)
        if w > 1:
            d.ellipse([9 - w, 4, 6 + w, 11], outline=dark)
        d.line([7, 4, 7, 6], fill=hexc("fff6c0"))
        coin.append(outline(img))
    save(sheet(coin), SPR, "coin.png")

    # gem and secret star gem
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(8, 2), (13, 7), (8, 14), (3, 7)], fill=hexc("3fd6ff"))
    d.polygon([(8, 2), (10, 7), (8, 14), (6, 7)], fill=hexc("9ff0ff"))
    gem = outline(img)
    stars = []
    for k in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        pts = []
        for i in range(10):
            r = 7 if i % 2 == 0 else 3
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((7.5 + r * math.cos(a), 8 + r * math.sin(a)))
        d.polygon(pts, fill=hexc("ff5fd2") if k == 0 else hexc("ff9ae6"))
        d.point((6, 7), fill=hexc("ffffff"))
        stars.append(outline(img))
    save(sheet([gem] + stars), SPR, "gems.png")

    # power-ups: speed, shield, mega jump, blast, magnet, extra life, heart
    icons = []
    rims = ["3a7bd5", "2fb3a0", "4caf50", "ff7a1a", "d6304a", "ff5fd2", "ff3b5c"]
    for idx, rim in enumerate(rims):
        img = new()
        d = ImageDraw.Draw(img)
        if idx == 6:
            d.ellipse([1, 3, 8, 10], fill=hexc(rim))
            d.ellipse([7, 3, 14, 10], fill=hexc(rim))
            d.polygon([(1, 7), (14, 7), (8, 14)], fill=hexc(rim))
            d.point((4, 5), fill=hexc("ffffff"))
            icons.append(outline(img))
            continue
        d.ellipse([1, 1, 14, 14], fill=hexc(rim))
        d.ellipse([3, 3, 12, 12], fill=hexc("fdf6e3"))
        if idx == 0:
            d.polygon([(9, 3), (5, 8), (8, 8), (6, 12), (11, 7), (8, 7)], fill=hexc("ffb400"))
        elif idx == 1:
            d.polygon([(5, 4), (10, 4), (10, 8), (7, 12), (5, 8)], fill=hexc("2fb3a0"))
            d.line([7, 5, 7, 10], fill=hexc("ffffff"))
        elif idx == 2:
            d.polygon([(7, 3), (11, 7), (9, 7), (9, 11), (6, 11), (6, 7), (4, 7)], fill=hexc("4caf50"))
        elif idx == 3:
            d.ellipse([4, 4, 11, 11], fill=hexc("ff7a1a"))
            d.ellipse([6, 6, 9, 9], fill=hexc("ffe14a"))
        elif idx == 4:
            d.arc([4, 3, 11, 11], 0, 180, fill=hexc("d6304a"), width=2)
            d.rectangle([4, 4, 5, 7], fill=hexc("d6304a"))
            d.rectangle([10, 4, 11, 7], fill=hexc("d6304a"))
            d.point((4, 3), fill=hexc("c0c0c0"))
            d.point((11, 3), fill=hexc("c0c0c0"))
        elif idx == 5:
            d.rectangle([5, 5, 10, 10], fill=HERO_PAL["S"])
            d.rectangle([5, 4, 10, 5], fill=HERO_PAL["T"])
            d.point((9, 7), fill=OUTLINE)
        icons.append(outline(img))
    save(sheet(icons), SPR, "powerups.png")

    # checkpoint: inactive, active a, active b
    cps = []
    for k in range(3):
        img = new(16, 32)
        d = ImageDraw.Draw(img)
        d.rectangle([3, 2, 4, 31], fill=hexc("c9c2d6"))
        d.ellipse([2, 0, 5, 3], fill=hexc("ffd23f"))
        col = hexc("8a8a9a") if k == 0 else hexc("4caf50")
        if k == 0:
            d.polygon([(5, 18), (13, 21), (5, 24)], fill=col)
        elif k == 1:
            d.polygon([(5, 4), (14, 7), (5, 11)], fill=col)
        else:
            d.polygon([(5, 4), (13, 8), (5, 11)], fill=col)
        cps.append(outline(img))
    save(sheet(cps), SPR, "checkpoint.png")

    # goal beacon 16x48 (2 frames)
    goal = []
    for k in range(2):
        img = new(24, 64)
        d = ImageDraw.Draw(img)
        d.rectangle([4, 4, 5, 60], fill=hexc("e8e8f0"))
        d.ellipse([2, 0, 7, 5], fill=hexc("ffd23f"))
        d.rectangle([1, 58, 9, 63], fill=hexc("6e6e80"))
        wave = 0 if k == 0 else 1
        d.polygon([(6, 6), (21, 9 + wave), (17, 13), (21, 17 - wave), (6, 20)], fill=hexc("ff3b5c"))
        d.ellipse([9, 10, 13, 15], fill=hexc("ffd23f"))
        goal.append(outline(img))
    save(sheet(goal), SPR, "goal.png")

    # warp portal 16x16 (2 frames)
    warp = []
    for k in range(2):
        img = new()
        d = ImageDraw.Draw(img)
        d.ellipse([1, 1, 14, 14], fill=hexc("6a2fd6"))
        d.ellipse([3, 3, 12, 12], fill=hexc("a47cff"))
        d.ellipse([5 + k, 5, 10 + k, 10], fill=hexc("e6dcff"))
        warp.append(outline(img))
    save(sheet(warp), SPR, "warp.png")

    # sign post
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([7, 8, 8, 15], fill=hexc("7a5230"))
    d.rectangle([1, 2, 14, 9], fill=hexc("c08850"))
    for y in (4, 6):
        d.line([3, y, 12, y], fill=hexc("7a5230"))
    save(outline(img), SPR, "sign.png")

    # spike ball, falling rock, crusher, bubble
    img = new()
    d = ImageDraw.Draw(img)
    for i in range(8):
        a = i * math.pi / 4
        d.line([8, 8, 8 + 7 * math.cos(a), 8 + 7 * math.sin(a)], fill=hexc("c9c2d6"))
    d.ellipse([3, 3, 12, 12], fill=hexc("505060"))
    d.point((6, 6), fill=hexc("a0a0b0"))
    save(outline(img), SPR, "spikeball.png")

    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(3, 1), (12, 1), (14, 6), (11, 14), (5, 14), (1, 7)], fill=hexc("8a7a6a"))
    d.line([5, 4, 8, 9], fill=hexc("6a5a4a"))
    d.point((10, 4), fill=hexc("b0a090"))
    save(outline(img), SPR, "rock.png")

    img = new(32, 32)
    d = ImageDraw.Draw(img)
    d.rectangle([1, 0, 30, 25], fill=hexc("6e6e80"))
    d.rectangle([3, 2, 28, 23], fill=hexc("8a8aa0"))
    d.rectangle([8, 8, 12, 12], fill=hexc("ff3b5c"))
    d.rectangle([19, 8, 23, 12], fill=hexc("ff3b5c"))
    d.line([9, 18, 22, 18], fill=OUTLINE)
    for i in range(8):
        d.polygon([(1 + i * 4, 26), (5 + i * 4, 26), (3 + i * 4, 31)], fill=hexc("c9c2d6"))
    save(outline(img), SPR, "crusher.png")

    # projectiles 8x8: fireball a/b, snowball, energy blast, dark orb, bubble
    proj = []
    specs = [("ff6a1a", "ffe14a"), ("ff3b1a", "ffb020"), ("f2f6ff", "ffffff"),
             ("3fd6ff", "e6fbff"), ("a020d0", "ff6aff"), ("8fdcff", "ffffff")]
    for i, (a, b) in enumerate(specs):
        img = new(8, 8)
        d = ImageDraw.Draw(img)
        if i == 5:
            d.ellipse([0, 0, 7, 7], outline=hexc(a))
            d.point((2, 2), fill=hexc(b))
        else:
            d.ellipse([1, 1, 6, 6], fill=hexc(a))
            d.ellipse([2, 2, 4, 4], fill=hexc(b))
        proj.append(img)
    save(sheet(proj), SPR, "projectiles.png")


# ---------------------------------------------------------------- tiles
WORLDS = [
    # name, ground top, ground fill, accent, brick, platform, sky top, sky bottom, far, near
    dict(top="5cc94a", fill="a0683a", accent="3d9a35", brick="c8643a", plat="c08850",
         sky=("6ec6ff", "d8f3ff"), far="9fd8a8", near="5cb85c", deco="ffd23f"),
    dict(top="f2c46d", fill="d39a50", accent="c98a3a", brick="d08048", plat="b07a40",
         sky=("ffb75e", "ffe9b8"), far="f0b070", near="d89048", deco="5aa04a"),
    dict(top="6b7fd6", fill="3a3f6b", accent="8fe0ff", brick="56609a", plat="7a6aa8",
         sky=("10102a", "2a2350"), far="2e2a5a", near="403a78", deco="8fe0ff"),
    dict(top="ffffff", fill="bfd8ff", accent="e0ecff", brick="9ab0e0", plat="f4f8ff",
         sky=("4aa8ff", "c8ecff"), far="ffffff", near="e8f4ff", deco="ffd23f"),
    dict(top="f2f8ff", fill="7fa8d8", accent="cfe8ff", brick="8ab4e0", plat="bfe0ff",
         sky=("a8c8e8", "eaf4ff"), far="d8e8f8", near="b8d0e8", deco="5a8a5a"),
    dict(top="5ab0a0", fill="3a6a70", accent="8adfc0", brick="4a8a8a", plat="7aa090",
         sky=("0a4a6a", "2a8aa8"), far="1a6a80", near="2a7a78", deco="ff7a59"),
    dict(top="5a3a3a", fill="3a2228", accent="ff6a1a", brick="6a3a30", plat="7a4a3a",
         sky=("2a0a10", "80301a"), far="501a1a", near="3a1414", deco="ff6a1a"),
    dict(top="5a5070", fill="2e2840", accent="a47cff", brick="4a4060", plat="6a6088",
         sky=("0a0614", "2a1a40"), far="1e1430", near="2a2040", deco="a47cff"),
]


def noise_fill(d, rng, x0, y0, w, h, base, amt=0.12, n=14):
    d.rectangle([x0, y0, x0 + w - 1, y0 + h - 1], fill=base)
    for _ in range(n):
        x = x0 + rng.randrange(w)
        y = y0 + rng.randrange(h)
        f = 1 + rng.uniform(-amt, amt) * 2
        d.point((x, y), fill=shade(base, f))


def tileset(wi, pal):
    rng = random.Random(1000 + wi)
    img = new(16 * 20, 16)
    d = ImageDraw.Draw(img)
    top, fill, acc = hexc(pal["top"]), hexc(pal["fill"]), hexc(pal["accent"])

    def tile(i):
        return 16 * i

    # 0 ground top
    x = tile(0)
    noise_fill(d, rng, x, 0, 16, 16, fill)
    d.rectangle([x, 0, x + 15, 4], fill=top)
    for k in range(0, 16, 3):
        d.point((x + k, 5), fill=top)
    d.line([x, 0, x + 15, 0], fill=shade(top, 1.15))
    d.line([x, 5, x + 15, 5], fill=shade(top, 0.75)) if wi in (2, 6, 7) else None
    # 1 ground fill
    x = tile(1)
    noise_fill(d, rng, x, 0, 16, 16, fill)
    for k in range(3):
        px, py = x + rng.randrange(2, 13), rng.randrange(2, 13)
        d.rectangle([px, py, px + 1, py], fill=shade(fill, 0.8))
    # 2 brick
    x = tile(2)
    b = hexc(pal["brick"])
    d.rectangle([x, 0, x + 15, 15], fill=shade(b, 0.6))
    for row in range(4):
        off = 0 if row % 2 == 0 else 4
        for col in range(-1, 3):
            bx = x + off + col * 8
            if bx + 6 < x or bx > x + 15:
                continue
            d.rectangle([max(x, bx), row * 4, min(x + 15, bx + 6), row * 4 + 2], fill=b)
    # 3 bonus block
    x = tile(3)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("ffb400"))
    d.rectangle([x + 1, 1, x + 14, 14], fill=hexc("ffd23f"))
    for p in ((1, 1), (14, 1), (1, 14), (14, 14)):
        d.point((x + p[0], p[1]), fill=hexc("c98a12"))
    d.rectangle([x + 6, 3, x + 9, 4], fill=hexc("ffffff"))
    d.rectangle([x + 9, 4, x + 10, 7], fill=hexc("ffffff"))
    d.rectangle([x + 7, 7, x + 9, 8], fill=hexc("ffffff"))
    d.rectangle([x + 7, 10, x + 8, 11], fill=hexc("ffffff"))
    d.rectangle([x, 15, x + 15, 15], fill=hexc("c98a12"))
    # 4 used block
    x = tile(4)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("7a5a3a"))
    d.rectangle([x + 1, 1, x + 14, 14], fill=hexc("9a7a5a"))
    for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
        d.point((x + p[0], p[1]), fill=hexc("5a3a1a"))
    # 5 metal
    x = tile(5)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("5a5a6e"))
    d.rectangle([x + 1, 1, x + 14, 14], fill=hexc("8a8aa0"))
    d.rectangle([x + 3, 3, x + 12, 12], fill=hexc("a0a0b8"))
    for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
        d.point((x + p[0], p[1]), fill=hexc("4a4a5a"))
    # 6 one-way platform
    x = tile(6)
    pl = hexc(pal["plat"])
    if wi == 3:
        d.ellipse([x, 0, x + 8, 8], fill=pl)
        d.ellipse([x + 6, 0, x + 15, 9], fill=pl)
        d.rectangle([x, 3, x + 15, 7], fill=pl)
    else:
        d.rectangle([x, 0, x + 15, 6], fill=pl)
        d.line([x, 0, x + 15, 0], fill=shade(pl, 1.25))
        d.line([x, 6, x + 15, 6], fill=shade(pl, 0.6))
        d.line([x + 7, 1, x + 7, 5], fill=shade(pl, 0.7))
    # 7 spikes
    x = tile(7)
    for k in range(4):
        d.polygon([(x + k * 4, 15), (x + k * 4 + 3, 15), (x + k * 4 + 1.5, 7)], fill=hexc("d8d8e8"))
        d.line([x + k * 4 + 1, 14, x + k * 4 + 1, 10], fill=hexc("9898a8"))
    # 8 lava top, 9 lava fill
    x = tile(8)
    d.rectangle([x, 3, x + 15, 15], fill=hexc("ff5a1a"))
    for k in range(0, 16, 4):
        d.ellipse([x + k, 1, x + k + 4, 5], fill=hexc("ff8a1a"))
    d.point((x + 5, 8), fill=hexc("ffe14a"))
    d.point((x + 11, 11), fill=hexc("ffe14a"))
    x = tile(9)
    noise_fill(d, rng, x, 0, 16, 16, hexc("e8401a"), 0.2, 20)
    # 10 water top, 11 water fill
    x = tile(10)
    d.rectangle([x, 3, x + 15, 15], fill=hexc("2a8ad8", 150))
    d.line([x, 3, x + 15, 3], fill=hexc("bfe8ff", 220))
    for k in range(0, 16, 6):
        d.line([x + k, 2, x + k + 2, 2], fill=hexc("bfe8ff", 200))
    x = tile(11)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("2a7ac8", 150))
    # 12 ice
    x = tile(12)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("9fd8ff"))
    d.rectangle([x + 1, 1, x + 14, 14], fill=hexc("c8ecff"))
    d.line([x + 3, 3, x + 8, 8], fill=hexc("ffffff"))
    d.line([x + 9, 3, x + 12, 6], fill=hexc("ffffff"))
    # 13 quicksand top, 14 quicksand fill
    x = tile(13)
    noise_fill(d, rng, x, 2, 16, 14, hexc("c8964a"), 0.15, 24)
    d.line([x, 2, x + 15, 2], fill=hexc("e8c27a"))
    x = tile(14)
    noise_fill(d, rng, x, 0, 16, 16, hexc("b8863a"), 0.15, 24)
    # 15 fake wall (same look as fill, slightly marked)
    x = tile(15)
    noise_fill(d, rng, x, 0, 16, 16, fill)
    d.point((x + 7, 7), fill=shade(fill, 0.9))
    # 16 decoration a, 17 decoration b (non-colliding)
    dec = hexc(pal["deco"])
    x = tile(16)
    if wi in (0, 4):
        d.line([x + 4, 15, x + 4, 10], fill=acc)
        d.ellipse([x + 2, 7, x + 6, 11], fill=dec)
        d.line([x + 10, 15, x + 11, 11], fill=acc)
        d.line([x + 12, 15, x + 13, 12], fill=acc)
    elif wi == 1:
        d.rectangle([x + 6, 5, x + 9, 15], fill=dec)
        d.rectangle([x + 2, 8, x + 4, 10], fill=dec)
        d.rectangle([x + 3, 8, x + 4, 12], fill=dec)
        d.rectangle([x + 11, 6, x + 13, 8], fill=dec)
        d.rectangle([x + 11, 6, x + 12, 11], fill=dec)
        img_out = outline(img.crop((x, 0, x + 16, 16)))
        img.paste(img_out, (x, 0))
    elif wi in (2, 7):
        d.polygon([(x + 4, 15), (x + 7, 4), (x + 9, 15)], fill=dec)
        d.polygon([(x + 9, 15), (x + 12, 8), (x + 14, 15)], fill=shade(dec, 0.8))
    elif wi == 3:
        d.ellipse([x + 3, 9, x + 12, 15], fill=hexc("ffffff", 200))
    elif wi == 5:
        for k in (4, 9, 12):
            d.line([x + k, 15, x + k + 1, 8], fill=hexc("3aa060"))
            d.line([x + k + 1, 8, x + k, 4], fill=hexc("3aa060"))
    else:
        d.ellipse([x + 4, 10, x + 11, 15], fill=hexc("6a4a4a"))
        d.point((x + 7, 11), fill=dec)
    x = tile(17)
    d.rectangle([x + 2, 12, x + 13, 15], fill=acc)
    d.point((x + 4, 11), fill=acc)
    d.point((x + 9, 10), fill=acc)
    d.point((x + 12, 11), fill=acc)
    # 18 current arrow (water current marker), 19 crumble platform look
    x = tile(18)
    d.rectangle([x, 0, x + 15, 15], fill=hexc("2a7ac8", 150))
    d.line([x + 3, 8, x + 12, 8], fill=hexc("bfe8ff", 160))
    d.line([x + 9, 5, x + 12, 8], fill=hexc("bfe8ff", 160))
    d.line([x + 9, 11, x + 12, 8], fill=hexc("bfe8ff", 160))
    x = tile(19)
    d.rectangle([x, 0, x + 15, 6], fill=shade(pl, 0.85))
    d.line([x + 4, 0, x + 6, 6], fill=shade(pl, 0.5))
    d.line([x + 11, 0, x + 9, 6], fill=shade(pl, 0.5))
    d.line([x, 6, x + 15, 6], fill=shade(pl, 0.55))
    save(img, TIL, "world%d.png" % (wi + 1))


# ---------------------------------------------------------------- backgrounds
def silhouette(width, height, rng, base_y, amp, freq, color, kind="hills"):
    img = new(width, height)
    d = ImageDraw.Draw(img)
    if kind == "hills":
        pts = [(0, height)]
        ph = rng.uniform(0, 6.28)
        for x in range(0, width + 1, 2):
            t = x / width * math.pi * 2
            y = base_y - amp * (0.6 * math.sin(t * freq + ph) + 0.4 * math.sin(t * freq * 2.0 + ph * 1.7))
            pts.append((x, y))
        pts.append((width, height))
        d.polygon(pts, fill=color)
    elif kind == "peaks":
        n = freq
        pts = [(0, height), (0, base_y)]
        for i in range(n):
            x0 = i * width / n
            pts.append((x0 + width / n / 2, base_y - amp * rng.uniform(0.6, 1.0)))
            pts.append((x0 + width / n, base_y))
        pts.append((width, height))
        d.polygon(pts, fill=color)
    return img, d


def backgrounds():
    W, H = 512, 256
    for wi, pal in enumerate(WORLDS):
        rng = random.Random(50 + wi)
        far_c = hexc(pal["far"])
        near_c = hexc(pal["near"])
        # sky gradient
        sky = new(4, 256)
        s0, s1 = hexc(pal["sky"][0]), hexc(pal["sky"][1])
        for y in range(256):
            t = y / 255
            c = tuple(int(s0[i] * (1 - t) + s1[i] * t) for i in range(3)) + (255,)
            for x in range(4):
                sky.putpixel((x, y), c)
        save(sky, BG, "w%d_sky.png" % (wi + 1))

        # far layer
        if wi == 0:
            far, d = silhouette(W, H, rng, 170, 40, 2, far_c)
            for _ in range(5):
                cx, cy = rng.randrange(W), rng.randrange(20, 90)
                for k in range(3):
                    d.ellipse([cx + k * 12 - 14, cy - 8, cx + k * 12 + 10, cy + 8], fill=hexc("ffffff", 230))
        elif wi == 1:
            far, d = silhouette(W, H, rng, 175, 30, 3, far_c)
            d.polygon([(300, 175), (350, 95), (400, 175)], fill=shade(far_c, 0.9))
            d.polygon([(380, 175), (415, 120), (450, 175)], fill=shade(far_c, 0.85))
            d.ellipse([60, 30, 110, 80], fill=hexc("fff4c0"))
        elif wi == 2:
            far = new(W, H)
            d = ImageDraw.Draw(far)
            for i in range(14):
                x = i * W / 14 + rng.randrange(10)
                d.polygon([(x, 0), (x + 18, 0), (x + 9, rng.randrange(40, 110))], fill=far_c)
                d.polygon([(x + 5, H), (x + 25, H), (x + 15, H - rng.randrange(40, 90))], fill=far_c)
            for _ in range(30):
                x, y = rng.randrange(W), rng.randrange(H)
                d.point((x, y), fill=hexc("8fe0ff"))
        elif wi == 3:
            far = new(W, H)
            d = ImageDraw.Draw(far)
            for _ in range(10):
                cx, cy = rng.randrange(W), rng.randrange(30, 200)
                for k in range(4):
                    d.ellipse([cx + k * 14 - 20, cy - 10 - (k % 2) * 5, cx + k * 14 + 12, cy + 10], fill=hexc("ffffff", 200))
            for k in range(3):
                ix = 80 + k * 160
                iy = 140 + rng.randrange(-30, 30)
                d.polygon([(ix - 30, iy), (ix + 30, iy), (ix, iy + 40)], fill=hexc("8aa0c0"))
                d.rectangle([ix - 30, iy - 6, ix + 30, iy], fill=hexc("6ac06a"))
        elif wi == 4:
            far, d = silhouette(W, H, rng, 200, 120, 5, far_c, "peaks")
            for _ in range(60):
                x, y = rng.randrange(W), rng.randrange(H)
                d.point((x, y), fill=hexc("ffffff"))
        elif wi == 5:
            far = new(W, H)
            d = ImageDraw.Draw(far)
            for k in range(5):
                x = 40 + k * 100
                h = rng.randrange(90, 160)
                d.rectangle([x, H - h, x + 18, H], fill=far_c)
                d.rectangle([x - 4, H - h - 6, x + 22, H - h], fill=far_c)
            for _ in range(25):
                x, y = rng.randrange(W), rng.randrange(H)
                d.ellipse([x, y, x + 3, y + 3], outline=hexc("8adfff", 160))
        elif wi == 6:
            far, d = silhouette(W, H, rng, 190, 50, 2, far_c)
            for k in range(2):
                vx = 120 + k * 260
                d.polygon([(vx - 70, 200), (vx - 12, 90), (vx + 12, 90), (vx + 70, 200)], fill=shade(far_c, 1.2))
                d.ellipse([vx - 12, 82, vx + 12, 96], fill=hexc("ff6a1a"))
        else:
            far = new(W, H)
            d = ImageDraw.Draw(far)
            for k in range(6):
                x = k * 90 + 10
                h = rng.randrange(100, 190)
                d.rectangle([x, H - h, x + 40, H], fill=far_c)
                for m in range(4):
                    d.rectangle([x + m * 11, H - h - 8, x + m * 11 + 6, H - h], fill=far_c)
                d.rectangle([x + 16, H - h + 20, x + 22, H - h + 30], fill=hexc("a47cff"))
            d.ellipse([400, 20, 440, 60], fill=hexc("e8d8ff"))
        save(far, BG, "w%d_far.png" % (wi + 1))

        # near layer
        if wi in (0, 1, 6):
            near, d = silhouette(W, H, rng, 215, 22, 3, near_c)
            if wi == 0:
                for k in range(6):
                    tx = rng.randrange(W)
                    ty = 205
                    d.rectangle([tx, ty - 10, tx + 4, ty + 20], fill=hexc("6a4a2a"))
                    d.ellipse([tx - 12, ty - 34, tx + 16, ty - 4], fill=shade(near_c, 0.85))
            if wi == 1:
                for k in range(5):
                    tx = rng.randrange(W)
                    d.rectangle([tx, 175, tx + 8, 215], fill=hexc("4a8a3a"))
                    d.rectangle([tx - 8, 188, tx - 2, 194], fill=hexc("4a8a3a"))
                    d.rectangle([tx - 8, 180, tx - 5, 194], fill=hexc("4a8a3a"))
        elif wi == 2:
            near = new(W, H)
            d = ImageDraw.Draw(near)
            for k in range(8):
                x = rng.randrange(W)
                h = rng.randrange(30, 70)
                d.polygon([(x, H), (x + 10, H - h), (x + 20, H)], fill=hexc("6a5ad6", 200))
                d.polygon([(x + 6, H), (x + 10, H - h + 10), (x + 14, H)], fill=hexc("8fe0ff", 200))
        elif wi == 3:
            near = new(W, H)
            d = ImageDraw.Draw(near)
            for _ in range(7):
                cx, cy = rng.randrange(W), rng.randrange(150, 240)
                for k in range(5):
                    d.ellipse([cx + k * 16 - 30, cy - 14 - (k % 2) * 6, cx + k * 16, cy + 14], fill=near_c)
        elif wi == 4:
            near = new(W, H)
            d = ImageDraw.Draw(near)
            for k in range(9):
                x = rng.randrange(W)
                for lvl in range(3):
                    w2 = 20 - lvl * 5
                    d.polygon([(x - w2, 240 - lvl * 18), (x + w2, 240 - lvl * 18), (x, 214 - lvl * 18)],
                              fill=hexc("3a6a5a"))
                d.rectangle([x - 2, 240, x + 2, H], fill=hexc("5a3a2a"))
            d.rectangle([0, 245, W, H], fill=near_c)
        elif wi == 5:
            near = new(W, H)
            d = ImageDraw.Draw(near)
            for k in range(14):
                x = rng.randrange(W)
                for seg in range(5):
                    d.line([x + (seg % 2) * 4, H - seg * 14, x + ((seg + 1) % 2) * 4, H - (seg + 1) * 14],
                           fill=hexc("2aa070"), width=3)
            d.rectangle([0, 240, W, H], fill=near_c)
        else:
            near = new(W, H)
            d = ImageDraw.Draw(near)
            for k in range(6):
                x = k * 90 + 40
                d.line([x, 0, x, 120], fill=hexc("4a4060"), width=2)
                d.ellipse([x - 6, 118, x + 6, 130], outline=hexc("4a4060"), width=2)
            d.rectangle([0, 230, W, H], fill=near_c)
            for k in range(0, W, 32):
                d.rectangle([k, 222, k + 16, 230], fill=near_c)
        save(near, BG, "w%d_near.png" % (wi + 1))


# ---------------------------------------------------------------- UI & icon
def ui():
    # 192x192 launcher icon: hero portrait over meadow
    icon = Image.new("RGBA", (192, 192), hexc("6ec6ff"))
    d = ImageDraw.Draw(icon)
    d.ellipse([-40, 120, 232, 300], fill=hexc("5cc94a"))
    d.ellipse([130, 20, 175, 65], fill=hexc("ffd23f"))
    hero_img = from_ascii(HERO_TOP[:8] + VICTORY + LEGS_IDLE[1:], HERO_PAL)
    big = hero_img.resize((128, 128), Image.NEAREST)
    icon.paste(big, (28, 52), big)
    save(icon, ROOT, "icon.png")
    # rating stars: earned, empty
    stars = []
    for col in ("ffd23f", "4a4060"):
        img = new()
        d = ImageDraw.Draw(img)
        pts = []
        for i in range(10):
            r = 7.5 if i % 2 == 0 else 3.2
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((7.5 + r * math.cos(a), 8.2 + r * math.sin(a)))
        d.polygon(pts, fill=hexc(col))
        if col == "ffd23f":
            d.point((6, 6), fill=hexc("fff6c0"))
        stars.append(outline(img))
    # lock icon
    img = new()
    d = ImageDraw.Draw(img)
    d.arc([4, 1, 11, 10], 180, 360, fill=hexc("c9c2d6"), width=2)
    d.rectangle([4, 5, 5, 7], fill=hexc("c9c2d6"))
    d.rectangle([10, 5, 11, 7], fill=hexc("c9c2d6"))
    d.rectangle([2, 7, 13, 14], fill=hexc("ffb400"))
    d.rectangle([7, 9, 8, 12], fill=OUTLINE)
    stars.append(outline(img))
    save(sheet(stars), SPR, "ui_icons.png")


if __name__ == "__main__":
    hero()
    enemies()
    items()
    for i, p in enumerate(WORLDS):
        tileset(i, p)
    backgrounds()
    ui()
    print("art generated")
