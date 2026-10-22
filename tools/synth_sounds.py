#!/usr/bin/env python3
"""Sons sintetizados que não vêm de gravação (silenciador, abate, acerto, vento, avião)."""
import math
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = 44100
rng = np.random.default_rng(99)


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


def lp(x, fc):
    a = math.exp(-2 * math.pi * fc / R)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def hp(x, fc):
    return x - lp(x, fc)


def bp(x, lo, hi):
    return lp(hp(x, lo), hi)


def noise(d):
    return rng.uniform(-1, 1, int(d * R))


def reverb(x, dur=0.6, mix=0.3):
    n = int(dur * R)
    t = np.arange(n) / R
    ir = rng.standard_normal(n) * np.exp(-t * 7 / dur)
    ir[:int(0.01 * R)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.concatenate([x, np.zeros(n)])
    w = np.convolve(y, ir)[:len(y)]
    return y + w / (np.max(np.abs(w)) + 1e-9) * mix * np.max(np.abs(x))


def loopify(x, fade=0.25):
    """Junta o fim com o começo pra repetir sem estalo."""
    f = int(fade * R)
    out = x[f:].copy()
    out[-f:] = out[-f:] * np.linspace(1, 0, f) + x[:f] * np.linspace(0, 1, f)
    return out


# silenciador: sopro curto e fino ("stiu") + clique do ferrolho
t = t_(0.22)
puff = bp(noise(0.22), 2500, 9000) * np.exp(-t * 55)
sweep = np.sin(2 * np.pi * (4200 * t - 9000 * t * t)) * np.exp(-t * 40) * 0.35
click = np.zeros_like(t)
c = bp(noise(0.02), 1500, 6000) * np.exp(-t_(0.02) * 300)
o = int(0.035 * R)
click[o:o + len(c)] += c * 0.5
thump = np.sin(2 * np.pi * 140 * t) * np.exp(-t * 60) * 0.4
save("shot_silenced", puff + sweep + click + thump, 0.8)

# acerto: estalo seco
t = t_(0.07)
save("hit", np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 70) + bp(noise(0.07), 3000, 9000) * np.exp(-t * 160) * 0.5, 0.55)

# tiro na cabeça: "tim" metálico
t = t_(0.35)
tink = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) * a for f, d, a in [(2900, 14, 1.0), (4350, 18, 0.6), (6150, 24, 0.4), (8100, 30, 0.2)])
save("headshot", tink + bp(noise(0.35), 4000, 10000) * np.exp(-t * 120) * 0.4, 0.6)

# abate: pancada grave e agressiva (soco no peito + estalo seco + estrondo distorcido), sem sininho
t = t_(1.1)
sub = np.sin(2 * np.pi * np.cumsum(55 + 140 * np.exp(-t * 18)) / R) * np.exp(-t * 5.5)
thump = lp(noise(1.1), 180) * np.exp(-t * 22) * 3.0
crack = bp(noise(1.1), 1800, 7000) * np.exp(-t * 90) * 1.4
metal = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) * a for f, d, a in [(310, 16, 0.5), (523, 20, 0.35), (911, 26, 0.25)])
o = int(0.06 * R)
tail = np.zeros_like(t)
tail[o:] = (lp(noise(1.1), 400) * np.exp(-t * 4.0))[:len(t) - o] * 0.9
kill = np.tanh((sub * 1.6 + thump + crack + metal * 0.6 + tail) * 2.2)
save("kill", reverb(kill, 0.9, 0.3), 0.85)

# vento em queda livre: rugido forte com rajadas
d = 3.0
t = t_(d)
gust = 0.65 + 0.25 * np.sin(2 * np.pi * 0.7 * t) + 0.1 * np.sin(2 * np.pi * 1.9 * t + 1)
roar = lp(noise(d), 900) * 3 + bp(noise(d), 800, 3500) * 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.43 * t))
save("wind_fall", loopify(roar * gust), 0.8)

# vento no paraquedas: mais calmo, com o pano tremendo
t = t_(d)
soft = lp(noise(d), 500) * 2 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.35 * t))
flap = bp(noise(d), 200, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 7.5 * t) ** 2) * 0.5
save("wind_chute", loopify(soft + flap), 0.6)

# avião: motor a hélice
t = t_(d)
eng = sum(np.sin(2 * np.pi * f * t + p) * a for f, p, a in [(62, 0, 1.0), (124, 1, 0.6), (186, 2, 0.35), (248, 0.5, 0.2)])
eng *= 0.8 + 0.2 * np.sin(2 * np.pi * 15.5 * t)
eng += lp(noise(d), 600) * 1.2
save("plane", loopify(eng), 0.7)

# abrir paraquedas: pano estourando
t = t_(0.8)
pop = bp(noise(0.8), 150, 2500) * np.exp(-t * 5) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t))
pop[:int(0.03 * R)] *= np.linspace(0, 1, int(0.03 * R))
save("chute", pop + lp(noise(0.8), 200) * np.exp(-t * 9) * 2, 0.75)
print("ok")


# motor de carro (loop de 2 s): roncos em 38 Hz com harmônicos + chiado; o jogo muda o tom com a velocidade
d = 2.0
t = t_(d)
f0 = 38.0
eng = sum(np.sin(2 * np.pi * f0 * k * t + k) / k ** 0.8 for k in range(1, 9))
eng *= 0.7 + 0.3 * np.sign(np.sin(2 * np.pi * f0 * 2 * t))
eng += lp(noise(d), 900) * 0.6
eng = np.tanh(eng * 1.2)
save("engine", eng, 0.6)

# porta do carro
t = t_(0.3)
save("door", lp(noise(0.3), 700) * np.exp(-t * 25) * 2 + np.sin(2 * np.pi * 140 * t) * np.exp(-t * 30), 0.7)
