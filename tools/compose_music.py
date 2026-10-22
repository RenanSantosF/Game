#!/usr/bin/env python3
"""Música do lobby (composição própria, sintetizada): tropical house animada em Lá menor, 124 BPM.
32 compassos que repetem sem emenda. Gera sounds/lobby_music.ogg (precisa do ffmpeg).

Estrutura: intro (marimba + pad) -> drop (bumbo, palma, baixo no contratempo, pluck com eco)
-> ponte (outra harmonia, arpejo) -> drop 2 (lead dobrado)."""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = 44100
BPM = 124.0
BEAT = 60.0 / BPM
STEP = BEAT / 4.0            # semicolcheia
BAR = BEAT * 4.0
BARS = 32
N = int(round(BAR * BARS * R))
rng = np.random.default_rng(7)

L = np.zeros(N)
Rt = np.zeros(N)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def nm(s):
    """'A4' -> número MIDI"""
    return NOTE[s[:-1]] + 12 * (int(s[-1]) + 1)


def add(buf_l, buf_r, x, t0, pan=0.0, gain=1.0):
    i = int(round(t0 * R)) % N
    n = len(x)
    gl = gain * np.sqrt(0.5 * (1 - pan))
    gr = gain * np.sqrt(0.5 * (1 + pan))
    end = min(N, i + n)
    buf_l[i:end] += x[:end - i] * gl
    buf_r[i:end] += x[:end - i] * gr
    if i + n > N:     # o que passa do fim volta pro começo (loop sem corte)
        r = i + n - N
        buf_l[:r] += x[n - r:] * gl
        buf_r[:r] += x[n - r:] * gr


def tt(d):
    return np.arange(int(d * R)) / R


def onepole(x, fc):
    a = np.exp(-2 * np.pi * fc / R)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


# ---------------- instrumentos ----------------

def kick():
    t = tt(0.42)
    f = 46 + 110 * np.exp(-t * 32)
    x = np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t * 7.5)
    x[:200] += np.linspace(1, 0, 200) * 0.5
    return np.tanh(x * 1.8)


def clap():
    t = tt(0.28)
    nz = rng.uniform(-1, 1, len(t))
    bp = onepole(nz - onepole(nz, 900), 3500)
    env = np.zeros_like(t)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        env += (t >= d) * np.exp(-np.clip(t - d, 0, None) * (90 if k < 2 else 16))
    return bp * env * 3.0


def hat(open_=False):
    t = tt(0.25 if open_ else 0.06)
    nz = rng.uniform(-1, 1, len(t))
    x = nz - onepole(nz, 6500)
    return x * np.exp(-t * (14 if open_ else 70))


def shaker():
    t = tt(0.07)
    nz = rng.uniform(-1, 1, len(t))
    x = nz - onepole(nz, 4500)
    return x * np.sin(np.pi * np.clip(t / 0.07, 0, 1)) ** 2 * 0.6


def pluck(f, d, bright=1.0):
    t = tt(d)
    x = np.zeros_like(t)
    for k in range(1, 14):
        if f * k > 9000:
            break
        x += np.sin(2 * np.pi * f * k * t + k * 0.7) / k * np.exp(-t * (4.0 + k * 2.2 / bright))
    x += np.sin(2 * np.pi * f * 0.5 * t) * 0.25 * np.exp(-t * 5)
    att = np.clip(t / 0.003, 0, 1)
    return x * att


def marimba(f, d):
    t = tt(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 6) + np.sin(2 * np.pi * f * 3.98 * t) * 0.35 * np.exp(-t * 22)
    x += np.sin(2 * np.pi * f * 9.9 * t) * 0.08 * np.exp(-t * 60)
    return x * np.clip(t / 0.002, 0, 1)


