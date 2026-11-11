#!/usr/bin/env python3
"""Composes and synthesizes the game's music into game/assets/music/*.ogg.

Everything is written here as notes and rendered with simple synthesis
(plucked strings, a warm pad, bass, soft percussion, bells), so there are
no third-party licences. The pieces were composed by an AI assistant, which
matters for the store's AI-content disclosure. Re-run after changes:
    python3 tools/music_gen.py          (needs numpy, scipy, ffmpeg)

Tracks: menu (calm), backyard and garage (the workshop theme, the garage
with percussion), bell_foundry (the theme on bells), iron_hall (minor, heavy).
"""
import os
import subprocess
import tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "music")
rng = np.random.default_rng(77)


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def low(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="low", fs=SR, output="sos"), x)


def high(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, btype="high", fs=SR, output="sos"), x)


# --- Instruments: each returns a mono note --------------------------------------

def pluck(midi, dur, bright=1.0):
    """Plucked string / kalimba: harmonics that die away, the high ones first."""
    n = int(SR * (dur + 1.2))
    t = np.arange(n) / SR
    f = hz(midi)
    out = np.zeros(n)
    for k in range(1, 9):
        if f * k > 9000:
            break
        amp = bright ** (k - 1) / k ** 1.4
        out += amp * np.sin(2 * np.pi * f * k * t * (1 + 0.0004 * k * k)) * np.exp(-t * (1.6 + 0.9 * k))
    return out * np.clip(t / 0.003, 0, 1)


def bell(midi, dur):
    """Small bell / glockenspiel: inharmonic partials, long ring."""
    n = int(SR * (dur + 2.5))
    t = np.arange(n) / SR
    f = hz(midi)
    out = np.zeros(n)
    for ratio, amp, decay in [(1.0, 1.0, 1.4), (2.76, 0.45, 2.6), (5.4, 0.22, 4.5), (8.9, 0.1, 7.0)]:
        if f * ratio < 12000:
            out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay)
    return out * np.clip(t / 0.002, 0, 1)


def pad(midi, dur):
    """Warm pad: three detuned saws through a low-pass, slow in and out."""
    n = int(SR * (dur + 0.8))
    t = np.arange(n) / SR
    f = hz(midi)
    out = np.zeros(n)
    for det in (-0.004, 0.0, 0.0045):
        out += signal.sawtooth(2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6.28))
    out = low(out, min(900 + f * 1.5, 3000))
    env = np.clip(t / 0.6, 0, 1) * np.clip((dur + 0.8 - t) / 0.8, 0, 1)
    return out * env / 3.0


def brass(midi, dur):
    """Soft horn for the iron hall lead: saw with a slow filter and vibrato."""
    n = int(SR * (dur + 0.25))
    t = np.arange(n) / SR
    f = hz(midi)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    out = low(signal.sawtooth(phase) + 0.5 * signal.sawtooth(phase * 1.003), min(f * 3.2, 4500))
    env = np.clip(t / 0.07, 0, 1) * np.clip((dur + 0.25 - t) / 0.25, 0, 1)
    return out * env * 0.6


def bass(midi, dur):
    n = int(SR * (dur + 0.15))
    t = np.arange(n) / SR
    f = hz(midi)
    out = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6) + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 9)
    env = np.clip(t / 0.012, 0, 1) * np.exp(-t * 1.3) * np.clip((dur + 0.15 - t) / 0.1, 0, 1)
    return out * env


def kick(strength=1.0):
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    f = 48 + 70 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11) * strength


def shaker(strength=1.0):
    n = int(SR * 0.09)
    t = np.arange(n) / SR
    return high(rng.uniform(-1, 1, n), 5500) * np.exp(-t * 55) * np.clip(t / 0.004, 0, 1) * strength


def anvil(strength=1.0):
    """A light hammer-on-steel clink: the foundry's own hi-hat."""
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, amp, decay in [(2140.0, 1.0, 16), (3390.0, 0.6, 22), (5270.0, 0.35, 30), (847.0, 0.25, 26)]:
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * decay)
    return out * strength * 0.5


def tom(midi, strength=1.0):
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    f = hz(midi) * (1 + 0.6 * np.exp(-t * 30))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8) * strength


# --- Mixer ------------------------------------------------------------------------

class Song:
    def __init__(self, bpm, beats):
        self.beat = 60.0 / bpm
        self.length = int(SR * self.beat * beats)
        self.buf = np.zeros((self.length, 2))
        self.wet = np.zeros((self.length, 2))

    def add(self, sound, at_beat, gain=1.0, pan=0.0, reverb=0.3):
        """Mixes a mono sound in at a beat. Whatever runs past the end wraps
        to the start, so the piece loops without a seam."""
        start = int(SR * self.beat * at_beat) % self.length
        left = gain * np.sqrt(0.5 * (1 - pan))
        right = gain * np.sqrt(0.5 * (1 + pan))
        idx = (start + np.arange(len(sound))) % self.length
        for target, amount in ((self.buf, 1.0), (self.wet, reverb)):
            np.add.at(target[:, 0], idx, sound * left * amount)
            np.add.at(target[:, 1], idx, sound * right * amount)

    def render(self):
        # Room: decaying noise as the impulse response, applied circularly.
        n = int(SR * 1.6)
        t = np.arange(n) / SR
        out = self.buf.copy()
        for ch in range(2):
            ir = low(rng.normal(0, 1, n), 5000) * np.exp(-t * 3.6)
            ir[: int(SR * 0.012)] = 0
            spec = np.fft.rfft(self.wet[:, ch]) * np.fft.rfft(ir, self.length)
            out[:, ch] += np.fft.irfft(spec, self.length) * 0.05
        out = high(out.T, 28).T
        out /= np.max(np.abs(out)) + 1e-9
        return np.tanh(out * 1.5) * 0.82


