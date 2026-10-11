#!/usr/bin/env python3
"""Synthesizes all original music loops and sound effects.

Music is composed procedurally from per-world settings (key, scale, tempo,
chord progression, timbre) and written as looping Ogg Vorbis files.
Sound effects are short 16-bit WAV files.

Requires: numpy, oggenc (vorbis-tools).
Usage: python3 tools/gen_audio.py
"""
import os
import random
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050


def write_wav(path, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(name, data):
    tmp = os.path.join(OUT, name + ".tmp.wav")
    write_wav(tmp, data)
    subprocess.run(["oggenc", "-Q", "-q", "2", "-o", os.path.join(OUT, name + ".ogg"), tmp], check=True)
    os.remove(tmp)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def osc(kind, freq, dur, duty=0.5):
    t = t_axis(dur)
    if np.isscalar(freq):
        phase = freq * t
    else:
        phase = np.cumsum(freq) / SR
    phase = phase % 1.0
    if kind == "square":
        return np.where(phase < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(phase - 0.5) - 1
    if kind == "saw":
        return 2 * phase - 1
    if kind == "sine":
        return np.sin(2 * np.pi * phase)
    if kind == "noise":
        rng = np.random.default_rng(int(freq) if np.isscalar(freq) else 7)
        return rng.uniform(-1, 1, len(t))
    raise ValueError(kind)


def env(n, a=0.005, d=0.08, s=0.6, r=0.05):
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = min(ai, n)
    e[:ai] = np.linspace(0, 1, ai) if ai else e[:ai]
    end_d = min(n, ai + di)
    if end_d > ai:
        e[ai:end_d] = np.linspace(1, s, end_d - ai)
    if ri and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------- SFX
def sweep(f0, f1, dur, kind="square", duty=0.5, vol=0.5, curve=1.0):
    n = int(SR * dur)
    f = f0 + (f1 - f0) * np.linspace(0, 1, n) ** curve
    return osc(kind, f, dur, duty) * env(n, 0.002, dur * 0.3, 0.7, dur * 0.4) * vol


def notes_seq(seq, dur, kind="square", duty=0.5, vol=0.45):
    parts = []
    for n in seq:
        if n is None:
            parts.append(np.zeros(int(SR * dur)))
        else:
            parts.append(osc(kind, midi(n), dur, duty) * env(int(SR * dur), 0.002, 0.05, 0.6, 0.03) * vol)
    return np.concatenate(parts)


def noise_burst(dur, vol=0.5, lowpass=0.0):
    n = int(SR * dur)
    x = np.random.default_rng(3).uniform(-1, 1, n)
    if lowpass > 0:
        y = np.zeros(n)
        acc = 0.0
        for i in range(n):
            acc += (x[i] - acc) * (1 - lowpass)
            y[i] = acc
        x = y * 2
    return x * env(n, 0.001, dur * 0.2, 0.4, dur * 0.6) * vol


def sfx():
    s = {}
    s["jump"] = sweep(260, 620, 0.16, duty=0.25, vol=0.35, curve=0.6)
    s["coin"] = np.concatenate([notes_seq([83], 0.05, duty=0.5, vol=0.3), notes_seq([88], 0.14, duty=0.5, vol=0.3)])
    s["gem"] = notes_seq([84, 88, 91, 96], 0.05, duty=0.25, vol=0.3)
    s["stomp"] = sweep(500, 120, 0.14, duty=0.5, vol=0.4, curve=0.7)
    s["hurt"] = sweep(700, 150, 0.3, "saw", vol=0.35)
    s["powerup"] = notes_seq([60, 64, 67, 72, 67, 72, 76, 79, 84], 0.045, duty=0.25, vol=0.3)
    s["oneup"] = notes_seq([76, 79, 88, 84, 86, 91], 0.08, duty=0.5, vol=0.3)
    s["checkpoint"] = notes_seq([72, 76, 79, 84], 0.07, "tri", vol=0.6)
    s["break"] = noise_burst(0.22, 0.5, 0.6)
    s["bump"] = sweep(180, 90, 0.08, "tri", vol=0.6)
    s["blast"] = sweep(900, 300, 0.12, duty=0.125, vol=0.3)
    s["death"] = np.concatenate([notes_seq([71, 77, None, 77, 77, 76, 74, 72], 0.1, duty=0.5, vol=0.3)])
    s["boss_hit"] = np.concatenate([sweep(300, 60, 0.25, "saw", vol=0.45), noise_burst(0.15, 0.3, 0.3)])
    s["secret"] = notes_seq([79, 78, 75, 69, 68, 76, 80, 84], 0.07, duty=0.25, vol=0.3)
    s["click"] = sweep(1200, 900, 0.04, duty=0.5, vol=0.25)
    s["pause"] = notes_seq([76, 72, 76, 72], 0.06, duty=0.5, vol=0.25)
    s["clear"] = np.concatenate([notes_seq([67, 72, 76, 79, 84, 88], 0.09, duty=0.5, vol=0.3),
                                 notes_seq([91], 0.5, duty=0.5, vol=0.3)])
    s["gameover"] = notes_seq([72, 67, 64, 69, 71, 69, 68, 70, 68, 67], 0.14, "tri", vol=0.55)
    s["splash"] = notes_seq([60, 64, 67, 72, 76], 0.07, duty=0.25, vol=0.25)
    s["swim"] = sweep(300, 450, 0.1, "sine", vol=0.4)
    s["shoot"] = sweep(600, 200, 0.18, duty=0.25, vol=0.25)
    s["crumble"] = noise_burst(0.3, 0.3, 0.85)
    s["kick"] = sweep(400, 800, 0.08, duty=0.5, vol=0.3)
    s["shield"] = sweep(400, 1200, 0.25, "sine", vol=0.4)
    s["thud"] = np.concatenate([sweep(120, 40, 0.2, "sine", vol=0.8), noise_burst(0.1, 0.2, 0.7)])
    for name, data in s.items():
        write_wav(os.path.join(OUT, "sfx_%s.wav" % name), data)


# ---------------------------------------------------------------- music
SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phryg": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixo": [0, 2, 4, 5, 7, 9, 10],
    "hminor": [0, 2, 3, 5, 7, 8, 11],
}

TRACKS = {
    # name: (root midi, scale, bpm, progression as scale degrees, lead timbre, seed, drums)
    "menu": (60, "major", 112, [0, 5, 3, 4], ("square", 0.25), 11, "soft"),
    "w1": (62, "major", 132, [0, 3, 4, 0, 5, 3, 4, 4], ("square", 0.5), 21, "bouncy"),
    "w2": (57, "phryg", 118, [0, 1, 0, 6, 0, 1, 3, 2], ("square", 0.25), 22, "shuffle"),
    "w3": (55, "minor", 96, [0, 5, 3, 4, 0, 5, 6, 4], ("tri", 0.5), 23, "soft"),
    "w4": (65, "lydian", 126, [0, 1, 0, 4, 3, 1, 4, 4], ("square", 0.125), 24, "bouncy"),
    "w5": (59, "dorian", 108, [0, 3, 0, 6, 5, 3, 4, 4], ("sine", 0.5), 25, "soft"),
    "w6": (60, "dorian", 92, [0, 6, 5, 6, 0, 3, 4, 4], ("tri", 0.5), 26, "soft"),
    "w7": (52, "hminor", 144, [0, 5, 6, 4, 0, 5, 1, 4], ("saw", 0.5), 27, "drive"),
    "w8": (50, "hminor", 136, [0, 1, 5, 4, 0, 1, 6, 4], ("square", 0.25), 28, "drive"),
    "boss": (48, "phryg", 156, [0, 1, 0, 1, 5, 4, 1, 0], ("saw", 0.5), 31, "drive"),
    "victory": (60, "major", 120, [0, 4, 5, 3, 0, 4, 3, 4], ("square", 0.25), 41, "bouncy"),
}


def degree_to_midi(root, scale, deg):
    sc = SCALES[scale]
    octave, idx = divmod(deg, len(sc))
    return root + sc[idx] + 12 * octave


def add(buf, start, data):
    end = min(len(buf), start + len(data))
    if end > start:
        buf[start:end] += data[: end - start]


def compose(name, root, scale, bpm, prog, timbre, seed, drums):
    rng = random.Random(seed)
    beat = 60.0 / bpm
    bars = len(prog) * 2  # each progression played twice, second time varied
    bar_len = int(beat * 4 * SR)
    total = bars * bar_len
    out = np.zeros(total)
    step = beat / 2  # eighth notes
    step_n = int(step * SR)

    # motif: 8 eighth-note pattern of chord-relative scale degrees (None = rest)
    motifs = []
    for m in range(2):
        pat = []
        for i in range(8):
            if rng.random() < 0.18 and i not in (0, 4):
                pat.append(None)
            else:
                pat.append(rng.choice([0, 2, 4, 2, 4, 5, 7, 1, 3]))
        motifs.append(pat)

    lead_kind, duty = timbre
    for b in range(bars):
        chord = prog[b % len(prog)]
        bar0 = b * bar_len
        second = b >= len(prog)
        # bass: root on beats, octave hops
        for i in range(8):
            deg = chord + (7 if (i % 4 == 2 and drums != "soft") else 0)
            n = degree_to_midi(root - 24, scale, deg)
            dur = step * (0.9 if drums != "soft" else 1.9)
            if drums == "soft" and i % 2 == 1:
                continue
            tone = osc("tri", midi(n), dur) * env(int(dur * SR), 0.003, 0.05, 0.8, 0.03) * 0.42
            add(out, bar0 + i * step_n, tone)
        # arpeggio (sixteenths)
        arp = [0, 2, 4, 7]
        for i in range(16):
            deg = chord + arp[i % 4]
            n = degree_to_midi(root - 12, scale, deg)
            d = step / 2
            tone = osc("square", midi(n), d * 0.8, 0.125) * env(int(d * 0.8 * SR), 0.002, 0.03, 0.4, 0.02) * 0.07
            add(out, bar0 + i * (step_n // 2), tone)
        # lead melody
        motif = motifs[(b // 2) % 2]
        for i, rel in enumerate(motif):
            if rel is None:
                continue
            deg = chord + rel
            if second and rng.random() < 0.3:
                deg += rng.choice([-1, 1, 2])
            n = degree_to_midi(root, scale, deg)
            long_note = (i == 7 and b % 2 == 1)
            d = step * (2.0 if long_note else 0.95)
            fm = midi(n)
            nsamp = int(d * SR)
            vib = fm * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * np.arange(nsamp) / SR))
            tone = osc(lead_kind, vib, d, duty) * env(nsamp, 0.005, 0.06, 0.65, 0.04)
            vol = 0.16 if lead_kind in ("square", "saw") else 0.3
            add(out, bar0 + i * step_n, tone * vol)
        # drums
        for i in range(8):
            pos = bar0 + i * step_n
            if drums == "soft":
                if i % 4 == 0:
                    add(out, pos, sweep(120, 45, 0.12, "sine", vol=0.5))
                if i % 2 == 1:
                    add(out, pos, noise_burst(0.03, 0.06))
            else:
                if i % 4 == 0 or (drums == "drive" and i % 2 == 0):
                    add(out, pos, sweep(140, 40, 0.12, "sine", vol=0.6))
                if i % 4 == 2:
                    add(out, pos, noise_burst(0.1, 0.22, 0.4))
                hat_on = True if drums != "shuffle" else (i % 3 != 1)
                if hat_on:
                    add(out, pos, noise_burst(0.025, 0.08))
    # normalise
    peak = np.max(np.abs(out)) or 1
    out = out / peak * 0.8
    write_ogg("music_%s" % name, out)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    for name, args in TRACKS.items():
        compose(name, *args)
    print("audio generated")