def supersaw(f, d, harm=12, voices=5, spread=0.012):
    t = tt(d)
    out_l = np.zeros_like(t)
    out_r = np.zeros_like(t)
    for v in range(voices):
        det = 1 + spread * (v - (voices - 1) / 2) / ((voices - 1) / 2)
        ph = rng.uniform(0, 2 * np.pi)
        x = np.zeros_like(t)
        for k in range(1, harm + 1):
            if f * det * k > 8000:
                break
            x += np.sin(2 * np.pi * f * det * k * t + ph * k) / k
        p = (v / (voices - 1)) * 2 - 1
        out_l += x * (1 - p) * 0.5
        out_r += x * (1 + p) * 0.5
    a = np.clip(t / 0.02, 0, 1) * np.clip((d - t) / 0.05, 0, 1)
    return out_l * a / voices, out_r * a / voices


def bass(f, d):
    t = tt(d)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t) + 0.12 * np.sin(2 * np.pi * f * 3 * t)
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t * 5.5)
    return np.tanh(x * env * 1.6)


def riser(d):
    t = tt(d)
    nz = rng.uniform(-1, 1, len(t))
    x = nz - onepole(nz, 1200)
    return x * (t / d) ** 2.2 * 0.5


def crash():
    t = tt(1.8)
    nz = rng.uniform(-1, 1, len(t))
    x = nz - onepole(nz, 3000)
    return x * np.exp(-t * 2.5) * 0.6


# ---------------- harmonia e melodia ----------------

CH_A = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"]]      # Am F C G
CH_B = [["F3", "A3", "C4"], ["G3", "B3", "D4"], ["E3", "G3", "B3"], ["A3", "C4", "E4"]]      # F G Em Am
ROOT_A = ["A1", "F1", "C2", "G1"]
ROOT_B = ["F1", "G1", "E1", "A1"]

# gancho (2 compassos cada, em semicolcheias): (passo, nota, duração)
HOOK1 = [(0, "E5", 2), (2, "E5", 1), (3, "D5", 1), (4, "C5", 2), (6, "D5", 2), (8, "E5", 3), (11, "G5", 1), (12, "E5", 2),
         (14, "D5", 2), (16, "C5", 2), (18, "C5", 1), (19, "A4", 1), (20, "C5", 2), (22, "D5", 2), (24, "C5", 3), (27, "A4", 1), (28, "G4", 4)]
HOOK2 = [(0, "E5", 2), (2, "E5", 1), (3, "D5", 1), (4, "C5", 2), (6, "D5", 2), (8, "E5", 3), (11, "G5", 1), (12, "A5", 2),
         (14, "G5", 2), (16, "E5", 2), (18, "D5", 1), (19, "C5", 1), (20, "D5", 4), (24, "B4", 2), (26, "D5", 2), (28, "G4", 4)]
BRIDGE = [(0, "A4", 2), (2, "C5", 2), (4, "F5", 4), (8, "E5", 2), (10, "D5", 2), (12, "B4", 4), (16, "B4", 2), (18, "D5", 2),
          (20, "G5", 4), (24, "E5", 3), (27, "D5", 1), (28, "E5", 4)]


def section(bar0):
    if bar0 < 8:
        return "intro"
    if bar0 < 16:
        return "drop"
    if bar0 < 24:
        return "ponte"
    return "drop2"


def delay_echo(x, t_d, fb=0.33, taps=3):
    d = int(t_d * R)
    y = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        y[d * k:d * k + len(x)] += x * fb ** k
    return y


K = kick()
CL = clap()
HT = hat()
HO = hat(True)
SH = shaker()

