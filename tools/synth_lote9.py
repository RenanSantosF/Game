#!/usr/bin/env python3
"""Sons do lote 9: troca de arma "bruta" (bomba de escopeta 12) e batida de carro grave."""
import math
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = 44100
rng = np.random.default_rng(909)


def save(name, x, gain=0.9):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(os.path.join(ROOT, "sounds", name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def t_(d):
    return np.arange(int(d * R)) / R


def noise(d):
    return rng.uniform(-1, 1, int(d * R))


def lp(x, fc, o=2):
    b, a = butter(o, fc / (R / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc, o=2):
    b, a = butter(o, fc / (R / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi):
    return lp(hp(x, lo), hi)


def metal(d, freqs, decay):
    t = t_(d)
    return sum(np.sin(2 * np.pi * f * t + i) * np.exp(-t * decay * (1 + i * 0.25)) / (1 + i * 0.4) for i, f in enumerate(freqs))


def place(buf, x, at):
    i = int(at * R)
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n]


def mix(*xs):
    n = max(len(a) for a in xs)
    out = np.zeros(n)
    for a in xs:
        out[: len(a)] += a
    return out


def room(x, dur=0.25, mix=0.25):
    n = int(dur * R)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / R * 18 / dur)
    ir[: int(0.004 * R)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.concatenate([x, np.zeros(n)])
    w = np.convolve(y, ir)[: len(y)]
    return y + w / (np.max(np.abs(w)) + 1e-9) * mix * np.max(np.abs(x))


# troca de arma: "CHK-CHAK" de bomba de escopeta 12 — trilho raspando pra trás com um estalo seco,
# e a volta pra frente batendo forte (metal pesado + pancada grave no corpo da arma)
d = 0.62
x = np.zeros(int(d * R))
grab = bp(noise(0.05), 400, 2500) * np.exp(-t_(0.05) * 80) * 0.5
back_slide = bp(noise(0.09), 900, 6000) * np.sin(np.pi * t_(0.09) / 0.09) ** 1.5 * 0.7
back_hit = mix(metal(0.12, [820, 1510, 2380, 3700, 5200], 38) * 1.1, bp(noise(0.06), 1800, 9000) * np.exp(-t_(0.06) * 120) * 0.9)
fwd_slide = bp(noise(0.07), 1000, 6500) * np.sin(np.pi * t_(0.07) / 0.07) ** 1.5 * 0.6
fwd_hit = mix(metal(0.22, [640, 1180, 1960, 3050, 4400], 26) * 1.4, bp(noise(0.08), 1500, 8000) * np.exp(-t_(0.08) * 90))
thump = np.sin(2 * np.pi * np.cumsum(70 + 110 * np.exp(-t_(0.25) * 30)) / R) * np.exp(-t_(0.25) * 16) * 1.3
place(x, grab, 0.0)
place(x, back_slide, 0.03)
place(x, back_hit, 0.12)
place(x, fwd_slide, 0.25)
place(x, mix(fwd_hit, thump), 0.32)
save("switch", room(np.tanh(x * 2.2), 0.3, 0.22), 0.95)

# batida de carro: pancada grave e pesada (lataria amassando, sem chiado fino)
d = 1.2
t = t_(d)
x = np.zeros(int(d * R))
boom = np.sin(2 * np.pi * np.cumsum(45 + 90 * np.exp(-t * 18)) / R) * np.exp(-t * 6) * 2.0
crunch = lp(noise(d), 1400, 3) * np.exp(-t * 9) * 1.6
dent = metal(0.6, [180, 310, 470, 690, 980], 9) * 0.9
debris = np.zeros(int(d * R))
for i in range(5):
    c = lp(noise(0.08), 2200) * np.exp(-t_(0.08) * 50) * rng.uniform(0.3, 0.6)
    place(debris, c, 0.12 + i * rng.uniform(0.05, 0.12))
place(x, boom + crunch, 0.0)
place(x, dent, 0.01)
x += debris
save("crash", room(np.tanh(lp(x, 3500, 2) * 1.8), 0.5, 0.3), 0.95)
print("lote 9 ok")