def save(song, name):
    data = (song.render() * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav = f.name
    wavfile.write(wav, SR, data)
    target = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", target], check=True)
    os.remove(wav)
    print("%s: %.0f s, %d kB" % (name, len(data) / SR, os.path.getsize(target) // 1024))


# --- The workshop theme (D major) --------------------------------------------------

D, G, BM, A, EM = "D", "G", "Bm", "A", "Em"
CHORDS = {
    D: (38, [50, 57, 62, 66]), G: (43, [55, 59, 62, 67]), BM: (35, [47, 59, 62, 66]),
    A: (33, [45, 57, 61, 64]), EM: (40, [52, 55, 59, 64]),
}
# Phrases: per bar a list of (midi, beats); 0 = rest.
PH_A = [
    [(66, 1), (69, 1), (74, 1.5), (71, .5)], [(71, 1), (67, 1), (71, 1), (74, 1)],
    [(78, 1.5), (76, .5), (74, 1), (71, 1)], [(73, 1), (76, 1), (69, 2)],
    [(66, 1), (69, 1), (74, 1.5), (76, .5)], [(74, 1), (71, 1), (67, 1), (71, 1)],
    [(69, 1), (73, 1), (76, 1), (73, 1)], [(74, 3), (0, 1)],
]
PH_A2 = PH_A[:6] + [[(76, 1), (73, 1), (69, 1), (64, 1)], [(74, 4)]]
PH_B = [
    [(71, 1.5), (74, .5), (78, 2)], [(79, 1), (78, 1), (74, 2)],
    [(69, 1), (74, 1), (78, 1), (81, 1)], [(76, 2), (73, 1), (69, 1)],
    [(71, 1.5), (74, .5), (78, 2)], [(79, 1), (78, 1), (74, 1), (71, 1)],
    [(76, 1), (67, 1), (69, 1), (73, 1)], [(74, 4)],
]
PROG_A = [D, G, BM, A, D, G, A, D]
PROG_B = [BM, G, D, A, BM, G, EM, D]


def theme(name, bpm, lead, drums, calm=False):
    form = [(PH_A, PROG_A), (PH_A2, PROG_A), (PH_B, PROG_B), (PH_A2, PROG_A)]
    song = Song(bpm, 32 * 4)
    bar = 0
    for section, (phrase, prog) in enumerate(form):
        for i in range(8):
            root, tones = CHORDS[prog[i]]
            beat = bar * 4
            # Em bar in the bridge turns to A for its second half.
            turn = prog[i] == EM
            for tone in tones[1:]:
                song.add(pad(tone, 4 * song.beat), beat, 0.16, rng.uniform(-0.5, 0.5), 0.6)
            song.add(bass(root, 1.8 * song.beat), beat, 0.5, 0.0, 0.05)
            song.add(bass(root + 7 if not turn else 33, 1.6 * song.beat), beat + 2, 0.4, 0.0, 0.05)
            # Broken chord in eighths; sparser in the calm version and the first pass.
            pattern = [0, 2, 1, 2, 3, 2, 1, 2]
            for k, which in enumerate(pattern):
                if calm and k % 2 == 1:
                    continue
                if section == 0 and k in (3, 7):
                    continue
                song.add(pluck(tones[which], 0.4, 0.75), beat + k * 0.5, 0.2 if k % 2 == 0 else 0.14, -0.35, 0.35)
            pos = 0.0
            for midi, dur in phrase[i]:
                if midi:
                    song.add(lead(midi, dur * song.beat), beat + pos, 0.42, 0.2, 0.45)
                    if section == 3 and lead is pluck:
                        # Last pass: the tune doubled an octave up, quietly.
                        song.add(bell(midi + 12, dur * song.beat), beat + pos, 0.07, 0.4, 0.6)
                pos += dur
            if drums:
                for k in range(8):
                    song.add(shaker(0.6 if k % 2 == 0 else 1.0), beat + k * 0.5, 0.07, 0.3, 0.1)
                song.add(kick(), beat, 0.4, 0.0, 0.03)
                song.add(kick(0.7), beat + 2, 0.4, 0.0, 0.03)
                if section > 0:
                    song.add(anvil(), beat + 1, 0.09, -0.3, 0.5)
                    song.add(anvil(0.7), beat + 3, 0.09, 0.35, 0.5)
            bar += 1
    save(song, name)


# --- Menu: slow, open -----------------------------------------------------------

def menu():
    prog = [D, BM, G, A]
    tunes = [
        [[(69, 2), (74, 2), (78, 4)], [(78, 2), (74, 2), (71, 4)], [(71, 2), (74, 2), (79, 4)], [(76, 2), (73, 2), (69, 4)]],
        [[(74, 2), (78, 2), (81, 4)], [(83, 2), (81, 2), (78, 4)], [(79, 2), (74, 2), (71, 4)], [(73, 2), (76, 2), (81, 4)]],
    ]
    song = Song(72, 24 * 4)
    for rep in range(3):
        tune = tunes[rep % 2]
        for c in range(4):
            root, tones = CHORDS[prog[c]]
            beat = (rep * 4 + c) * 8
            for tone in tones[1:]:
                song.add(pad(tone, 8 * song.beat), beat, 0.2, rng.uniform(-0.6, 0.6), 0.7)
            song.add(bass(root, 3.5 * song.beat), beat, 0.42, 0.0, 0.1)
            song.add(bass(root, 3.0 * song.beat), beat + 4, 0.3, 0.0, 0.1)
            for k, which in enumerate([0, 1, 2, 3, 2, 1, 2, 3]):
                song.add(pluck(tones[which], 0.8, 0.7), beat + k, 0.17, -0.3 + 0.1 * k, 0.5)
            pos = 0.0
            for midi, dur in tune[c]:
                song.add(bell(midi, dur * song.beat), beat + pos, 0.16, 0.25, 0.7)
                pos += dur
    save(song, "menu")


# --- Iron hall: D minor, heavy ---------------------------------------------------

DM, BB, F, C, GM, AMAJ = "Dm", "Bb", "F", "C", "Gm", "A"
IRON = {
    DM: (38, [50, 53, 57]), BB: (34, [46, 50, 53]), F: (41, [53, 57, 60]),
    C: (36, [48, 52, 55]), GM: (43, [55, 58, 62]), AMAJ: (33, [57, 61, 64]),
}
IRON_PROG = [DM, BB, F, C, DM, BB, GM, AMAJ]
IRON_HIGH = [
    [(62, 1), (65, 1), (69, 2)], [(70, 1.5), (69, .5), (65, 2)], [(69, 1), (72, 1), (77, 1.5), (76, .5)], [(76, 1), (72, 1), (67, 2)],
    [(74, 1), (77, 1), (81, 2)], [(82, 1.5), (81, .5), (77, 2)], [(74, 1), (79, 1), (82, 1), (79, 1)], [(81, 1), (76, 1), (73, 2)],
]
IRON_LOW = [
    [(69, 2), (74, 2)], [(77, 2), (74, 2)], [(72, 2), (69, 2)], [(67, 3), (0, 1)],
    [(69, 2), (74, 2)], [(77, 1), (74, 1), (70, 2)], [(67, 1), (70, 1), (74, 2)], [(76, 2), (69, 2)],
]


def iron_hall():
    song = Song(100, 32 * 4)
    for section, phrase in enumerate([IRON_LOW, IRON_HIGH, IRON_LOW, IRON_HIGH]):
        for i in range(8):
            root, tones = IRON[IRON_PROG[i]]
            beat = (section * 8 + i) * 4
            for tone in tones:
                song.add(pad(tone, 4 * song.beat), beat, 0.17, rng.uniform(-0.5, 0.5), 0.6)
            # Driving bass: root on every beat, the fifth as a pickup.
            for k in range(4):
                song.add(bass(root, 0.8 * song.beat), beat + k, 0.5 if k % 2 == 0 else 0.36, 0.0, 0.04)
            song.add(bass(root + 7, 0.4 * song.beat), beat + 3.5, 0.3, 0.0, 0.04)
            for k in range(8):
                song.add(pluck(tones[[0, 1, 2, 1][k % 4]] + 12, 0.3, 0.8), beat + k * 0.5, 0.12, 0.35, 0.3)
            pos = 0.0
            for midi, dur in phrase[i]:
                if midi:
                    song.add(brass(midi - (12 if section % 2 == 1 else 0), dur * song.beat), beat + pos, 0.34, -0.15, 0.5)
                pos += dur
            song.add(kick(1.2), beat, 0.5, 0.0, 0.03)
            song.add(kick(0.9), beat + 2, 0.5, 0.0, 0.03)
            song.add(anvil(1.0), beat + 1, 0.16, -0.4, 0.6)
            song.add(anvil(1.0), beat + 3, 0.16, 0.4, 0.6)
            if section > 0:
                song.add(tom(45, 0.8), beat + 2.5, 0.25, -0.3, 0.3)
                song.add(tom(41, 0.9), beat + 3.5, 0.25, 0.3, 0.3)
    save(song, "iron_hall")


if __name__ == "__main__":
    menu()
    theme("backyard", 92, pluck, drums=False, calm=True)
    theme("garage", 98, pluck, drums=True)
    theme("bell_foundry", 88, bell, drums=False)
    iron_hall()