for bar in range(BARS):
    sec = section(bar)
    t0 = bar * BAR
    chords = CH_B if sec == "ponte" else CH_A
    roots = ROOT_B if sec == "ponte" else ROOT_A
    ch = chords[bar % 4]
    full = sec in ("drop", "drop2")
    # pad (com "respiração" do sidechain nos drops)
    harm = 12 if full else 6
    pl = np.zeros(int(BAR * R) + 1)
    pr = np.zeros(int(BAR * R) + 1)
    for n in ch:
        a, b = supersaw(midi(nm(n)), BAR, harm)
        pl[:len(a)] += a
        pr[:len(b)] += b
    tb = np.arange(len(pl)) / R
    if full or (sec == "intro" and bar >= 4) or sec == "ponte":
        pump = 1 - 0.75 * np.exp(-(tb % BEAT) * 9)
    else:
        pump = np.ones_like(tb)
    vol = 0.22 if full else 0.16
    add(L, Rt, pl * pump, t0, -0.6, vol)
    add(L, Rt, pr * pump, t0, 0.6, vol)
    # bateria
    if full or sec == "ponte" or bar >= 4:
        for b in range(4):
            if sec == "ponte" and bar % 4 == 3 and b >= 2:
                continue
            add(L, Rt, K, t0 + b * BEAT, 0.0, 0.95 if full else 0.7)
    if full or sec == "ponte":
        for b in (1, 3):
            add(L, Rt, CL, t0 + b * BEAT, 0.0, 0.42)
    for s in range(16):
        if s % 4 == 2:
            add(L, Rt, HO if full else HT, t0 + s * STEP, 0.25, 0.22 if full else 0.16)
        elif full and s % 2 == 1:
            add(L, Rt, HT, t0 + s * STEP, 0.35, 0.1)
        add(L, Rt, SH, t0 + s * STEP, -0.4, 0.06 + 0.04 * (s % 2))
    # baixo no contratempo (pa-pa-pa típico de tropical) + nota longa no 1
    if full or sec == "ponte":
        f = midi(nm(roots[bar % 4]) + 12)
        add(L, Rt, bass(f, 0.5), t0, 0.0, 0.55)
        for b in range(4):
            add(L, Rt, bass(f, 0.22), t0 + b * BEAT + BEAT / 2, 0.0, 0.5)
    # melodia
    if bar % 2 == 0:
        if sec == "ponte":
            mel = BRIDGE
        else:
            mel = HOOK1 if (bar // 2) % 2 == 0 else HOOK2
        for (st, n, ln) in mel:
            f = midi(nm(n))
            d = ln * STEP
            if sec == "intro":
                x = marimba(f, d + 0.5)
                add(L, Rt, delay_echo(x, STEP * 3, 0.28, 2), t0 + st * STEP, 0.15, 0.32)
            else:
                x = pluck(f, d + 0.35, 1.0 if sec != "drop2" else 1.4)
                ech = delay_echo(x, STEP * 3, 0.32, 3)
                add(L, Rt, ech, t0 + st * STEP, -0.2, 0.36)
                add(L, Rt, ech, t0 + st * STEP + 0.012, 0.3, 0.2)
                if sec == "drop2":
                    # lead dobrado uma oitava acima
                    add(L, Rt, pluck(f * 2, d + 0.3, 1.2), t0 + st * STEP, 0.4, 0.14)
                if sec == "drop":
                    add(L, Rt, marimba(f / 2, d + 0.3), t0 + st * STEP, -0.4, 0.12)
    # arpejo na ponte
    if sec == "ponte":
        notes = [nm(n) + 12 for n in ch]
        for s in range(16):
            n = notes[[0, 1, 2, 1][s % 4]] + (12 if s % 8 >= 4 else 0)
            add(L, Rt, marimba(midi(n), 0.25), t0 + s * STEP, 0.5 if s % 2 else -0.5, 0.09)
    # subida e prato nas viradas
    if bar in (7, 15, 23, 31):
        add(L, Rt, riser(BAR), t0, 0.0, 0.55)
        for s in range(8, 16):
            add(L, Rt, CL, t0 + s * STEP, 0.0, 0.12 + 0.03 * (s - 8))
    if bar in (0, 8, 16, 24):
        add(L, Rt, crash(), t0, 0.1, 0.5)

mix = np.stack([L, Rt], axis=1)
mix = np.tanh(mix * 1.15)
mix = mix / np.max(np.abs(mix)) * 0.84
tmp = os.path.join(ROOT, "sounds", "_lobby_tmp.wav")
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(R)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
out = os.path.join(ROOT, "sounds", "lobby_music.ogg")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
os.remove(tmp)
print("ok", out, "%.1f s" % (N / R))
