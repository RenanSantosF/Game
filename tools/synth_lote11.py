#!/usr/bin/env python3
"""Sons do lote 11: troca de arma (gravações reais de ferrolho/engatilhar, CC0) e abate estrondoso.

Fontes (CC0, opengameart.org):
  - "equipment clicks III" (LFA): equipment_clicks3.wav  -> estalos de ferrolho de rifle de verdade
  - "Gun reload sounds" (SpringySpringo): assaultriflereload1_0.wav, shotguncock_0.wav
Uso: python3 tools/synth_lote11.py <pasta_com_os_wav_baixados>
Precisa de ffmpeg, numpy e scipy. Saída: sounds/switch.wav, sounds/kill.wav
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import butter, lfilter, resample

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = 44100
rng = np.random.default_rng(1111)
SRC = sys.argv[1] if len(sys.argv) > 1 else "."


def load(name):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC, name), "-ac", "1", "-ar", str(R), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def save(name, x, gain=0.92):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(os.path.join(ROOT, "sounds", name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def t_(d):
    return np.arange(int(d * R)) / R


def lp(x, fc, o=2):
    b, a = butter(o, fc / (R / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc, o=2):
    b, a = butter(o, fc / (R / 2), "high")
    return lfilter(b, a, x)


def cut(x, at, d):
    i = int(at * R)
    y = x[i:i + int(d * R)].copy()
    f = int(0.004 * R)
    y[:f] *= np.linspace(0, 1, f)
    y[-f * 4:] *= np.linspace(1, 0, f * 4)
    return y


def pitch(x, k):
    """k < 1 deixa mais grave e mais "pesado" (estica)."""
    return resample(x, int(len(x) / k))


def place(buf, x, at, g=1.0):
    i = int(at * R)
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * g


def room(x, dur=0.3, amt=0.25):
    n = int(dur * R)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / R * 14 / dur)
    ir[: int(0.006 * R)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.concatenate([x, np.zeros(n)])
    w = np.convolve(y, ir)[: len(y)]
    return y + w / (np.max(np.abs(w)) + 1e-9) * amt * np.max(np.abs(x))


def thunk(d, f0, f1, decay):
    """pancada grave de metal/madeira (corpo da arma batendo na mão)."""
    t = t_(d)
    f = f1 + (f0 - f1) * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / R
    return np.sin(ph) * np.exp(-t * decay)


def soft_clip(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


clicks = load("equipment_clicks3.wav")
rifle = load("assaultriflereload1_0.wav")
pump = load("shotguncock_0.wav")

# ---- troca de arma: pega a arma (pano/correia), puxa o ferrolho pra trás e solta batendo ----
d = 0.75
x = np.zeros(int(d * R))
# roupa/correia raspando ao puxar a arma (ruído grave, curto)
rus = hp(lp(rng.uniform(-1, 1, int(0.16 * R)), 1400), 150) * np.sin(np.linspace(0, np.pi, int(0.16 * R))) ** 1.5
place(x, rus, 0.0, 0.35)
# trava/ferrolho de rifle de verdade, mais grave (arma pesada): "TCHK"
c1 = pitch(cut(clicks, 2.16, 0.2), 0.78)
place(x, c1, 0.09, 1.0)
place(x, thunk(0.16, 260, 120, 28), 0.095, 0.55)
# volta do ferrolho batendo: "TCHAK" (gravação do fuzil, também mais grave) + pancada no corpo
c2 = pitch(cut(rifle, 1.18, 0.24), 0.82)
place(x, c2, 0.27, 1.05)
place(x, pitch(cut(clicks, 0.2, 0.22), 0.7), 0.275, 0.55)
place(x, thunk(0.22, 210, 85, 18), 0.28, 0.8)
x = hp(x, 70)
x = soft_clip(x / (np.max(np.abs(x)) + 1e-9), 1.6)
save("switch", room(x, 0.22, 0.18))

# ---- abate: estrondo grave e pesado (pancada de baixo + estalo metálico + cauda de eco) ----
d = 1.5
k = np.zeros(int(d * R))
t = t_(1.1)
# bumbo de cinema: varre de 140 Hz pra 38 Hz, longo
f = 38 + 110 * np.exp(-t * 9)
boom = np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-t * 3.2)
place(k, soft_clip(boom, 2.5), 0.0, 1.0)
# estalo inicial forte (ataque) — ruído curto filtrado
att = lp(rng.uniform(-1, 1, int(0.05 * R)), 3500) * np.exp(-t_(0.05) * 70)
place(k, att, 0.0, 0.8)
# metal pesado (ferrolho bem grave) dando o "CLANG" de impacto
place(k, pitch(cut(pump, 0.05, 0.3), 0.55), 0.01, 0.6)
place(k, pitch(cut(clicks, 2.16, 0.2), 0.5), 0.015, 0.45)
# segundo golpe grave logo depois ("BOOM-BOOM")
t2 = t_(0.7)
f2 = 34 + 70 * np.exp(-t2 * 12)
place(k, soft_clip(np.sin(2 * np.pi * np.cumsum(f2) / R) * np.exp(-t2 * 4.5), 2.0), 0.16, 0.7)
# sub-ronco que cresce e some (dá peso)
rum = lp(rng.uniform(-1, 1, int(1.3 * R)), 180) * np.exp(-t_(1.3) * 2.5)
place(k, rum, 0.0, 0.9)
k = soft_clip(k / (np.max(np.abs(k)) + 1e-9), 2.2)
save("kill", room(k, 0.8, 0.3), 0.95)
print("ok: switch.wav, kill.wav")
