#!/usr/bin/env python3
"""Synthesizes the game's sound effects into game/assets/sfx/*.wav.

Everything is generated from scratch (noise, filters, modal synthesis),
so the sounds are free of third-party licences. Re-run after tweaking:
    python3 tools/sfx_gen.py
"""
import os
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sfx")
rng = np.random.default_rng(1234)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.002, decay=0.3):
    x = t(dur)
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="low", fs=SR, output="sos"), x)


def high(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)


def modal(dur, partials):
    """Sum of decaying sines: [(freq, amp, decay_seconds), ...]."""
    x = t(dur)
    out = np.zeros_like(x)
    for f, a, d in partials:
        out += a * np.sin(2 * np.pi * f * x + rng.uniform(0, 6.28)) * np.exp(-x / d)
    return out


def pad(x, dur):
    out = np.zeros(int(SR * dur))
    out[: min(len(x), len(out))] = x[: len(out)]
    return out


def mix(*parts):
    """Adds signals of different lengths (zero-padded to the longest)."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(SR * 0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def loopable(x, xfade=0.25):
    n = int(SR * xfade)
    head, body = x[:n], x[n:]
    body[-n:] = body[-n:] * np.linspace(1, 0, n) + head * np.linspace(0, 1, n)
    return body


def clank(i):
    base = [520, 610, 480][i]
    parts = [(base, 1.0, 0.35), (base * 2.58, 0.7, 0.22), (base * 4.31, 0.45, 0.14), (base * 6.9, 0.3, 0.08)]
    hit = modal(0.9, parts)
    thud = low(noise(0.9), 180) * env(0.9, 0.001, 0.05) * 2.5
    tick = high(noise(0.9), 3000) * env(0.9, 0.0005, 0.01)
    return hit + thud + tick


def crunch(dur=0.35, grain=40):
    n = band(noise(dur), 300, 3500)
    am = (rng.random(int(SR * dur)) < grain / SR * 60).astype(float)
    am = low(am, 60) * 8 + 0.3
    return n * am * env(dur, 0.003, dur * 0.35)


def thump(f=70, dur=0.4):
    x = t(dur)
    sweep = np.sin(2 * np.pi * (f * x + 40 * (1 - np.exp(-x * 30)) / 30))
    return sweep * env(dur, 0.001, 0.09)


def bell(f, dur=1.2, bright=1.0):
    return modal(dur, [(f, 1.0, 0.6), (f * 2.0, 0.5 * bright, 0.35), (f * 3.01, 0.25 * bright, 0.2), (f * 4.2, 0.15 * bright, 0.12)])


def crickets(dur=8.0):
    """Evening ambience: a few chirping crickets over a soft distant hum."""
    x = t(dur)
    out = low(noise(dur), 300) * 0.04
    for k in range(5):
        f = rng.uniform(4200, 5200)
        rate = rng.uniform(2.2, 3.4)
        phase = rng.uniform(0, 1)
        gate = ((x * rate + phase) % 1.0) < 0.35
        trill = (np.sin(2 * np.pi * 28 * x) > 0).astype(float)
        out += np.sin(2 * np.pi * f * x) * gate * trill * rng.uniform(0.04, 0.09)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    save("evening_crickets", loopable(crickets(), 0.5), 0.35)
    for i in range(3):
        save(f"hammer_clank_{i + 1}", clank(i))
        save(f"ram_thud_{i + 1}", mix(thump(60 + i * 12) * 1.6, crunch(0.4) * 0.5))
        save(f"step_grass_{i + 1}", mix(crunch(0.12, 80) * 0.6, low(noise(0.12), 400) * env(0.12, 0.002, 0.03)))
    save("sand_burst", pad(thump(48, 0.8) * 2, 1.4) + pad(crunch(1.4, 70), 1.4) * 1.2)
    for i in range(2):
        d = 0.55 + i * 0.1
        x = t(d)
        swell = np.sin(np.pi * np.clip(x / d, 0, 1)) ** 1.5
        save(f"bellows_{i + 1}", band(noise(d), 200, 1400) * swell + low(noise(d), 120) * swell * 0.6)
    pour = high(noise(3.0), 1800) * 0.5 + band(noise(3.0), 400, 1200) * 0.4
    crackle = (rng.random(int(SR * 3.0)) < 0.0015).astype(float)
    pour += band(crackle, 1500, 6000) * 6
    save("pour_loop", loopable(pour), 0.6)
    roar = low(noise(4.0), 220, 3) * 3 + band(noise(4.0), 200, 900) * 0.3
    roar += band((rng.random(int(SR * 4.0)) < 0.0008).astype(float), 800, 5000) * 4
    save("furnace_loop", loopable(roar), 0.6)
    save("steam_hiss", high(noise(1.6), 2500) * env(1.6, 0.02, 0.6))
    sparks = band((rng.random(int(SR * 0.7)) < 0.004).astype(float), 1200, 7000) * env(0.7, 0.001, 0.25)
    save("sparks", sparks)
    save("coin", mix(bell(1568, 0.6), np.concatenate([np.zeros(int(SR * 0.08)), bell(2093, 0.8)])))
    arp = np.zeros(int(SR * 1.6))
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        s = int(SR * 0.09 * k)
        b = bell(f, 1.6 - 0.09 * k, 0.8)
        arp[s : s + len(b)] += b
    save("reveal_fanfare", arp)
    save("grade_good", pad(bell(880, 0.7), 0.7) + pad(bell(1318.5, 0.7), 0.7) * 0.6)
    x = t(0.9)
    wah = np.sin(2 * np.pi * np.cumsum(np.linspace(330, 180, len(x))) / SR) * env(0.9, 0.02, 0.5)
    save("grade_bad", low(signal.sawtooth(np.cumsum(np.linspace(330, 180, len(x))) * 2 * np.pi / SR) * env(0.9, 0.02, 0.5), 1800) + wah * 0.3)
    save("statue_gong", modal(3.5, [(110, 1.0, 1.6), (110 * 2.76, 0.6, 1.0), (110 * 5.4, 0.35, 0.6), (110 * 8.9, 0.2, 0.3)]))
    x = t(0.12)
    save("pop", np.sin(2 * np.pi * np.cumsum(np.linspace(300, 900, len(x))) / SR) * env(0.12, 0.002, 0.04))
    save("pickup", mix(thump(140, 0.15) * 0.8, crunch(0.1) * 0.2))
    save("drop_thud", mix(thump(90, 0.3), crunch(0.2) * 0.3))
    save("scrap_clatter", mix(modal(0.5, [(1900, 0.6, 0.08), (2870, 0.5, 0.06), (4100, 0.4, 0.05)]), crunch(0.3) * 0.4))
    # Batch A (appended so the sounds above keep their random draws): footsteps on
    # the dirt work area (duller, a soft heel thump) and a fourth grass step, and
    # a swish for throwing.
    save("step_grass_4", mix(crunch(0.12, 80) * 0.6, low(noise(0.12), 400) * env(0.12, 0.002, 0.03)))
    for i in range(4):
        grit = low(crunch(0.14, 45 + i * 8), 2600) * 0.7
        heel = thump(95 + i * 9, 0.12) * 0.55
        save(f"step_dirt_{i + 1}", mix(grit, heel, low(noise(0.1), 300) * env(0.1, 0.002, 0.025) * 0.6))
    d = 0.38
    x = t(d)
    swell = np.sin(np.pi * np.clip(x / d, 0, 1)) ** 2
    sweep = np.zeros(len(x))
    n = noise(d)
    for k, (lo, hi) in enumerate([(350, 900), (700, 1700), (1200, 2600)]):
        part = band(n, lo, hi) * np.clip(1.0 - np.abs(x / d - (0.3 + 0.2 * k)) * 3.0, 0, 1)
        sweep += part
    save("throw_whoosh", sweep * swell + low(noise(d), 160) * swell * 0.3, 0.8)


if __name__ == "__main__":
    main()
    print("written:", sorted(os.listdir(OUT)))
